#!/usr/bin/env bash
# Containerfile test suite for container/opencode.
#
# Stages:
#   1. Lint      — hadolint static analysis of the Containerfile
#   2. Build     — docker build of the image under test
#   3. Structure — GoogleContainerTools/container-structure-test against the
#                  built image (metadata, files, installed tooling — see
#                  container-structure-test.yaml)
#   4. Smoke     — run the container with the opencode entrypoint and confirm it
#                  reports a version (proves subcommand pass-through works)
#
# Usage:
#   ./test.sh              # run everything
#   ./test.sh lint         # run a single stage
#   SKIP_BUILD=1 ./test.sh # reuse a previously built image tag
#
# Requirements: bash, docker, hadolint, container-structure-test.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_DIR="$(cd "${HERE}/.." && pwd)"
CONTAINERFILE="${CONTEXT_DIR}/Containerfile"
IMAGE_TAG="${IMAGE_TAG:-do-ob/opencode:test}"
CONTAINER_NAME="${CONTAINER_NAME:-do-ob-opencode-test}"

log()  { printf '\033[1;34m[test]\033[0m %s\n' "$*" >&2; }
pass() { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
    exit 127
  fi
}

stage_lint() {
  log "lint: hadolint ${CONTAINERFILE}"
  require hadolint
  hadolint "${CONTAINERFILE}"
  pass "hadolint clean"
}

stage_build() {
  if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    log "build: skipped (SKIP_BUILD=1); expecting ${IMAGE_TAG} to exist"
    return
  fi
  log "build: docker build -t ${IMAGE_TAG} ${CONTEXT_DIR}"
  require docker
  docker build \
    --file "${CONTAINERFILE}" \
    --tag "${IMAGE_TAG}" \
    "${CONTEXT_DIR}"
  pass "image built: ${IMAGE_TAG}"
}

stage_structure() {
  log "structure: container-structure-test against ${IMAGE_TAG}"
  require docker
  require container-structure-test
  container-structure-test test \
    --image "${IMAGE_TAG}" \
    --config "${HERE}/container-structure-test.yaml"
  pass "structure tests passed"
}

stage_smoke() {
  log "smoke: run ${IMAGE_TAG} and confirm opencode reports a version"
  require docker

  local out status
  set +e
  out="$(docker run --rm --name "${CONTAINER_NAME}" "${IMAGE_TAG}" --version 2>&1)"
  status=$?
  set -e

  if [[ "${status}" -ne 0 ]]; then
    fail "opencode --version exited with ${status}:"
    printf '%s\n' "${out}" >&2
    exit 1
  fi

  if grep -Eq '[0-9]+\.[0-9]+\.[0-9]+' <<<"${out}"; then
    pass "opencode reported a version: ${out}"
    return
  fi

  fail "unexpected --version output:"
  printf '%s\n' "${out}" >&2
  exit 1
}

run_all() {
  stage_lint
  stage_build
  stage_structure
  stage_smoke
  pass "all container tests passed"
}

main() {
  case "${1:-all}" in
    all)       run_all ;;
    lint)      stage_lint ;;
    build)     stage_build ;;
    structure) stage_build; stage_structure ;;
    smoke)     stage_build; stage_smoke ;;
    *)
      fail "unknown stage: $1"
      echo "usage: $0 [all|lint|build|structure|smoke]" >&2
      exit 2
      ;;
  esac
}

main "$@"
