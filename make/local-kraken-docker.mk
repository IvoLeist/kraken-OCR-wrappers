DOCKER_BIN ?= $(shell command -v docker 2>/dev/null)
KRAKEN_DOCKER_IMAGE ?= local/kraken-ocr:latest
KRAKEN_DOCKERFILE ?= docker/kraken.Dockerfile
KRAKEN_DOCKER_UV_VERSION ?= 0.11.18
KRAKEN_DOCKER_PYTHON_VERSION ?= 3.13
KRAKEN_VERSION ?= 7.0.2

ifeq ($(OS),Windows_NT)
DOCKER_KRAKEN_SUPPORTED := no
DOCKER_KRAKEN_UNSUPPORTED_REASON := native Windows is not supported by this Makefile
else ifeq ($(UNAME_S),Linux)
DOCKER_KRAKEN_SUPPORTED := yes
else ifeq ($(UNAME_S),Darwin)
DOCKER_KRAKEN_SUPPORTED := yes
else
DOCKER_KRAKEN_SUPPORTED := no
DOCKER_KRAKEN_UNSUPPORTED_REASON := unsupported operating system: $(UNAME_S)
endif

.PHONY: local-kraken-install-docker
.PHONY: local-kraken-docker-build local-kraken-docker-test local-kraken-docker-shell local-kraken-docker-remove
.PHONY: check-docker-bin check-docker-supported

local-kraken-install-docker: local-kraken-docker-build

local-kraken-docker-build: check-docker-supported check-docker-bin
	$(DOCKER_BIN) build \
		-f $(KRAKEN_DOCKERFILE) \
		-t $(KRAKEN_DOCKER_IMAGE) \
		--build-arg UV_VERSION=$(KRAKEN_DOCKER_UV_VERSION) \
		--build-arg PYTHON_VERSION=$(KRAKEN_DOCKER_PYTHON_VERSION) \
		--build-arg KRAKEN_VERSION=$(KRAKEN_VERSION) \
		.

local-kraken-docker-test: check-docker-supported check-docker-bin
	$(DOCKER_BIN) run --rm \
		-v "$$(pwd):/work" \
		-w /work \
		$(KRAKEN_DOCKER_IMAGE) \
		kraken --version

local-kraken-docker-shell: check-docker-supported check-docker-bin
	$(DOCKER_BIN) run --rm -it \
		-v "$$(pwd):/work" \
		-w /work \
		$(KRAKEN_DOCKER_IMAGE) \
		/bin/bash

local-kraken-docker-remove: check-docker-bin
	$(DOCKER_BIN) image rm $(KRAKEN_DOCKER_IMAGE)

check-docker-bin:
	@if [ -z "$(DOCKER_BIN)" ]; then \
		echo "docker was not found in PATH."; \
		echo "Install Docker first."; \
		exit 1; \
	fi

check-docker-supported:
ifeq ($(DOCKER_KRAKEN_SUPPORTED),yes)
	@true
else
	$(error Docker-based Kraken installation is not supported here: $(DOCKER_KRAKEN_UNSUPPORTED_REASON))
endif