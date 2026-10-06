# OpenRouter proxy

Keep your real OpenRouter API key on a separate proxy host, out of reach of
OpenCode and other clients. Give those clients only the proxy URL and a
placeholder key. Caddy forwards requests to `https://openrouter.ai`, replacing
any incoming `Authorization` header with the key configured on the proxy host
in `OPENROUTER_API_KEY`. Client-supplied `X-API-Key` headers are removed, and
so are the `X-Forwarded-For`, `X-Forwarded-Host`, `X-Forwarded-Proto` and
`Via` headers Caddy would otherwise add, so OpenRouter does not learn client
addresses, the proxy's hostname, or that it runs Caddy. Paths, query strings,
request bodies, response bodies, and streaming responses are proxied as-is.

The runtime image is built from Caddy's official Alpine image into `scratch`.
It contains the Caddy binary, system CA certificates, and this configuration,
not a shell or package manager. CI publishes it to
`ghcr.io/schack/openrouter-proxy` for `linux/amd64` and `linux/arm64` on every
merge to `main`, signed with keyless cosign. Caddy-version releases also publish
a matching version tag, such as `:2.11.7`, and create a GitHub release from the
matching `v2.11.7` Git tag.

## Run

1. Copy `compose.yaml` and `.env.example` to a directory on the proxy host.
2. Copy `.env.example` to `.env`, set `OPENROUTER_API_KEY`, and restrict access
   to the file. Do not commit `.env`.
3. From that directory, run `docker compose up -d`.

To update, run `docker compose pull && docker compose up -d`. To control when
updates happen, set `PROXY_IMAGE` in `.env` to a digest
(`ghcr.io/schack/openrouter-proxy@sha256:...`) instead of the `latest` tag.

Verify the signature before running a new image:

```sh
cosign verify ghcr.io/schack/openrouter-proxy:latest \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity https://github.com/schack/openrouter-proxy/.github/workflows/ci.yml@refs/heads/main
```

For a versioned image, use its release-tag identity when verifying, for example
`https://github.com/schack/openrouter-proxy/.github/workflows/ci.yml@refs/tags/v2.11.7`.

To build locally instead, run `docker build -t openrouter-proxy:local .` and set
`PROXY_IMAGE=openrouter-proxy:local` in `.env`.

The default port binding is loopback-only (`127.0.0.1:8080`). To allow another
device to connect, change `PROXY_BIND_ADDRESS` in `.env` to the proxy host's
network IP and run `docker compose up -d` again. Anyone who can reach the proxy
can use your OpenRouter account (including other containers on the Compose network),
so do not expose it to the public internet. Client-to-proxy HTTP traffic,
including prompts and responses, is unencrypted. For clients outside a trusted
network, put it behind an authenticated HTTPS proxy or use a VPN. The
connection from Caddy to OpenRouter uses verified HTTPS.

## Use

Set the client's OpenAI-compatible base URL to
`http://<PROXY-HOST-IP>:8080/api/v1`.
The client's API key can be any placeholder because the proxy replaces it:

```text
OPENAI_BASE_URL=http://<PROXY-HOST-IP>:8080/api/v1
OPENAI_API_KEY=placeholder
```

The proxy forwards all paths to OpenRouter, so OpenRouter endpoints outside
`/api/v1` are available too. SSE responses are streamed by Caddy without
buffering the complete response.

## Security boundary

The real key must exist only on the proxy host, not in client configuration,
environment variables, or credential stores on the computer running the TUI.
Clients can still **use** your OpenRouter account through the proxy: hiding the
key does not prevent requests or charges. Keep the proxy reachable only by
devices you trust. This separation also depends on the TUI and its tools not
having access to the proxy host's `.env`, container environment, Docker API,
or other places where the real key is stored.

## Configuration

- `OPENROUTER_API_KEY`: required OpenRouter API key.
- `PROXY_BIND_ADDRESS`: host interface for the published port, defaults to
  `127.0.0.1`.
- `PROXY_PORT`: host port, defaults to `8080`.
- `PROXY_IMAGE`: image to run, defaults to
  `ghcr.io/schack/openrouter-proxy:latest`.

The Caddyfile header injection behavior is documented at
https://caddyserver.com/docs/caddyfile/directives/reverse_proxy.

Dependabot checks the base image and GitHub Actions weekly. The 21-day cooldown
only takes effect for GitHub Actions: Docker Hub sends no `Last-Modified`
header, so Dependabot cannot date images and opens base image PRs immediately.
Check the age of a new base image digest before merging, and do not enable
auto-merge.

CI lints the Dockerfile, builds the image, scans the final `scratch` image with
Trivy, validates the Caddy configuration and the injected and removed headers,
and sends a request through the running container to `/api/v1/auth/key` with
a well-formed but nonexistent key.
OpenRouter answers `User not found.` only when the proxy replaced the client's
headers with that key, which proves the injection end to end. After those
checks pass on `main`, CI builds both architectures, pushes `latest` and
`sha-<commit>` tags, and signs the pushed digest. To make a release, push a
`vMAJOR.MINOR.PATCH` Git tag on a commit already on `main`, matching the Caddy
version pinned in `Dockerfile`. CI validates that match, publishes the
corresponding `MAJOR.MINOR.PATCH` image tag, signs the image, and creates a
GitHub release with generated notes. The commit tag was published when the
commit was merged to `main`. Release tags do not move `latest`.

The vulnerability scan reports all severities in the CI logs and blocks the
required `check` job for HIGH or CRITICAL findings with an available fix.
Unfixed findings remain visible but do not block CI. Trivy inspects Go dependency
and compiler-version metadata embedded in the Caddy binary; it does not provide
complete coverage of vulnerabilities in Caddy itself. CI also runs every Monday
at 06:23 UTC to catch newly disclosed vulnerabilities without a code change.
Scheduled runs do not publish images. The scanner version is pinned separately
from its action and needs periodic review, observing the 21-day cooldown; its
vulnerability database is refreshed during scans.

Trivy's Go scanning coverage is documented at
https://trivy.dev/latest/docs/coverage/language/golang/.
