#!/usr/bin/env bash
# Containerfile test suite for container/caddy.
#
# Stages:
#   1. Lint     — hadolint static analysis of the Containerfile
#   2. Build    — docker build of the image under test
#   3. Structure — GoogleContainerTools/container-structure-test against the
#                  built image (metadata, files, commands — see
#                  container-structure-test.yaml)
#   4. Smoke    — run the container and curl it to confirm it actually serves
#                 the bundled index.html on :80
#
# Usage:
#   ./test.sh              # run everything
#   ./test.sh lint         # run a single stage
#   SKIP_BUILD=1 ./test.sh # reuse a previously built image tag
#
# Requirements: bash, docker, hadolint. container-structure-test is
# auto-downloaded into .cache/ if it is not already on PATH. The smoke stage
# uses a throwaway curl container (curlimages/curl) so the test works the
# same whether run on a host or inside a dev container where the Docker
# daemon lives on a different network than the caller.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_DIR="$(cd "${HERE}/.." && pwd)"
CONTAINERFILE="${CONTEXT_DIR}/Containerfile"
IMAGE_TAG="${IMAGE_TAG:-do-ob/caddy:test}"
CONTAINER_NAME="${CONTAINER_NAME:-do-ob-caddy-test}"
CACHE_DIR="${HERE}/.cache"
CST_VERSION="${CST_VERSION:-v1.19.3}"

log()  { printf '\033[1;34m[test]\033[0m %s\n' "$*" >&2; }
pass() { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
    exit 127
  fi
}

ensure_cst() {
  if command -v container-structure-test >/dev/null 2>&1; then
    echo "container-structure-test"
    return
  fi
  mkdir -p "${CACHE_DIR}"
  local bin="${CACHE_DIR}/container-structure-test"
  if [[ ! -x "${bin}" ]]; then
    local os arch url
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$(uname -m)" in
      x86_64|amd64) arch="amd64" ;;
      aarch64|arm64) arch="arm64" ;;
      *) fail "unsupported arch: $(uname -m)"; exit 1 ;;
    esac
    url="https://github.com/GoogleContainerTools/container-structure-test/releases/download/${CST_VERSION}/container-structure-test-${os}-${arch}"
    log "downloading container-structure-test ${CST_VERSION} (${os}/${arch})"
    curl -fsSL -o "${bin}" "${url}"
    chmod +x "${bin}"
  fi
  echo "${bin}"
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
  local cst
  cst="$(ensure_cst)"
  "${cst}" test \
    --image "${IMAGE_TAG}" \
    --config "${HERE}/container-structure-test.yaml"
  pass "structure tests passed"
}

stage_smoke() {
  log "smoke: run ${IMAGE_TAG} and curl the file_server"
  require docker

  # Clean up any prior run.
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

  # No host port mapping: we curl from a sibling container that shares this
  # one's network namespace. This works identically on a developer host and
  # inside a dev container where the Docker daemon lives elsewhere.
  docker run -d --rm --name "${CONTAINER_NAME}" "${IMAGE_TAG}" >/dev/null
  trap 'docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true' EXIT

  local url='http://127.0.0.1:80/'
  log "smoke: waiting for ${url} (via --network container:${CONTAINER_NAME})"

  local attempt status body
  for attempt in $(seq 1 30); do
    if body="$(docker run --rm \
        --network "container:${CONTAINER_NAME}" \
        curlimages/curl:latest \
        -fsS -w '\n%{http_code}' "${url}" 2>/dev/null)"; then
      status="${body##*$'\n'}"
      body="${body%$'\n'*}"
      if [[ "${status}" == "200" ]] && grep -q 'do-ob Caddy Works!' <<<"${body}"; then
        pass "served expected index.html (HTTP ${status})"
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        trap - EXIT
        return
      fi
      fail "unexpected response (status=${status}):"
      printf '%s\n' "${body}" >&2
      exit 1
    fi
    sleep 0.5
  done

  fail "caddy did not respond on ${url} in time"
  docker logs "${CONTAINER_NAME}" >&2 || true
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
