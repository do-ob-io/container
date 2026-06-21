# opencode Container Image

[opencode](https://github.com/anomalyco/opencode) running in a [Chainguard Wolfi](https://images.chainguard.dev/directory/image/wolfi-base/overview) based development environment with a `zsh` shell and a full set of language toolchains.

The image runs as the non-root `opencode` user (uid/gid `1000`) and ships with:

- **opencode** with LSP enabled (language servers auto-install on demand)
- **zsh** + **Oh My Zsh** as the default shell
- **Git** and **Git LFS**
- **Python** (latest, via [Astral uv](https://docs.astral.sh/uv/)) with `ty` and `ruff`
- **Rust** (via `rustup`) with the `rust-analyzer` component
- **Node.js** with **pnpm** and **TypeScript**
- **Playwright** browsers (Chromium, Firefox, WebKit)

## Usage

`opencode` is the entrypoint, so any subcommand and its flags are passed straight through.

Start the web UI:

```bash
docker run --name opencode-web -p 4096:4096 \
  do-ob/opencode web --hostname 0.0.0.0 --port 4096
```

Start the headless server:

```bash
docker run --name opencode-server -p 4096:4096 \
  do-ob/opencode serve --hostname 0.0.0.0 --port 4096
```

Open an interactive TUI against a mounted project:

```bash
docker run --rm -it \
  -v "$PWD:/home/opencode/workspace" \
  do-ob/opencode
```

Check the version:

```bash
docker run --rm do-ob/opencode --version
```

## Configuration

| Path                                            | Purpose                                   |
| ----------------------------------------------- | ----------------------------------------- |
| `/home/opencode`                                | `HOME` directory for the `opencode` user  |
| `/home/opencode/projects`                       | Default working directory (mount here)    |
| `/home/opencode/.config/opencode/opencode.json` | opencode configuration (LSP enabled)      |
| `/home/opencode/.opencode/bin`                  | opencode binary                           |

Provide credentials and overrides through environment variables or by mounting your own configuration over the default path, for example:

```bash
docker run --rm -it \
  -e OPENCODE_API_KEY=... \
  -v "$PWD/opencode.json:/home/opencode/.config/opencode/opencode.json:ro" \
  -v "$PWD:/home/opencode/projects" \
  do-ob/opencode
```

## Projects

The working directory is `/home/opencode/projects`. There are two ways to populate it:

- **Bind mount** existing code: `-v "$PWD:/home/opencode/projects"`.
- **Clone on start** by setting one or more numbered `REPOSITORY_X` variables (`REPOSITORY_0`, `REPOSITORY_1`, ...). Starting from `0` and stopping at the first unset variable, the entrypoint clones each repository into its own subdirectory under `~/projects` (named after the repository):

  ```bash
  docker run --rm -it \
    -e REPOSITORY_0=https://github.com/myorganization/api.git \
    -e REPOSITORY_1=https://github.com/myorganization/web.git \
    do-ob/opencode
  ```

  A repository is skipped when its target directory is already a git checkout (e.g. a persisted volume) or contains unrelated files (e.g. a bind mount), so existing work is never clobbered.

  After cloning, each repository's root `setup.sh` (if present) is run in order from `REPOSITORY_0`, executed from within that repository's directory. A non-zero exit is logged but does not prevent opencode from starting.

  **SSH remotes** (`git@host:org/repo.git`) are supported by mounting a directory of ssh keys to the container's `~/.ssh`:

  ```bash
  docker run --rm -it \
    -v "$HOME/.ssh:/home/opencode/.ssh:ro" \
    -e REPOSITORY_0=git@github.com:myorganization/api.git \
    do-ob/opencode
  ```

  Include a `known_hosts` entry for the host in the mounted directory so the non-interactive clone is not rejected by host-key verification. The mounted key files must have appropriate permissions (private keys `600`).

## Notes

- **Playwright browsers are fetched lazily.** Only the Playwright CLI is baked into the image; the browsers (Chromium, Firefox, WebKit) download in the background on the first container start so opencode is usable immediately. A marker in `~/.cache/ms-playwright` prevents repeat downloads — persist `/home/opencode` with a volume to keep them across container recreation. Tune or disable this with the variables below.
- Wolfi uses `apk`, which Playwright's `--with-deps` does not support; the browser system libraries are installed at the image layer on a best-effort basis. WebKit in particular may require additional libraries depending on the workload.
- LSP servers are downloaded by opencode at runtime. Set `OPENCODE_DISABLE_LSP_DOWNLOAD=true` to opt out.

### Environment variables

| Variable                        | Default                      | Description                                            |
| ------------------------------- | ---------------------------- | ------------------------------------------------------ |
| `REPOSITORY_0`, `REPOSITORY_1`, | _(unset)_                    | HTTPS git URLs cloned into `~/projects` (numbered from 0) |
| `GIT_USER_NAME`                 | _(unset)_                    | Git identity name; with `GIT_USER_EMAIL` sets the global git user |
| `GIT_USER_EMAIL`                | _(unset)_                    | Git identity email; with `GIT_USER_NAME` sets the global git user |
| `GIT_USER_PAT`                  | _(unset)_                    | Personal access token; with `GIT_USER_NAME` stores an HTTPS credential |
| `GIT_HOST`                      | `github.com`                 | Host the stored git credential applies to              |
| `PLAYWRIGHT_BROWSERS`           | `chromium`                   | Space-separated browsers to fetch on first start       |
| `OPENCODE_SKIP_BROWSER_INSTALL` | `0`                          | Set to `1` to skip the lazy browser download entirely  |

Git is configured at runtime (never baked into the image), so the token is read from the container environment and stored only in the running container's `~/.git-credentials`. Configuration is applied before the `REPOSITORY_X` clones so private repositories can authenticate:

```bash
docker run --rm -it \
  -e GIT_USER_NAME=octocat \
  -e GIT_USER_EMAIL=octocat@example.com \
  -e GIT_USER_PAT=ghp_xxx \
  -e REPOSITORY_0=https://github.com/myorganization/api.git \
  do-ob/opencode
```



## Reference

- opencode documentation: <https://opencode.ai/docs/>
- opencode repository: <https://github.com/anomalyco/opencode>
