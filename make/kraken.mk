# local | docker
RUN_METHOD ?= local

# uv | conda
# Only relevant when RUN_METHOD=local
USED_ENV ?= uv

KRAKEN_ENV_NAME ?= kraken-ocr
KRAKEN_DOCKER_IMAGE ?= local/kraken-ocr:latest

DOCKER_BIN ?= $(shell command -v docker 2>/dev/null)
CONDA_BIN ?= $(shell command -v mamba 2>/dev/null || command -v conda 2>/dev/null)

CMD ?= kraken
KRAKEN_ARGS ?= --help

# Shared Kraken CLI flags
KRAKEN_VERBOSE ?= 0
KRAKEN_RAISE_ON_ERROR ?= yes

# inputs/outputs
INPUT_DIR ?= example_input
BIN_INPUT_FILE ?= input.jpg
BIN_INPUT ?= $(INPUT_DIR)/$(BIN_INPUT_FILE)

OUTPUT_DIR ?= output
BIN_SUFFIX ?= _bw
BIN_OUT ?= $(OUTPUT_DIR)/$(BIN_INPUT_FILE:.jpg=$(BIN_SUFFIX).png)

# Binarize options
BIN_THRESHOLD ?= 0.5
BIN_ZOOM ?= 0.5
BIN_ESCALE ?= 1.0
BIN_BORDER ?= 0.1
BIN_PERC ?= 80
BIN_RANGE ?= 20
BIN_LOW ?= 5
BIN_HIGH ?= 90

# Segment options
SEG_INPUT ?= $(BIN_OUT)
SEG_OUT_DIR ?= $(OUTPUT_DIR)/boxes_segmentation
SEG_WRAPPER ?= scripts/kraken_segment_wrapper.sh

# Output XML formats for multi-format segmentation.
#SEG_OUT_FORMATS ?= native
SEG_OUT_FORMATS ?= alto,abbyy,pagexml,hocr,native
#SEG_OUT_FORMATS ?= alto,abbyy

# boxes | baseline
SEGMENTER ?= boxes
SEG_TEXT_DIRECTION ?= horizontal-lr
SEG_ARGS := --$(SEGMENTER) --text-direction $(SEG_TEXT_DIRECTION)

SEG_BASELINE_DIR ?= $(OUTPUT_DIR)/baseline_segmentation
SEG_BOXES_DIR ?= $(OUTPUT_DIR)/boxes_segmentation
SEG_DIFF_HTML ?= $(OUTPUT_DIR)/segmentation_diff.html
PAGES_DIR ?= build/pages

VERBOSE_FLAGS := $(shell i=0; while [ $$i -lt $(KRAKEN_VERBOSE) ]; do printf -- "-v "; i=$$((i+1)); done)

ifeq ($(KRAKEN_RAISE_ON_ERROR),yes)
KRAKEN_ERROR_FLAGS := --raise-on-error
else
KRAKEN_ERROR_FLAGS :=
endif

.PHONY: kraken-run check-binarise-input binarise segment
.PHONY: check-kraken-input check-kraken-output check-kraken-model check-kraken-segmentation
.PHONY: check-docker-bin check-conda-bin

define RUN_KRAKEN
	@echo "Running Kraken with arguments: $(1)"
	$(MAKE) run-kraken KRAKEN_ARGS='$(1)'
endef

run-kraken:
ifeq ($(RUN_METHOD),local)
ifeq ($(USED_ENV),uv)
	. .venv-$(KRAKEN_ENV_NAME)/bin/activate && \
		$(CMD) $(KRAKEN_ARGS)
else ifeq ($(USED_ENV),conda)
	$(MAKE) check-conda-bin
	$(CONDA_BIN) run -n $(KRAKEN_ENV_NAME) \
		$(CMD) $(KRAKEN_ARGS)
else
	$(error Unsupported USED_ENV='$(USED_ENV)'. Use uv or conda)
endif
else ifeq ($(RUN_METHOD),docker)
	$(MAKE) check-docker-bin
	$(DOCKER_BIN) run --rm \
		-v "$$(pwd):/work" \
		-w /work \
		$(KRAKEN_DOCKER_IMAGE) \
		$(CMD) $(KRAKEN_ARGS)
else
	$(error Unsupported RUN_METHOD='$(RUN_METHOD)'. Use local or docker)
endif


check-binarise-input:
	@if [ -z "$(BIN_INPUT)" ]; then \
		echo "KRAKEN_BINARISE_INPUT is required."; \
		exit 1; \
	fi
	@if [ ! -e "$(BIN_INPUT)" ]; then \
		echo "Input file does not exist: $(BIN_INPUT)"; \
		exit 1; \
	fi

binarise: check-binarise-input
	$(call RUN_KRAKEN,$(KRAKEN_VERBOSE_FLAGS) $(KRAKEN_ERROR_FLAGS) \
		-i "$(BIN_INPUT)" "$(BIN_OUT)" \
		binarize \
		--threshold "$(BIN_THRESHOLD)" \
		--zoom "$(BIN_ZOOM)" \
		--escale "$(BIN_ESCALE)" \
		--border "$(BIN_BORDER)" \
		--perc "$(BIN_PERC)" \
		--range "$(BIN_RANGE)" \
		--low "$(BIN_LOW)" \
		--high "$(BIN_HIGH)")

	@if [ ! -e "$(BIN_OUT)" ]; then \
		echo "Binarization failed, output file was not created: $(BIN_OUT)"; \
		exit 1; \
	fi
	@echo "Binarized image created: $(BIN_OUT)"

check-segment-input:
	@if [ -z "$(BIN_INPUT)" ]; then \
		echo "KRAKEN_SEGMENT_INPUT is required."; \
		exit 1; \
	fi
	@if [ ! -e "$(BIN_INPUT)" ]; then \
		echo "Input file does not exist: $(BIN_INPUT)"; \
		exit 1; \
	fi

segment: check-segment-input
	mkdir -p "$(SEG_OUT_DIR)"
	$(MAKE) run-kraken \
		CMD=bash \
		KRAKEN_ARGS="$(SEG_WRAPPER) $(SEG_INPUT) $(SEG_OUT_DIR) $(SEG_OUT_FORMATS) $(SEG_ARGS)"

seg-neural-baseline:
	$(MAKE) segment \
		SEG_OUT_DIR="$(OUTPUT_DIR)/baseline_segmentation" \
		SEG_ARGS="--baseline --text-direction $(SEG_TEXT_DIRECTION)"


seg-diff-html:
	python scripts/segmentation_diff/create_seg_diff.py \
		"$(SEG_BASELINE_DIR)" \
		"$(SEG_BOXES_DIR)" \
		"$(SEG_DIFF_HTML)"
	@echo "Open: $(SEG_DIFF_HTML)"

pages-build:
	mkdir -p "$(PAGES_DIR)"
	cp docs/index.html "$(PAGES_DIR)/index.html"
	cp docs/styles.css "$(PAGES_DIR)/styles.css"
	touch "$(PAGES_DIR)/.nojekyll"
	$(MAKE) seg-diff-html SEG_DIFF_HTML="$(PAGES_DIR)/segmentation-diff.html"
	@echo "Built GitHub Pages site in $(PAGES_DIR)"

pages-serve: pages-build
	python3 -m http.server --directory "$(PAGES_DIR)" 8000