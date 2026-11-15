# TODO / known gaps

## Needs verification on hardware
First board test (2026-11-14, CI image from `main`):

- [x] TF-A → OP-TEE → U-Boot → Linux boots from SD; rootfs grows; first-boot
      SSH keys; `apt update`/`install` from Debian and the Pages repo.
- [x] USB-C gadget serial console (`/dev/ttyACM*` on the host).
- [x] RTC (`rtc0`, BM8563) sets the clock at boot and is kept in sync by NTP.
- [x] LCD (`panel-mipi-dbi`, 40 MHz SPI) shows the text console the right way
      up (`fbcon=map:1`). Backlight dims; the speaker plays a test tone.
- [x] `poweroff` cuts power via the AXP2101.
- [x] Touch (FT6336U) reports taps with axes matching the LCD; both ALSA cards present.
- [x] USB-A (GL852G hub): a USB 3.0 flash drive enumerates at high speed,
      `usb-storage` binds, ~35 MB/s sequential read.
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
- [ ] OTP has no MAC addresses programmed; the kernel assigns random ones and
      udev's `MACAddressPolicy=persistent` keeps them stable (derived from
      `/etc/machine-id`, so they change on reflash). Consider deriving them
      from the SoC UID in U-Boot instead.
- [ ] CAN: `ip link set can0 up type can bitrate 500000`; can0 <-> can1 loopback.
- [ ] RS485 on `/dev/ttySTM3` (hardware DE on PD12).
- [ ] HDMI picture and audio on a monitor (`lontium-lt8618sxb` bridge driver,
      720p60, 74.25 MHz pixel clock from PLL4Q). PLL4 changed from a 600 to a
      594 MHz VCO for this, so SDMMC now runs from 99 MHz (49.5 MHz bus clock
      in high-speed mode): re-check SD card speed. The PLL settings only take
      effect after `sudo coremp135-flash-bootloader`.
- [ ] HDMI modes other than 720p: read EDID through the LT8618SXB's DDC
      master, and program the chip for the chosen mode.

## Planned
- [ ] **AXP2101 regulator driver** (upstreamable) instead of the backlight
      shim. This would allow OPPs above 650 MHz (900 MHz/1 GHz need
      VDDCPU = 1.35 V) and suspend support.
- [ ] Upstream the board DTs, the AXP2101 support and the LT8618SXB driver
      (Linux, U-Boot, TF-A, OP-TEE).
- [ ] Optional: A/B rootfs or RAUC for unattended updates.
