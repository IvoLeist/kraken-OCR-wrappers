# notebooks/Makefile

PROJECT_ROOT := ..
KRAKEN_ENV_NAME ?= kraken-ocr
KRAKEN_VENV := $(PROJECT_ROOT)/.venv-$(KRAKEN_ENV_NAME)
KRAKEN_PYTHON := $(KRAKEN_VENV)/bin/python

UV_BIN ?= $(shell command -v uv 2>/dev/null)

KERNEL_NAME ?= $(KRAKEN_ENV_NAME)
KERNEL_DISPLAY_NAME ?= Python (.venv-$(KRAKEN_ENV_NAME))

VSCODE_DIR := $(PROJECT_ROOT)/.vscode
VSCODE_SETTINGS := $(VSCODE_DIR)/settings.json

NOTEBOOKS_DIR := $(PROJECT_ROOT)/notebooks
SEGMENTATION_NB_PY_SCRIPT := $(NOTEBOOKS_DIR)/kraken_segmentation_diff.py
SEGMENTATION_NB := $(NOTEBOOKS_DIR)/nb_kraken_segmentation_diff.ipynb

.PHONY: help
.PHONY: check-uv check-venv
.PHONY: install-kernel-support register-kernel setup-vscode-kernel
.PHONY: kernel-info remove-kernel

help:
	@echo "Notebook helper targets:"
	@echo ""
	@echo "  make install-kernel-support   Install ipykernel into the uv venv"
	@echo "  make register-kernel          Register the uv venv as a Jupyter kernel"
	@echo "  make setup-vscode-kernel      Install ipykernel, register kernel, write VS Code interpreter setting"
	@echo "  make kernel-info              Show kernel/interpreter info"
	@echo "  make remove-kernel            Remove registered Jupyter kernel"
	@echo ""
	@echo "Variables:"
	@echo "  KRAKEN_ENV_NAME=$(KRAKEN_ENV_NAME)"
	@echo "  KERNEL_NAME=$(KERNEL_NAME)"
	@echo "  KERNEL_DISPLAY_NAME=$(KERNEL_DISPLAY_NAME)"

check-uv:
	@if [ -z "$(UV_BIN)" ]; then \
		echo "uv was not found in PATH."; \
		echo "Install uv first:"; \
		echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"; \
		exit 1; \
	fi

check-venv:
	@if [ ! -x "$(KRAKEN_PYTHON)" ]; then \
		echo "Python executable not found: $(KRAKEN_PYTHON)"; \
		echo "Create the Kraken uv environment first, for example from the project root:"; \
		echo "  make local-kraken-install"; \
		exit 1; \
	fi

install-kernel-support: check-uv check-venv
	$(UV_BIN) pip install --python "$(KRAKEN_VENV)" ipykernel

register-kernel: check-venv
	"$(KRAKEN_PYTHON)" -m ipykernel install \
		--user \
		--name "$(KERNEL_NAME)" \
		--display-name "$(KERNEL_DISPLAY_NAME)"

setup-vscode-kernel: install-kernel-support register-kernel
	mkdir -p "$(VSCODE_DIR)"
	printf '%s\n' '{' \
		'  "python.defaultInterpreterPath": "$${workspaceFolder}/.venv-$(KRAKEN_ENV_NAME)/bin/python"' \
		'}' > "$(VSCODE_SETTINGS)"
	@echo "Wrote $(VSCODE_SETTINGS)"
	@echo "VS Code kernel display name: $(KERNEL_DISPLAY_NAME)"

kernel-info: check-venv
	@echo "Project root:         $(PROJECT_ROOT)"
	@echo "Kraken venv:          $(KRAKEN_VENV)"
	@echo "Python executable:    $(KRAKEN_PYTHON)"
	@echo "Kernel name:          $(KERNEL_NAME)"
	@echo "Kernel display name:  $(KERNEL_DISPLAY_NAME)"
	@echo ""
	@"$(KRAKEN_PYTHON)" --version
	@"$(KRAKEN_PYTHON)" -c "import ipykernel; print('ipykernel:            installed (' + ipykernel.__version__ + ')')" 2>/dev/null || \
		echo "ipykernel:            not installed"

kernel-list:
	jupyter kernelspec list

remove-kernel:
	jupyter kernelspec remove -f "$(KERNEL_NAME)"

convert-py-script-to-notebook:
	@echo "Converting Python script to Jupyter notebook..."
	uvx jupytext --to ipynb "$(SEGMENTATION_NB_PY_SCRIPT)" --output "$(SEGMENTATION_NB)"
	@echo "Notebook created: $(SEGMENTATION_NB)"
