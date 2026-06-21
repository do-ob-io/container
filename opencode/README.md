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
| `/home/opencode/workspace`                      | Default working directory (mount here)    |
| `/home/opencode/.config/opencode/opencode.json` | opencode configuration (LSP enabled)      |
| `/home/opencode/.opencode/bin`                  | opencode binary                           |

Provide credentials and overrides through environment variables or by mounting your own configuration over the default path, for example:

```bash
docker run --rm -it \
  -e OPENCODE_API_KEY=... \
  -v "$PWD/opencode.json:/home/opencode/.config/opencode/opencode.json:ro" \
  -v "$PWD:/home/opencode/workspace" \
  do-ob/opencode
```

## Notes

- **Playwright browsers are fetched lazily.** Only the Playwright CLI is baked into the image; the browsers (Chromium, Firefox, WebKit) download in the background on the first container start so opencode is usable immediately. A marker in `~/.cache/ms-playwright` prevents repeat downloads — persist `/home/opencode` with a volume to keep them across container recreation. Tune or disable this with the variables below.
- Wolfi uses `apk`, which Playwright's `--with-deps` does not support; the browser system libraries are installed at the image layer on a best-effort basis. WebKit in particular may require additional libraries depending on the workload.
- LSP servers are downloaded by opencode at runtime. Set `OPENCODE_DISABLE_LSP_DOWNLOAD=true` to opt out.

### Environment variables

| Variable                        | Default                      | Description                                            |
| ------------------------------- | ---------------------------- | ------------------------------------------------------ |
| `PLAYWRIGHT_BROWSERS`           | `chromium firefox webkit`    | Space-separated browsers to fetch on first start       |
| `OPENCODE_SKIP_BROWSER_INSTALL` | `0`                          | Set to `1` to skip the lazy browser download entirely  |


## Reference

- opencode documentation: <https://opencode.ai/docs/>
- opencode repository: <https://github.com/anomalyco/opencode>
