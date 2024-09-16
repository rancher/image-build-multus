SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

BUILD_META=-build$(shell date +%Y%m%d)
ORG ?= rancher
PKG ?= github.com/k8snetworkplumbingwg/multus-cni
SRC ?= github.com/k8snetworkplumbingwg/multus-cni
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := v4.1.1$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build-thin
image-build-thin:
	docker buildx build \
		--platform=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thin \
		--tag $(ORG)/hardened-multus-cni:$(TAG) \
		--tag $(ORG)/hardened-multus-cni:$(TAG)-$(ARCH) \
		--load \
	.

.PHONY: image-build-thick
image-build-thick:
	docker buildx build \
		--platform=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thick \
		--tag $(ORG)/hardened-multus-thick:$(TAG) \
		--tag $(ORG)/hardened-multus-thick:$(TAG)-$(ARCH) \
		--load \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-multus-cni:$(TAG)-$(ARCH)

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-multus-cni:$(TAG)

.PHONY: log
log:
	@echo "ARCH=$(ARCH)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "ORG=$(ORG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
