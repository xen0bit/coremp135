#!/bin/bash
# Build the Debian armhf root filesystem with mmdebstrap into $BUILD/rootfs.
# Requires root (run via scripts/docker-run.sh, which is privileged).
source "$(dirname "$0")/common.sh"

ROOTFS="$BUILD/rootfs"

# armhf binaries need qemu-user via binfmt_misc. With the F flag the
# interpreter is pinned at registration time, so it works inside the chroot.
[ -e /proc/sys/fs/binfmt_misc/register ] || mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-arm ]; then
	conf=$(ls /usr/lib/binfmt.d/qemu-arm*.conf | head -n1)
	log "registering qemu-arm binfmt from $conf"
	grep -v '^#' "$conf" > /proc/sys/fs/binfmt_misc/register
fi
arch-test armhf >/dev/null || { echo "cannot execute armhf binaries" >&2; exit 1; }

pkgs=$(grep -v '^\s*#' "$TOP/rootfs/packages.list" | xargs | tr ' ' ',')

rm -rf "$ROOTFS"
log "mmdebstrap $DEBIAN_SUITE armhf"
DEBS="$DEBS" TOP="$TOP" mmdebstrap \
	--mode=root --arch=armhf --variant=apt \
	--components="main non-free-firmware" \
	--include="$pkgs" \
	--aptopt='APT::Install-Recommends "false"' \
	--dpkgopt='path-exclude=/usr/share/doc/*' \
	--dpkgopt='path-include=/usr/share/doc/*/copyright' \
	--dpkgopt='path-exclude=/usr/share/man/*' \
	--customize-hook="$TOP/rootfs/hooks/customize.sh \"\$1\"" \
	"$DEBIAN_SUITE" "$ROOTFS" "$DEBIAN_MIRROR"
log "rootfs: $(du -sh "$ROOTFS" | cut -f1)"
