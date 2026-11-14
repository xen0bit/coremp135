#!/bin/bash
# Assemble sdcard.img from the firmware and $BUILD/rootfs with genimage.
source "$(dirname "$0")/common.sh"

ROOTFS="$BUILD/rootfs"
IMG="$BUILD/images"
[ -d "$ROOTFS/usr" ] || { echo "no rootfs, run build-rootfs.sh first" >&2; exit 1; }
rm -rf "$IMG" "$BUILD/genimage.tmp"; mkdir -p "$IMG"
cp "$OUT"/firmware/*.stm32 "$OUT"/firmware/fip.bin "$IMG/"

# ext4 size: used space + 30% + 256 MiB headroom, rounded to 64 MiB.
# The partition is grown to fill the card at first boot.
used=$(du -sm "$ROOTFS" | cut -f1)
size=$(( (used * 13 / 10 + 256 + 63) / 64 * 64 ))
sed "s/@ROOTFS_SIZE@/${size}M/" "$TOP/image/genimage.cfg.in" > "$BUILD/genimage.cfg"

log "genimage (rootfs ${size} MiB)"
genimage --config "$BUILD/genimage.cfg" --rootpath "$ROOTFS" \
	--tmppath "$BUILD/genimage.tmp" --inputpath "$IMG" --outputpath "$IMG"

name="coremp135-debian-$DEBIAN_SUITE-$(date -u +%Y%m%d).img"
mv "$IMG/sdcard.img" "$OUT/$name"
log "compressing"
xz -T0 -6 -f -k "$OUT/$name"
sgdisk -p "$OUT/$name"
ls -lh "$OUT/$name"*
