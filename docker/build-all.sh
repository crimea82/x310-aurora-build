#!/bin/bash
# Build everything for one X310 Aurora target, end to end:
#   1. the OL8 image (software stack + RPMs, self-tested on a clean OL8)
#   2. the Vivado license check
#   3. the FPGA bitfile for the target
#   4. the uhd-images-x310-aurora RPM and the dnf repo in ./output/rpms
#
# Usage: docker/build-all.sh [X310_AA|X310_AA1]      (default: X310_AA1)
#
# Environment overrides are passed through to docker/build.sh and
# docker/run.sh (JOBS, VIVADO_DIR, LICENSE_FILE, IMAGE, OUTPUT_DIR, ...).
# The generated-IP cache is kept in ./build-ip so reruns skip IP generation.
set -euo pipefail
cd "$(dirname "$0")/.."

export BUILD_TARGET="${1:-${BUILD_TARGET:-X310_AA1}}"
export BUILD_IP_DIR="${BUILD_IP_DIR:-$PWD/build-ip}"
case "$BUILD_TARGET" in
    X310_AA|X310_AA1) ;;
    *) echo "ERROR: BUILD_TARGET must be X310_AA or X310_AA1 (got '$BUILD_TARGET')" >&2; exit 1 ;;
esac

step() {
    echo
    echo "################################################################"
    echo "## $(date '+%F %T')  $*"
    echo "################################################################"
}

start=$(date +%s)
step "1/3 Building the image (software stack + RPMs)"
docker/build.sh

step "2/3 Vivado license check"
docker/run.sh license-check

step "3/3 Bitfile build for $BUILD_TARGET (+ images RPM, dnf repo)"
docker/run.sh build

step "Done in $(( ($(date +%s) - start) / 60 )) min. Results:"
ls -l output/usrp_x310_fpga_Aurora*.bit output/rpms/*.rpm
