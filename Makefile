SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ORG ?= rancher
TAG ?= v3.6

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

.PHONY: image-build
image-build:
	docker build \
		--build-arg ARCH=$(ARCH) \
		--build-arg TAG=$(TAG) \
		--tag $(ORG)/hardened-multus:$(TAG) \
		--tag $(ORG)/hardened-multus:$(TAG)-$(ARCH) \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-multus:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-multus:$(TAG) \
		$(ORG)/hardened-multus:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-multus:$(TAG)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-multus:$(TAG)
