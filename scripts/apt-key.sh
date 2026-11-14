#!/bin/bash
# Ensure an apt repo signing key exists in $BUILD/gnupg and export its
# public part to $OUT/coremp135-archive-keyring.pgp.
#   APT_SIGNING_KEY  armored private key (CI secret). Otherwise a local,
#                    throwaway key is generated once per build directory.
source "$(dirname "$0")/common.sh"
export GNUPGHOME="$BUILD/gnupg"
mkdir -p "$GNUPGHOME"; chown -R "$(id -u):$(id -g)" "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
if [ -n "${APT_SIGNING_KEY:-}" ]; then
	echo "$APT_SIGNING_KEY" | gpg --batch --quiet --import
elif ! gpg --batch --list-secret-keys 2>/dev/null | grep -q sec; then
	log "generating a local apt signing key (set APT_SIGNING_KEY for a stable one)"
	gpg --batch --quiet --passphrase '' --quick-gen-key \
		"CoreMP135 local build <noreply@example.invalid>" ed25519 sign never
fi
gpg --batch --export > "$OUT/coremp135-archive-keyring.pgp"
gpg --batch --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}' > "$OUT/apt-key.fpr"
