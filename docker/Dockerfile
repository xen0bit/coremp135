# Reproducible build environment for the CoreMP135 Debian image.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates cpio curl debhelper \
        device-tree-compiler dosfstools dpkg-dev e2fsprogs fakeroot fdisk flex \
        gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf gdisk genimage git gnupg \
        kmod libelf-dev libgnutls28-dev libncurses-dev libssl-dev mmdebstrap \
        mtools python3 python3-cryptography python3-dev python3-pyelftools \
        python3-setuptools python3-libfdt qemu-user-static binfmt-support reprepro rsync \
        swig u-boot-tools uuid-runtime xz-utils zstd arch-test file sudo \
    && rm -rf /var/lib/apt/lists/*

# Let a host UID/GID own build outputs (set by scripts/docker-run.sh)
RUN git config --system --add safe.directory '*'
WORKDIR /work
