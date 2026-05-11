#!/usr/bin/env bash
set -euo pipefail

# Required: dashboard plaintext password
: "${DASHBOARD_PASSWORD:?DASHBOARD_PASSWORD must be set (plaintext; will be bcrypt-hashed at runtime)}"

# Defaults
: "${PORT:=8080}"
: "${DASHBOARD_USERNAME:=admin}"
: "${HERMES_DASHBOARD:=1}"
: "${HERMES_DASHBOARD_HOST:=127.0.0.1}"
: "${HERMES_DASHBOARD_PORT:=9119}"

# Bcrypt-hash the plaintext password using Caddy itself (cost=10 default)
DASHBOARD_PASSWORD_HASH="$(caddy hash-password --plaintext "$DASHBOARD_PASSWORD")"

export DASHBOARD_USERNAME DASHBOARD_PASSWORD_HASH PORT
export HERMES_DASHBOARD HERMES_DASHBOARD_HOST HERMES_DASHBOARD_PORT

# Render Caddyfile (env interpolation happens at Caddy load via {$VAR} in template)
cp /etc/caddy/Caddyfile.tmpl /etc/caddy/Caddyfile

echo "[hermes-railway] Caddy reverse-proxy: 0.0.0.0:${PORT} → 127.0.0.1:${HERMES_DASHBOARD_PORT}"
echo "[hermes-railway] Dashboard auth user: ${DASHBOARD_USERNAME}"

# Start Caddy in background
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

# Verify Caddy stayed up
sleep 2
if ! kill -0 "$CADDY_PID" 2>/dev/null; then
    echo "[hermes-railway] FATAL: Caddy failed to start"
    exit 1
fi
echo "[hermes-railway] Caddy alive (pid $CADDY_PID)"

# Forward signals to children
shutdown() {
    echo "[hermes-railway] Shutting down"
    kill -TERM "$CADDY_PID" 2>/dev/null || true
    [[ -n "${HERMES_PID:-}" ]] && kill -TERM "$HERMES_PID" 2>/dev/null || true
    wait "$CADDY_PID" 2>/dev/null || true
    [[ -n "${HERMES_PID:-}" ]] && wait "$HERMES_PID" 2>/dev/null || true
    exit 0
}
trap shutdown INT TERM

# Hand off to the upstream entrypoint to run the gateway
# The upstream entrypoint handles UID/GID switching via gosu and starts the
# in-process dashboard side-process when HERMES_DASHBOARD=1
/opt/hermes/docker/entrypoint.sh gateway run &
HERMES_PID=$!

wait "$HERMES_PID"
HERMES_EXIT=$?
echo "[hermes-railway] hermes gateway exited with $HERMES_EXIT"
kill -TERM "$CADDY_PID" 2>/dev/null || true
exit "$HERMES_EXIT"
