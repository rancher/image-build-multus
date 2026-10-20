# image-build-multus

This repo builds hardened, statically-linked Go binaries from
[k8snetworkplumbingwg/multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni) and packages them in:

| Variant | Base Image | Published Image |
|---------|------------|-----------------|
| thin    | scratch    | [rancher/hardened-multus-cni](https://hub.docker.com/r/rancher/hardened-multus-cni) |
| thick   | [SUSE Linux BCI Busybox](https://registry.suse.com/repositories/bci-bci-busybox-16-0) | [rancher/hardened-multus-thick](https://hub.docker.com/r/rancher/hardened-multus-thick) |

Binaries are compiled against [`rancher/hardened-build-base`](https://github.com/rancher/image-build-base),
which provides the latest supported Go toolchain (FIPS/BoringCrypto-enabled on amd64).