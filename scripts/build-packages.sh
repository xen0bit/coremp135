#!/bin/bash
# Assemble the board .debs from packages/*: coremp135-support,
# coremp135-firmware, coremp135-hdmi-blob and the kernel metapackages.
# Needs build-firmware.sh and build-kernel.sh to have run.
source "$(dirname "$0")/common.sh"

# Versions only increase when a package's inputs change (see input_rev).
SUPPORT_VERSION="1.$(input_rev packages/coremp135-support board/panel scripts/build-packages.sh scripts/mipi-dbi-cmd.py)-$PKG_REVISION"
FIRMWARE_VERSION="1.$(input_rev board/dts board/patches/tfa board/patches/optee board/patches/uboot board/uboot scripts/build-firmware.sh versions.env)-$PKG_REVISION"
HDMI_VERSION="1.$(input_rev packages/coremp135-hdmi-blob versions.env)-$PKG_REVISION"
STAGE="$BUILD/pkg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"

"$TOP/scripts/apt-key.sh"
rm -f "$DEBS"/coremp135-*.deb "$DEBS"/linux-image-coremp135_*.deb "$DEBS"/linux-headers-coremp135_*.deb

# stage <pkgdir> -> prints staging dir with DEBIAN/ + root contents
stage() {
	local name=$1 d="$STAGE/$1"
	mkdir -p "$d"
	[ -d "$TOP/packages/$name/root" ] && cp -a "$TOP/packages/$name/root/." "$d/"
	cp -a "$TOP/packages/$name/DEBIAN" "$d/"
	echo "$d"
}
subst() { # file key value...
	local f=$1; shift
	while [ $# -gt 0 ]; do sed -i "s|@$1@|$2|g" "$f"; shift 2; done
}
build_deb() {
	local d=$1
	# drop template-only files
	rm -f "$d/DEBIAN/"control.*
	dpkg-deb --root-owner-group -Zxz --build "$d" "$DEBS/" >/dev/null
}

# --- coremp135-support
d=$(stage coremp135-support)
subst "$d/DEBIAN/control" VERSION "$SUPPORT_VERSION"
mkdir -p "$d/usr/lib/firmware"
python3 -I "$TOP/scripts/mipi-dbi-cmd.py" "$TOP/board/panel/m5stack,coremp135-panel.txt" \
	"$d/usr/lib/firmware/m5stack,coremp135-panel.bin"
mkdir -p "$d/usr/share/keyrings"
cp "$OUT/coremp135-archive-keyring.pgp" "$d/usr/share/keyrings/coremp135-archive-keyring.pgp"
if [ -n "$APT_REPO_URL" ]; then
	mkdir -p "$d/etc/apt/sources.list.d"
	cat > "$d/etc/apt/sources.list.d/coremp135.sources" <<-SRC
	Types: deb
	URIs: $APT_REPO_URL
	Suites: $APT_SUITE
	Components: main
	Signed-By: /usr/share/keyrings/coremp135-archive-keyring.pgp
	SRC
	echo /etc/apt/sources.list.d/coremp135.sources >> "$d/DEBIAN/conffiles"
fi
build_deb "$d"

# --- coremp135-firmware
d=$(stage coremp135-firmware)
subst "$d/DEBIAN/control" VERSION "$FIRMWARE_VERSION" \
	VERSIONS "Built from TF-A $TFA_REF, OP-TEE $OPTEE_REF, U-Boot $UBOOT_REF."
mkdir -p "$d/usr/lib/coremp135/firmware"
cp "$OUT"/firmware/* "$d/usr/lib/coremp135/firmware/"
build_deb "$d"

# --- coremp135-hdmi-blob (fetched, verified, never committed)
d=$(stage coremp135-hdmi-blob)
subst "$d/DEBIAN/control" VERSION "$HDMI_VERSION"
mkdir -p "$d/usr/lib/coremp135"
blob="$BUILD/lt8618sxb_mcu_config"
[ -s "$blob" ] || curl -fsSL -o "$blob" "$HDMI_BLOB_URL"
echo "$HDMI_BLOB_SHA256  $blob" | sha256sum -c --quiet
install -m 755 "$blob" "$d/usr/lib/coremp135/lt8618sxb_mcu_config"
lic="$BUILD/m5stack-LICENSE"
[ -s "$lic" ] || curl -fsSL -o "$lic" "${HDMI_BLOB_URL%%/tools/*}/LICENSE"
mkdir -p "$d/usr/share/doc/coremp135-hdmi-blob"
{ echo "lt8618sxb_mcu_config: prebuilt binary from $HDMI_BLOB_URL"
  echo "sha256: $HDMI_BLOB_SHA256"
  echo "Distributed under the license of that repository:"; echo; cat "$lic"; } \
	> "$d/usr/share/doc/coremp135-hdmi-blob/copyright"
build_deb "$d"

# --- kernel metapackages
KREL=$(cat "$OUT/kernel-release")
KPKGVER=$(dpkg-deb -f "$DEBS"/linux-image-"$KREL"_*.deb Version)
for kind in image headers; do
	d="$STAGE/linux-$kind-coremp135"; mkdir -p "$d/DEBIAN"
	src="$TOP/packages/linux-image-coremp135/DEBIAN/control"
	[ $kind = headers ] && src="$src.headers"
	cp "$src" "$d/DEBIAN/control"
	subst "$d/DEBIAN/control" VERSION "$KPKGVER" KREL "$KREL" KPKGVER "$KPKGVER"
	build_deb "$d"
done

log "packages:"; ls -l "$DEBS"
