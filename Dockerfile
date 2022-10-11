ARG ARCH="amd64"
ARG TAG="v3.8"
ARG BCI_IMAGE=registry.suse.com/bci/bci-base:15.3.17.20.12
ARG GO_IMAGE=rancher/hardened-build-base:v1.16.10b7

# Build the multus project
FROM ${GO_IMAGE} as builder
RUN set -x \
 && apk --no-cache add \
    patch
ARG ARCH
ARG TAG
ENV GOARCH ${ARCH}
ENV GOOS "linux"
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/multus-cni \
    && cd multus-cni \
    && git fetch --all --tags --prune \
    && git checkout tags/${TAG} -b ${TAG} \
    && ./hack/build-go.sh

# Create the multus image
FROM ${BCI_IMAGE}
RUN zypper refresh && \
    zypper update -y && \
    zypper install -y \
        python \
        gawk \
        which && \
    zypper clean -a
COPY --from=builder /go/multus-cni /usr/src/multus-cni
WORKDIR /
RUN cp /usr/src/multus-cni/images/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
