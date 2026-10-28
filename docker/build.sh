#!/bin/bash
# Build the Oracle Linux 8 image containing patched UHD + rfnoc-oot-blocks.
# Usage: docker/build.sh            (JOBS=<n> to change parallel compile jobs)
# TARGET=<stage> builds only up to that Dockerfile stage (e.g. TARGET=builder
# skips the RPM build and test stages while iterating on the bitfile flow).
set -euo pipefail
cd "$(dirname "$0")/.."
args=()
[ -n "${TARGET:-}" ] && args+=(--target "$TARGET")
DOCKER_BUILDKIT=1 docker build \
    -f docker/Dockerfile \
    --build-arg JOBS="${JOBS:-4}" \
    -t "${IMAGE:-x310-aurora-build:ol8}" \
    "${args[@]}" \
    .
