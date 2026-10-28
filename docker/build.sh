#!/bin/bash
# Build the Oracle Linux 8 image containing patched UHD + rfnoc-oot-blocks.
# Usage: docker/build.sh            (JOBS=<n> to change parallel compile jobs)
set -euo pipefail
cd "$(dirname "$0")/.."
DOCKER_BUILDKIT=1 docker build \
    -f docker/Dockerfile \
    --build-arg JOBS="${JOBS:-4}" \
    -t "${IMAGE:-x310-aurora-build:ol8}" \
    .
