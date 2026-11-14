# Adding drivers and components

There are four extension points. Pick the one that matches what you're adding:

| You want… | Edit | Ships via |
|---|---|---|
| an in-kernel driver (USB WiFi, USB serial, CAN adapter…) | `kernel/config/fragments/*.config` | `linux-image-*` package |
| firmware for a device | `rootfs/packages.list` (Debian `firmware-*`) | Debian archive |
| a driver that isn't in mainline | `board/patches/linux/NNNN-*.patch` or a DKMS package | `linux-image-*` / DKMS |
| to enable a bus or pins on M5-Bus/Grove | a DT overlay in `board/dts/linux/overlays/` | `linux-image-*` package |

After changing the kernel config, patches or DT, run `make kernel packages`
(or push to CI). Devices then pick up the change with `sudo apt full-upgrade`.
After changing the Debian package list, rebuild the image, or simply
`apt install` the package on running devices.

## Kernel config fragments

The kernel is `multi_v7_defconfig` plus every `kernel/config/fragments/*.config`
in name order:

```
00-coremp135-base.config   board essentials (don't remove things here)
10-usb-serial.config       USB serial adapters, USB-CAN, USB-Ethernet, modems
20-wifi.config             USB WiFi dongles
30-bluetooth.config        USB Bluetooth dongles
99-local.config            your private additions (git-ignored)
```

`scripts/build-kernel.sh` checks the result: any option you asked for that
does not appear in the final `.config` stops the build with a message. That
catches typos, renamed symbols and unmet dependencies. For example:

```
ERROR: 20-wifi.config: wanted 'CONFIG_RTW88_8822BU=m', got 'CONFIG_RTW88_8822BU missing (unknown symbol or unmet dependency)'
```

To find a symbol and its dependencies:

```sh
make shell
cd build/src/linux
grep -rn "config RTW88_8822BU" --include=Kconfig* drivers/
make O=../../linux-obj menuconfig     # search with '/'
```

### Example 1: a USB WiFi dongle (Realtek RTL8821CU)

1. Find the driver: `lsusb` on the device shows `0bda:c811`. A search of
   `drivers/net/wireless` shows it's handled by `rtw88_8821cu`.
2. Enable it in `kernel/config/fragments/20-wifi.config`. It's already enabled; for a
   new one, add `CONFIG_RTW88_8821CU=m`.
3. Firmware: rtw88 loads `rtw88/rtw8821c_fw.bin`, which is in Debian's
   `firmware-realtek`, already in `rootfs/packages.list`. Use
   `apt-file search <firmware-name>` on any Debian machine to find the package.
4. `make kernel packages` → publish → `sudo apt full-upgrade` on the device.
5. Connect: `nmcli dev wifi connect "<SSID>" password "<pass>"`.

### Example 2: a USB serial adapter (FTDI / CH340 / CP2102)

1. Already enabled in `10-usb-serial.config`: `CONFIG_USB_SERIAL_FTDI_SIO`,
   `CONFIG_USB_SERIAL_CH341`, `CONFIG_USB_SERIAL_CP210X`,
   `CONFIG_USB_SERIAL_PL2303` and `CONFIG_USB_ACM` (CDC-ACM, e.g. Arduino, ESP32-S3).
2. For something else, e.g. a Keyspan adapter, add
   `CONFIG_USB_SERIAL_KEYSPAN=m` to `10-usb-serial.config`.
3. Plug it in: `/dev/ttyUSB0` (or `/dev/ttyACM0`). The `coremp135` user is in
   the `dialout` group.

## Out-of-tree drivers

- **Small or board-specific:** add a `git format-patch` style patch to
  `board/patches/linux/`. Patches are applied in name order to a pristine tree on
  every build. Add the matching `CONFIG_` option to a fragment.
- **Vendor drivers you don't want to carry as patches** (e.g. Realtek
  out-of-tree WiFi): package them as DKMS. The image can install
  `linux-headers-coremp135` (published with every kernel), so
  `apt install dkms <driver>-dkms` builds against the running kernel.

## Device tree overlays

The board DT is `board/dts/linux/stm32mp135f-coremp135.dts`. Optional
hardware on the M5-Bus/Grove ports is enabled with overlays in
`board/dts/linux/overlays/*.dtso`, which are built into the kernel package.

Included:

| Overlay | Effect |
|---|---|
| `coremp135-mbus-uart2` | USART2 on the M5-Bus → `/dev/ttySTM2` |
| `coremp135-mbus-spidev` | SPI4 on the M5-Bus with a spidev on CS0 |
| `coremp135-usb-c-host` | USB-C port as host instead of gadget |

To enable an overlay on a device:

```sh
sudo sed -i 's/^OVERLAYS=.*/OVERLAYS="coremp135-mbus-uart2"/' /etc/default/coremp135
sudo update-extlinux && sudo reboot
```

To add one, drop a `.dtso` into `board/dts/linux/overlays/`, using the board DT's
labels (`&spi4`, `&usart2`, `&i2c1`, …). It's added to the kernel build
automatically.

## Board-level userland

Packages for the board live in `packages/<name>/` (`DEBIAN/` control files
plus a `root/` tree) and are assembled by `scripts/build-packages.sh`. Add a
new directory and a `stage`/`build_deb` block there to ship more board
tooling through the apt repo.
