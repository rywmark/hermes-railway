FROM nousresearch/hermes-agent:latest

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        curl \
        gnupg \
        ca-certificates \
    && curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
        -o /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends caddy \
    && rm -rf /var/lib/apt/lists/*

COPY Caddyfile.tmpl /etc/caddy/Caddyfile.tmpl
COPY start.sh /usr/local/bin/hermes-railway-start
RUN chmod +x /usr/local/bin/hermes-railway-start

# Keep tini as PID 1 (inherited from upstream image) for signal forwarding
# and zombie reaping; our wrapper script runs under it.
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/hermes-railway-start"]
