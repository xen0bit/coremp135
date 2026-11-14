#!/bin/bash
# Run a command inside the build container with the repo mounted at /work.
#   scripts/docker-run.sh make image
# Runs privileged: the rootfs step registers qemu-arm binfmt and runs
# mmdebstrap as root. Build outputs (except rootfs trees) are chowned back to
# the calling user.
set -euo pipefail
TOP="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${COREMP135_BUILDER:-coremp135-builder}"
docker build -q -t "$IMAGE" "$TOP/docker" >/dev/null
tty=(); [ -t 0 ] && tty=(-it)
exec docker run --rm "${tty[@]}" --privileged \
	-v "$TOP:/work" -w /work \
	-e JOBS -e PKG_REVISION -e APT_REPO_URL -e APT_SIGNING_KEY -e REPO_DIR -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
	"$IMAGE" bash -c '"$@"; rc=$?
		# Hand build outputs back to the caller, but never the target root
		# filesystems: their root ownership and setuid bits go into the image.
		find /work/build \( -path /work/build/rootfs -o -path "/work/build/*-rootfs" \) -prune \
			-o -exec chown -h "$HOST_UID:$HOST_GID" {} + 2>/dev/null
		exit $rc' _ "$@"
