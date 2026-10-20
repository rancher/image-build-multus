SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
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
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := $(shell cat TAG)$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

REPO ?= rancher

.PHONY: image-build-thin
image-build-thin: IMAGE = $(REPO)/hardened-multus-cni:$(TAG)
image-build-thin:
	docker buildx build \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thin \
		--tag $(IMAGE) \
		--load \
	.

.PHONY: push-image-thin
push-image-thin: IMAGE = $(REPO)/hardened-multus-cni:$(TAG)
push-image-thin:
	docker buildx build \
		$(IID_FILE_FLAG) \
		$(BUILDX_ARGS) \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thin \
		--tag $(IMAGE) \
		--push \
		.

.PHONY: push-prime-image-thin
push-prime-image-thin:
	BUILDX_ARGS="--sbom=true --attest type=provenance,mode=max" \
	$(MAKE) push-image-thin

.PHONY: image-build-thick
image-build-thick: IMAGE = $(REPO)/hardened-multus-thick:$(TAG)
image-build-thick:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thick \
		--tag $(IMAGE) \
		--load \
	.

.PHONY: push-image-thick
push-image-thick: IMAGE = $(REPO)/hardened-multus-thick:$(TAG)
push-image-thick:
	docker buildx build \
		$(IID_FILE_FLAG) \
		$(BUILDX_ARGS) \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target multus-thick \
		--tag $(IMAGE) \
		--push \
		.

.PHONY: push-prime-image-thick
push-prime-image-thick:
	BUILDX_ARGS="--sbom=true --attest type=provenance,mode=max" \
	$(MAKE) push-image-thick

.PHONY: image-build
image-build: image-build-thin image-build-thick

.PHONY: image-scan
image-scan:
	@trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-multus-cni:$(TAG) || true
	@trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-multus-thick:$(TAG) || true

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "REPO=$(REPO)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
