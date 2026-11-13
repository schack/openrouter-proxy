# The builder stage is needed because no caddy release yet vendors
# golang.org/x/net v0.62.0 (CVE-2026-78661, fixed in v0.62.0); the stock
# caddy:2.11.9-alpine binary fails the Trivy HIGH gate on it.
# Drop this stage once a caddy release ships x/net v0.62.0 or newer.
FROM caddy:2.11.9-builder-alpine@sha256:646fee578e680989ca5c7fd1ce6f1de574d19fd71ef2221810cc0510a9f40c86 AS builder

# Downloaded via the Go module proxy, so the source is sumdb-verified.
RUN go mod download github.com/caddyserver/caddy/v2@v2.11.9 \
    && cp -r /go/pkg/mod/github.com/caddyserver/caddy/v2@v2.11.9 /src \
    && chmod -R u+w /src
WORKDIR /src
RUN go get golang.org/x/net@v0.62.0 \
    && CGO_ENABLED=0 go build -trimpath \
    -ldflags "-X github.com/caddyserver/caddy/v2.CustomVersion=2.11.9+xnet0.62.0" \
    -o /usr/bin/caddy ./cmd/caddy

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

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
