ARG ARCH="amd64"
ARG TAG="v3.7.1"
ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.8b5

# Build the multus project
FROM ${GO_IMAGE} as builder
RUN set -x \
 && apk --no-cache add \
    patch
ARG ARCH
ARG TAG
ENV GOARCH ${ARCH}
ENV GOOS "linux"
COPY 0001-Add-all-important-multus-binaries.patch .
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/multus-cni \
    && cd multus-cni \
    && git fetch --all --tags --prune \
    && git checkout tags/${TAG} -b ${TAG} \
    && patch -p1 < ../0001-Add-all-important-multus-binaries.patch \
    && ./hack/build-go.sh

### Build the CNI plugins ###
FROM ${GO_IMAGE} as cni_plugins
ARG TAG
ARG CNI_PLUGINS_VERSION="v0.9.1"
RUN git clone --depth=1 https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && git fetch --all --tags --prune \
    && git checkout tags/${CNI_PLUGINS_VERSION} -b ${CNI_PLUGINS_VERSION} \
    && sh -ex ./build_linux.sh -v \
    -gcflags=-trimpath=/go/src \
    -ldflags " \
        -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${CNI_PLUGINS_VERSION} \
        -linkmode=external -extldflags \"-static -Wl,--fatal-warnings\" \
    "
WORKDIR $GOPATH/src/github.com/containernetworking/plugins
RUN go-assert-static.sh bin/* \
    && go-assert-boring.sh \
    bin/bridge \
    bin/dhcp \
    bin/host-device \
    bin/host-local \
    bin/ipvlan \
    bin/macvlan \
    bin/ptp \
    && mkdir -vp /opt/cni/bin \
    && install -D -s bin/* /opt/cni/bin

# Create the multus image
FROM ${UBI_IMAGE}
COPY --from=builder /go/multus-cni /usr/src/multus-cni
COPY --from=cni_plugins /opt/cni/bin/bridge /opt/cni/bin/dhcp /opt/cni/bin/host-device /opt/cni/bin/host-local /opt/cni/bin/ipvlan /opt/cni/bin/macvlan /opt/cni/bin/ptp /opt/cni/bin/static /opt/cni/bin/tuning /opt/cni/bin/
WORKDIR /
RUN cp /usr/src/multus-cni/images/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
