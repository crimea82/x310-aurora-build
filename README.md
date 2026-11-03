# X310 Aurora Build

Builds the X310 Aurora RFNoC stack from source: patched UHD 4.10.0.0, the
rfnoc-oot-blocks Aurora block with its Python bindings, and the X310 FPGA
bitfile. It can run in an Oracle Linux 8 Docker container, which also produces
RPMs, or natively with `make`.

## Prerequisites

Both routes need Vivado 2024.2 on the host for bitfile generation. The Docker
route needs nothing else beyond Docker; the native route needs the toolchain
installed on the host.

### Docker build

- Docker (on Ubuntu: `sudo apt install docker.io && sudo usermod -aG docker $USER`,
  then log out and back in).
- Vivado 2024.2 installed on the host under `/tools/Xilinx` (override with
  `VIVADO_DIR=/path/to/Xilinx`, the directory that contains `Vivado/2024.2`).
- A Vivado license file, by default `~/.Xilinx/Xilinx_trial.lic` (override with
  `LICENSE_FILE=...`). A node-locked license keeps working because the container
  runs with `--network host` and sees the host's MAC address.

The compilers, CMake, Boost, Python and pybind11 all live inside the image, so
nothing is installed on the host and the host's UHD installation is untouched.

### Native `make` build

- Vivado 2024.2 installed (for bitfile generation)
- CMake 3.12+, GCC with C++17 support
- `sudo` access for installing to `INSTALL_PREFIX`
- For the `rfnoc_oot_blocks` Python bindings (optional, used by the Python
  examples): `pybind11-dev`, `python3-dev` and `python3-numpy`. On Ubuntu 22.04:

  ```bash
  sudo apt install pybind11-dev python3-pybind11 python3-dev python3-numpy
  ```

  If pybind11 is missing, the rfnoc-oot-blocks build silently produces only
  the C++ library. Install
  it before running `make`; the patched `rfnoc-oot-blocks/README.md` explains
  how to verify the bindings afterwards.

## Quick start

### Option A: Docker (Oracle Linux 8 container, recommended)

