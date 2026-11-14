#!/bin/bash
# Clone (or reset) all upstream trees at the pinned refs and apply board patches.
source "$(dirname "$0")/common.sh"
want="${*:-tfa optee uboot linux}"
for c in $want; do
	case $c in
	tfa)   fetch_src tfa   "$TFA_REPO"   "$TFA_REF" ;;
	optee) fetch_src optee "$OPTEE_REPO" "$OPTEE_REF" ;;
	uboot) fetch_src uboot "$UBOOT_REPO" "$UBOOT_REF" ;;
	linux) fetch_src linux "$LINUX_REPO" "$LINUX_REF" ;;
	*) echo "unknown component $c" >&2; exit 1 ;;
	esac
done
