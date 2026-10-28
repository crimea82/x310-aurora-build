#!/bin/bash
# Container entrypoint for the x310-aurora-build image.
#   build          (default) run the bitfile phase, copy results and RPMs to /output
#   license-check  start Vivado and synthesize a stub to verify the license
#   rpms           copy the pre-built RPMs to /output/rpms, add an images RPM
#                  from any bitfiles present, and create repo metadata (no Vivado)
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

RPMS_DIR=/work/rpms
RPM_OUT="$OUTPUT_DIR/rpms"

case "$MODE" in
    build|license-check|rpms) ;;
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

# Build the noarch uhd-images-x310-aurora RPM from all bitfiles in /output.
# copy_outputs() has already placed a fresh build there, so a build for one
# target is packaged together with earlier builds of the other target.
build_images_rpm() {
    local src tmp
    shopt -s nullglob
    local files=("$OUTPUT_DIR"/usrp_x310_fpga_Aurora*.{bit,bin,lvbitx,rpt})
    shopt -u nullglob
    if [ ${#files[@]} -gt 0 ]; then src="$OUTPUT_DIR"
    else
        echo "== No usrp_x310_fpga_Aurora* bitfiles found; skipping the images RPM"
        return 0
    fi
    echo "== Building uhd-images-x310-aurora RPM from $src"
    tmp=$(mktemp -d)
    mkdir -p "$tmp"/{SOURCES,BUILD,BUILDROOT,RPMS,SRPMS}
    (cd "$src" && tar -cf "$tmp/SOURCES/x310-aurora-images.tar" usrp_x310_fpga_Aurora*)
    rpmbuild -bb --define "_topdir $tmp" --define "build_date $(date -u +%Y%m%d)" \
        /work/rpm/uhd-images-x310-aurora.spec > "$tmp/rpmbuild.log" 2>&1 \
        || { cat "$tmp/rpmbuild.log"; rm -rf "$tmp"; return 1; }
    mkdir -p "$RPM_OUT"
    cp -v "$tmp"/RPMS/noarch/uhd-images-x310-aurora-*.rpm "$RPM_OUT"/
    rm -rf "$tmp"
}

# Copy the software RPMs built into the image, add the images RPM and make
# /output/rpms usable as a dnf repository.
publish_rpms() {
    mkdir -p "$RPM_OUT"
    if compgen -G "$RPMS_DIR/*/*.rpm" > /dev/null; then
        cp -v "$RPMS_DIR"/*/*.rpm "$RPM_OUT"/
    else
        echo "WARNING: no RPMs under $RPMS_DIR (image built with TARGET=builder?)"
    fi
    build_images_rpm
    createrepo_c --update "$RPM_OUT" > /dev/null
    echo "== RPMs in $RPM_OUT:"
    ls -1 "$RPM_OUT"/*.rpm
}

BITFILE_OK=0
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
    # Only package bitfiles from a successful build, never stale ones.
    if [ "$BITFILE_OK" = 1 ]; then
        publish_rpms || echo "WARNING: RPM publishing failed"
    fi
    chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$OUTPUT_DIR" || true
}

if [ "$MODE" = "rpms" ]; then
    publish_rpms
    chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$OUTPUT_DIR" || true
    exit 0
fi

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
BITFILE_OK=1
echo "== Bitfile build finished; outputs and RPMs copied to $OUTPUT_DIR"
