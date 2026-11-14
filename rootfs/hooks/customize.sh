#!/bin/bash
# mmdebstrap customize hook: $1 = rootfs path. Runs on the build host with the
# target chroot mounted; DEBS and TOP are passed in the environment.
set -euo pipefail
R=$1

# Our packages (kernel, board support, firmware, HDMI blob)
mkdir -p "$R/tmp/debs"
cp "$DEBS"/*.deb "$R/tmp/debs/"
chroot "$R" sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /tmp/debs/*.deb'
rm -rf "$R/tmp/debs"

# Static configuration
cp -a "$TOP/rootfs/overlay/." "$R/"
rm -f "$R/etc/apt/sources.list"

# Default user (password must be changed at first login), root stays locked
chroot "$R" useradd -m -s /bin/bash -c "CoreMP135 user" \
	-G sudo,adm,dialout,audio,video,input,plugdev,netdev,i2c,bluetooth coremp135
echo 'coremp135:coremp135' | chroot "$R" chpasswd
chroot "$R" chage -d 0 coremp135

# Locale
sed -i 's/^# *\(en_US.UTF-8\)/\1/' "$R/etc/locale.gen"
chroot "$R" locale-gen >/dev/null
echo 'LANG=C.UTF-8' > "$R/etc/default/locale"

# Services
chroot "$R" systemctl preset-all >/dev/null 2>&1 || true
chroot "$R" systemctl enable coremp135-firstboot.service serial-getty@ttyGS0.service coremp135-hdmi.service
# NetworkManager owns networking
chroot "$R" systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service >/dev/null 2>&1 || true

# Image hygiene: per-device identity is created at first boot
rm -f "$R"/etc/ssh/ssh_host_*
: > "$R/etc/machine-id"
rm -f "$R/var/lib/dbus/machine-id"
chroot "$R" apt-get clean
rm -rf "$R"/var/lib/apt/lists/* "$R"/var/cache/apt/*.bin "$R"/var/log/*.log
echo "customize: done"
