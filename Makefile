# M5Stack CoreMP135 Debian build.
#   make            -> everything up to the compressed SD image (in Docker)
#   make kernel     -> just the kernel .debs
# Set NATIVE=1 to run directly on a Debian trixie host with the packages from
# docker/Dockerfile installed (root needed for rootfs/image).

RUN := $(if $(NATIVE),,scripts/docker-run.sh)
OUT := build/out

.PHONY: all sources firmware kernel packages rootfs image repo shell clean distclean help

all: image

help:
	@echo "targets: firmware kernel packages rootfs image repo shell clean distclean"

sources:
	$(RUN) scripts/fetch-sources.sh

firmware:
	$(RUN) scripts/build-firmware.sh

kernel:
	$(RUN) scripts/build-kernel.sh

packages: $(OUT)/firmware/fip.bin $(OUT)/kernel-release
	$(RUN) scripts/build-packages.sh

$(OUT)/firmware/fip.bin:
	$(RUN) scripts/build-firmware.sh

$(OUT)/kernel-release:
	$(RUN) scripts/build-kernel.sh

rootfs: packages
	$(RUN) scripts/build-rootfs.sh

image: rootfs
	$(RUN) scripts/build-image.sh

repo: packages
	$(RUN) scripts/publish-repo.sh

shell:
	$(RUN) bash

clean:
	$(RUN) rm -rf build/out build/rootfs build/images build/pkg-stage build/linux-obj build/genimage.tmp

distclean:
	$(RUN) rm -rf build
