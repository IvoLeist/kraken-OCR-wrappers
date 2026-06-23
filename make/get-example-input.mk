# make/local-kraken-data.mk

EXAMPLE_DATA_DIR ?= example_input

CURL_BIN ?= $(shell command -v curl 2>/dev/null)
WGET_BIN ?= $(shell command -v wget 2>/dev/null)

# Example image URLs
KRAKEN_REPO_URL ?= https://raw.githubusercontent.com/mittagessen/kraken/refs/heads/
BRANCH ?= main
RESOURCE_PATH ?= tests/resources
FULL_URL ?= $(KRAKEN_REPO_URL)$(BRANCH)/$(RESOURCE_PATH)/
BINARISE_EXAMPLE_IMAGE ?= $(FULL_URL)input.jpg
SEGMENT_EXAMPLE_IMAGE ?= $(FULL_URL)input_bw.png

# Example images local paths
KRAKEN_EXAMPLE_IMAGE ?= $(EXAMPLE_DATA_DIR)/input.jpg
KRAKEN_EXAMPLE_BINARIZED ?= $(EXAMPLE_DATA_DIR)/input_bw.png

.PHONY: kraken-input-examples kraken-input-examples-info

kraken-input-examples: check-download-bin
	$(call download_file,$(BINARISE_EXAMPLE_IMAGE),$(KRAKEN_EXAMPLE_IMAGE))
	$(call download_file,$(SEGMENT_EXAMPLE_IMAGE),$(KRAKEN_EXAMPLE_BINARIZED))

local-kraken-data-info:
	@echo "Example data dir:          $(EXAMPLE_DATA_DIR)"
	@echo "curl bin:                  $(CURL_BIN)"
	@echo "wget bin:                  $(WGET_BIN)"
	@echo ""
	@echo "Example image:"
	@echo "  $(KRAKEN_EXAMPLE_IMAGE)"
	@echo ""
	@echo "Example binarised image:"
	@echo "  $(KRAKEN_EXAMPLE_BINARIZED)"

check-download-bin:
	@if [ -z "$(CURL_BIN)" ] && [ -z "$(WGET_BIN)" ]; then \
		echo "Neither curl nor wget was found in PATH."; \
		exit 1; \
	fi

define download_file
	@if [ -f "$(2)" ]; then \
		echo "Already exists: $(2)"; \
	else \
		echo "Downloading $(1)"; \
		if [ -n "$(CURL_BIN)" ]; then \
			$(CURL_BIN) -L --fail -o "$(2)" "$(1)"; \
		else \
			$(WGET_BIN) -O "$(2)" "$(1)"; \
		fi; \
	fi
endef