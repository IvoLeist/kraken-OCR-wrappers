# %%
from __future__ import annotations

from pathlib import Path
from urllib.request import urlretrieve
import shlex
import subprocess
import sys


try:
    import google.colab  # type: ignore

    IN_COLAB = True
except ImportError:
    IN_COLAB = False


print("Running in Google Colab:", IN_COLAB)

# %%
# Project root detection


def find_project_root(start: Path) -> Path:
    """
    Try to find the project root by walking upward.

    Expected project structure contains:
      scripts/
      output/           optional
      notebooks/        optional
    """
    start = start.resolve()

    for candidate in [start, *start.parents]:
        if (candidate / "scripts").is_dir():
            return candidate

    # Fallback:
    # - if running from notebooks/, use parent
    # - otherwise use cwd
    if start.name == "notebooks":
        return start.parent

    return start


PROJECT_ROOT = find_project_root(Path.cwd())

print("PROJECT_ROOT:", PROJECT_ROOT)

# %%
# Configuration

OUTPUT_DIR = PROJECT_ROOT / "output"
INPUT_DIR = PROJECT_ROOT / "example_input"

KRAKEN_VERSION = "7.0.2"
KRAKEN_ENV_NAME = "kraken-ocr"
KRAKEN_VENV = PROJECT_ROOT / f".venv-{KRAKEN_ENV_NAME}"

# Kraken example data source.
KRAKEN_REPO_URL = "https://raw.githubusercontent.com/mittagessen/kraken/refs/heads/"
BRANCH = "main"
RESOURCE_PATH = "tests/resources"

FULL_URL = f"{KRAKEN_REPO_URL}{BRANCH}/{RESOURCE_PATH}/"

BINARISE_EXAMPLE_IMAGE_URL = f"{FULL_URL}input.jpg"
SEGMENT_EXAMPLE_IMAGE_URL = f"{FULL_URL}input_bw.png"

BINARISE_EXAMPLE_IMAGE = INPUT_DIR / "input.jpg"
SEGMENT_EXAMPLE_IMAGE = INPUT_DIR / "input_bw.png"

# Segmentation input.
# This is automatically downloaded by ensure_example_data() if missing.
SEG_INPUT = SEGMENT_EXAMPLE_IMAGE

# Adjust this if your wrapper has a different name.
SEG_WRAPPER = PROJECT_ROOT / "scripts" / "kraken_segment_wrapper.sh"

# Your folder was previously named "segmentation_diff".
# Change this path if you rename it.
SEG_DIFF_SCRIPT = (
    PROJECT_ROOT
    / "scripts"
    / "segmentation_diff"
    / "create_seg_diff.py"
)

SEG_OUT_FORMATS = "native,alto,abbyy,pagexml,hocr"
SEG_TEXT_DIRECTION = "horizontal-lr"

SEG_BASELINE_DIR = OUTPUT_DIR / "baseline_segmentation"
SEG_BOXES_DIR = OUTPUT_DIR / "boxes_segmentation"
SEG_DIFF_HTML = OUTPUT_DIR / "segmentation_diff.html"

print("KRAKEN_VENV:", KRAKEN_VENV)
print("SEG_WRAPPER:", SEG_WRAPPER)
print("SEG_DIFF_SCRIPT:", SEG_DIFF_SCRIPT)
print("SEG_INPUT:", SEG_INPUT)
print("BINARISE_EXAMPLE_IMAGE_URL:", BINARISE_EXAMPLE_IMAGE_URL)
print("SEGMENT_EXAMPLE_IMAGE_URL:", SEGMENT_EXAMPLE_IMAGE_URL)

# %%
# Command helpers


def run_command(cmd: list[str], *, cwd: Path | None = None) -> None:
    """Run a command and print it first."""
    print("+", " ".join(shlex.quote(str(part)) for part in cmd))
    subprocess.run(cmd, check=True, cwd=cwd)


def command_exists(command: str) -> bool:
    result = subprocess.run(
        ["bash", "-lc", f"command -v {shlex.quote(command)} >/dev/null 2>&1"],
        check=False,
    )
    return result.returncode == 0


# %%
# Example data helpers


