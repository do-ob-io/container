# container Tool

Build, test, and publish open-source container images. Each subdirectory is a self-contained image project with its own `Containerfile`, `README.md`, and test suite.

## Quality Instructions

- **Test**: `./<project>/test/test.sh` — runs the project's lint → build → structure → smoke pipeline
- **Test all**: `./publish.sh --dry-run` — tests every project and prints (without executing) publish commands
- **Publish**: `./publish.sh` — tests then builds, pushes, and syncs READMEs to Docker Hub for every project

## Structure

- `publish.sh` — Iterates every project; runs its tests, then builds, pushes, and syncs its README via `docker pushrm`. Continues on failure and reports a final summary.
- `<project>/Containerfile` — Image definition.
- `<project>/README.md` — Synced to the Docker Hub repository description on publish.
- `<project>/test/test.sh` — Per-project test suite (lint, build, structure, smoke).
- `<project>/test/container-structure-test.yaml` — Declarative image structure assertions.

## Technical Stack

- **Languages**: Bash, Containerfile (Docker)
- **Base Images**: Chainguard (`wolfi-base`, `static`)
- **Tooling**: `docker`, `hadolint`, `container-structure-test`, `docker pushrm`
- **Conventions**: Non-root runtime users; multi-stage builds; per-project test scripts gated by stage names

## Conventions

- New images live in their own subdirectory with the layout above.
- The image name on Docker Hub matches the subdirectory name (`${REGISTRY}/${NAMESPACE}/<dir>:${TAG}`).
- Test dependencies (`hadolint`, `container-structure-test`) are expected on `PATH`; do not re-add auto-download logic.
