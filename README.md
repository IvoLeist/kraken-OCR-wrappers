# kraken-OCR-wrappers

Lightweight wrapper scripts, notebooks and helpers for running Kraken OCR and producing segmentation comparison output.

## Overview

This repository collects tools to run Kraken OCR models, convert between common layout/segmentation formats, and produce segmentation-diff views for inspection. It contains shell wrappers, Python helper scripts, example inputs, and notebooks optimized for local and Colab usage.

## Features

- Wrapper to run Kraken segmentation and recognition pipelines
- Scripts to generate side-by-side segmentation diffs (HTML)
- Example inputs and baseline outputs for testing
- Dockerfile for reproducible environments
- Notebooks demonstrating segmentation diff workflows

## Repository layout

- `docker/` — Dockerfile for a Kraken environment
- `notebooks/` — Jupyter notebooks and conversion scripts for Colab/local
- `scripts/` — Shell and Python scripts for running Kraken and producing diffs
- `models/` — Notes and model storage guidelines
- `example_input/` — Sample inputs for quick testing
- `output/` — Example generated outputs and HTML diff

## Requirements

- Python 3.10+ (recommended)
- Kraken OCR (see installation sections)
- Optional: Docker for containerized runs

## Installation (local, virtualenv)

1. Create and activate a virtual environment:

```
python3 -m venv .venv-kraken-ocr
source .venv-kraken-ocr/bin/activate
```

2. Install dependencies (project provides Make targets used by the notebooks):

```
make install-venv
```

Note: the above target sets up the Python environment used by the notebooks. See `make/` for other make targets including Docker and Colab helpers.

## Docker

To build a reproducible image using the provided Dockerfile:

```
docker build -f docker/kraken.Dockerfile -t kraken-ocr:local .
```

Run a container interactively if needed:

```
docker run --rm -it -v "$PWD":/workspace kraken-ocr:local /bin/bash
```

## Quick usage

- Run the main segmentation wrapper:

```
bash scripts/kraken_segment_wrapper.sh path/to/image.png --model path/to/model.mlmodel
```

- Create a segmentation diff HTML from two segmentation outputs (example):

```
python3 scripts/segmentation_diff/create_seg_diff.py output/baseline_segmentation/input_bw_native.json output/boxes_segmentation/input_bw_native.json -o output/segmentation_diff.html
```

## Notebooks

Interactive examples live in `notebooks/`. To convert Colab scripts to notebooks and install kernel support, use the provided Makefile in `notebooks/`:

```
cd notebooks
make install-kernel-support
make convert-colab-script-to-notebook
```

## GitHub Pages

The repository includes a GitHub Pages workflow that publishes a Zensical-inspired docs shell and renders the sample segmentation diff during the build.

To preview the same site locally:

```bash
make pages-build
python3 -m http.server --directory build/pages 8000
```

The published landing page is the docs-style index, and the main content frame loads the generated `segmentation-diff.html` report.

## Examples and outputs

Example inputs are in `example_input/`. Generated example outputs and a pre-built segmentation diff HTML are in `output/` for quick review.

## License

This project is licensed under the MIT License. See LICENSE for details.