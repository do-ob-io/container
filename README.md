# Container

Open source container images for running applications and services.

Each subdirectory is a self-contained image project with its own `Containerfile`, `README.md`, and `test/test.sh`.

## Layout

```
container/
├── publish.sh         # test + publish all images
└── <project>/
    ├── Containerfile  # image definition
    ├── README.md      # synced to Docker Hub repo description
    └── test/test.sh   # lint, build, structure, smoke
```

## Publishing

[`publish.sh`](publish.sh) iterates each project, runs its `test/test.sh`, and on success builds, pushes, and syncs the README to Docker Hub. Failures are collected and reported in a final summary; a single project's failure does not stop the rest.

### Usage

```bash
# Test + publish every project
./publish.sh

# Only the named projects
./publish.sh caddy

# Run tests and print (but do not execute) publish commands
./publish.sh --dry-run
```

### Options

| Flag         | Description                                                |
| ------------ | ---------------------------------------------------------- |
| `--dry-run`  | Run tests for real; print publish commands without running |
| `-h`, `--help` | Show usage                                               |

### Environment variables

| Variable    | Default      | Description                                  |
| ----------- | ------------ | -------------------------------------------- |
| `NAMESPACE` | `do-ob`      | Docker Hub namespace                         |
| `REGISTRY`  | `docker.io`  | Registry host                                |
| `TAG`       | `latest`     | Image tag (also tagged `:latest` if not set) |

### Examples

```bash
# Custom namespace
NAMESPACE=my-org ./publish.sh

# Versioned release of a single project
NAMESPACE=my-org TAG=v1.2.3 ./publish.sh caddy

# Push to GitHub Container Registry instead of Docker Hub
REGISTRY=ghcr.io NAMESPACE=my-org ./publish.sh --dry-run
```

### Requirements

- `docker`, authenticated against the target registry (`docker login`).
- [`docker pushrm`](https://github.com/christian-korneck/docker-pushrm) plugin to sync each project's `README.md` to Docker Hub. Not required for `--dry-run`.
- Per-project test dependencies: `bash`, `hadolint`, `container-structure-test`.
