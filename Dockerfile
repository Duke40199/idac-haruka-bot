# syntax=docker/dockerfile:1

# ---- build stage ----
# Pin to the module's Go version (go.mod: go 1.25.0).
FROM golang:1.25-bookworm AS build
WORKDIR /src

# NOTE: go.mod currently pins github.com/Duke40199/sega-idac-client via a local
# `replace => ../sega-idac-client`, which lives OUTSIDE this build context. A plain
# `docker build .` from the repo root cannot see it, so one of these must hold at
# build time:
#   (a) Go-live path (preferred): publish/tag sega-idac-client, drop the replace
#       (see go.mod), then this Dockerfile builds unchanged; or
#   (b) build with the parent directory as context so the sibling checkout is
#       available, e.g. from go/src:
#         docker build -f idac-haruka-bot/Dockerfile -t haruka .
#       and adjust the COPY paths below accordingly.

# Cache deps first.
COPY go.mod go.sum ./
RUN go mod download

# Build the static binary. CGO off => no libc needed at runtime, so the
# distroless/static image below works. The unauthorized.gif is go:embed-ed,
# so no resource files need to be copied into the final image.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /haruka ./cmd/haruka

# ---- runtime stage ----
# static-debian12 ships CA certificates (needed for the HTTPS calls to Discord,
# SEGA and All.Net) and runs as a non-root user. No shell, tiny attack surface.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /haruka /haruka

# Health server (/healthz) listens here; keep in sync with PORT in the ConfigMap.
EXPOSE 10000

USER nonroot:nonroot
ENTRYPOINT ["/haruka"]
