# Flashing and recovery

## Write the image

Download the `.img.xz` from the newest
[release](https://github.com/xen0bit/coremp135/releases/latest) (every merge to
`main` makes one), check it against `sha256sums`, and write it:

```sh
sha256sum -c --ignore-missing sha256sums
xzcat build-YYYYMMDD-<commit>-coremp135-debian-trixie.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

You can also use balenaEtcher or Raspberry Pi Imager ("use custom"), both of
which read `.img.xz` directly. Any microSD card of 2 GB or more works; the root
filesystem grows to fill the card on first boot.

## Partition layout (GPT)

| # | Name | Size | Contents |
|---|---|---|---|
| 1 | `fsbl1` | 256 KiB | TF-A BL2 (`tf-a-stm32mp135f-coremp135.stm32`) |
| 2 | `fsbl2` | 256 KiB | TF-A BL2 (backup copy) |
| 3 | `fip` | 4 MiB | FIP: OP-TEE + U-Boot + DTBs (`fip.bin`) |
| 4 | `u-boot-env` | 512 KiB | U-Boot environment |
| 5 | `rootfs` | rest | ext4, legacy-bootable; `/boot/extlinux/extlinux.conf` |

The STM32MP13 ROM code finds `fsbl1`/`fsbl2` by name, TF-A finds `fip` by
name, U-Boot finds `u-boot-env` by name and boots the `rootfs` partition
because of its legacy-bootable flag. The kernel mounts root by
`PARTLABEL=rootfs`. Keep these names if you re-partition.

The layout matches M5Stack's images, so their docs on boot pins and recovery still apply.

## Boot firmware recovery from a PC

If a bootloader update fails, write a known-good firmware build (the
`tf-a-stm32mp135f-coremp135.stm32` and `fip.bin` attached to every release, or
`build/out/firmware/`) back to the card:

```sh
sudo dd if=fip.bin of=/dev/disk/by-partlabel/fip conv=fsync
sudo dd if=tf-a-stm32mp135f-coremp135.stm32 of=/dev/disk/by-partlabel/fsbl2 conv=fsync
sudo dd if=tf-a-stm32mp135f-coremp135.stm32 of=/dev/disk/by-partlabel/fsbl1 conv=fsync
```

Check that the by-partlabel links point at the SD card and not at your PC's
disk (`lsblk -o NAME,PARTLABEL`).

## Serial console

PORT.C (the Grove connector labelled C) carries USART6 at 115200 8N1 (3.3 V).
Boot messages from TF-A, OP-TEE, U-Boot and Linux all appear there. Once Linux
is up, a second console is available over USB-C (`/dev/ttyACM0` on the host).

> M5Stack's vendor DT sets `rx-tx-swap` on USART6 for Linux, while TF-A,
> OP-TEE and U-Boot don't swap the pins. This build copies that behaviour
> exactly. If you see bootloader output but no kernel output (or the other
> way round), swap RX/TX on your adapter for the other stage, and please
> report which wiring works.
