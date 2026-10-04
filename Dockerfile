FROM caddy:2.11.6-alpine@sha256:c776e0c6413b544d0459665e54ec7b8b2a15000c0cbee8b254da0067b1d184ff AS caddy

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
