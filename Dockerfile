ARG GO_IMAGE=rancher/hardened-build-base:v1.21.11b3

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.3.0 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld patch
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc lld 

# Build the multus project
FROM base-builder AS multus-builder
ARG TAG=v4.1.0
ARG SRC=github.com/k8snetworkplumbingwg/multus-cni
ARG PKG=github.com/k8snetworkplumbingwg/multus-cni
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG}
RUN go mod download
# cross-compilation setup
ARG TARGETARCH

RUN xx-go --wrap && \
    ./hack/build-go.sh
RUN xx-verify --static bin/thin_entrypoint bin/multus

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/thin_entrypoint /thin_entrypoint
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/multus /multus
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/kubeconfig_generator /kubeconfig_generator
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/cert-approver /cert-approver
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/install_multus /install_multus
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/multus-daemon /multus-daemon
COPY --from=multus-builder /go/src/github.com/k8snetworkplumbingwg/multus-cni/bin/multus-shim /multus-shim
RUN strip /thin_entrypoint /multus /kubeconfig_generator /cert-approver /install_multus /multus-daemon /multus-shim

# Create the multus image
FROM scratch AS multus-thin
COPY --from=strip_binary  /multus /usr/src/multus-cni/bin/multus
COPY --from=multus-builder  /go/src/github.com/k8snetworkplumbingwg/multus-cni/LICENSE /usr/src/multus-cni/LICENSE
COPY --from=strip_binary    /thin_entrypoint /
COPY --from=strip_binary    /kubeconfig_generator /
COPY --from=strip_binary    /cert-approver /
COPY --from=strip_binary    /install_multus /
ENTRYPOINT ["/thin_entrypoint"]

# Create the thick plugin image
FROM scratch AS multus-thick
COPY --from=multus-builder  /go/src/github.com/k8snetworkplumbingwg/multus-cni/LICENSE /usr/src/multus-cni/LICENSE
COPY --from=strip_binary  /multus-daemon /usr/src/multus-cni/bin/multus-daemon
COPY --from=strip_binary  /multus-shim /usr/src/multus-cni/bin/multus-shim
ENTRYPOINT [ "/usr/src/multus-cni/bin/multus-daemon" ]
