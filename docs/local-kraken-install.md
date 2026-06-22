# Local Kraken OCR Installation

This Makefile provides a local installation workflow for [Kraken OCR](https://kraken.re) on Linux and macOS.

It supports two installation methods:

* `uv` — default on Linux and macOS
* `conda` / `mamba` — optional on supported systems

Native Windows is not supported. Use Linux, WSL2, Docker, or a remote Linux environment instead.

## Supported platforms

| Platform                  | Default method | Conda/mamba supported |
| ------------------------- | -------------: | --------------------: |
| Linux x86_64              |           `uv` |                   Yes |
| macOS Intel x86_64        |           `uv` |                   Yes |
| macOS ARM / Apple Silicon |           `uv` |                    No |
| Native Windows            |  Not supported |                    No |

Conda/mamba installation is not supported on macOS ARM / Apple Silicon because the `kraken-ocr` conda package does not yet support macOS ARM.

## Requirements

For the default installation method, install `uv` first:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

For optional conda/mamba installation, install either `mamba` or `conda`.

The Makefile prefers `mamba` if available and falls back to `conda`.

## Show installation information

Before installing, check what the Makefile detects:

```bash
make local-kraken-info
```

Example output on macOS ARM:

```text
Detected OS:              Darwin
Detected arch:            arm64
Requested install method: auto
Resolved install method:  uv
uv bin:                   /opt/homebrew/bin/uv
Kraken env name:          kraken-ocr
Python version:           3.12
Conda/mamba supported:    no
Reason:                   the kraken-ocr conda package does not yet support macOS ARM / Apple Silicon
```

Example output on Linux:

```text
Detected OS:              Linux
Detected arch:            x86_64
Requested install method: auto
Resolved install method:  uv
uv bin:                   /home/user/.local/bin/uv
Kraken env name:          kraken-ocr
Python version:           3.12
Conda/mamba supported:    yes
Conda-compatible bin:     /home/user/.local/bin/mamba
Channels:                 -c conda-forge
```

## Install Kraken OCR

Default installation:

```bash
make local-kraken-install
```

By default, this uses `uv` on Linux and macOS.

It creates a local virtual environment:

```text
.venv-kraken-ocr/
```

and installs Kraken with PDF support.

## Test the installation

After installation, run:

```bash
make local-kraken-test
```

This should print the installed Kraken version:

```text
kraken, version ...
```

## Remove the installation

For the default `uv` installation:

```bash
make local-kraken-remove
```

This removes the local virtual environment:

```text
.venv-kraken-ocr/
```

## Choose the installation method manually

The installation method can be selected with `KRAKEN_INSTALL_METHOD`.

Available values:

| Method  | Description                                                      |
| ------- | ---------------------------------------------------------------- |
| `auto`  | Default. Uses `uv` on Linux and macOS.                           |
| `uv`    | Creates a local `.venv-*` environment with `uv`.                 |
| `conda` | Installs `kraken-ocr` from conda-forge using `mamba` or `conda`. |

Use the default method:

```bash
make local-kraken-install
```

Force `uv`:

```bash
make local-kraken-install KRAKEN_INSTALL_METHOD=uv
```

Force conda/mamba:

```bash
make local-kraken-install KRAKEN_INSTALL_METHOD=conda
```

Conda/mamba installation is only supported on Linux and macOS Intel.

## Change the environment name

The default environment name is:

```text
kraken-ocr
```

For `uv`, this creates:

```text
.venv-kraken-ocr/
```

For conda/mamba, this creates a conda environment named:

```text
kraken-ocr
```

Override it with:

```bash
make local-kraken-install KRAKEN_ENV_NAME=test-kraken
```

For `uv`, this creates:

```text
.venv-test-kraken/
```

## Change the Python version

The default Python version is:

```text
3.12
```

Override it with:

```bash
make local-kraken-install KRAKEN_PYTHON_VERSION=3.13
```

## Use conda instead of mamba

The Makefile automatically prefers `mamba` if available.

To force `conda`:

```bash
make local-kraken-install KRAKEN_INSTALL_METHOD=conda CONDA_BIN=conda
```

To force a specific binary path:

```bash
make local-kraken-install KRAKEN_INSTALL_METHOD=conda CONDA_BIN=/opt/homebrew/bin/conda
```

## Manual activation

For the default `uv` installation:

```bash
source .venv-kraken-ocr/bin/activate
kraken --version
```

For conda/mamba installation:

```bash
conda activate kraken-ocr
kraken --version
```

or without activating:

```bash
mamba run -n kraken-ocr kraken --version
```

## Notes

Plain system `pip install` is intentionally not supported.

The recommended default is `uv`, because it creates an isolated local virtual environment and avoids modifying the system Python installation.

The conda/mamba method is available as an optional alternative on platforms where the `kraken-ocr` conda package is supported.
