# syntax=docker/dockerfile:1
# Oracle Linux 8 image for the X310 Aurora stack.
#
# Stages:
#   base      OL8 + build/runtime packages (python3.11, boost1.78, gcc-toolset-13, rpm tools)
#   sources   base + patched UHD and rfnoc-oot-blocks trees cloned into /work
#   builder   sources + UHD and rfnoc-oot-blocks built into /usr/local (bitfile build env)
#   rpmbuild  sources + RPMs of the whole stack built with rpm/*.spec
#   rpmtest   clean OL8 that installs the RPMs and verifies them
#   final     builder + the tested RPMs under /work/rpms (the image docker/run.sh uses)
#
# Vivado is NOT part of the image. docker/run.sh bind-mounts the host's
# /tools/Xilinx and license file and runs the bitfile phase.
#
# Build from the repository root:  docker/build.sh   (TARGET=builder skips the RPM stages)

# ---------------------------------------------------------------------------
FROM oraclelinux:8 AS base

ARG JOBS=4
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# OL8's stock python3 (3.6) and boost (1.66) are below UHD's minimums
# (3.7 / 1.71), so use the python3.11 AppStream stream and EPEL's boost1.78
# (headers in /usr/include/boost1.78, libs and CMake config in /usr/lib64).
# The stock GCC 8.5 keeps std::filesystem in a separate libstdc++fs that UHD
# does not link, so use gcc-toolset-13 (its binaries run on the stock libstdc++).
# The X11/ncurses libs are what Vivado dlopen()s even in batch mode.
# rpm-build & co. are for the rpmbuild stage; python3.11-pybind11 (CodeReady)
# is the pybind11 the RPMs are built against.
RUN dnf -y install oracle-epel-release-el8 dnf-utils \
 && dnf config-manager --set-enabled ol8_codeready_builder \
 && dnf -y install \
        gcc-toolset-13-gcc-c++ make cmake git pkgconf-pkg-config \
        python3.11 python3.11-devel python3.11-pip python3.11-setuptools python3.11-wheel \
        python3.11-numpy python3.11-requests python3.11-pybind11 \
        python3-rpm-macros python3.11-rpm-macros \
        rpm-build rpmdevtools redhat-rpm-config createrepo_c \
        libusbx-devel boost1.78-devel \
        bash which diffutils findutils patch gawk sed procps-ng hostname net-tools \
        tar xz bzip2 gzip unzip file \
        ncurses ncurses-compat-libs glibc-langpack-en libnsl \
        libXrender libXtst libXi libXft libXext libX11 fontconfig \
 && alternatives --set python3 /usr/bin/python3.11 \
 && dnf clean all

ENV HOME=/root \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# git am in the patch repos needs an identity.
RUN git config --global user.name "x310-aurora-build" \
 && git config --global user.email "build@localhost"

WORKDIR /work
COPY Makefile /work/Makefile

# ---------------------------------------------------------------------------
# Clone + patch both projects once; shared by the builder and rpmbuild stages.
# ---------------------------------------------------------------------------
FROM base AS sources
RUN make .stamps/uhd-patched
RUN make .stamps/rfnoc-patched

# ---------------------------------------------------------------------------
# builder: UHD + rfnoc-oot-blocks built into /usr/local, the environment the
# bitfile phase runs in.
# ---------------------------------------------------------------------------
FROM sources AS builder

# Python deps for the UHD build/utilities and the OOT bindings.
# pybind11 2.10.x matches the internals ABI of the copy UHD bundles.
RUN python3 -m pip install --no-cache-dir \
        'pybind11==2.10.4' mako 'ruamel.yaml' requests jsonschema

# The OOT module's installed .so files carry no RPATH; make /usr/local/lib64
# visible to the dynamic loader.
RUN printf '/usr/local/lib64\n/usr/local/lib\n' > /etc/ld.so.conf.d/x310-aurora.conf \
 && ldconfig

# OL8's python3.11 does not search /usr/local site-packages, which is where
# UHD and rfnoc_oot_blocks install their modules. Required both at the OOT
# configure step (it imports uhd) and at run time (rfnoc_image_builder).
ENV PYTHONPATH=/usr/local/lib64/python3.11/site-packages

# Common CMake arguments for both projects. UHD_PYTHON_DIR is set explicitly
# because OL8's python reports prefix=/usr while its platlib already lives under
# /usr/local, which makes UHD's relative-path logic produce /usr/local/local/...
ENV PATH=/opt/rh/gcc-toolset-13/root/usr/bin:$PATH
ENV X310_CMAKE_COMMON="-DCMAKE_C_COMPILER=/opt/rh/gcc-toolset-13/root/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-13/root/usr/bin/g++ \
    -DPYTHON_EXECUTABLE=/usr/bin/python3.11 \
    -DRUNTIME_PYTHON_EXECUTABLE=/usr/bin/python3.11 \
    -DPython_EXECUTABLE=/usr/bin/python3.11 \
    -DPython3_EXECUTABLE=/usr/bin/python3.11 \
    -DUHD_PYTHON_DIR=lib64/python3.11/site-packages \
    -DBoost_DIR=/usr/lib64/cmake/Boost-1.78.0"

