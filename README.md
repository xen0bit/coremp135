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

Nothing comes from M5Stack's prebuilt toolchains or `dl.7z` caches. The only
vendor binary is the optional HDMI bridge tool (see [HDMI](#hdmi)), which is
downloaded at a pinned commit, checked against a sha256 and never committed.

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
kernel/config/fragments/     kernel config fragments (on top of multi_v7_defconfig)
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
| 2" 320x240 LCD (ILI9342C, SPI) | `panel-mipi-dbi` + init file | mainline driver, text console (`fbcon=map:1`) |
| LCD backlight (AXP2101 DLDO1) | `axp2101_m5stack_bl` | board patch |
| Power off (AXP2101) | `axp2101-poweroff` | board patch |
| Touch (FT6336U) | `edt-ft5x06` | mainline |
| RTC (BM8563) | `rtc-pcf8563` | mainline, `rtc0` |
| Speaker (NS4168 via SAI1A) | `stm32-sai` + `simple-audio-card` | mainline |
| 2x CAN FD | `m_can` | mainline |
| RS485 (USART3) | `stm32-usart` RS485 mode | mainline, `/dev/ttySTM3` |
| USB-A x2 (GL852G hub) | EHCI/OHCI | mainline |
| USB-C OTG | DWC2, peripheral by default | mainline, `usb-c-host` overlay |
| HDMI (LT8618SXB) | M5Stack userspace binary | see below |
| CPU DVFS | SCMI perf via OP-TEE | limited to 650 MHz (see TODO) |

### HDMI

The LTDC sends 1280x720 RGB to the LT8618SXB bridge. Mainline has no driver for
this bridge, so the `coremp135-hdmi-blob` package runs M5Stack's closed
`lt8618sxb_mcu_config` tool at boot. Replacing it with a DRM bridge driver is
tracked in [docs/TODO.md](docs/TODO.md). To leave HDMI out, drop the package
or `systemctl disable coremp135-hdmi`.

## Credits

Board device trees, the AXP2101 drivers and the LCD init sequence are derived
from M5Stack's [CoreMP135_buildroot-external-st](https://github.com/m5stack/CoreMP135_buildroot-external-st)
and STMicroelectronics' upstream STM32MP135F-DK support.
