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

exec opencode "$@"
