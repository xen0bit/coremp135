#!/bin/bash
# Add the built .debs to a signed apt repository (reprepro) in $REPO_DIR
# (default $OUT/repo). Existing repo state in that directory is kept, so CI
# can check out the gh-pages branch there and publish incrementally.
source "$(dirname "$0")/common.sh"
REPO_DIR="${REPO_DIR:-$OUT/repo}"

"$TOP/scripts/apt-key.sh"
export GNUPGHOME="$BUILD/gnupg"
FPR=$(cat "$OUT/apt-key.fpr")

mkdir -p "$REPO_DIR/conf"
cat > "$REPO_DIR/conf/distributions" <<DIST
Origin: CoreMP135
Label: CoreMP135
Suite: $APT_SUITE
Codename: $APT_SUITE
Architectures: armhf
Components: main
Description: Debian packages for the M5Stack CoreMP135
SignWith: $FPR
DIST
cat > "$REPO_DIR/conf/options" <<OPT
basedir $REPO_DIR
OPT

for deb in "$DEBS"/*.deb; do
	name=$(dpkg-deb -f "$deb" Package); ver=$(dpkg-deb -f "$deb" Version)
	have=$(reprepro -b "$REPO_DIR" --list-format '${version}\n' list "$APT_SUITE" "$name" 2>/dev/null | head -n1)
	if [ "$have" = "$ver" ]; then
		echo "skip $name $ver (already published; bump the version to republish)"
		continue
	fi
	reprepro -b "$REPO_DIR" --ignore=wrongdistribution includedeb "$APT_SUITE" "$deb"
done
# Packages we no longer build. Devices drop them via Conflicts on upgrade.
for old in coremp135-hdmi-blob; do
	reprepro -b "$REPO_DIR" remove "$APT_SUITE" "$old" >/dev/null 2>&1 || true
done
reprepro -b "$REPO_DIR" export
cp "$OUT/coremp135-archive-keyring.pgp" "$REPO_DIR/"
touch "$REPO_DIR/.nojekyll"
cat > "$REPO_DIR/index.html" <<HTML
<!doctype html><title>CoreMP135 apt repository</title>
<h1>CoreMP135 apt repository</h1>
<pre>
sudo curl -fsSLo /usr/share/keyrings/coremp135-archive-keyring.pgp ${APT_REPO_URL:-&lt;this-url&gt;}/coremp135-archive-keyring.pgp
echo "deb [signed-by=/usr/share/keyrings/coremp135-archive-keyring.pgp] ${APT_REPO_URL:-&lt;this-url&gt;} $APT_SUITE main" | sudo tee /etc/apt/sources.list.d/coremp135.list
</pre>
HTML
log "repository in $REPO_DIR:"; reprepro -b "$REPO_DIR" list "$APT_SUITE"