def download_if_missing(url: str, output_path: Path) -> Path:
	
    """
    Download a file only if it does not already exist.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if output_path.exists():
        print(f"Already exists: {output_path}")
        return output_path

    print(f"Downloading {url}")
    print(f"Saving to {output_path}")
    urlretrieve(url, output_path)

    return output_path


def ensure_example_data() -> None:
    """
    Download Kraken example input data if it is not already present.

    This creates:
      output/input.jpg
      output/input_bw.png
    """
    download_if_missing(
        BINARISE_EXAMPLE_IMAGE_URL,
        BINARISE_EXAMPLE_IMAGE,
    )

    download_if_missing(
        SEGMENT_EXAMPLE_IMAGE_URL,
        SEGMENT_EXAMPLE_IMAGE,
    )


# %%
# Kraken runtime helpers


def check_local_uv_kraken_env() -> None:
    """
    Local mode:
    Check that .venv-kraken-ocr exists and contains kraken.
    """
    kraken_bin = KRAKEN_VENV / "bin" / "kraken"

    if not KRAKEN_VENV.exists():
        raise FileNotFoundError(
            f"uv environment does not exist: {KRAKEN_VENV}\n"
            "Create it first from the project root with:\n"
            "  make local-kraken-install"
        )

    if not kraken_bin.exists():
        raise FileNotFoundError(
            f"Kraken executable does not exist: {kraken_bin}\n"
            "Check that Kraken was installed into the uv environment."
        )


def ensure_colab_kraken_installed() -> None:
    """
    Colab mode:
    Install Kraken into the current Colab runtime if it is not already available.

    This is safe to re-run. If kraken is already on PATH, it does nothing.
    """
    if not IN_COLAB:
        return

    if command_exists("kraken"):
        run_command(["kraken", "--version"])
        print("Kraken already available in Colab.")
        return

    print("Installing Kraken in Colab...")

    run_command(["apt-get", "update", "-qq"])
    run_command(["apt-get", "install", "-y", "-qq", "libvips42"])

    run_command([sys.executable, "-m", "pip", "install", "-q", "uv"])
    run_command(["uv", "pip", "install", "--system", f"kraken[pdf]=={KRAKEN_VERSION}"])

    run_command(["kraken", "--version"])


def run_kraken_command(cmd: str, args: list[str] | None = None) -> None:
    """
    Unified runner.

    Local VS Code / Jupyter:
      - uses .venv-kraken-ocr

    Google Colab:
      - uses kraken installed into the Colab runtime
    """
    if args is None:
        args = []

    if IN_COLAB:
        ensure_colab_kraken_installed()
        run_command([cmd, *map(str, args)])
        return

    check_local_uv_kraken_env()

    if cmd == "bash":
        # bash itself is outside the venv, but prepend the venv's bin dir
        # so the wrapper can call `kraken`.
        env_path = str((KRAKEN_VENV / "bin").resolve())

        run_command(
            [
                "bash",
                "-lc",
                f'export PATH="{env_path}:$PATH"; bash "$@"',
                "bash",
                *map(str, args),
            ]
        )
    else:
        executable = KRAKEN_VENV / "bin" / cmd
        run_command([str(executable), *map(str, args)])


# %%
# Diagnostics


def show_config() -> None:
    print("IN_COLAB:               ", IN_COLAB)
    print("PROJECT_ROOT:           ", PROJECT_ROOT)
    print("OUTPUT_DIR:             ", OUTPUT_DIR)
    print("KRAKEN_VENV:            ", KRAKEN_VENV)
    print("SEG_WRAPPER:            ", SEG_WRAPPER)
    print("SEG_DIFF_SCRIPT:        ", SEG_DIFF_SCRIPT)
    print("SEG_INPUT:              ", SEG_INPUT)
    print("SEG_BASELINE_DIR:       ", SEG_BASELINE_DIR)
    print("SEG_BOXES_DIR:          ", SEG_BOXES_DIR)
    print("SEG_DIFF_HTML:          ", SEG_DIFF_HTML)
    print()
    print("SEG_WRAPPER exists:     ", SEG_WRAPPER.exists())
    print("SEG_DIFF_SCRIPT exists: ", SEG_DIFF_SCRIPT.exists())
    print("SEG_INPUT exists:       ", SEG_INPUT.exists())
    print("input.jpg exists:       ", BINARISE_EXAMPLE_IMAGE.exists())
    print("input_bw.png exists:    ", SEGMENT_EXAMPLE_IMAGE.exists())


show_config()

# %%
# Prepare example data if needed

ensure_example_data()

# %%
# Check configuration again after example-data download

show_config()

# %%
# Optional: check Kraken version

run_kraken_command("kraken", ["--version"])

# %%
# Segmentation functions


def check_segment_input(seg_input: Path) -> None:
    if not seg_input.exists():
        raise FileNotFoundError(f"Input image does not exist: {seg_input}")


def check_segmentation_scripts() -> None:
    if not SEG_WRAPPER.exists():
        raise FileNotFoundError(f"Segmentation wrapper does not exist: {SEG_WRAPPER}")

    if not SEG_DIFF_SCRIPT.exists():
        raise FileNotFoundError(f"Segmentation diff script does not exist: {SEG_DIFF_SCRIPT}")


def segment(
    *,
    seg_input: Path = SEG_INPUT,
    seg_out_dir: Path = SEG_BOXES_DIR,
    seg_out_formats: str = SEG_OUT_FORMATS,
    seg_args: list[str] | None = None,
) -> None:
    """
    Run the Kraken segmentation wrapper.

    Equivalent Makefile logic:

        segment:
            mkdir -p "$(SEG_OUT_DIR)"
            make run-kraken \
                CMD=bash \
                KRAKEN_ARGS="$(SEG_WRAPPER) $(SEG_INPUT) $(SEG_OUT_DIR) $(SEG_OUT_FORMATS) $(SEG_ARGS)"
    """
    if seg_args is None:
        seg_args = ["--boxes", "--text-direction", SEG_TEXT_DIRECTION]

    check_segment_input(seg_input)
    check_segmentation_scripts()

    seg_out_dir.mkdir(parents=True, exist_ok=True)

    print(
        "Running Kraken segmentation wrapper with arguments:",
        seg_input,
        seg_out_dir,
        seg_out_formats,
        " ".join(seg_args),
    )

    run_kraken_command(
        "bash",
        [
            str(SEG_WRAPPER),
            str(seg_input),
            str(seg_out_dir),
            seg_out_formats,
            *seg_args,
        ],
    )


def seg_boxes(
    *,
    seg_input: Path = SEG_INPUT,
    seg_out_dir: Path = SEG_BOXES_DIR,
    seg_out_formats: str = SEG_OUT_FORMATS,
) -> None:
    """Run Kraken box segmentation."""
    segment(
        seg_input=seg_input,
        seg_out_dir=seg_out_dir,
        seg_out_formats=seg_out_formats,
        seg_args=["--boxes", "--text-direction", SEG_TEXT_DIRECTION],
    )


def seg_neural_baseline(
    *,
    seg_input: Path = SEG_INPUT,
    seg_out_dir: Path = SEG_BASELINE_DIR,
    seg_out_formats: str = SEG_OUT_FORMATS,
) -> None:
    """
    Run Kraken neural baseline segmentation.

    Equivalent Makefile logic:

        seg-neural-baseline:
            make segment \
                SEG_OUT_DIR="$(OUTPUT_DIR)/baseline_segmentation" \
                SEG_ARGS="--baseline --text-direction $(SEG_TEXT_DIRECTION)"
    """
    segment(
        seg_input=seg_input,
        seg_out_dir=seg_out_dir,
        seg_out_formats=seg_out_formats,
        seg_args=["--baseline", "--text-direction", SEG_TEXT_DIRECTION],
    )


# %%
# HTML diff function


def seg_diff_html(
    *,
    baseline_dir: Path = SEG_BASELINE_DIR,
    boxes_dir: Path = SEG_BOXES_DIR,
    output_html: Path = SEG_DIFF_HTML,
) -> Path:
    """
    Create the tabbed side-by-side HTML diff report.

    Equivalent Makefile logic:

        seg-diff-html:
            python scripts/segmentation_diff/create_seg_diff.py \
                "$(SEG_BASELINE_DIR)" \
                "$(SEG_BOXES_DIR)" \
                "$(SEG_DIFF_HTML)"
    """
    check_segmentation_scripts()

    output_html.parent.mkdir(parents=True, exist_ok=True)

    run_command(
        [
            sys.executable,
            str(SEG_DIFF_SCRIPT),
            str(baseline_dir),
            str(boxes_dir),
            str(output_html),
        ]
    )

    print(f"Open: {output_html}")
    return output_html


# %%
# Display helpers


def show_seg_diff_html(path: Path = SEG_DIFF_HTML, *, height: int = 800) -> None:
    """
    Show the generated HTML report.

    Local VS Code / Jupyter:
      - uses IFrame

    Google Colab:
      - embeds the HTML directly
    """
    if not path.exists():
        raise FileNotFoundError(f"HTML diff report does not exist: {path}")

    if IN_COLAB:
        from IPython.display import HTML, display

        display(HTML(filename=str(path)))
    else:
        from IPython.display import IFrame, display

        display(IFrame(str(path), width="100%", height=height))


def download_seg_diff_html(path: Path = SEG_DIFF_HTML) -> None:
    """
    Download the generated HTML report in Google Colab.
    """
    if not IN_COLAB:
        print("download_seg_diff_html() is only needed in Google Colab.")
        return

    if not path.exists():
        raise FileNotFoundError(f"HTML diff report does not exist: {path}")

    from google.colab import files  # type: ignore

    files.download(str(path))


# %%
# Run box segmentation

seg_boxes(
    seg_input=SEG_INPUT,
    seg_out_dir=SEG_BOXES_DIR,
    seg_out_formats=SEG_OUT_FORMATS,
)

# %%
# Run neural baseline segmentation

seg_neural_baseline(
    seg_input=SEG_INPUT,
    seg_out_dir=SEG_BASELINE_DIR,
    seg_out_formats=SEG_OUT_FORMATS,
)

# %%
# Create HTML diff report

seg_diff_html()

# %%
# Render HTML diff report

show_seg_diff_html()

# %%
# Optional Colab-only download

# download_seg_diff_html()