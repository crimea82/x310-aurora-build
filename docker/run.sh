#!/bin/bash
# Run the bitfile build (or a helper mode) inside the OL8 image with the host's
# Vivado install and node-locked license visible.
#
#   docker/run.sh                 build the bitfile (BUILD_TARGET=X310_AA default)
#   docker/run.sh license-check   quick Vivado start + license checkout test
#   docker/run.sh bash            interactive shell for debugging
#
# Environment overrides: BUILD_TARGET, JOBS, VIVADO_DIR (host dir mounted at
# /tools/Xilinx), LICENSE_FILE (host license file), IMAGE, OUTPUT_DIR, BUILD_IP_DIR.
set -euo pipefail

IMAGE="${IMAGE:-x310-aurora-build:ol8}"
VIVADO_DIR="${VIVADO_DIR:-/tools/Xilinx}"
LICENSE_FILE="${LICENSE_FILE:-$HOME/.Xilinx/Xilinx_trial.lic}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/output}"

if [ ! -x "$VIVADO_DIR/Vivado/2024.2/bin/vivado" ]; then
    echo "ERROR: $VIVADO_DIR/Vivado/2024.2/bin/vivado not found (set VIVADO_DIR)" >&2
    exit 1
fi
if [ ! -r "$LICENSE_FILE" ]; then
    echo "ERROR: license file $LICENSE_FILE not readable (set LICENSE_FILE)" >&2
    exit 1
fi
mkdir -p "$OUTPUT_DIR"

# Optional: persist the generated-IP cache between runs to skip IP regeneration.
extra_mounts=()
if [ -n "${BUILD_IP_DIR:-}" ]; then
    mkdir -p "$BUILD_IP_DIR"
    extra_mounts+=(-v "$BUILD_IP_DIR:/work/rfnoc-patches/rfnoc-oot-blocks/build-ip")
fi

tty_flags=()
if [ -t 0 ] && [ -t 1 ]; then tty_flags=(-it); fi

# --network host: the Vivado license is node-locked to the MAC of the host NIC.
# FlexLM reads the MACs of the interfaces visible in the container's network
# namespace, so the container must share the host's.
# No --memory limit on purpose: Kintex-7 410T synthesis needs ~8-10 GB.
exec docker run --rm "${tty_flags[@]}" \
    --network host \
    --shm-size=2g \
    -v "$VIVADO_DIR:/tools/Xilinx:ro" \
    -v "$LICENSE_FILE:/licenses/Xilinx.lic:ro" \
    -e XILINXD_LICENSE_FILE=/licenses/Xilinx.lic \
    -v "$OUTPUT_DIR:/output" \
    "${extra_mounts[@]}" \
    -e BUILD_TARGET="${BUILD_TARGET:-X310_AA}" \
    -e JOBS="${JOBS:-4}" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    "$IMAGE" "$@"
