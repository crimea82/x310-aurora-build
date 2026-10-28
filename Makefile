# -------------------------------------------------------------------
# Configurable variables — override on the command line as needed
# -------------------------------------------------------------------
VIVADO_PATH       ?= /tools/Xilinx/Vivado
INSTALL_PREFIX    ?= /usr/local
BUILD_TARGET      ?= X310_AA
JOBS              ?= $(shell nproc)
SUDO              ?= sudo

UHD_PATCH_REPO   ?= https://github.com/crimea82/uhd-x310-aurora-patches.git
RFNOC_PATCH_REPO ?= https://github.com/crimea82/rfnoc-oot-blocks-x310-aurora-patches.git

# Extra arguments appended to the CMake configure step of each project
# (e.g. -DPYTHON_EXECUTABLE=... or Boost hints on distros with old packages).
UHD_CMAKE_ARGS    ?=
RFNOC_CMAKE_ARGS  ?=

# -------------------------------------------------------------------
# Derived paths
# -------------------------------------------------------------------
UHD_PATCHES_DIR   = uhd-patches
UHD_SRC_DIR       = $(UHD_PATCHES_DIR)/uhd
RFNOC_PATCHES_DIR = rfnoc-patches
RFNOC_SRC_DIR     = $(RFNOC_PATCHES_DIR)/rfnoc-oot-blocks

STAMPS = .stamps

ifeq ($(BUILD_TARGET),X310_AA1)
IMAGE_CORE_YML = icores/x310_Aurora1_rfnoc_image_core.yml
else
IMAGE_CORE_YML = icores/x310_Aurora_rfnoc_image_core.yml
endif

# -------------------------------------------------------------------
# Top-level phased targets
# -------------------------------------------------------------------
.PHONY: all uhd rfnoc bitfile clean

all: bitfile

uhd:    $(STAMPS)/uhd-installed
rfnoc:  $(STAMPS)/rfnoc-installed
bitfile: $(STAMPS)/bitfile

# -------------------------------------------------------------------
# Phase 1: Clone and patch UHD
# -------------------------------------------------------------------
$(UHD_PATCHES_DIR)/Makefile:
	git clone $(UHD_PATCH_REPO) $(UHD_PATCHES_DIR)

$(STAMPS)/uhd-patched: $(UHD_PATCHES_DIR)/Makefile
	$(MAKE) -C $(UHD_PATCHES_DIR)
	@mkdir -p $(STAMPS)
	@touch $@

# -------------------------------------------------------------------
# Phase 2: Build and install UHD host
# -------------------------------------------------------------------
$(STAMPS)/uhd-built: $(STAMPS)/uhd-patched
	cd $(UHD_SRC_DIR)/host && \
	    cmake -B build -DCMAKE_INSTALL_PREFIX=$(INSTALL_PREFIX) $(UHD_CMAKE_ARGS) && \
	    cmake --build build -j$(JOBS)
	@touch $@

$(STAMPS)/uhd-installed: $(STAMPS)/uhd-built
	$(SUDO) cmake --install $(UHD_SRC_DIR)/host/build
	@touch $@

# -------------------------------------------------------------------
# Phase 3: Clone and patch rfnoc-oot-blocks
# -------------------------------------------------------------------
$(RFNOC_PATCHES_DIR)/Makefile:
	git clone $(RFNOC_PATCH_REPO) $(RFNOC_PATCHES_DIR)

$(STAMPS)/rfnoc-patched: $(RFNOC_PATCHES_DIR)/Makefile
	$(MAKE) -C $(RFNOC_PATCHES_DIR)
	@mkdir -p $(STAMPS)
	@touch $@

# -------------------------------------------------------------------
# Phase 4: Build and install rfnoc-oot-blocks host library
# -------------------------------------------------------------------
$(STAMPS)/rfnoc-built: $(STAMPS)/rfnoc-patched $(STAMPS)/uhd-installed
	cd $(RFNOC_SRC_DIR) && \
	    cmake -B build -DCMAKE_INSTALL_PREFIX=$(INSTALL_PREFIX) $(RFNOC_CMAKE_ARGS) && \
	    cmake --build build -j$(JOBS)
	@touch $@

$(STAMPS)/rfnoc-installed: $(STAMPS)/rfnoc-built
	$(SUDO) cmake --install $(RFNOC_SRC_DIR)/build
	@touch $@

# -------------------------------------------------------------------
# Phase 5: Build FPGA bitfile
# -------------------------------------------------------------------
$(STAMPS)/bitfile: $(STAMPS)/rfnoc-installed
	cd $(RFNOC_SRC_DIR) && \
	    rfnoc_image_builder \
	        -y $(IMAGE_CORE_YML) \
	        -t $(BUILD_TARGET) \
	        -I . \
	        -F $(abspath $(UHD_SRC_DIR)/fpga) \
	        -p $(VIVADO_PATH) \
	        -j $(JOBS)
	@touch $@

# -------------------------------------------------------------------
# Clean
# -------------------------------------------------------------------
clean:
	-$(MAKE) -C $(UHD_PATCHES_DIR) clean
	-$(MAKE) -C $(RFNOC_PATCHES_DIR) clean
	rm -rf $(UHD_PATCHES_DIR) $(RFNOC_PATCHES_DIR) $(STAMPS)
