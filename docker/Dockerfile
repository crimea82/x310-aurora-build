# Oracle Linux 8 image with the patched X310 Aurora software stack:
# UHD 4.10.0.0 (host library, Python API, rfnoc_image_builder) and
# rfnoc-oot-blocks (C++ library + rfnoc_oot_blocks Python bindings).
#
# Vivado is NOT part of the image. docker/run.sh bind-mounts the host's
# /tools/Xilinx and license file and runs only the bitfile phase.
#
# Build from the repository root:  docker/build.sh   (or see that script)
FROM oraclelinux:8

ARG JOBS=4
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Packages. OL8's stock python3 (3.6) and boost (1.66) are below UHD's minimums
# (3.7 / 1.71), so use the python3.11 AppStream stream and EPEL's boost1.78
# (headers in /usr/include/boost1.78, libs and CMake config in /usr/lib64).
# The stock GCC 8.5 keeps std::filesystem in a separate libstdc++fs that UHD
# does not link, so use gcc-toolset-13 (its binaries run on the stock libstdc++).
# The X11/ncurses libs are what Vivado dlopen()s even in batch mode.
# ---------------------------------------------------------------------------
RUN dnf -y install oracle-epel-release-el8 dnf-utils \
 && dnf config-manager --set-enabled ol8_codeready_builder \
 && dnf -y install \
        gcc-toolset-13-gcc-c++ make cmake git pkgconf-pkg-config \
        python3.11 python3.11-devel python3.11-pip python3.11-setuptools python3.11-numpy \
        libusbx-devel boost1.78-devel \
        bash which diffutils findutils patch gawk sed procps-ng hostname net-tools \
        tar xz bzip2 gzip unzip file \
        ncurses ncurses-compat-libs glibc-langpack-en libnsl \
        libXrender libXtst libXi libXft libXext libX11 fontconfig \
 && alternatives --set python3 /usr/bin/python3.11 \
 && dnf clean all

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
ENV HOME=/root \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONPATH=/usr/local/lib64/python3.11/site-packages

# git am in the patch repos needs an identity.
RUN git config --global user.name "x310-aurora-build" \
 && git config --global user.email "build@localhost"

WORKDIR /work
COPY Makefile /work/Makefile

# ---------------------------------------------------------------------------
# Phase 1-3: clone + patch both projects, then build and install UHD.
# ENABLE_PYTHON_API / ENABLE_PYMOD_UTILS are forced ON so that missing Python
# deps fail the build instead of silently dropping the API or the image builder.
# ---------------------------------------------------------------------------
RUN make .stamps/uhd-patched
RUN make .stamps/rfnoc-patched

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

# ---------------------------------------------------------------------------
# Phase 4: build and install rfnoc-oot-blocks.
# The Python bindings are skipped silently if pybind11 or the uhd module is
# not found at configure time, so require the enabling message in the log.
# ---------------------------------------------------------------------------
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

COPY docker/license-check.tcl docker/license-check.v docker/vivado-warmup.tcl /opt/x310-aurora/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["build"]
