#!/bin/bash
# Build the OL8 RPMs for the X310 Aurora stack. Runs in the "rpmbuild" stage
# of docker/Dockerfile (a clean OL8 with the patched source trees cloned to
# /work by the Makefile, no /usr/local UHD, no PYTHONPATH).
#
# Order matters: the Python dependency RPMs are installed before UHD is
# built (its configure needs mako/ruamel.yaml), and the uhd RPMs are
# installed before rfnoc-oot-blocks is built against them.
set -euo pipefail

TOP=${TOP:-/work/rpmbuild}
SPECS=${SPECS:-/work/rpm}
JOBS=${JOBS:-4}
UHD_SRC=${UHD_SRC:-/work/uhd-patches/uhd}
OOT_SRC=${OOT_SRC:-/work/rfnoc-patches/rfnoc-oot-blocks}
UHD_VERSION=$(rpmspec -q --qf '%{version}\n' "$SPECS/uhd.spec" | head -1)
OOT_VERSION=$(rpmspec -q --qf '%{version}\n' "$SPECS/rfnoc-oot-blocks.spec" --define "uhd_fpga_dir x" | head -1)

mkdir -p "$TOP"/{SOURCES,BUILD,BUILDROOT,RPMS,SRPMS,SPECS}
RB=(rpmbuild --define "_topdir $TOP" --define "_smp_build_ncpus $JOBS")

echo "== 1. Python dependency RPMs (mako, ruamel.yaml)"
# Source0 of these specs is a PyPI URL; spectool downloads it and the spec's
# source_sha256 verifies it.
for spec in python3.11-mako python3.11-ruamel-yaml; do
    url=$(rpmspec -P "$SPECS/$spec.spec" | awk '/^Source0:/{print $2}')
    sha=$(awk '/^%global source_sha256/{print $3}' "$SPECS/$spec.spec")
    file="$TOP/SOURCES/$(basename "$url")"
    [ -f "$file" ] || spectool -g -C "$TOP/SOURCES" "$SPECS/$spec.spec"
    echo "$sha  $file" | sha256sum -c -
done
dnf -y builddep "$SPECS/python3.11-mako.spec" "$SPECS/python3.11-ruamel-yaml.spec"
"${RB[@]}" -ba "$SPECS/python3.11-mako.spec" "$SPECS/python3.11-ruamel-yaml.spec"
dnf -y install "$TOP"/RPMS/noarch/python3.11-mako-*.rpm "$TOP"/RPMS/noarch/python3.11-ruamel-yaml-*.rpm

echo "== 2. uhd $UHD_VERSION"
git -C "$UHD_SRC" archive --format=tar --prefix="uhd-$UHD_VERSION/" HEAD host images LICENSE.md \
    | gzip -1 > "$TOP/SOURCES/uhd-$UHD_VERSION.tar.gz"
dnf -y builddep "$SPECS/uhd.spec"
"${RB[@]}" -ba "$SPECS/uhd.spec"
dnf -y install "$TOP"/RPMS/x86_64/uhd-"$UHD_VERSION"-*.rpm "$TOP"/RPMS/x86_64/uhd-devel-*.rpm

echo "== 3. rfnoc-oot-blocks $OOT_VERSION"
git -C "$OOT_SRC" archive --format=tar --prefix="rfnoc-oot-blocks-$OOT_VERSION/" HEAD \
    | gzip -1 > "$TOP/SOURCES/rfnoc-oot-blocks-$OOT_VERSION.tar.gz"
dnf -y builddep --define "uhd_fpga_dir $UHD_SRC/fpga" "$SPECS/rfnoc-oot-blocks.spec"
"${RB[@]}" -ba --define "uhd_fpga_dir $UHD_SRC/fpga" "$SPECS/rfnoc-oot-blocks.spec"
dnf -y install "$TOP"/RPMS/x86_64/rfnoc-oot-blocks-*.rpm

echo "== 4. done"
rm -rf "$TOP/BUILD" "$TOP/BUILDROOT"
ls -l "$TOP"/RPMS/*/
