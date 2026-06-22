include .env
export

SHELL := /usr/bin/env bash

# Prefer mamba, fall back to conda
CONDA_BIN ?= $(shell command -v mamba 2>/dev/null || command -v conda 2>/dev/null)

ifeq ($(CONDA_BIN),)
$(error Neither mamba nor conda was found in PATH)
endif

include make/local-kraken-install.mk
include make/local-kraken-docker.mk
include make/colab.mk
include make/kraken.mk
include make/get-example-input.mk