# Updating

## On a device

```sh
sudo apt update
sudo apt full-upgrade
```

This updates:
- **Debian userland** from deb.debian.org (trixie, trixie-updates, trixie-security).
- **The kernel**: `linux-image-coremp135` always depends on the newest
  `linux-image-<version>-coremp135`. On install, the kernel hook
  (`/etc/kernel/postinst.d/zz-coremp135-extlinux`) runs `update-extlinux`. It
  copies the DTB and overlays to `/boot/dtbs/<version>/` and rewrites
  `/boot/extlinux/extlinux.conf` with the newest kernel as the default and
  older ones (up to `MAX_KERNELS`) as fallback entries in U-Boot's menu.
  Pick a fallback on the serial console during the 2-second boot menu.
- **Board support** (`coremp135-support`): the extlinux hook, LCD init file and first-boot service.
- **Boot firmware** (`coremp135-firmware`): the TF-A/OP-TEE/U-Boot files are
  installed to `/usr/lib/coremp135/firmware`, but **not flashed**. Write them
  to the SD card yourself when you choose to:

  ```sh
  sudo coremp135-flash-bootloader
  ```

  This writes the FIP first, then the backup BL2 (`fsbl2`), then the primary
  BL2 (`fsbl1`). If a new bootloader doesn't boot, put the card in a PC and
  write the files from a known-good build with `dd` (see FLASHING.md).

Old kernels are removed with `sudo apt autoremove` like on any Debian system.

### Apt repository

Images built by CI contain `/etc/apt/sources.list.d/coremp135.sources`
pointing at the repository on GitHub Pages, plus its signing key in
`/usr/share/keyrings/coremp135-archive-keyring.pgp`.

Local builds only add the source when `APT_REPO_URL` is set, e.g.:

```sh
APT_REPO_URL=https://example.org/coremp135 make image
```

## In the build

All upstream versions are pinned in `versions.env`.

| To update | Change | Notes |
|---|---|---|
| Kernel point release | `LINUX_REF=v6.18.x` | Usually just works; patches are tiny |
| Kernel major (next LTS) | `LINUX_REF=v7.y.z` | Rebase `board/patches/linux`, check the fragment report |
| U-Boot | `UBOOT_REF` | Check `board/uboot/coremp135.config` still applies |
| OP-TEE | `OPTEE_REF` | Rebase `board/patches/optee` (flavor registration) |
| TF-A | `TFA_REF` | Check `board/dts/tfa` against upstream `fdts/stm32mp135f-dk.dts` |
| Debian release | `DEBIAN_SUITE`, `APT_SUITE`, `rootfs/overlay/etc/apt/` | |

`make` (or CI) rebuilds, and `make repo` publishes.

### Package versions

Versions go up automatically when a package's inputs change. They are derived
from the number of git commits touching those inputs (`input_rev` in
`scripts/common.sh`):

| Package | Version | Inputs |
|---|---|---|
| `linux-image-<kver>-coremp135` | `<kver>-<PKG_REVISION>.<n>` | `kernel/`, `board/dts/linux`, `board/patches/linux`, `versions.env` |
| `coremp135-firmware` | `1.<n>-<PKG_REVISION>` | `board/dts`, `board/patches/{tfa,optee,uboot}`, `board/uboot`, `versions.env` |
| `coremp135-support` | `1.<n>-<PKG_REVISION>` | `packages/coremp135-support`, `board/panel` |

`publish-repo.sh` skips any package whose version is already in the repository.
To force a republish without changing inputs, raise `PKG_REVISION` in
`versions.env`.

### Switching to ST's vendor trees

STMicroelectronics maintains `*-stm32mp` branches of all four projects (e.g.
`v6.18-stm32mp-r1`). They have more complete low-power and DVFS support. To try
them, point the `*_REPO`/`*_REF` lines in `versions.env` at
`https://github.com/STMicroelectronics/<project>` and rebuild. The board
patches and DTs may need small adjustments.

## CI setup (GitHub)

1. Create a signing key once and store it as a repository secret:

   ```sh
   gpg --batch --passphrase '' --quick-gen-key "CoreMP135 apt <you@example.org>" ed25519 sign never
   gpg --export-secret-keys --armor "CoreMP135 apt" | gh secret set APT_SIGNING_KEY
   ```

2. Enable GitHub Pages for the `gh-pages` branch.
3. Push to `main`. CI builds everything, uploads the image as an artifact
   and publishes the apt repository. Tag `vX.Y` to attach the image to a
   GitHub release.

Without `APT_SIGNING_KEY`, CI still builds, but it skips publishing, so devices
never see a repository whose key changes on every run.
