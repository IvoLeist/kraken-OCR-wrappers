# Detect operating system and CPU architecture
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
UNAME_M := $(shell uname -m 2>/dev/null || echo unknown)

KRAKEN_ENV_NAME ?= kraken-ocr
KRAKEN_PYTHON_VERSION ?= 3.12
KRAKEN_CHANNELS ?= -c conda-forge

# auto | uv | conda | docker
KRAKEN_INSTALL_METHOD ?= auto

CONDA_BIN ?= $(shell command -v mamba 2>/dev/null || command -v conda 2>/dev/null)
UV_BIN ?= $(shell command -v uv 2>/dev/null)

# Resolve install method
ifeq ($(KRAKEN_INSTALL_METHOD),auto)
ifeq ($(OS),Windows_NT)
RESOLVED_KRAKEN_INSTALL_METHOD := unsupported
else ifeq ($(UNAME_S),Linux)
RESOLVED_KRAKEN_INSTALL_METHOD := uv
else ifeq ($(UNAME_S),Darwin)
RESOLVED_KRAKEN_INSTALL_METHOD := uv
else
RESOLVED_KRAKEN_INSTALL_METHOD := unsupported
endif
else
RESOLVED_KRAKEN_INSTALL_METHOD := $(KRAKEN_INSTALL_METHOD)
endif


# Check whether conda/mamba install is supported for Kraken OCR
ifeq ($(OS),Windows_NT)
CONDA_KRAKEN_SUPPORTED := no
CONDA_KRAKEN_UNSUPPORTED_REASON := native Windows is not supported
else ifeq ($(UNAME_S),Linux)
CONDA_KRAKEN_SUPPORTED := yes
else ifeq ($(UNAME_S),Darwin)
ifeq ($(UNAME_M),arm64)
CONDA_KRAKEN_SUPPORTED := no
CONDA_KRAKEN_UNSUPPORTED_REASON := the kraken-ocr conda package does not yet support macOS ARM / Apple Silicon
else ifeq ($(UNAME_M),x86_64)
CONDA_KRAKEN_SUPPORTED := yes
else
CONDA_KRAKEN_SUPPORTED := no
CONDA_KRAKEN_UNSUPPORTED_REASON := unsupported macOS architecture: $(UNAME_M)
endif
else
CONDA_KRAKEN_SUPPORTED := no
CONDA_KRAKEN_UNSUPPORTED_REASON := unsupported operating system: $(UNAME_S)
endif

.PHONY: local-kraken-install local-kraken-remove local-kraken-test local-kraken-info
.PHONY: local-kraken-install-uv local-kraken-install-conda
.PHONY: check-uv-bin check-conda-bin check-conda-supported

local-kraken-install:
ifeq ($(OS),Windows_NT)
	$(error Native Windows is not supported for Kraken OCR. Use Linux, WSL2, Docker, or a remote Linux environment)
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),uv)
	$(MAKE) local-kraken-install-uv
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),conda)
	$(MAKE) check-conda-supported
	$(MAKE) local-kraken-install-conda
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),docker)
	$(MAKE) local-kraken-install-docker
else
	$(error Unsupported KRAKEN_INSTALL_METHOD='$(KRAKEN_INSTALL_METHOD)'. Use auto, uv, conda, or docker)
endif

local-kraken-install-uv: check-uv-bin
	$(UV_BIN) venv --python $(KRAKEN_PYTHON_VERSION) .venv-$(KRAKEN_ENV_NAME)
	$(UV_BIN) pip install \
		--python .venv-$(KRAKEN_ENV_NAME) \
		"kraken[pdf]"

local-kraken-install-conda: check-conda-bin
	$(CONDA_BIN) create -y \
		-n $(KRAKEN_ENV_NAME) \
		$(KRAKEN_CHANNELS) \
		python=$(KRAKEN_PYTHON_VERSION) \
		kraken-ocr

local-kraken-remove:
ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),uv)
	rm -rf .venv-$(KRAKEN_ENV_NAME)
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),conda)
	$(MAKE) check-conda-supported
	$(MAKE) check-conda-bin
	$(CONDA_BIN) env remove -y -n $(KRAKEN_ENV_NAME)
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),docker)
	$(MAKE) local-kraken-docker-remove
else
	$(error Unsupported KRAKEN_INSTALL_METHOD='$(KRAKEN_INSTALL_METHOD)'. Use auto, uv, conda, or docker)
endif

local-kraken-test:
ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),uv)
	.venv-$(KRAKEN_ENV_NAME)/bin/kraken --version
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),conda)
	$(MAKE) check-conda-supported
	$(MAKE) check-conda-bin
	$(CONDA_BIN) run -n $(KRAKEN_ENV_NAME) kraken --version
else ifeq ($(RESOLVED_KRAKEN_INSTALL_METHOD),docker)
	$(MAKE) local-kraken-docker-test
else
	$(error Unsupported KRAKEN_INSTALL_METHOD='$(KRAKEN_INSTALL_METHOD)'. Use auto, uv, conda, or docker)
endif

local-kraken-install-info:
	@echo "Detected OS:              $(UNAME_S)"
	@echo "Detected arch:            $(UNAME_M)"
	@echo "Requested install method: $(KRAKEN_INSTALL_METHOD)"
	@echo "Resolved install method:  $(RESOLVED_KRAKEN_INSTALL_METHOD)"
	@echo "uv bin:                   $(UV_BIN)"
	@echo "Kraken env name:          $(KRAKEN_ENV_NAME)"
	@echo "Python version:           $(KRAKEN_PYTHON_VERSION)"
	@if [ -n "$(UV_BIN)" ]; then $(UV_BIN) --version; fi
ifeq ($(CONDA_KRAKEN_SUPPORTED),yes)
	@echo "Conda/mamba supported:    yes"
	@echo "Conda-compatible bin:     $(CONDA_BIN)"
	@echo "Channels:                 $(KRAKEN_CHANNELS)"
	@if [ -n "$(CONDA_BIN)" ]; then $(CONDA_BIN) --version; fi
else
	@echo "Conda/mamba supported:    no"
	@echo "Reason:                   $(CONDA_KRAKEN_UNSUPPORTED_REASON)"
endif

check-uv-bin:
	@if [ -z "$(UV_BIN)" ]; then \
		echo "uv was not found in PATH."; \
		echo "Install uv first:"; \
		echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"; \
		exit 1; \
	fi

check-conda-bin:
	@if [ -z "$(CONDA_BIN)" ]; then \
		echo "Neither mamba nor conda was found in PATH."; \
		exit 1; \
	fi

check-conda-supported:
ifeq ($(CONDA_KRAKEN_SUPPORTED),yes)
	@true
else
	$(error Conda-based Kraken installation is not supported here: $(CONDA_KRAKEN_UNSUPPORTED_REASON). Use KRAKEN_INSTALL_METHOD=uv)
endif