#!/bin/bash
# Build the boot chain: OP-TEE (BL32) + U-Boot (BL33) -> TF-A BL2 (.stm32) + FIP.
# Outputs: $OUT/firmware/{tf-a-stm32mp135f-coremp135.stm32,fip.bin}
source "$(dirname "$0")/common.sh"

FW="$OUT/firmware"
mkdir -p "$FW"

"$TOP/scripts/fetch-sources.sh" optee uboot tfa

# --- OP-TEE OS -------------------------------------------------------------
log "building OP-TEE $OPTEE_REF"
cp "$TOP"/board/dts/optee/*.dts "$SRC/optee/core/arch/arm/dts/"
make -C "$SRC/optee" -j"$JOBS" \
	CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_core="$CROSS_COMPILE" \
	CROSS_COMPILE_ta_arm32="$CROSS_COMPILE" ARCH=arm \
	PLATFORM=stm32mp1-135F_COREMP135 \
	CFG_STPMIC1=n CFG_STM32_TAMP=n \
	CFG_TEE_CORE_LOG_LEVEL=2 \
	O=out
OPTEE_OUT="$SRC/optee/out/core"

# --- U-Boot ----------------------------------------------------------------
log "building U-Boot $UBOOT_REF"
cp "$TOP/board/dts/linux/$BOARD_DTB.dts" "$SRC/uboot/dts/upstream/src/arm/st/"
cp "$TOP"/board/dts/uboot/*.dtsi "$SRC/uboot/arch/arm/dts/"
make -C "$SRC/uboot" stm32mp13_defconfig
(cd "$SRC/uboot" && scripts/kconfig/merge_config.sh -m .config "$TOP/board/uboot/coremp135.config" && make olddefconfig)
make -C "$SRC/uboot" -j"$JOBS" DEVICE_TREE="st/$BOARD_DTB" all

# --- TF-A ------------------------------------------------------------------
log "building TF-A $TFA_REF"
cp "$TOP"/board/dts/tfa/*.dts "$SRC/tfa/fdts/"
make -C "$SRC/tfa" -j"$JOBS" \
	PLAT=stm32mp1 ARCH=aarch32 ARM_ARCH_MAJOR=7 STM32MP13=1 \
	CROSS_COMPILE="$CROSS_COMPILE" \
	DTB_FILE_NAME="$BOARD_DTB.dtb" \
	AARCH32_SP=optee \
	STM32MP_SDMMC=1 STM32MP_USB_PROGRAMMER=1 \
	BL32="$OPTEE_OUT/tee-header_v2.bin" \
	BL32_EXTRA1="$OPTEE_OUT/tee-pager_v2.bin" \
	BL32_EXTRA2="$OPTEE_OUT/tee-pageable_v2.bin" \
	BL33="$SRC/uboot/u-boot-nodtb.bin" \
	BL33_CFG="$SRC/uboot/u-boot.dtb" \
	all fip

cp "$SRC/tfa/build/stm32mp1/release/tf-a-$BOARD_DTB.stm32" "$FW/"
cp "$SRC/tfa/build/stm32mp1/release/fip.bin" "$FW/"
printf 'TFA=%s\nOPTEE=%s\nUBOOT=%s\n' "$TFA_REF" "$OPTEE_REF" "$UBOOT_REF" > "$FW/VERSIONS"
log "firmware ready in $FW"; ls -l "$FW"
