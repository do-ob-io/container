# container/caddy

Caddy web server container image built on Chainguard Wolfi + static base.

## Layout

- `Containerfile` — multi-stage build (Wolfi builder → Chainguard static runtime)
- `Caddyfile` — default Caddy configuration (serves `/usr/share/caddy` on `:80`)
- `index.html` — static landing page bundled into the image
- `test/` — container test suite (see below)

## Testing

Container tests live in `test/` and use the community-standard stack:

- **hadolint** — static analysis of the `Containerfile`
- **container-structure-test** (Google) — declarative image tests in
  `test/container-structure-test.yaml` (metadata, files, commands)
- **bash + docker + curl** — runtime smoke test that boots the container and
  verifies it serves `index.html` on port 80

Run the full suite from this directory:

```sh
./test/test.sh            # lint → build → structure → smoke
./test/test.sh lint       # single stage
SKIP_BUILD=1 ./test/test.sh structure   # reuse existing image tag
```

`container-structure-test`, `hadolint`, `docker`, and `curl` must be installed
and available on `PATH`.
