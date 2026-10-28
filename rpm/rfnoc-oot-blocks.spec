# rfnoc-oot-blocks (Ettus RFNoC Aurora block) with the X310 Aurora patches,
# packaged for Oracle Linux 8 against the matching uhd RPM.
%global python3_pkgversion 3.11
%global __python3 /usr/bin/python3.11
%global __python %{__python3}
%global debug_package %{nil}
%global uhd_version 4.10.0.0
# The block YAML and gateware are only installed when CMake is pointed at a
# UHD FPGA source tree (it checks for usrp3/top/Makefile.common).
%{!?uhd_fpga_dir:%{error:pass --define "uhd_fpga_dir /path/to/patched/uhd/fpga"}}

Name:           rfnoc-oot-blocks
Version:        4.9.0
Release:        1.aurora%{?dist}
Summary:        RFNoC Aurora out-of-tree block for UHD (X310 Aurora patched)
License:        GPL-3.0-or-later
URL:            https://github.com/crimea82/rfnoc-oot-blocks-x310-aurora-patches
Source0:        rfnoc-oot-blocks-%{version}.tar.gz

BuildRequires:  cmake >= 3.12
BuildRequires:  make
BuildRequires:  bash
BuildRequires:  gcc-toolset-13-gcc-c++
BuildRequires:  boost1.78-devel
BuildRequires:  uhd = %{uhd_version}
BuildRequires:  uhd-devel = %{uhd_version}
BuildRequires:  python3-rpm-macros
BuildRequires:  python3.11-rpm-macros
BuildRequires:  python3.11-devel
BuildRequires:  python3.11-numpy
BuildRequires:  python3.11-setuptools
BuildRequires:  python3.11-pybind11

Requires:       uhd = %{uhd_version}

%description
The Ettus Research RFNoC Aurora block as an out-of-tree UHD module, with
the X310 Aurora patch series (X310 support, SFP0/SFP1 variants, examples).
Contains the block controller library (registered with UHD via modules.d),
the rfnoc_oot_blocks Python bindings, the block definitions and FPGA
sources for rfnoc_image_builder, image core files and Python examples.

%package devel
Summary:        Development files for rfnoc-oot-blocks
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       uhd-devel = %{uhd_version}

%description devel
Headers and CMake config for building against the Aurora block controller.

%prep
%autosetup -n rfnoc-oot-blocks-%{version}

%build
source /opt/rh/gcc-toolset-13/enable
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INSTALL_LIBDIR=%{_lib} \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DUHD_DIR=%{_libdir}/cmake/uhd \
    -DUHD_FPGA_DIR=%{uhd_fpga_dir} \
    -DPYTHON_EXECUTABLE=%{__python3} \
    -DRUNTIME_PYTHON_EXECUTABLE=%{__python3} \
    -DPython_EXECUTABLE=%{__python3} \
    -DPython3_EXECUTABLE=%{__python3} \
    -DUHD_PYTHON_DIR=%{_lib}/python%{python3_version}/site-packages \
    -Dpybind11_DIR=$(%{__python3} -m pybind11 --cmakedir) \
    -DBoost_DIR=%{_libdir}/cmake/Boost-1.78.0 \
    2>&1 | tee cmake.log
# Both of these are skipped silently by the OOT CMake if a prerequisite is
# missing; make that a hard failure.
grep -q "Enabling Python API for this module." cmake.log
grep -q "Using FPGA source directory: %{uhd_fpga_dir}" cmake.log
cmake --build build -- %{_smp_mflags}

%install
DESTDIR=%{buildroot} cmake --install build
# Unit test binary lands in a generic lib64/tests dir; not shipped.
rm -rf %{buildroot}%{_libdir}/tests
# Pin example scripts to python3.11 (see uhd.spec).
find %{buildroot}%{_datadir}/uhd/examples -type f -name '*.py' \
    -exec sed -i '1s|^#!/usr/bin/env python3$|#!%{__python3}|' {} +
# Image core definitions are handy on a target that builds bitfiles.
install -D -m644 -t %{buildroot}%{_datadir}/uhd/rfnoc/oot-blocks/icores \
    icores/x310_Aurora_rfnoc_image_core.yml icores/x310_Aurora1_rfnoc_image_core.yml

%check
LD_LIBRARY_PATH=%{buildroot}%{_libdir} \
PYTHONPATH=%{buildroot}%{python3_sitearch} \
    %{__python3} -c 'import rfnoc_oot_blocks; print(rfnoc_oot_blocks.AuroraBlockControl)'

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%{_libdir}/librfnoc-oot-blocks.so
%dir %{_datadir}/uhd/modules.d
%{_datadir}/uhd/modules.d/rfnoc-oot-blocks
%{_datadir}/uhd/rfnoc/blocks/aurora.yml
%{_datadir}/uhd/rfnoc/blocks/aurora_x310.yml
%dir %{_datadir}/uhd/rfnoc/fpga
%{_datadir}/uhd/rfnoc/fpga/oot-blocks/
%{_datadir}/uhd/rfnoc/oot-blocks/
%dir %{_datadir}/uhd/examples
%{_datadir}/uhd/examples/rfnoc-oot-blocks/
%{python3_sitearch}/rfnoc_oot_blocks/

%files devel
%{_includedir}/rfnoc/
%{_libdir}/cmake/rfnoc-oot-blocks/

%changelog
* Tue Oct 27 2026 crimea82 <crimea82@protonmail.com> - 4.9.0-1.aurora
- Initial OL8 package of rfnoc-oot-blocks with the X310 Aurora patch series
