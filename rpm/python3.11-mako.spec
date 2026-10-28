# Mako templating library for the python3.11 stream on Oracle Linux 8.
# Needed by UHD's rfnoc_image_builder / rfnoc_modtool; OL8 only ships
# python3-mako for Python 3.6.
%global python3_pkgversion 3.11
%global __python3 /usr/bin/python3.11
%global pypi_name mako
%global source_sha256 99579a6f39583fa7e5630a28c3c1f440e4e97a414b80372649c0ce338da2ea28

Name:           python3.11-mako
Version:        1.3.10
Release:        1%{?dist}
Summary:        Mako template library for Python 3.11
License:        MIT
URL:            https://www.makotemplates.org/
Source0:        https://files.pythonhosted.org/packages/source/m/mako/mako-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  python3-rpm-macros
BuildRequires:  python3.11-rpm-macros
BuildRequires:  python3.11-devel
BuildRequires:  python3.11-pip
BuildRequires:  python3.11-setuptools
BuildRequires:  python3.11-wheel
Requires:       python3.11-markupsafe >= 2.0

%description
Mako is a template library written in Python. This package provides it for
the python3.11 stream, as required by UHD 4.10's RFNoC tooling.

%prep
%autosetup -n mako-%{version}

%build
%{__python3} -m pip wheel --no-deps --no-build-isolation --no-index -w dist .

%install
%{__python3} -m pip install --no-deps --no-index --no-build-isolation \
    --root %{buildroot} --prefix %{_prefix} dist/*.whl
# OL8's python would use /usr/local for non-RPM installs; make sure the
# RPM_BUILD_ROOT heuristic kept everything under /usr.
test ! -e %{buildroot}/usr/local

%files
%license LICENSE
%{python3_sitelib}/mako/
%{python3_sitelib}/[Mm]ako-%{version}.dist-info/
%{_bindir}/mako-render

%changelog
* Tue Oct 27 2026 crimea82 <crimea82@protonmail.com> - 1.3.10-1
- Initial package for the python3.11 stream on OL8 (1.3.x: last series whose
  sdist builds with OL8's setuptools 65)
