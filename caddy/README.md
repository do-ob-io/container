# Caddy Container Image

[Caddy web server](https://github.com/caddyserver/caddy) built with Chainguard images: [Wolfi OS](https://images.chainguard.dev/directory/image/wolfi-base/overview), [Static](https://images.chainguard.dev/directory/image/static/overview).

The image runs as a non-root user, exposes ports `80`, `443`, and `443/udp`, and starts with a default `Caddyfile` that serves a placeholder `index.html`.

## Usage

Run with the bundled defaults:

```bash
docker run --rm -p 8080:80 do-ob/caddy:test
```

Mount your own `Caddyfile` and site content:

```bash
docker run --rm \
  -p 8080:80 \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v "$PWD/site:/usr/share/caddy:ro" \
  do-ob/caddy:test
```

## Configuration

| Path                   | Purpose                  |
| ---------------------- | ------------------------ |
| `/etc/caddy/Caddyfile` | Caddy configuration file |
| `/usr/share/caddy/`    | Default static site root |

## Reference

- Caddy on Docker Hub: <https://hub.docker.com/_/caddy>
- Caddy documentation: <https://caddyserver.com/docs/>
