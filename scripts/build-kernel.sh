#!/bin/bash
# Build the kernel as Debian packages (linux-image-<ver>-coremp135, headers).
#   multi_v7_defconfig + kernel/config/fragments/*.config
#   + board/patches/linux/*.patch + board/dts/linux (DTB and overlays)
# Outputs .debs into $DEBS.
source "$(dirname "$0")/common.sh"

"$TOP/scripts/fetch-sources.sh" linux

KSRC="$SRC/linux"
KOBJ="$BUILD/linux-obj"
KVER="${LINUX_REF#v}"
LOCALVERSION="-coremp135"
KPKGVER="$KVER-$PKG_REVISION.$(input_rev kernel board/dts/linux board/patches/linux scripts/build-kernel.sh versions.env)"
DTSDIR="$KSRC/arch/arm/boot/dts/st"
mkdir -p "$KOBJ"

# Board DT + overlays into the tree
cp "$TOP/board/dts/linux/$BOARD_DTB.dts" "$DTSDIR/"
{
	echo
	echo "# M5Stack CoreMP135 (added by coremp135 build)"
	echo "DTC_FLAGS_$BOARD_DTB := -@"
	echo "dtb-\$(CONFIG_ARCH_STM32) += $BOARD_DTB.dtb"
	for o in "$TOP"/board/dts/linux/overlays/*.dtso; do
		[ -e "$o" ] || continue
		cp "$o" "$DTSDIR/"
		echo "dtb-\$(CONFIG_ARCH_STM32) += $(basename "${o%.dtso}").dtbo"
	done
} >> "$DTSDIR/Makefile"

# Config
frags=("$TOP"/kernel/config/fragments/*.config)
log "configuring: multi_v7_defconfig + ${frags[*]##*/}"
make -C "$KSRC" O="$KOBJ" multi_v7_defconfig >/dev/null
"$KSRC/scripts/kconfig/merge_config.sh" -m -O "$KOBJ" "$KOBJ/.config" "${frags[@]}" >/dev/null
make -C "$KSRC" O="$KOBJ" olddefconfig >/dev/null

# Every option requested by a fragment must survive olddefconfig.
fail=0
for f in "${frags[@]}"; do
	while IFS= read -r line; do
		case "$line" in
		CONFIG_*=*)
			sym=${line%%=*}
			if ! grep -qxF "$line" "$KOBJ/.config"; then
				echo "ERROR: ${f##*/}: wanted '$line', got '$(grep -E "^$sym=|^# $sym is not set" "$KOBJ/.config" || echo "$sym missing (unknown symbol or unmet dependency)")'" >&2
				fail=1
			fi ;;
		"# CONFIG_"*" is not set")
			sym=${line#\# }; sym=${sym%% *}
			if grep -q "^$sym=" "$KOBJ/.config"; then
				echo "ERROR: ${f##*/}: wanted $sym unset, got '$(grep "^$sym=" "$KOBJ/.config")'" >&2
				fail=1
			fi ;;
		esac
	done < "$f"
done
[ "$fail" = 0 ] || { echo "kernel config check failed" >&2; exit 1; }

# Build + package
log "building linux $KVER$LOCALVERSION"
rm -f "$BUILD"/linux-*.deb "$BUILD"/linux-upstream* "$BUILD"/linux-coremp135_*
make -C "$KSRC" O="$KOBJ" -j"$JOBS" \
	LOCALVERSION="$LOCALVERSION" \
	KDEB_PKGVERSION="$KPKGVER" \
	KDEB_SOURCENAME=linux-coremp135 \
	KDEB_COMPRESS=xz \
	KBUILD_BUILD_USER=coremp135 KBUILD_BUILD_HOST=build \
	DPKG_FLAGS=-d \
	bindeb-pkg

rm -f "$DEBS"/linux-image-* "$DEBS"/linux-headers-*
mv "$BUILD"/linux-image-*.deb "$BUILD"/linux-headers-*.deb "$DEBS/"
rm -f "$BUILD"/linux-libc-dev_*.deb "$BUILD"/linux-coremp135_* "$BUILD"/linux-image-*-dbg_*.deb
make -s -C "$KSRC" O="$KOBJ" LOCALVERSION="$LOCALVERSION" kernelrelease > "$OUT/kernel-release"
log "kernel packages:"; ls -l "$DEBS"/linux-*
