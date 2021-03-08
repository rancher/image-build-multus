ARG ARCH="amd64"
ARG TAG="v3.6"
ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.8b5

# Build the project
FROM ${GO_IMAGE} as builder
RUN set -x \
 && apk --no-cache add \
    git
ARG ARCH
ARG TAG
ENV GOARCH ${ARCH}
ENV GOOS "linux"
RUN git clone --depth=1 https://github.com/intel/multus-cni
WORKDIR multus-cni
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG} 
RUN ./build 

# Create the multus image
FROM ${UBI_IMAGE}
COPY --from=builder /go/multus-cni /usr/src/multus-cni
WORKDIR /
RUN cp /usr/src/multus-cni/images/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
