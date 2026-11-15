# Debian for the M5Stack CoreMP135

A reproducible **Debian 13 (trixie) armhf** image for the
[M5Stack CoreMP135](https://docs.m5stack.com/en/core/CoreMP135) (STM32MP135),
built entirely from upstream sources and updated with `apt`.

| Component | Source | Pinned in |
|---|---|---|
| TF-A (BL2) | trustedfirmware.org, LTS branch | `versions.env` |
| OP-TEE OS (BL32) | github.com/OP-TEE/optee_os | `versions.env` |
| U-Boot (BL33) | source.denx.de/u-boot | `versions.env` |
| Linux | kernel.org stable (6.18 LTS) | `versions.env` |
| Userland | deb.debian.org (trixie) | `versions.env`, `rootfs/packages.list` |

Nothing comes from M5Stack's prebuilt toolchains or `dl.7z` caches, and no
vendor binaries are used.

## Quick start

Requirements: Docker, about 10 GB of free disk space, and a network connection.

```sh
make            # firmware + kernel + packages + rootfs + image, all in Docker
ls build/out/   # coremp135-debian-trixie-YYYYMMDD.img(.xz), debs/, firmware/
```

Flash the image to a microSD card (see [docs/FLASHING.md](docs/FLASHING.md)):

```sh
xzcat build/out/coremp135-debian-trixie-*.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

Default login: `coremp135` / `coremp135`. You must change the password on
first login. The root account is locked; use `sudo`.

Consoles:
- **Serial** on PORT.C (Grove, USART6), 115200 8N1, `/dev/ttySTM0`
- **USB serial** on the USB-C port (`g_serial`), which shows up as `/dev/ttyACM*` on your PC
- **SSH** over either Ethernet port (DHCP via NetworkManager), reachable as `coremp135.local`

On first boot the root filesystem grows to fill the card and fresh SSH
host keys are generated.

## Make targets

| Target | What it does | Output |
|---|---|---|
| `make firmware` | OP-TEE, U-Boot, TF-A BL2 and FIP | `build/out/firmware/` |
| `make kernel` | kernel + DTBs + overlays as `.deb` | `build/out/debs/linux-*` |
| `make packages` | board packages (support, firmware, HDMI, metapackages) | `build/out/debs/` |
| `make rootfs` | Debian rootfs with mmdebstrap | `build/rootfs/` |
| `make image` | GPT SD image with genimage | `build/out/*.img.xz` |
| `make repo` | signed apt repository (reprepro) | `build/out/repo/` |
| `make shell` | shell in the build container | |

Add `NATIVE=1` to run on a Debian trixie host without Docker (install the
packages listed in `docker/Dockerfile`).

> The rootfs step runs a privileged container and registers `qemu-arm` in the
> host kernel's `binfmt_misc` so it can run armhf binaries. The registration
> lasts until the host reboots.

## Repository layout

```
versions.env                 pinned upstream refs and the apt repo URL
board/dts/{tfa,optee,uboot}  per-stage board device trees
board/dts/linux/             kernel DT (also used by U-Boot) and overlays/
board/patches/<component>/   patches applied on top of upstream, in order
board/uboot/coremp135.config U-Boot config fragment (on top of stm32mp13_defconfig)
board/panel/                 LCD init sequence (panel-mipi-dbi firmware source)
kernel/config/fragments/     kernel config fragments (on top of multi_v7_defconfig, trimmed to STM32)
rootfs/packages.list         Debian packages in the image
rootfs/overlay/, hooks/      static files and the mmdebstrap customize hook
packages/                    sources of our .deb packages
image/genimage.cfg.in        SD card partition layout
scripts/                     build steps (all runnable on their own)
.github/workflows/build.yml  CI: build, image artifact, apt repo on GitHub Pages
```

## Keeping it up to date

- **Devices:** `sudo apt update && sudo apt full-upgrade`. Kernels, DTBs and
  board support come from the project apt repository, and everything else from Debian.
- **Build:** bump a ref in `versions.env`, push, and CI publishes new packages.
  See [docs/UPDATING.md](docs/UPDATING.md).

## Adding drivers (WiFi, USB serial, …)

Add a line to a kernel config fragment, add firmware to
`rootfs/packages.list`, or add a DT overlay. Worked examples are in
[docs/ADDING_DRIVERS.md](docs/ADDING_DRIVERS.md). USB serial adapters (FTDI,
CP210x, CH34x, PL2303, CDC-ACM) and common USB WiFi/Bluetooth dongles
(Realtek, MediaTek, Atheros, Broadcom) are already enabled.

## Hardware support

| Block | Driver | Status |
|---|---|---|
| 2x Gigabit Ethernet (RTL8211F) | `dwmac-stm32` | mainline |
| microSD | `mmci` (STM32 SDMMC) | mainline |
| 2" 320x240 LCD (ILI9342C, SPI) | `panel-mipi-dbi` + init file | mainline driver, text console (`fbcon=map:1`) or a [kiosk app](#gui-apps-on-the-lcd) |
| LCD backlight (AXP2101 DLDO1) | `axp2101_m5stack_bl` | board patch |
| Power off (AXP2101) | `axp2101-poweroff` | board patch |
| Touch (FT6336U) | `edt-ft5x06` | mainline |
| RTC (BM8563) | `rtc-pcf8563` | mainline, `rtc0` |
| Speaker (NS4168 via SAI1A) | `stm32-sai` + `simple-audio-card` | mainline |
| 2x CAN FD | `m_can` | mainline |
| RS485 (USART3) | `stm32-usart` RS485 mode | mainline, `/dev/ttySTM3` |
| USB-A x2 (GL852G hub) | EHCI/OHCI | mainline |
| USB-C OTG | DWC2, peripheral by default | mainline, `usb-c-host` overlay |
| HDMI (LT8618SXB) | `lontium-lt8618sxb` DRM bridge (our patch) | 1280x720, see below |
| CPU DVFS | SCMI perf via OP-TEE | limited to 650 MHz (see TODO) |

### HDMI

The LTDC sends 1280x720 RGB to the LT8618SXB bridge. Mainline has no driver
for this bridge, so `board/patches/linux` adds a small DRM bridge driver
(`lontium-lt8618sxb`) that replays the register sequence from M5Stack's
MIT-licensed U-Boot driver when the display is enabled. The mode is fixed at
720p60 (the bridge's DDC/EDID isn't used), with the 74.25 MHz pixel clock from
PLL4Q. HDMI audio is 48 kHz I2S on the `CoreMP135-HDMI` ALSA card.

The HDMI output is DRM card 0 (`/dev/fb0`), the LCD is card 1 (`/dev/fb1`). The
text console is on the LCD (`fbcon=map:1` in `/etc/default/coremp135`); use
`fbcon=map:0` for HDMI.

### GUI apps on the LCD

`coremp135-support` ships an optional kiosk service. It runs one full-screen
Wayland app on the LCD with the [cage](https://github.com/cage-kiosk/cage)
compositor, in place of the text login on tty1:

```sh
sudo apt install cage foot
sudo systemctl enable --now coremp135-kiosk@tty1   # starts at boot from now on
```

- The app is `KIOSK_APP` in `/etc/default/coremp135-kiosk` (default: the
  `foot` terminal). After changing it, run
  `sudo systemctl restart coremp135-kiosk@tty1`.
- It runs as the `coremp135` user in a logind session. cage gets the
  touchscreen as a touch device and passes touches to the app.
- To go back to the text console:
  `sudo systemctl disable --now coremp135-kiosk@tty1 && sudo systemctl start getty@tty1`.

There is no GPU, so cage renders in software (pixman) on the 650 MHz CPU, and
the SPI link limits the panel to roughly 30 full-screen updates per second.
Pick lightweight apps; cage plus `foot` uses about 15 MB of RAM. For a custom
UI, Qt (`QT_QPA_PLATFORM=linuxfb:fb=/dev/fb1`), SDL2 (`kmsdrm`) or LVGL can
also draw on the LCD directly, without a compositor.

## Credits

Board device trees, the AXP2101 drivers and the LCD init sequence are derived
from M5Stack's [CoreMP135_buildroot-external-st](https://github.com/m5stack/CoreMP135_buildroot-external-st)
and STMicroelectronics' upstream STM32MP135F-DK support.
