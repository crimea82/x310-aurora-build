# UHD 4.10.0.0 with the X310 Aurora patches, packaged for Oracle Linux 8.
#
# Built from the patched source tree (uhd-x310-aurora-patches applied on top of
# UHD v4.10.0.0). Uses the python3.11 stream, EPEL boost1.78 and gcc-toolset-13
# because OL8's stock Python 3.6, Boost 1.66 and GCC 8 are below UHD's minimums.
%global python3_pkgversion 3.11
%global __python3 /usr/bin/python3.11
%global __python %{__python3}
# gcc-13 emits DWARF5 which el8's debugedit does not handle; no debuginfo.
%global debug_package %{nil}
# Ship the curated FPGA source tree (share/uhd/rfnoc/fpga) in a subpackage.
# Off by default: it adds ~90 MB and bitfile builds need Vivado anyway.
%bcond_with rfnoc_dev

Name:           uhd
Version:        4.10.0.0
Release:        1.aurora%{?dist}
Summary:        Universal Hardware Driver for Ettus Research USRPs (X310 Aurora patched)
License:        GPL-3.0-or-later
URL:            https://github.com/crimea82/uhd-x310-aurora-patches
Source0:        uhd-%{version}.tar.gz

BuildRequires:  cmake >= 3.12
BuildRequires:  make
BuildRequires:  pkgconf-pkg-config
BuildRequires:  gcc-toolset-13-gcc-c++
BuildRequires:  boost1.78-devel
BuildRequires:  libusbx-devel
BuildRequires:  python3-rpm-macros
BuildRequires:  python3.11-rpm-macros
BuildRequires:  python3.11-devel
BuildRequires:  python3.11-numpy
BuildRequires:  python3.11-setuptools
BuildRequires:  python3.11-pybind11
BuildRequires:  python3.11-mako
BuildRequires:  python3.11-ruamel-yaml
BuildRequires:  python3.11-requests

Requires:       python3.11-numpy
Requires:       python3.11-requests
Requires:       python3.11-mako
Requires:       python3.11-ruamel-yaml

%description
UHD is the host driver for Ettus Research USRP software defined radios.
This build is UHD %{version} with the X310 Aurora patch series applied
(X310_AA / X310_AA1 image targets, Aurora SFP transport, Vivado 2024.2
fixes). It includes the C++ library, utilities, the Python 3.11 API and
rfnoc_image_builder.

%package devel
Summary:        Development files for UHD
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       boost1.78-devel

%description devel
Headers, CMake and pkg-config files for building software against UHD.
Build with gcc-toolset-13 and -DBoost_DIR=%{_libdir}/cmake/Boost-1.78.0.

%if %{with rfnoc_dev}
%package rfnoc-devel
Summary:        RFNoC FPGA source files for building custom images
Requires:       %{name} = %{version}-%{release}

%description rfnoc-devel
The RFNoC FPGA sources installed under %{_datadir}/uhd/rfnoc/fpga, used by
rfnoc_image_builder when building bitfiles from installed files.
%endif

%prep
%autosetup -n uhd-%{version}

%build
source /opt/rh/gcc-toolset-13/enable
cd host
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INSTALL_LIBDIR=%{_lib} \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DUHD_VERSION=%{version} \
    -DPYTHON_EXECUTABLE=%{__python3} \
    -DRUNTIME_PYTHON_EXECUTABLE=%{__python3} \
    -DPython_EXECUTABLE=%{__python3} \
    -DPython3_EXECUTABLE=%{__python3} \
    -DUHD_PYTHON_DIR=%{_lib}/python%{python3_version}/site-packages \
    -Dpybind11_DIR=$(%{__python3} -m pybind11 --cmakedir) \
    -DBoost_DIR=%{_libdir}/cmake/Boost-1.78.0 \
    -DENABLE_PYTHON_API=ON \
    -DENABLE_PYMOD_UTILS=ON \
    -DENABLE_SIM=OFF \
    -DENABLE_TESTS=OFF \
    -DENABLE_EXAMPLES=OFF \
    -DENABLE_DPDK=OFF \
    -DENABLE_MANUAL=OFF \
    -DENABLE_DOXYGEN=OFF \
    %{?with_rfnoc_dev:-DENABLE_RFNOC_DEV=ON} \
    2>&1 | tee cmake.log
grep -q "Enabling LibUHD - Python API support" cmake.log
grep -q "Enabling Python Module (Utils only) support" cmake.log
cmake --build build -- %{_smp_mflags}

%install
DESTDIR=%{buildroot} cmake --install host/build
# Not wanted even if a future option re-enables them.
rm -rf %{buildroot}%{python3_sitearch}/usrp_mpm %{buildroot}%{_bindir}/usrp_hwd.py
# On a stock OL8 target /usr/bin/python3 is 3.6; pin the scripts to 3.11.
# Must happen before brp-mangle-shebangs, which would pick /usr/bin/python3.
find %{buildroot}%{_bindir} %{buildroot}%{_libdir}/uhd -type f \
    -exec sed -i '1s|^#!/usr/bin/env python3$|#!%{__python3}|' {} +
if grep -rl '^#!/usr/bin/env python' %{buildroot}%{_bindir} %{buildroot}%{_libdir}/uhd; then
    echo "ERROR: unpinned python shebangs remain" >&2
    exit 1
fi
# udev rules go where udev reads them instead of relying on a %%post copy.
install -D -m644 %{buildroot}%{_libdir}/uhd/utils/uhd-usrp.rules \
    %{buildroot}%{_prefix}/lib/udev/rules.d/uhd-usrp.rules

%check
LD_LIBRARY_PATH=%{buildroot}%{_libdir} PYTHONPATH=%{buildroot}%{python3_sitearch} \
    %{__python3} -c 'import uhd; assert uhd.__version__ == "%{version}", uhd.__version__'

%post
/sbin/ldconfig
udevadm control --reload-rules >/dev/null 2>&1 || :

%postun
/sbin/ldconfig
udevadm control --reload-rules >/dev/null 2>&1 || :

%files
%license LICENSE.md
%{_docdir}/uhd/
%{_bindir}/rfnoc_image_builder
%{_bindir}/rfnoc_modtool
%{_bindir}/uhd_*
%{_bindir}/usrp2_card_burner
%{_bindir}/usrpctl
%{_libdir}/libuhd.so.*
%{_libdir}/uhd/
%{python3_sitearch}/uhd/
%dir %{_datadir}/uhd
%{_datadir}/uhd/cal/
%{_datadir}/uhd/rfnoc-newmod/
%dir %{_datadir}/uhd/rfnoc
%{_datadir}/uhd/rfnoc/blocks/
%{_datadir}/uhd/rfnoc/core/
%{_datadir}/uhd/rfnoc/modules/
%{_datadir}/uhd/rfnoc/transport_adapters/
%{_mandir}/man1/*
%{_prefix}/lib/udev/rules.d/uhd-usrp.rules

%files devel
%{_includedir}/uhd/
%{_includedir}/uhd.h
%{_libdir}/libuhd.so
%{_libdir}/cmake/uhd/
%{_libdir}/pkgconfig/uhd.pc

%if %{with rfnoc_dev}
%files rfnoc-devel
%{_datadir}/uhd/rfnoc/fpga/usrp3/
%endif

%changelog
* Tue Oct 27 2026 crimea82 <crimea82@protonmail.com> - 4.10.0.0-1.aurora
- Initial OL8 package of UHD 4.10.0.0 with the X310 Aurora patch series
