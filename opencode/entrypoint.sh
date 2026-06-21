#!/usr/bin/env bash
# Container entrypoint for the opencode image.
#
# On the first container start it kicks off the Playwright browser download in
# the background so opencode is available immediately, then hands off to
# opencode with whatever subcommand and flags were passed to `docker run`.
#
# The browsers land in the Playwright cache (~/.cache/ms-playwright). A marker
# file records a completed install so subsequent starts — and restarts when the
# home directory is persisted via a volume — skip the download. Set
# OPENCODE_SKIP_BROWSER_INSTALL=1 to opt out entirely.

set -euo pipefail

# Space-separated list; override to fetch a subset, e.g. "chromium".
PLAYWRIGHT_BROWSERS="${PLAYWRIGHT_BROWSERS:-chromium}"

marker="${HOME}/.cache/ms-playwright/.opencode-browsers-installed"
log="${HOME}/.cache/playwright-install.log"

if [ "${OPENCODE_SKIP_BROWSER_INSTALL:-0}" != "1" ] \
  && command -v playwright >/dev/null 2>&1 \
  && [ ! -f "${marker}" ]; then
  (
    mkdir -p "${HOME}/.cache"
    if playwright install ${PLAYWRIGHT_BROWSERS} >"${log}" 2>&1; then
      mkdir -p "$(dirname "${marker}")"
      touch "${marker}"
    fi
  ) &
fi

# ------------------------------------------------------------------------------
# Optional git configuration
#
# Applied at runtime (never at build) so the personal access token is taken from
# the container environment and is never baked into an image layer. Each piece
# is configured independently and only when its variables are present:
#   GIT_USER_NAME + GIT_USER_EMAIL -> global identity
#   GIT_USER_NAME + GIT_USER_PAT   -> HTTPS credential in the per-user store
#                                     (~/.git-credentials) for GIT_HOST
# GIT_HOST defaults to github.com. This runs before the clones below so private
# REPOSITORY_X repositories can authenticate.
# ------------------------------------------------------------------------------
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  echo "entrypoint: configuring git identity for ${GIT_USER_NAME}"
  git config --global user.name "${GIT_USER_NAME}"
  git config --global user.email "${GIT_USER_EMAIL}"
fi

if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_PAT:-}" ]; then
  echo "entrypoint: storing git HTTPS credentials for ${GIT_HOST:-github.com}"
  git config --global credential.helper store
  printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n' \
    "${GIT_HOST:-github.com}" "${GIT_USER_NAME}" "${GIT_USER_PAT}" \
    | git credential approve
fi

# ------------------------------------------------------------------------------
# Optional project repositories
#
# Clone REPOSITORY_0, REPOSITORY_1, ... (numbered from 0, stopping at the first
# unset variable) into ~/projects. Each repository is checked out into its own
# subdirectory named after the repository. A repository is skipped when its
# target directory is already a git checkout (e.g. a persisted volume) or holds
# unrelated files (e.g. a bind mount), so existing work is never clobbered.
#
# This runs after the git configuration above so private repositories can
# authenticate: HTTPS with a token, or SSH (git@host:org/repo.git) by mounting
# an ssh key directory to /home/opencode/.ssh.
# ------------------------------------------------------------------------------
mkdir -p "${HOME}/projects"

declare -a project_dirs=()
index=0
while true; do
  repo_var="REPOSITORY_${index}"
  repo_url="${!repo_var:-}"
  [ -n "${repo_url}" ] || break

  repo_name="$(basename "${repo_url}" .git)"
  repo_dir="${HOME}/projects/${repo_name}"

  if [ -d "${repo_dir}/.git" ]; then
    echo "entrypoint: ${repo_dir} is already a git repo; skipping clone of ${repo_url}"
  elif [ -d "${repo_dir}" ] && [ -n "$(ls -A "${repo_dir}" 2>/dev/null)" ]; then
    echo "entrypoint: ${repo_dir} is not empty and not a git repo; skipping clone of ${repo_url}" >&2
  else
    echo "entrypoint: cloning ${repo_url} into ${repo_dir}"
    git clone "${repo_url}" "${repo_dir}"
  fi

  project_dirs+=("${repo_dir}")
  index=$((index + 1))
done

# ------------------------------------------------------------------------------
# Optional per-project setup scripts
#
# For each cloned repository (in order, from REPOSITORY_0), run a root setup.sh
# if present. Each script runs from within its own repository directory so its
# relative paths resolve there. A non-zero exit is logged but does not stop
# opencode from starting.
# ------------------------------------------------------------------------------
if [ "${#project_dirs[@]}" -gt 0 ]; then
  for repo_dir in "${project_dirs[@]}"; do
    if [ -f "${repo_dir}/setup.sh" ]; then
      echo "entrypoint: running setup script ${repo_dir}/setup.sh"
      ( cd "${repo_dir}" && bash setup.sh ) \
        || echo "entrypoint: ${repo_dir}/setup.sh exited non-zero; continuing" >&2
    fi
  done
fi

# Start opencode in the projects directory.
cd "${HOME}/projects"

exec opencode "$@"
