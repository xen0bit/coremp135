# TODO / known gaps

## Needs verification on hardware
This build compiles and the update path has been tested in emulation. These
items still need a real board:

- [ ] TF-A/OP-TEE/U-Boot reach the U-Boot prompt (console on PORT.C).
- [ ] Console pin swap: Linux uses `rx-tx-swap` on USART6 (copied from
      M5Stack), the bootloaders don't. Decide whether to keep it.
- [ ] Both Ethernet ports link at 1 Gbit/s. The PHYs supply the 125 MHz
      clock on ETHx_CLK125 (no `st,ext-phyclk`), as in the vendor DT.
- [ ] LCD: `panel-mipi-dbi` + `/lib/firmware/m5stack,coremp135-panel.bin`.
      Check the orientation (MADCTL in `board/panel/*.txt`), colours (BGR,
      inversion) and the 40 MHz SPI clock.
- [ ] Touch axes vs. LCD orientation (`touchscreen-*` properties).
- [ ] Backlight: `/sys/class/backlight/*/brightness` 0–100.
- [ ] `poweroff` really cuts power (AXP2101).
- [ ] Speaker: `aplay -l`, then `speaker-test -c 1 -D plughw:<card>` (SAI1 clocks come from
      OP-TEE PLL3 via SCMI).
- [ ] CAN: `ip link set can0 up type can bitrate 500000`; can0 <-> can1 loopback.
- [ ] RS485 on `/dev/ttySTM3` (hardware DE on PD12).
- [ ] USB-A ports (via GL852G hub) and USB-C gadget serial.
- [ ] HDMI: the LTDC pixel clock is 74.25 MHz from PLL4 (owned by OP-TEE).
      Check that Linux can get that rate, or tune `pll4` in
      `board/dts/optee/` so that LTDC_PX can reach it.

## Planned
- [ ] **Replace the HDMI blob** with a Linux DRM bridge driver for the
      LT8618SXB. M5Stack published U-Boot source for the same init sequence
      (`board/m5stack/coremp135_5_15/patches/uboot/0005-lt8618sx.patch` in
      CoreMP135_buildroot-external-st), which gives the register sequence.
      Then drop `coremp135-hdmi-blob` and wire `panel-hdmi` as a bridge.
- [ ] **AXP2101 regulator driver** (upstreamable) instead of the backlight
      shim. This would allow OPPs above 650 MHz (900 MHz/1 GHz need
      VDDCPU = 1.35 V) and suspend support.
- [ ] Upstream the board DTs and the AXP2101 support (Linux, U-Boot, TF-A, OP-TEE).
- [ ] Trim the kernel: `multi_v7_defconfig` builds many unrelated platforms
      and DTBs.
- [ ] Optional: A/B rootfs or RAUC for unattended updates.
