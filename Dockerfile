FROM caddy:2.11.7-alpine@sha256:d76116d819d5162f464b0f2cd09bd28c568a86148c7bc539ce17c33eb22d8bbb AS caddy

# The upstream binary has cap_net_bind_service, which is unnecessary on 8080
# and prevents execution when the runtime drops all capabilities.
RUN setcap -r /usr/bin/caddy

FROM scratch

LABEL org.opencontainers.image.source="https://github.com/schack/openrouter-proxy"

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY --from=caddy /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=caddy --chown=1000:1000 /config/caddy /config/caddy
COPY --from=caddy --chown=1000:1000 /data/caddy /data/caddy
COPY Caddyfile /etc/caddy/Caddyfile

ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data

USER 1000:1000
EXPOSE 8080

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
