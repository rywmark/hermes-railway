# hermes-railway

Thin wrapper around [`nousresearch/hermes-agent`](https://hermes-agent.nousresearch.com) for Railway deployment.

## What this adds

The official Hermes web dashboard has no built-in authentication and binds to `127.0.0.1` by default. This wrapper:

1. Starts Caddy on Railway's `$PORT` with HTTP basic auth.
2. Reverse-proxies authed requests to the dashboard on `127.0.0.1:9119`.
3. Hands off to the upstream entrypoint to run `gateway run` (which spawns the dashboard side-process when `HERMES_DASHBOARD=1`).

Upstream image is unchanged; this is a thin auth + reverse-proxy layer.

## Required env vars

| Var | Purpose |
|-----|---------|
| `DASHBOARD_PASSWORD` | Plaintext dashboard password — bcrypt-hashed at container start |
| `OPENROUTER_API_KEY` | LLM provider key (or other provider env vars per Hermes docs) |

## Optional env vars

| Var | Default | Purpose |
|-----|---------|---------|
| `DASHBOARD_USERNAME` | `admin` | Basic auth username |
| `PORT` | `8080` | Public port (Railway sets this) |
| `HERMES_DASHBOARD` | `1` | Enables the dashboard side-process |
| `HERMES_DASHBOARD_HOST` | `127.0.0.1` | Dashboard internal bind |
| `HERMES_DASHBOARD_PORT` | `9119` | Dashboard internal port |

Pass any other Hermes env vars (channels, model providers, etc.) through Railway as normal — the upstream entrypoint reads them.

## Volume

Mount a persistent volume at `/opt/data` so config, sessions, skills, and memories survive redeploys.

## Updating

Bump the upstream image by changing the `FROM` tag in `Dockerfile`, push, Railway redeploys.

## Local test

```bash
docker build -t hermes-railway .
docker run --rm -p 8080:8080 \
  -e DASHBOARD_PASSWORD=test \
  -e OPENROUTER_API_KEY=sk-or-... \
  -v $(pwd)/data:/opt/data \
  hermes-railway
# → http://localhost:8080  (admin / test)
```
