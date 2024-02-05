ARG ARCH="amd64"
ARG TAG=v4.0.2
ARG GO_IMAGE=rancher/hardened-build-base:v1.20.7b3

# Build the multus project
FROM ${GO_IMAGE} as builder
RUN set -x && \
    apk --no-cache add patch
ARG ARCH
ARG TAG=v4.0.2
ENV GOARCH ${ARCH}
ENV GOOS "linux"
# patch to solve https://github.com/rancher/rke2/issues/4568
# to be removed once upstream merges the fix
# https://github.com/k8snetworkplumbingwg/multus-cni/pull/1137
COPY self_delegation_bug.patch /tmp
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/multus-cni && \
    cd multus-cni && \
    git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG} && \
    git apply /tmp/self_delegation_bug.patch && \
    ./hack/build-go.sh

# Create the multus image
FROM scratch
COPY --from=builder  /go/multus-cni/bin /usr/src/multus-cni/bin
COPY --from=builder  /go/multus-cni/LICENSE /usr/src/multus-cni/LICENSE
WORKDIR /
COPY --from=builder /go/multus-cni/bin/install_multus /
COPY --from=builder /go/multus-cni/bin/thin_entrypoint /
ENTRYPOINT ["/thin_entrypoint"]