# ENABLE_PYTHON_API / ENABLE_PYMOD_UTILS are forced ON so that missing Python
# deps fail the build instead of silently dropping the API or the image builder.
# PYBIND11_INCLUDE_DIR: UHD's simulator device (ENABLE_SIM) embeds Python and
# only derives this path itself when falling back to its bundled pybind11.
RUN make uhd SUDO= JOBS=${JOBS} \
        UHD_CMAKE_ARGS="${X310_CMAKE_COMMON} \
            -Dpybind11_DIR=$(python3 -m pybind11 --cmakedir) \
            -DPYBIND11_INCLUDE_DIR=$(python3 -c 'import pybind11; print(pybind11.get_include())') \
            -DENABLE_PYTHON_API=ON -DENABLE_PYMOD_UTILS=ON \
            -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_DPDK=OFF \
            -DENABLE_MANUAL=OFF -DENABLE_DOXYGEN=OFF" \
 && ldconfig \
 && rm -rf uhd-patches/uhd/host/build \
 && python3 -c "import uhd; print('uhd', uhd.__version__)" \
 && rfnoc_image_builder --help > /dev/null

# The Python bindings are skipped silently if pybind11 or the uhd module is
# not found at configure time, so require the enabling message in the log.
RUN make rfnoc SUDO= JOBS=${JOBS} \
        RFNOC_CMAKE_ARGS="${X310_CMAKE_COMMON} \
            -Dpybind11_DIR=$(python3 -m pybind11 --cmakedir)" \
        2>&1 | tee /tmp/rfnoc-build.log \
 && grep -q "Enabling Python API for this module." /tmp/rfnoc-build.log \
 && ldconfig \
 && rm -f /tmp/rfnoc-build.log

# Verify the installed software stack.
RUN python3 -c "import uhd, rfnoc_oot_blocks; print('uhd', uhd.__version__); print(rfnoc_oot_blocks.AuroraBlockControl)" \
 && ls /usr/local/lib64/python3.11/site-packages/rfnoc_oot_blocks/rfnoc_oot_blocks_python*.so \
 && ! ldd /usr/local/lib64/librfnoc-oot-blocks.so | grep -q 'not found' \
 && rfnoc_image_builder --help > /dev/null

# ---------------------------------------------------------------------------
# rpmbuild: package the stack with rpm/*.spec. Deliberately starts from the
# pristine "sources" stage (no /usr/local UHD, no PYTHONPATH, no pip modules)
# so the specs' BuildRequires are what actually satisfies the build.
# ---------------------------------------------------------------------------
FROM sources AS rpmbuild
COPY rpm/ /work/rpm/
COPY docker/build-rpms.sh /usr/local/bin/build-rpms.sh
RUN JOBS=${JOBS} build-rpms.sh

# ---------------------------------------------------------------------------
# rpmtest: prove the RPMs install and work on a stock OL8 system.
# ---------------------------------------------------------------------------
FROM oraclelinux:8 AS rpmtest
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY --from=rpmbuild /work/rpmbuild/RPMS /rpms
RUN dnf -y install oracle-epel-release-el8 dnf-utils \
 && dnf config-manager --set-enabled ol8_codeready_builder \
 && dnf -y install /rpms/*/*.rpm \
 && dnf clean all
RUN set -x \
 && rpm -qa 'uhd*' 'rfnoc*' 'python3.11-mako' 'python3.11-ruamel-yaml' \
 && uhd_config_info --version | grep -q '4.10.0.0' \
 && python3.11 -c 'import uhd, rfnoc_oot_blocks; assert uhd.__version__ == "4.10.0.0", uhd.__version__; assert uhd.get_pkg_data_path() == "/usr/share/uhd", uhd.get_pkg_data_path(); print(rfnoc_oot_blocks.AuroraBlockControl)' \
 && rfnoc_image_builder --help > /dev/null \
 && rfnoc_modtool --help > /dev/null \
 && uhd_images_downloader --help > /dev/null \
 && (uhd_find_devices > /dev/null 2>&1 || true) \
 && ! ldd /usr/lib64/librfnoc-oot-blocks.so /usr/lib64/python3.11/site-packages/*/*.so | grep 'not found' \
 && ! (readelf -d /usr/lib64/libuhd.so.4.10.0 /usr/lib64/librfnoc-oot-blocks.so /usr/lib64/python3.11/site-packages/*/*.so | grep -E 'RPATH|RUNPATH') \
 && ! grep -rl '^#!/usr/bin/python3$' /usr/bin /usr/lib64/uhd/utils \
 && ! (rpm -q --requires uhd rfnoc-oot-blocks | grep -x '/usr/bin/python3') \
 && ! (rpm -q --requires python3.11-ruamel-yaml | grep -i clib) \
 && test -f /usr/share/uhd/rfnoc/blocks/aurora_x310.yml \
 && test -d /usr/share/uhd/rfnoc/fpga/oot-blocks/ip \
 && test -f /usr/share/uhd/modules.d/rfnoc-oot-blocks \
 && test -f /usr/lib/udev/rules.d/uhd-usrp.rules \
 && test ! -d /usr/local/lib/python3.11 \
 && test -z "${PYTHONPATH:-}"

# ---------------------------------------------------------------------------
FROM builder AS final
COPY rpm/ /work/rpm/
COPY --from=rpmtest /rpms /work/rpms
COPY docker/license-check.tcl docker/license-check.v docker/vivado-warmup.tcl /opt/x310-aurora/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["build"]
