# TODO / known gaps

## Needs verification on hardware
First board test (2026-11-14, CI image from `main`):

- [x] TF-A → OP-TEE → U-Boot → Linux boots from SD; rootfs grows; first-boot
      SSH keys; `apt update`/`install` from Debian and the Pages repo.
- [x] USB-C gadget serial console (`/dev/ttyACM*` on the host).
- [x] RTC (`rtc0`, BM8563) sets the clock at boot and is kept in sync by NTP.
- [x] LCD framebuffer + backlight device, touch input device, both ALSA cards,
      HDMI blob service runs, USB hub enumerates.
- [x] Ethernet `end1` (ETH2, 5800e000) links at 1 Gbit/s with DHCP.
- [ ] **Ethernet `end0` (ETH1, 5800a000) doesn't come up**: every open fails with
      `Failed to reset the dma`, with or without a cable. The DWMAC DMA
      software reset needs RX_CLK and the 125 MHz clock on ETH1_CLK125 (PF12)
      from the PHY, so one of them is missing. The same open works on `end1`
      without a cable. Already ruled out:
      - pinmux (identical to M5Stack's DT and to mainline `eth1_rgmii_pins_a`);
      - SYSCFG mode (PMCSETR `0x20200000`: both RGMII with an external clock);
      - RCC clocks (identical for both MACs);
      - PHY ALDPS (off);
      - a longer PHY reset delay (200 ms).
      Next steps: check on the stock M5Stack image whether this port works at
      all, then read PHY1's PHYCR2 CLKOUT from U-Boot (`mdio read`) or check
      the schematic for how ETH1_CLK125 is wired.
- [ ] TF-A/OP-TEE/U-Boot console on PORT.C (needs a USB-UART).
- [ ] Console pin swap: Linux uses `rx-tx-swap` on USART6 (copied from
      M5Stack), the bootloaders don't. Decide whether to keep it.
- [ ] LCD: `panel-mipi-dbi` + `/lib/firmware/m5stack,coremp135-panel.bin`.
      Check the orientation (MADCTL in `board/panel/*.txt`), colours (BGR,
      inversion) and the 40 MHz SPI clock.
- [ ] Touch axes vs. LCD orientation (`touchscreen-*` properties).
- [ ] Backlight: changing `/sys/class/backlight/*/brightness` (0–100) dims the panel.
- [ ] OTP has no MAC addresses programmed; the kernel assigns random ones and
      udev's `MACAddressPolicy=persistent` keeps them stable (derived from
      `/etc/machine-id`, so they change on reflash). Consider deriving them
      from the SoC UID in U-Boot instead.
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
