#!/bin/bash
# Container entrypoint for the x310-aurora-build image.
#   build          (default) run the bitfile phase, copy results to /output
#   license-check  start Vivado and synthesize a stub to verify the license
#   <anything>     exec it (e.g. "bash")
set -euo pipefail
cd /work

MODE="${1:-build}"
BUILD_TARGET="${BUILD_TARGET:-X310_AA}"
JOBS="${JOBS:-4}"
VIVADO_PATH="${VIVADO_PATH:-/tools/Xilinx/Vivado}"
VIVADO_VER="${VIVADO_VER:-2024.2}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
OOT_DIR=/work/rfnoc-patches/rfnoc-oot-blocks
VIVADO_BIN="$VIVADO_PATH/$VIVADO_VER/bin/vivado"
LMUTIL="$VIVADO_PATH/$VIVADO_VER/bin/unwrapped/lnx64.o/lmutil"

case "$MODE" in
    build|license-check) ;;
    *) exec "$@" ;;
esac

preflight() {
    if [ ! -x "$VIVADO_BIN" ]; then
        echo "ERROR: $VIVADO_BIN not found. Mount the host Vivado install at $VIVADO_PATH." >&2
        exit 1
    fi
    if [ -z "${XILINXD_LICENSE_FILE:-}" ] || [ ! -r "$XILINXD_LICENSE_FILE" ]; then
        echo "ERROR: XILINXD_LICENSE_FILE is unset or unreadable (${XILINXD_LICENSE_FILE:-})." >&2
        exit 1
    fi
    echo "== Vivado:  $VIVADO_BIN"
    echo "== License: $XILINXD_LICENSE_FILE"
    echo "== Host ID seen by FlexLM (must match the HOSTID in the license file):"
    # lmutil is linked against the LSB loader, which most distros lack; run it
    # through the regular glibc loader instead.
    /lib64/ld-linux-x86-64.so.2 "$LMUTIL" lmhostid 2>/dev/null | grep -i 'host id' || true
    grep -m1 -oE 'HOSTID=[0-9a-fA-F]+' "$XILINXD_LICENSE_FILE" | sed 's/^/== License file: /' || true
}

copy_outputs() {
    mkdir -p "$OUTPUT_DIR"
    shopt -s nullglob
    cp -v "$OOT_DIR"/build/usrp_x310_fpga_*.{bit,bin,lvbitx,rpt} "$OUTPUT_DIR"/ 2>/dev/null || true
    for d in "$OOT_DIR"/build-usrp_x310_fpga_*; do
        [ -d "$d" ] || continue
        mkdir -p "$OUTPUT_DIR/$(basename "$d")"
        cp -v "$d"/*.log "$d"/*.rpt "$OUTPUT_DIR/$(basename "$d")/" 2>/dev/null || true
    done
    shopt -u nullglob
    chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$OUTPUT_DIR" || true
}

warmup() {
    # One Vivado run to populate $HOME/.Xilinx before parallel IP builds start.
    echo "== Vivado warm-up (populating $HOME/.Xilinx Tcl app store)"
    local tmp
    tmp=$(mktemp -d)
    (cd "$tmp" && "$VIVADO_BIN" -mode batch -nolog -nojournal \
        -source /opt/x310-aurora/vivado-warmup.tcl | grep -E 'VIVADO_WARMUP_OK|ERROR')
    rm -rf "$tmp"
}

preflight
warmup

if [ "$MODE" = "license-check" ]; then
    echo "== vivado -version"
    "$VIVADO_BIN" -version
    echo "== Synthesizing a stub for xc7k410tffg900-2 (checks out the Kintex-7 license)"
    tmp=$(mktemp -d)
    cd "$tmp"
    "$VIVADO_BIN" -mode batch -nolog -nojournal -source /opt/x310-aurora/license-check.tcl
    echo "== License check PASSED"
    exit 0
fi

trap copy_outputs EXIT
echo "== Building bitfile: BUILD_TARGET=$BUILD_TARGET JOBS=$JOBS"
rm -f .stamps/bitfile
make bitfile BUILD_TARGET="$BUILD_TARGET" VIVADO_PATH="$VIVADO_PATH" JOBS="$JOBS" SUDO=
echo "== Bitfile build finished; outputs copied to $OUTPUT_DIR"
