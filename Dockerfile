ARG GO_IMAGE=rancher/hardened-build-base:v1.21.11b3

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.3.0 as xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} as base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld patch
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc lld 

# Build the multus project
FROM base-builder as multus-builder
ARG TAG=v4.0.2
ARG SRC=github.com/k8snetworkplumbingwg/multus-cni
ARG PKG=github.com/k8snetworkplumbingwg/multus-cni
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
# patch to solve https://github.com/rancher/rke2/issues/4568
# to be removed once upstream merges the fix
# https://github.com/k8snetworkplumbingwg/multus-cni/pull/1137
COPY self_delegation_bug.patch /tmp

RUN git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG} && \
    git apply /tmp/self_delegation_bug.patch
RUN go mod download
# cross-compilation setup
ARG TARGETARCH

RUN xx-go --wrap && \
    ./hack/build-go.sh
RUN xx-verify --static bin/thin_entrypoint bin/multus

FROM ${GO_IMAGE} as strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/thin_entrypoint /thin_entrypoint
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/multus /multus
RUN strip /thin_entrypoint /multus

# Create the multus image
FROM scratch as multus-cni
COPY --from=strip_binary  /multus /usr/src/multus-cni/bin/multus
COPY --from=multus-builder  /go/src/github.com/k8snetworkplumbingwg/multus-cni/LICENSE /usr/src/multus-cni/LICENSE
COPY --from=strip_binary    /thin_entrypoint /
ENTRYPOINT ["/thin_entrypoint"]
