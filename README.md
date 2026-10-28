# X310 Aurora Build

Automated build of the full X310 Aurora RFNoC stack from source:

1. Clone and patch UHD 4.10.0.0
2. Build and install the UHD host library and tools
3. Clone and patch rfnoc-oot-blocks
4. Build and install the rfnoc-oot-blocks host library (registers Aurora block with UHD) and, if pybind11 is present, the `rfnoc_oot_blocks` Python bindings
5. Run `rfnoc_image_builder` to produce the FPGA bitfile

## Prerequisites

- Vivado 2024.2 installed (for bitfile generation)
- CMake 3.12+, GCC with C++17 support
- `sudo` access for installing to `INSTALL_PREFIX`
- For the `rfnoc_oot_blocks` Python bindings (optional, used by the Python
  examples): `pybind11-dev`, `python3-dev` and `python3-numpy`. On Ubuntu 22.04:

  ```bash
  sudo apt install pybind11-dev python3-pybind11 python3-dev python3-numpy
  ```

  If pybind11 is missing, step 4 silently builds only the C++ library. Install
  it before running `make`; the patched `rfnoc-oot-blocks/README.md` explains
  how to verify the bindings afterwards.

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
| `UHD_PATCH_REPO` | `https://github.com/crimea82/uhd-x310-aurora-patches.git` | URL of the UHD patch repo |
| `RFNOC_PATCH_REPO` | `https://github.com/crimea82/rfnoc-oot-blocks-x310-aurora-patches.git` | URL of the rfnoc-oot-blocks patch repo |
| `UHD_CMAKE_ARGS` | empty | Extra arguments for the UHD CMake configure step |
| `RFNOC_CMAKE_ARGS` | empty | Extra arguments for the rfnoc-oot-blocks CMake configure step |

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

## Docker build (Oracle Linux 8)

The `docker/` directory builds the whole stack inside an Oracle Linux 8
container instead of on the host. The image contains the OL8 toolchain plus
patched UHD and rfnoc-oot-blocks (C++ library and the `rfnoc_oot_blocks` Python
bindings) already built and installed. Vivado is **not** in the image; the host
install is bind-mounted read-only at run time, together with the license file,
and only the bitfile phase runs in the container.

### Host prerequisites

- Docker (on Ubuntu: `sudo apt install docker.io && sudo usermod -aG docker $USER`,
  then log out and back in).
- Vivado 2024.2 installed on the host under `/tools/Xilinx` (override with
  `VIVADO_DIR=/path/to/Xilinx`, the directory that contains `Vivado/2024.2`).
- A Vivado license file, by default `~/.Xilinx/Xilinx_trial.lic` (override with
  `LICENSE_FILE=...`).

### Usage

```bash
docker/build.sh                      # build the image (~15 min on 8 cores, needs network)
docker/run.sh license-check          # ~2 min: Vivado starts and checks out a K7 license
docker/run.sh                        # build the bitfile (X310_AA), ~25 min on 8 cores
BUILD_TARGET=X310_AA1 docker/run.sh  # the SFP1 variant
docker/run.sh bash                   # interactive shell in the image
```

Results are copied to `./output/` on the host (`usrp_x310_fpga_Aurora*.bit`,
`.bin`, `.lvbitx`, `.rpt`, plus the Vivado logs under `output/build-usrp_x310_fpga_*/`)
and chowned to the invoking user. Everything else in the container is discarded
when it exits. Set `BUILD_IP_DIR=$PWD/build-ip` to keep the generated-IP cache
between runs (IP generation is roughly the first third of the run). `JOBS`
(default 4) controls parallelism for both scripts.

### How licensing works in the container

The Vivado license is node-locked: its `HOSTID` is the MAC address of the host's
network interface. FlexLM determines the host ID from the interfaces visible in
the container's network namespace, so a container on the default bridge network
(random MAC) fails with an "invalid host" error. `docker/run.sh` therefore runs
the container with `--network host`, which shares the host's network namespace
and exposes the real interface and MAC. The trade-off is that the container has
no network isolation from the host. If host networking is not acceptable, the
alternative is `--mac-address <host MAC>` on a bridge network, which FlexLM
usually accepts but is less widely tested.

The license file is mounted read-only at `/licenses/Xilinx.lic` and passed via
`XILINXD_LICENSE_FILE`. `docker/run.sh license-check` prints the host IDs FlexLM
sees next to the `HOSTID` from the license file, runs `vivado -version`, and
synthesizes a one-gate design for `xc7k410tffg900-2`, which is the step that
actually checks out a Kintex-7 license. Run it before the long build.

### Caveats

- Oracle Linux 8 is binary-compatible with RHEL 8, but AMD's supported list for
  Vivado 2024.2 names RHEL 8.8-8.10 and AlmaLinux 8.x, not OL8.
- Vivado is mounted read-only. It writes only to `$HOME/.Xilinx`, `/tmp` and the
  build directory inside the container. If a Vivado version ever insists on
  writing into its install tree, drop the `:ro` in `docker/run.sh`.
- OL8's stock Python (3.6), Boost (1.66) and GCC (8.5, whose `std::filesystem`
  lives in a separate library UHD does not link) are too old for UHD 4.10. The
  image uses the AppStream `python3.11` stream, EPEL's `boost1.78` and
  `gcc-toolset-13`, and installs pybind11 2.10.4 from pip to match the pybind11
  ABI UHD bundles.
- The Python modules land in `/usr/local/lib64/python3.11/site-packages`, which
  OL8's Python does not search by default; the image sets `PYTHONPATH` for this.
- Evaluation licenses expire; check the `INCREMENT ... <date>` lines in the
  license file if Vivado suddenly refuses to synthesize.
- The VM has 15 GB of RAM; Kintex-7 410T synthesis needs 8-10 GB. The container
  runs without a memory limit. Lower `JOBS` if the host starts swapping.

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
