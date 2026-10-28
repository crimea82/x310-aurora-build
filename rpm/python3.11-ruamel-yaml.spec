# ruamel.yaml for the python3.11 stream on Oracle Linux 8. Needed by UHD's
# rfnoc_image_builder; EPEL only ships python3-ruamel-yaml for Python 3.6.
# Packaged without the optional ruamel.yaml.clib C accelerator (the pure
# Python code path is used).
%global python3_pkgversion 3.11
%global __python3 /usr/bin/python3.11
%global pypi_name ruamel.yaml
%global source_sha256 a6e587512f3c998b2225d68aa1f35111c29fad14aed561a26e73fab729ec5e5a
# Do not let the dist generator add a dependency on the C accelerator.
%global __requires_exclude ^python3\\.11dist\\(ruamel[.-]yaml[.-]clib\\)

Name:           python3.11-ruamel-yaml
Version:        0.18.16
Release:        1%{?dist}
Summary:        YAML 1.2 loader/dumper for Python 3.11
License:        MIT
URL:            https://sourceforge.net/projects/ruamel-yaml/
Source0:        https://files.pythonhosted.org/packages/source/r/ruamel.yaml/ruamel.yaml-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  python3-rpm-macros
BuildRequires:  python3.11-rpm-macros
BuildRequires:  python3.11-devel
BuildRequires:  python3.11-pip
BuildRequires:  python3.11-setuptools
BuildRequires:  python3.11-wheel

%description
ruamel.yaml is a YAML 1.2 parser/emitter for Python with round-trip
preservation of comments. This package provides it for the python3.11
stream, as required by UHD 4.10's rfnoc_image_builder.

%prep
%autosetup -n ruamel.yaml-%{version}

%build
%{__python3} -m pip wheel --no-deps --no-build-isolation --no-index -w dist .

%install
%{__python3} -m pip install --no-deps --no-index --no-build-isolation \
    --root %{buildroot} --prefix %{_prefix} dist/*.whl
test ! -e %{buildroot}/usr/local

%check
PYTHONPATH=%{buildroot}%{python3_sitelib} %{__python3} -c \
    'import ruamel.yaml; y = ruamel.yaml.YAML(); print(y.load("a: [1, 2]"))'

%files
%license LICENSE
%{python3_sitelib}/ruamel/
%{python3_sitelib}/ruamel[._]yaml-%{version}.dist-info/

%changelog
* Tue Oct 27 2026 crimea82 <crimea82@protonmail.com> - 0.18.16-1
- Initial package for the python3.11 stream on OL8
