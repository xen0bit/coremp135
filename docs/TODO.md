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
- [ ] **Ethernet `end0` (ETH1, 5800a000): PHY1 is held in reset on the test
      board (likely a hardware fault).** Every open fails with
      `Failed to reset the dma`: the DWMAC DMA reset needs the 125 MHz clock
      from the PHY (ETH1_CLK125, PF12), and PHY1 never runs.
      - Nothing answers on end0's MDIO bus at any address, even with
        `reset-gpios` removed. The `RTL8211F` driver binding is not evidence
        of a PHY: with `ethernet-phy-id001c.c916` the kernel doesn't read the ID.
      - PHY1's reset ETH1_RSTN (PA10) won't go high. With a GPIO hog driving
        it high, GPIOA is push-pull output with ODR=1 but IDR=0. PA14
        (ETH2_RSTN) in the same state reads 1. PA10 isn't secured by OP-TEE
        (SECCFGR=0) and nothing else claims it.
      - The schematic (Sch_M5_CoreMP135_2024-04-24, p. 9, 11) matches our DT
        for every ETH1 pin. Each PHY has its own 25 MHz crystal and filtered
        VDD_3V3, and ETH1_RSTN only has R32 = 4.7k to GND (same as ETH2's
        R33), which a push-pull output easily overrides.
      - So the line is pulled low on the board: a solder bridge, the wrong
        part at R32, or a damaged PA10/PHYRSTB pin. Check with the board
        unpowered: R32 to GND should read about 4.7 kOhm, near 0 means a short.
        Booting M5Stack's stock image should show the same failure.
      - Not the cause: pinmux, SYSCFG PMCSETR (`0x20200000`, both RGMII with
        the PHY clock), RCC clocks, PHY ALDPS, longer reset delays, or a
        missing PMIC rail (ALDO3/4 and BLDO2 are off, but M5Stack's software
        never enables them and the PHYs run from VDD_3V3).
- [ ] TF-A/OP-TEE/U-Boot console on PORT.C (needs a USB-UART).
- [ ] Console pin swap: Linux uses `rx-tx-swap` on USART6 (copied from
      M5Stack), the bootloaders don't. Decide whether to keep it.
- [ ] OTP has no MAC addresses programmed; the kernel assigns random ones and
      udev's `MACAddressPolicy=persistent` keeps them stable (derived from
      `/etc/machine-id`, so they change on reflash). Consider deriving them
      from the SoC UID in U-Boot instead.
- [ ] CAN: `ip link set can0 up type can bitrate 500000`; can0 <-> can1 loopback.
- [ ] RS485 on `/dev/ttySTM3` (hardware DE on PD12).
- [x] HDMI pipeline with the new boot firmware: PLL4Q and the LTDC pixel clock
      are 74.25 MHz, the LT8618SXB probes (chip ID 17 02 e2) and its TX PLL
      locks. SDMMC runs from PLL4P = 99 MHz (49.5 MHz bus clock): SD reads
      22.9 MB/s vs 23.2 MB/s before. The hardware RNG (PLL4R = 49.5 MHz) works.
- [x] HDMI on a monitor (2026-11-15): 1280x720@60, an 8-bar RGB565 test
      pattern on `/dev/fb0` shows the right colours in order with all four
      edges visible; a 48 kHz stereo tone on the `CoreMP135-HDMI` card plays
      on both channels. (Needs the PLL4 firmware: `sudo coremp135-flash-bootloader`.)
- [x] HDMI modes from EDID (2026-11-16): the bridge reads EDID (256 bytes)
      and HPD; with a monitor whose preferred mode is 1080p60 it offers
      720p60 (used) and 720p50, and `modetest` switches to 720p50 with the
      right AVI VIC (19). Other clocks need a different PLL4 plan; 1080p60 is
      over the LTDC's 90 MHz pad limit.
- [x] Suspend-to-idle (2026-11-16): `systemctl suspend`, screens off, a tap
      on the LCD wakes it; display, Ethernet and the kiosk come back. The
      wake tap itself is lost (edt-ft5x06 reads it before I2C resumes, one
      "Transfer while suspended" warning).
- [ ] RTC timed power-on: the BM8563 INT drives the AXP2101 IRQ pin, but an
      alarm doesn't power the board on after `poweroff` (tested). The
      AXP2101's sleep mode with IRQ-pin wakeup might; needs the datasheet.

## Planned
- [x] **AXP2101 regulator driver** (`axp2101-regulator`, board patch 0005):
      all rails in `/sys/class/regulator`, the used ones always-on with
      their OTP voltages. Not possible on this board: CPU above 650 MHz
      (VDDCPU and VDDCORE share DCDC2; 1.35 V for overdrive is out of
      VDDCORE's range).
- [ ] Suspend-to-RAM: needs PSCI SYSTEM_SUSPEND (STM32MP13 low-power modes)
      in OP-TEE; upstream OP-TEE has none for stm32mp1, ST's fork does.
- [ ] Upstream the board DTs, the AXP2101 support and the LT8618SXB driver
      (Linux, U-Boot, TF-A, OP-TEE).
- [ ] Optional: A/B rootfs or RAUC for unattended updates.
