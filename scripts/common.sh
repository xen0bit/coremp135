# Sourced by all build scripts.
set -euo pipefail
TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../versions.env
source "$TOP/versions.env"
BUILD="${BUILD:-$TOP/build}"
SRC="$BUILD/src"
OUT="$BUILD/out"           # final artifacts (bootloader bins, .debs, images)
DEBS="$OUT/debs"
export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
JOBS="${JOBS:-$(nproc)}"
BOARD_DTB=stm32mp135f-coremp135
mkdir -p "$SRC" "$OUT" "$DEBS"

log() { printf '\033[1;34m==> %s\033[0m\n' "$*"; }

# with_mirrors <cmd...>: run a git command with kernel.org URLs redirected to
# GitHub mirrors. Used as a retry when git.kernel.org is unreachable (it has
# been from GitHub's runners at times).
with_mirrors() {
	log "retrying via GitHub mirrors: $*"
	GIT_CONFIG_COUNT=2 \
	GIT_CONFIG_KEY_0=url.https://github.com/gregkh/linux.git.insteadOf \
	GIT_CONFIG_VALUE_0=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
	GIT_CONFIG_KEY_1=url.https://github.com/dgibson/dtc.git.insteadOf \
	GIT_CONFIG_VALUE_1=https://git.kernel.org/pub/scm/utils/dtc/dtc.git \
	"$@"
}

# fetch_src <name> <repo> <ref>: shallow clone at ref into $SRC/<name>, apply
# board/patches/<name>/*.patch on a pristine tree (re-run safe).
fetch_src() {
	local name=$1 repo=$2 ref=$3 dir="$SRC/$1"
	if [ ! -d "$dir/.git" ] || [ "$(git -C "$dir" describe --tags --exact-match 2>/dev/null)" != "$ref" ]; then
		rm -rf "$dir"
		log "cloning $name @ $ref"
		git clone --depth 1 --branch "$ref" "$repo" "$dir" ||
			{ rm -rf "$dir"; with_mirrors git clone --depth 1 --branch "$ref" "$repo" "$dir"; }
	fi
	if [ -f "$dir/.gitmodules" ]; then
		git -C "$dir" submodule update --init --depth 1 --recursive ||
			with_mirrors git -C "$dir" submodule update --init --depth 1 --recursive
	fi
	git -C "$dir" reset -q --hard
	git -C "$dir" submodule foreach -q --recursive 'git reset -q --hard' 2>/dev/null || true
	git -C "$dir" clean -qfdx -e '/build*' -e '/out*'
	local p
	for p in "$TOP"/board/patches/"$name"/*.patch; do
		[ -e "$p" ] || continue
		log "patch $name: $(basename "$p")"
		git -C "$dir" apply --whitespace=nowarn "$p"
	done
}

# input_rev <paths...>: number of commits touching these paths. Used in package
# versions so they only increase when a package's inputs change.
input_rev() { git -C "$TOP" rev-list --count HEAD -- "$@" 2>/dev/null || echo 0; }
