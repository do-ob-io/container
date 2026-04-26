#!/usr/bin/env bash
# Test and publish all container images under container/.
#
# For each immediate subdirectory:
#   1. Runs <project>/test/test.sh.
#   2. If the tests pass, builds and pushes the image to the registry and
#      syncs the project's README.md to the Docker Hub repository.
#   3. If the tests fail, the project is skipped (not published) but the
#      script continues with the remaining projects.
#
# At the end, the script prints a summary listing which projects were
# successfully published, which failed tests, and which failed publish.
#
# Usage:
#   ./publish.sh                # test + publish every project
#   ./publish.sh caddy [...]    # only the named projects
#   ./publish.sh --dry-run      # run tests, but only print publish commands
#
# Environment:
#   NAMESPACE   Docker Hub namespace (default: do-ob)
#   REGISTRY    Registry host        (default: docker.io)
#   TAG         Image tag            (default: latest)
#
# Requirements:
#   - docker CLI, authenticated against the target registry
#     (e.g. `docker login`).
#   - `docker pushrm` plugin for syncing READMEs:
#     https://github.com/christian-korneck/docker-pushrm

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-do-ob}"
REGISTRY="${REGISTRY:-docker.io}"
TAG="${TAG:-latest}"
DRY_RUN=0

log()  { printf '\033[1;34m[container/publish]\033[0m %s\n' "$*" >&2; }
pass() { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
    exit 127
  fi
}

# Run a command, or print it if --dry-run is set.
run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    printf '\033[1;33m[dry-run]\033[0m + %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

# Parse args: flags vs project names.
projects=()
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      fail "unknown flag: ${arg}"
      exit 2
      ;;
    *) projects+=("${arg}") ;;
  esac
done

# Always validate docker; only validate pushrm for real publishes.
require docker
if [[ "${DRY_RUN}" != "1" ]]; then
  if ! docker pushrm --help >/dev/null 2>&1; then
    fail "docker pushrm plugin not installed (https://github.com/christian-korneck/docker-pushrm)"
    exit 127
  fi
fi

# Default project list = every subdirectory containing a Containerfile.
if [[ ${#projects[@]} -eq 0 ]]; then
  for dir in "${HERE}"/*/; do
    [[ -f "${dir}Containerfile" ]] && projects+=("$(basename "${dir}")")
  done
fi

if [[ ${#projects[@]} -eq 0 ]]; then
  fail "no projects with a Containerfile found under ${HERE}"
  exit 1
fi

published=()
test_failed=()
publish_failed=()

for name in "${projects[@]}"; do
  ctx="${HERE}/${name}"
  containerfile="${ctx}/Containerfile"
  readme="${ctx}/README.md"
  test_script="${ctx}/test/test.sh"
  repo="${REGISTRY}/${NAMESPACE}/${name}"
  image="${repo}:${TAG}"

  if [[ ! -f "${containerfile}" ]]; then
    fail "${name}: missing Containerfile, skipping"
    test_failed+=("${name}")
    continue
  fi

  log "==> ${name}: testing"
  if [[ ! -x "${test_script}" ]]; then
    fail "${name}: missing or non-executable ${test_script}"
    test_failed+=("${name}")
    continue
  fi
  if ! "${test_script}"; then
    fail "${name}: tests failed, will not publish"
    test_failed+=("${name}")
    continue
  fi
  pass "${name}: tests passed"

  log "==> ${name}: publish ${image}"

  if ! run docker build --file "${containerfile}" --tag "${image}" "${ctx}"; then
    fail "${name}: build failed"
    publish_failed+=("${name}")
    continue
  fi
  if [[ "${TAG}" != "latest" ]]; then
    run docker tag "${image}" "${repo}:latest"
  fi

  if ! run docker push "${image}"; then
    fail "${name}: push failed"
    publish_failed+=("${name}")
    continue
  fi
  if [[ "${TAG}" != "latest" ]]; then
    run docker push "${repo}:latest"
  fi

  if [[ -f "${readme}" ]]; then
    if ! run docker pushrm --file "${readme}" "${repo}"; then
      fail "${name}: pushrm failed"
      publish_failed+=("${name}")
      continue
    fi
  else
    warn "${name}: no README.md found, skipping pushrm"
  fi

  published+=("${image}")
  pass "${name}: published as ${image}"
done

# ---- Summary -----------------------------------------------------------------
echo
if [[ "${DRY_RUN}" == "1" ]]; then
  log "summary (dry-run)"
else
  log "summary"
fi

if [[ ${#published[@]} -gt 0 ]]; then
  if [[ "${DRY_RUN}" == "1" ]]; then
    pass "would publish (${#published[@]}):"
  else
    pass "published (${#published[@]}):"
  fi
  for img in "${published[@]}"; do
    printf '  - %s\n' "${img}" >&2
  done
fi
if [[ ${#test_failed[@]} -gt 0 ]]; then
  fail "test failures (${#test_failed[@]}): ${test_failed[*]}"
fi
if [[ ${#publish_failed[@]} -gt 0 ]]; then
  fail "publish failures (${#publish_failed[@]}): ${publish_failed[*]}"
fi

if [[ ${#test_failed[@]} -gt 0 || ${#publish_failed[@]} -gt 0 ]]; then
  exit 1
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  pass "all container projects would be published"
else
  pass "all container projects published"
fi
