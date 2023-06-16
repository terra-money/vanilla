# syntax=docker/dockerfile:1

ARG GO_VERSION="1.20"
ARG GOOS=linux
ARG GOARCH=amd64
ARG ALPINE_VERSION="3.16"
ARG BUILDPLATFORM=linux/amd64
ARG BASE_IMAGE="golang:${GO_VERSION}-alpine${ALPINE_VERSION}"
FROM --platform=${BUILDPLATFORM} ${BASE_IMAGE} as base

###############################################################################
# Builder
###############################################################################

FROM base as builder-stage-1

ARG BUILDPLATFORM
ARG GOOS
ARG GOARCH

ENV GOOS=$GOOS \ 
    GOARCH=$GOARCH

# NOTE: add libusb-dev to run with LEDGER_ENABLED=true
RUN set -eux &&\
    apk update &&\
    apk add --no-cache \
    ca-certificates \
    linux-headers \
    build-base \
    cmake \
    git

# download dependencies to cache as layer
WORKDIR ${GOPATH}/src/app
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    go mod download -x

# Download CosmWasm libwasmvm if found.
RUN set -eux &&\
    WASMVM_VERSION=$(go list -m github.com/CosmWasm/wasmvm | cut -d ' ' -f 2) && \
    if [ ! -z "${WASMVM_VERSION}" ]; then \
        WASMVM_DOWNLOADS="https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERSION}"; \
        wget ${WASMVM_DOWNLOADS}/checksums.txt -O /tmp/checksums.txt; \
        if [ ${BUILDPLATFORM} = "linux/amd64" ]; then \
            WASMVM_URL="${WASMVM_DOWNLOADS}/libwasmvm_muslc.x86_64.a"; \
        elif [ ${BUILDPLATFORM} = "linux/arm64" ]; then \
            WASMVM_URL="${WASMVM_DOWNLOADS}/libwasmvm_muslc.aarch64.a"; \
        # elif [ ${BUILDPLATFORM} = "darwin/amd64" ]; then \
        #     WASMVM_URL="${WASMVM_DOWNLOADS}/libwasmvm.dylib"; \        
        # elif [ ${BUILDPLATFORM} = "darwin/arm64" ]; then \
        #     WASMVM_URL="${WASMVM_DOWNLOADS}/libwasmvm.dylib"; \        
        else \
            echo "Unsupported Build Platfrom ${BUILDPLATFORM}"; \
            exit 1; \
        fi; \
        wget ${WASMVM_URL} -O /lib/libwasmvm_muslc.a; \
        CHECKSUM=`sha256sum /lib/libwasmvm_muslc.a | cut -d" " -f1`; \
        grep ${CHECKSUM} /tmp/checksums.txt; \
        rm /tmp/checksums.txt; \
    fi

###############################################################################

FROM builder-stage-1 as builder-stage-2

ARG BUILDPLATFORM
ARG GOOS
ARG GOARCH

ENV GOOS=$GOOS \ 
    GOARCH=$GOARCH

# Copy the remaining files
COPY . .

# force it to use static lib (from above) not standard libgo_cosmwasm.so file
# then log output of file /code/bin/vanillad
# then ensure static linking
RUN set -eux &&\
  ls && \
  LEDGER_ENABLED=false BUILD_TAGS=muslc LINK_STATICALLY=true make build && \
  file /${GOPATH}/src/app/bin/vanillad && \
  echo "Ensuring binary is statically linked ..." && \
  (file /${GOPATH}/src/app/bin/vanillad | grep "statically linked")

################################################################################

FROM alpine:${ALPINE_VERSION} as vanilla

COPY --from=builder-stage-2 /go/bin/vanillad /usr/local/bin/vanillad

RUN addgroup -g 1000 vanilla && \
    adduser -u 1000 -G vanilla -D -h /app vanilla

WORKDIR /app

# rest server, tendermint p2p, tendermint rpc
EXPOSE 1317 26656 26657

CMD ["vanillad", "--home", "/app", "start"]