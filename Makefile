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

ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

BUILD_META=-build$(shell date +%Y%m%d)
PKG ?= github.com/k8snetworkplumbingwg/multus-cni
SRC ?= github.com/k8snetworkplumbingwg/multus-cni
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := v4.1.3$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

REPO ?= rancher

.PHONY: image-build-thin
image-build-thin: IMAGE = $(REPO)/hardened-multus-cni:$(TAG)
image-build-thin:
	docker buildx build \
		--platform=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thin \
		--tag $(IMAGE) \
		--tag $(IMAGE)-$(ARCH) \
		--load \
	.

.PHONY: push-image-thin
push-image-thin: IMAGE = $(REPO)/hardened-multus-cni:$(TAG)
push-image-thin:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thin \
		--tag $(IMAGE) \
		--tag $(IMAGE)-arch \
		--push \
		.

.PHONY: image-build-thick
image-build-thick: IMAGE = $(REPO)/hardened-multus-thick:$(TAG)
image-build-thick:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--platform=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thick \
		--tag $(IMAGE) \
		--tag $(IMAGE)-$(ARCH) \
		--load \
	.

.PHONY: push-image-thick
push-image-thick: IMAGE = $(REPO)/hardened-multus-thick:$(TAG)
push-image-thick:
	docker buildx build \
	    $(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thick \
		--tag $(IMAGE) \
		--tag $(IMAGE)-$(ARCH) \
		--push \
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
	@echo "REPO=$(REPO)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
