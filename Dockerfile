# Flyte Single Binary Build
# Builds unified Flyte binary from manager/cmd/main.go

ARG GO_VERSION=1.24.6
ARG TARGETARCH=amd64

# Stage 1: Build Flyte binary
FROM --platform=linux/${TARGETARCH} golang:${GO_VERSION}-trixie AS flytebuilder

ARG TARGETARCH
ENV GOARCH=${TARGETARCH}
ENV GOOS=linux
ENV CGO_ENABLED=1

WORKDIR /workspace

# Copy go module files first for better caching
COPY go.mod go.sum ./

# Download dependencies with cache mount
RUN --mount=type=cache,target=/root/go/pkg/mod \
    go mod download

# Copy all source code needed for the unified binary
# The unified binary in manager/cmd/main.go imports:
# - dataproxy, executor, manager, queue, runs (services)
# - flytestdlib, flyteplugins (libraries)
# - gen/go (generated code)
# - flyteidl2 (proto definitions, may be needed for some builds)
COPY dataproxy ./dataproxy
COPY executor ./executor
COPY manager ./manager
COPY queue ./queue
COPY runs ./runs
COPY flytestdlib ./flytestdlib
COPY flyteplugins ./flyteplugins
COPY gen ./gen
COPY flyteidl2 ./flyteidl2

# Build the unified Flyte binary
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    go build -v -o /flyte-binary -ldflags="-s -w" ./manager/cmd

# Stage 2: Final runtime image
FROM debian:trixie-slim

ARG FLYTE_VERSION=dev
ENV FLYTE_VERSION=${FLYTE_VERSION}
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install --no-install-recommends --yes \
        ca-certificates \
        tini \
        libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary
COPY --from=flytebuilder /flyte-binary /usr/local/bin/flyte

# Set entrypoint
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/flyte"]
