# X310 Aurora Build

Automated build of the full X310 Aurora RFNoC stack from source:

1. Clone and patch UHD 4.10.0.0
2. Build and install the UHD host library and tools
3. Clone and patch rfnoc-oot-blocks
4. Build and install the rfnoc-oot-blocks host library (registers Aurora block with UHD)
5. Run `rfnoc_image_builder` to produce the FPGA bitfile

## Prerequisites

- Vivado 2024.2 installed (for bitfile generation)
- CMake 3.12+, GCC with C++17 support
- `sudo` access for installing to `INSTALL_PREFIX`

## Quick start

```bash
git clone https://github.com/crimea82/x310-aurora-build.git
cd x310-aurora-build
make
```

`make` will:
1. Clone `uhd-x310-aurora-patches` from GitHub and apply patches to UHD 4.10.0.0
2. Build and install the UHD host library and tools to `/usr/local`
3. Clone `rfnoc-oot-blocks-x310-aurora-patches` from GitHub and apply patches
4. Build and install the rfnoc-oot-blocks host library to `/usr/local`
5. Run `rfnoc_image_builder` with Vivado 2024.2 to produce the X310 Aurora bitfile

The install steps (`cmake --install`) require `sudo`. Set `SUDO=` to skip if running
as root.

If Vivado is not at `/tools/Xilinx/Vivado`, pass the base path:

```bash
make VIVADO_PATH=/opt/Xilinx/Vivado
```

## Usage

```bash
make                    # build everything (X310_AA by default)
make uhd                # run through UHD install only
make rfnoc              # run through rfnoc-oot-blocks install only
make bitfile            # run through bitfile generation
make clean              # remove all cloned sources and build artifacts
```

## Configuration

All variables can be overridden on the command line:

| Variable | Default | Description |
|---|---|---|
| `VIVADO_PATH` | `/tools/Xilinx/Vivado` | Vivado install base (version appended by setupenv.sh) |
| `INSTALL_PREFIX` | `/usr/local` | CMake install prefix for UHD and rfnoc-oot-blocks |
| `BUILD_TARGET` | `X310_AA` | `X310_AA` (Aurora SFP0) or `X310_AA1` (Aurora SFP1) |
| `JOBS` | `nproc` | Parallel build jobs |
| `SUDO` | `sudo` | Set to empty string if running as root |
| `UHD_PATCH_REPO` | gitlab.home.lan | URL of the UHD patch repo |
| `RFNOC_PATCH_REPO` | gitlab.home.lan | URL of the rfnoc-oot-blocks patch repo |

Example — build the SFP1 Aurora variant with a custom Vivado path:

```bash
make BUILD_TARGET=X310_AA1 VIVADO_PATH=/opt/Xilinx/Vivado
```

## Build targets

Each phase depends on the previous and is tracked by a stamp file in `.stamps/`.
Rerunning `make` after a partial build resumes from where it left off.

| Target | What it does |
|---|---|
| `uhd` | Clone + patch + build + install UHD host |
| `rfnoc` | Clone + patch + build + install rfnoc-oot-blocks |
| `bitfile` | Run `rfnoc_image_builder` to produce `x300.bit` |
| `all` | All of the above in order |
| `clean` | Remove all cloned sources, build trees, and stamp files |

## Output

The bitfile is written by `rfnoc_image_builder` into the `rfnoc-oot-blocks/build/`
directory inside the rfnoc source tree:

```
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.bit
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.bin
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.lvbitx
```

## Network configuration

The X310 uses Ethernet for its control plane. In Aurora builds one SFP port
is consumed by the Aurora link and is no longer usable as Ethernet. Connect
the host to the remaining Ethernet port.

The X310 stores IP addresses in EEPROM with factory defaults:

- SFP0 (eth0): `192.168.10.2`
- SFP1 (eth1): `192.168.20.2`

**X310_AA** (Aurora on SFP0): connect host NIC to SFP1, set host address to
`192.168.20.1/24`. UHD reaches the X310 at `192.168.20.2`.

**X310_AA1** (Aurora on SFP1): connect host NIC to SFP0, set host address to
`192.168.10.1/24`. UHD reaches the X310 at `192.168.10.2`.