Builds everything inside a container, so the host only needs Docker and a
Vivado 2024.2 install with its license file (see
[Docker build](#docker-build-oracle-linux-8) for details):

```bash
git clone https://github.com/crimea82/x310-aurora-build.git
cd x310-aurora-build
docker/build-all.sh X310_AA1    # or X310_AA; takes ~1 h on 8 cores
```

This builds the image, runs the Vivado license check, generates the bitfile and
writes the bitfiles and RPMs to `./output/`.

### Option B: Native build with `make`

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

### Docker build

```bash
docker/build-all.sh X310_AA1         # image + license check + bitfile + RPMs for one target
docker/build.sh                      # build the image only (~20 min on 8 cores, needs network)
docker/run.sh license-check          # ~2 min: Vivado starts and checks out a K7 license
docker/run.sh                        # build the bitfile (X310_AA), ~25 min on 8 cores
BUILD_TARGET=X310_AA1 docker/run.sh  # the SFP1 variant
docker/run.sh rpms                   # write the RPMs to ./output/rpms (no Vivado needed)
docker/run.sh bash                   # interactive shell in the image
```

Results land in `./output/`. See [Docker build](#docker-build-oracle-linux-8)
for the environment variables (`VIVADO_DIR`, `LICENSE_FILE`, `BUILD_IP_DIR`,
`JOBS`) and caveats.

### Native `make` build

```bash
make                    # build everything (X310_AA by default)
make uhd                # run through UHD install only
make rfnoc              # run through rfnoc-oot-blocks install only
make bitfile            # run through bitfile generation
make clean              # remove all cloned sources and build artifacts
```

## Configuration

### Docker build

Environment variables read by the `docker/` scripts; `docker/build-all.sh`
passes them all through:

| Variable | Default | Used by | Description |
|---|---|---|---|
| `BUILD_TARGET` | `X310_AA` (`X310_AA1` for `build-all.sh`) | `run.sh`, `build-all.sh` | `X310_AA` (Aurora SFP0) or `X310_AA1` (Aurora SFP1) |
| `JOBS` | `4` | all | Parallel jobs for compiling the image and for Vivado |
| `VIVADO_DIR` | `/tools/Xilinx` | `run.sh` | Host directory containing `Vivado/2024.2`, mounted read-only |
| `LICENSE_FILE` | `~/.Xilinx/Xilinx_trial.lic` | `run.sh` | Host Vivado license file, mounted read-only |
| `OUTPUT_DIR` | `./output` | `run.sh` | Host directory that receives bitfiles, logs and RPMs |
| `BUILD_IP_DIR` | unset (`./build-ip` for `build-all.sh`) | `run.sh`, `build-all.sh` | Host directory for the generated-IP cache; reruns skip IP generation |
| `IMAGE` | `x310-aurora-build:ol8` | `run.sh` | Image tag to run |
| `TARGET` | unset (final stage) | `build.sh` | Build only up to this Dockerfile stage, e.g. `builder` to skip the RPM stages |

Example — build the SFP1 variant with Vivado installed elsewhere:

```bash
VIVADO_DIR=/opt/Xilinx LICENSE_FILE=~/licenses/vivado.lic docker/build-all.sh X310_AA1
```

### Native `make` build

All variables can be overridden on the `make` command line:

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

## Build phases

### Docker build

The image is built in stages by `docker/Dockerfile`; the software phases run
inside the image, the bitfile phase runs in a container from it:

| Stage / step | What it does |
|---|---|
| `base` | Oracle Linux 8 with EPEL, CodeReady, `gcc-toolset-13`, `boost1.78`, Python 3.11 and the RPM tooling |
| `sources` | Clone + patch UHD and rfnoc-oot-blocks (same Makefile as the native build) |
| `builder` | Build + install UHD and rfnoc-oot-blocks (with Python bindings) to `/usr/local` |
| `rpmbuild` | Build the RPMs from the patched sources with prefix `/usr` |
| `rpmtest` | Install the RPMs on a stock `oraclelinux:8` and run import/tool checks |
| `final` | `builder` plus the tested RPMs and the entrypoint; this is the image `docker/run.sh` uses |
| `docker/run.sh` | Run `make bitfile` inside the container with the host's Vivado, then package the images RPM |

Docker caches each stage, so rerunning `docker/build.sh` after a change to
`rpm/` or `docker/` only rebuilds from the affected stage onward.

### Native `make` build

Each phase depends on the previous and is tracked by a stamp file in `.stamps/`.
Rerunning `make` after a partial build resumes from where it left off.

| Target | What it does |
|---|---|
| `uhd` | Clone + patch + build + install UHD host |
| `rfnoc` | Clone + patch + build + install rfnoc-oot-blocks |
| `bitfile` | Run `rfnoc_image_builder` to produce the bitfile |
| `all` | All of the above in order |
| `clean` | Remove all cloned sources, build trees, and stamp files |

## Output

The bitfile is named `usrp_x310_fpga_Aurora.*` for `X310_AA` and
`usrp_x310_fpga_Aurora1.*` for `X310_AA1`.

### Docker build

Everything is copied to `./output/` on the host (or `OUTPUT_DIR`) and chowned
to the invoking user; nothing else survives the container:

```
output/usrp_x310_fpga_Aurora1.bit            # also .bin, .lvbitx and the .rpt summary
output/build-usrp_x310_fpga_Aurora1/         # Vivado build.log, timing, utilization and DRC reports
output/rpms/*.rpm                            # software RPMs + uhd-images-x310-aurora
output/rpms/repodata/                        # makes output/rpms usable as a dnf repository
```

The software stack itself stays inside the image, installed under `/usr/local`
(`docker/run.sh bash` to inspect it); install it on other machines from the RPMs.

### Native `make` build

UHD and rfnoc-oot-blocks are installed to `INSTALL_PREFIX` (`/usr/local`). The
bitfile is written by `rfnoc_image_builder` into the `rfnoc-oot-blocks/build/`
directory inside the rfnoc source tree:

```
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.bit
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.bin
rfnoc-patches/rfnoc-oot-blocks/build/usrp_x310_fpga_Aurora.lvbitx
rfnoc-patches/rfnoc-oot-blocks/build-usrp_x310_fpga_Aurora/   # Vivado logs and reports
```

## Docker build (Oracle Linux 8)

The `docker/` directory builds the whole stack inside an Oracle Linux 8
container instead of on the host. The image contains the OL8 toolchain plus
patched UHD and rfnoc-oot-blocks (C++ library and the `rfnoc_oot_blocks` Python
bindings) already built and installed. Vivado is **not** in the image; the host
install is bind-mounted read-only at run time, together with the license file,
and only the bitfile phase runs in the container.

The host prerequisites, commands, variables and output locations are in the
[Prerequisites](#docker-build), [Usage](#docker-build-1),
[Configuration](#docker-build-2) and [Output](#docker-build-4) sections above.
This section covers how the pieces fit together.

### Scripts

- `docker/build-all.sh [X310_AA|X310_AA1]` runs the three steps below in order
  for one target, keeping the IP cache in `./build-ip`.
- `docker/build.sh` builds the image. It also builds and self-tests the RPM
  packages (see [RPM packages](#rpm-packages)); set `TARGET=builder` to skip
  that while iterating on the bitfile flow.
- `docker/run.sh license-check` starts Vivado from the mounted install and checks
  out a Kintex-7 license. Run it before the long build.
- `docker/run.sh` builds the bitfile for `BUILD_TARGET`, copies the results to
  `./output/`, then packages the images RPM and refreshes `./output/rpms`.
  IP generation is roughly the first third of the run; set `BUILD_IP_DIR` to
  keep the generated-IP cache between runs.
- `docker/run.sh rpms` writes the RPMs without starting Vivado;
  `docker/run.sh bash` opens a shell in the image.

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

## RPM packages

The Docker route also builds RPMs of the whole software stack so that any
Oracle Linux 8 (or RHEL 8 compatible) system can install it with `dnf`,
without a source build. The native `make` build does not produce packages; it
installs straight to `INSTALL_PREFIX`.

| Package | Contents |
|---|---|
| `uhd` | Patched UHD 4.10.0.0: `libuhd`, utilities, Python 3.11 API (`import uhd`), `rfnoc_image_builder`, `rfnoc_modtool`, udev rules |
| `uhd-devel` | Headers, CMake config, pkg-config file |
| `rfnoc-oot-blocks` | Aurora block controller (registered with UHD via `modules.d`), `rfnoc_oot_blocks` Python bindings, block YAML and FPGA sources under `/usr/share/uhd/rfnoc`, image core files, Python examples |
| `rfnoc-oot-blocks-devel` | Headers and CMake config |
| `python3.11-mako`, `python3.11-ruamel-yaml` | Python 3.11 modules needed by `rfnoc_image_builder` that OL8 does not ship |
| `uhd-images-x310-aurora` | The X310 Aurora bitfiles, installed to `/usr/share/uhd/images` |

The spec files live in `rpm/`; `docker/build-rpms.sh` runs them in the
`rpmbuild` Dockerfile stage, in a clean OL8 environment, in dependency order.
A separate `rpmtest` stage then installs the results on a stock `oraclelinux:8`
and runs import/tool checks, so a successful `docker/build.sh` means the
packages are known to install on a fresh system. The packages are built with
prefix `/usr`, so the Python modules are on `sys.path` and `modules.d` is
found without any environment tweaks.

```bash
docker/run.sh rpms          # -> ./output/rpms/*.rpm + repodata/
```

The `rpms` mode copies the software RPMs out of the image, packages any
`usrp_x310_fpga_Aurora*` bitfiles found (from the current `./output` or the
container's last build) into `uhd-images-x310-aurora`, and runs `createrepo_c`
so `./output/rpms` can be used as a dnf repository. A `docker/run.sh` bitfile
build does the same after it succeeds.

### Installing on a target OL8 system

```bash
sudo dnf -y install oracle-epel-release-el8 dnf-utils
sudo dnf config-manager --set-enabled ol8_codeready_builder
sudo dnf -y install ./rpms/*.rpm          # or copy only the packages you need
```

EPEL and CodeReady are required for the runtime dependencies (`boost1.78`,
`python3.11-markupsafe`, `python3.11-pybind11`). Alternatively point dnf at the
directory as a repository:

```bash
sudo dnf config-manager --add-repo file:///path/to/rpms
sudo dnf -y --nogpgcheck install uhd rfnoc-oot-blocks uhd-images-x310-aurora
```

Verify:

```bash
uhd_config_info --version
python3.11 -c "import uhd, rfnoc_oot_blocks; print(uhd.__version__)"
rfnoc_image_builder --help
uhd_image_loader --args "type=x300,addr=192.168.20.2" \
    --fpga-path /usr/share/uhd/images/usrp_x310_fpga_Aurora.bit
```

Notes:

- Everything is built for the `python3.11` stream. Run scripts with
  `python3.11` (or `alternatives --set python3 /usr/bin/python3.11`); the
  installed tools already have `python3.11` shebangs.
- Compiling your own code against `uhd-devel` needs `gcc-toolset-13`
  (`scl enable gcc-toolset-13 bash`) and `-DBoost_DIR=/usr/lib64/cmake/Boost-1.78.0`.
- The `uhd` package is version 4.10.0.0 and replaces EPEL's `uhd` 3.15 if that
  was installed.
- `rfnoc_image_builder` prints a warning that `jsonschema` is not installed;
  OL8 has no `python3.11-jsonschema` package. It only disables schema
  validation of the YAML inputs and is harmless.
- Building new bitfiles on a target still needs Vivado and the patched UHD
  `fpga/` tree (`-F`); the Aurora block's own YAML and gateware are already
  installed under `/usr/share/uhd/rfnoc`.

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
