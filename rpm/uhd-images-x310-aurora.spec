# FPGA bitfiles for the USRP X310 with the Aurora RFNoC block, built by
# x310-aurora-build. Installed where UHD looks for images (share/uhd/images).
%global debug_package %{nil}

Name:           uhd-images-x310-aurora
Version:        4.10.0.0
Release:        1.%{?build_date}%{!?build_date:0}%{?dist}
Summary:        USRP X310 FPGA images with the Aurora RFNoC block
License:        GPL-3.0-or-later
URL:            https://github.com/crimea82/x310-aurora-build
Source0:        x310-aurora-images.tar
BuildArch:      noarch
Requires:       uhd >= 4.10.0.0

%description
Bitfiles for the USRP X310 built from UHD 4.10.0.0 and rfnoc-oot-blocks with
the X310 Aurora patch series:
  usrp_x310_fpga_Aurora   - X310_AA:  Aurora on SFP0, 1 GigE on SFP1
  usrp_x310_fpga_Aurora1  - X310_AA1: Aurora on SFP1, 1 GigE on SFP0
(whichever variants were built). Load with:
  uhd_image_loader --args "type=x300,addr=<ip>" \
      --fpga-path %{_datadir}/uhd/images/usrp_x310_fpga_Aurora.bit

%prep
%setup -q -c -n x310-aurora-images

%install
install -D -m644 -t %{buildroot}%{_datadir}/uhd/images usrp_x310_fpga_Aurora*

%files
%dir %{_datadir}/uhd/images
%{_datadir}/uhd/images/usrp_x310_fpga_Aurora*

%changelog
* Tue Oct 27 2026 crimea82 <crimea82@protonmail.com> - 4.10.0.0-1
- Initial package of the X310 Aurora bitfiles
