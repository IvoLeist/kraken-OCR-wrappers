# %%
from pathlib import Path
import subprocess
import shlex
from IPython.display import IFrame, display

# %%
# Project paths

PROJECT_ROOT = Path.cwd()

if PROJECT_ROOT.name == "notebooks":
    PROJECT_ROOT = PROJECT_ROOT.parent

OUTPUT_DIR = PROJECT_ROOT / "output"

KRAKEN_ENV_NAME = "kraken-ocr"
KRAKEN_VENV = PROJECT_ROOT / f".venv-{KRAKEN_ENV_NAME}"

SEG_WRAPPER = PROJECT_ROOT / "scripts/kraken_segment_wrapper.sh"
SEG_DIFF_SCRIPT = PROJECT_ROOT / "scripts/segmentation_diff/create_seg_diff.py"

SEG_INPUT = OUTPUT_DIR / "input_bw.png"

SEG_OUT_FORMATS = "native,alto,abbyy,pagexml,hocr"
SEG_TEXT_DIRECTION = "horizontal-lr"

SEG_BASELINE_DIR = OUTPUT_DIR / "baseline_segmentation"
SEG_BOXES_DIR = OUTPUT_DIR / "boxes_segmentation"
SEG_DIFF_HTML = OUTPUT_DIR / "segmentation_diff.html"

# %%
def run_command(cmd: list[str], *, cwd: Path | None = None) -> None:
    """Run a shell command and print it first."""
    print("+", " ".join(shlex.quote(str(part)) for part in cmd))
    subprocess.run(cmd, check=True, cwd=cwd)


def check_uv_kraken_env() -> None:
    """Check that the uv environment and Kraken executable exist."""
    kraken_bin = KRAKEN_VENV / "bin" / "kraken"

    if not KRAKEN_VENV.exists():
        raise FileNotFoundError(
            f"uv environment does not exist: {KRAKEN_VENV}\n"
            "Create it first with:\n"
            "  make local-kraken-install"
        )

    if not kraken_bin.exists():
        raise FileNotFoundError(
            f"Kraken executable does not exist: {kraken_bin}\n"
            "Check that Kraken was installed into the uv environment."
        )


def run_in_uv_env(cmd: str, args: list[str] | None = None) -> None:
    """
    Run a command using the local uv environment.

    Only uv is supported in this notebook.
    """
    if args is None:
        args = []

    check_uv_kraken_env()

    if cmd == "bash":
        # bash itself is outside the venv, but we prepend the venv bin dir
        # so the wrapper can call `kraken`.
        env_path = str((KRAKEN_VENV / "bin").resolve())

        run_command([
            "bash",
            "-lc",
            f'export PATH="{env_path}:$PATH"; bash "$@"',
            "bash",
            *map(str, args),
        ])
    else:
        executable = KRAKEN_VENV / "bin" / cmd
        run_command([str(executable), *map(str, args)])

# %%
def check_segment_input(seg_input: Path) -> None:
    if not seg_input.exists():
        raise FileNotFoundError(f"Input image does not exist: {seg_input}")


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
            make run-kraken CMD=bash KRAKEN_ARGS="..."
    """
    if seg_args is None:
        seg_args = ["--boxes", "--text-direction", SEG_TEXT_DIRECTION]

    check_segment_input(seg_input)
    seg_out_dir.mkdir(parents=True, exist_ok=True)

    print(
        "Running Kraken segmentation wrapper with arguments:",
        seg_input,
        seg_out_dir,
        seg_out_formats,
        " ".join(seg_args),
    )

    run_in_uv_env(
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
    """Run legacy/box segmentation."""
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
    Run neural baseline segmentation.

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
def seg_diff_html(
    *,
    baseline_dir: Path = SEG_BASELINE_DIR,
    boxes_dir: Path = SEG_BOXES_DIR,
    output_html: Path = SEG_DIFF_HTML,
) -> Path:
    """
    Create the tabbed HTML side-by-side diff report.

    Equivalent Makefile logic:

        seg-diff-html:
            python scripts/segmentation_diff/create_seg_diff.py \
                "$(SEG_BASELINE_DIR)" \
                "$(SEG_BOXES_DIR)" \
                "$(SEG_DIFF_HTML)"
    """
    output_html.parent.mkdir(parents=True, exist_ok=True)

    run_command([
        "python",
        str(SEG_DIFF_SCRIPT),
        str(baseline_dir),
        str(boxes_dir),
        str(output_html),
    ])

    print(f"Open: {output_html}")
    return output_html


def show_seg_diff_html(path: Path = SEG_DIFF_HTML, *, height: int = 800) -> None:
    """Render the generated HTML report inside VS Code/Jupyter."""
    display(IFrame(str(path), width="100%", height=height))

# %%
# Check the current configuration

print("Kraken venv:        ", KRAKEN_VENV)
print("Segmentation input: ", SEG_INPUT)
print("Boxes output dir:   ", SEG_BOXES_DIR)
print("Baseline output dir:", SEG_BASELINE_DIR)
print("Diff HTML:          ", SEG_DIFF_HTML)

# %%
# Optional: check Kraken version

run_in_uv_env("kraken", ["--version"])

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
# Render HTML diff report in VS Code

show_seg_diff_html()