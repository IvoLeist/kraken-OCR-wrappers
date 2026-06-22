#!/usr/bin/env python3

from __future__ import annotations

import argparse
import difflib
import html
from pathlib import Path


TEXT_EXTENSIONS = {".xml", ".json", ".html", ".htm", ".txt"}

FORMAT_ORDER = ["native", "alto", "abbyy", "pagexml", "hocr"]


def read_text(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def detect_format(path: Path) -> str:
    """
    Detect the output format from filenames such as:

        input_bw_native.json  -> native
        input_bw_alto.xml     -> alto
        input_bw_abbyy.xml    -> abbyy
        input_bw_pagexml.xml  -> pagexml
        input_bw_hocr.html    -> hocr
    """
    stem = path.stem

    for fmt in FORMAT_ORDER:
        if stem.endswith(f"_{fmt}"):
            return fmt

    return "other"


def load_template() -> tuple[str, str]:
    """
    Load seg_diff.html and seg_diff.css from the same directory as this script.
    """
    template_dir = Path(__file__).resolve().parent

    html_template_path = template_dir / "seg_diff.html"
    css_template_path = template_dir / "seg_diff.css"

    if not html_template_path.is_file():
        raise SystemExit(f"HTML template does not exist: {html_template_path}")

    if not css_template_path.is_file():
        raise SystemExit(f"CSS template does not exist: {css_template_path}")

    html_template = html_template_path.read_text(encoding="utf-8")
    css = css_template_path.read_text(encoding="utf-8")

    return html_template, css


def make_tab_button(fmt: str, active: bool) -> str:
    active_class = " active" if active else ""
    safe_fmt = html.escape(fmt)

    return (
        f'<button class="tab-button{active_class}" '
        f'onclick="openTab(event, \'{safe_fmt}\')">'
        f"{safe_fmt}"
        f"</button>"
    )


def make_file_diff_section(
    rel_path: Path,
    baseline_files: dict[Path, Path],
    boxes_files: dict[Path, Path],
    baseline_dir: Path,
    boxes_dir: Path,
    differ: difflib.HtmlDiff,
) -> str:
    left = baseline_files.get(rel_path)
    right = boxes_files.get(rel_path)

    safe_name = html.escape(str(rel_path))

    if left is None:
        return (
            f"<h2>{safe_name}</h2>\n"
            f"<p class='missing'>Only exists in boxes directory.</p>\n"
        )

    if right is None:
        return (
            f"<h2>{safe_name}</h2>\n"
            f"<p class='missing'>Only exists in baseline directory.</p>\n"
        )

    if rel_path.suffix.lower() not in TEXT_EXTENSIONS:
        return (
            f"<h2>{safe_name}</h2>\n"
            f"<p class='skipped'>Skipped non-text file.</p>\n"
        )

    left_lines = read_text(left)
    right_lines = read_text(right)

    if left_lines == right_lines:
        return (
            f"<h2>{safe_name}</h2>\n"
            f"<p class='same'>No differences.</p>\n"
        )

    table = differ.make_table(
        left_lines,
        right_lines,
        fromdesc=html.escape(str(baseline_dir / rel_path)),
        todesc=html.escape(str(boxes_dir / rel_path)),
        context=True,
        numlines=3,
    )

    return f"<h2>{safe_name}</h2>\n{table}\n"


def make_tab_panel(
    fmt: str,
    rel_paths: list[Path],
    active: bool,
    baseline_files: dict[Path, Path],
    boxes_files: dict[Path, Path],
    baseline_dir: Path,
    boxes_dir: Path,
    differ: difflib.HtmlDiff,
) -> str:
    safe_fmt = html.escape(fmt)
    panel_style = "display: block;" if active else "display: none;"

    sections = [
        make_file_diff_section(
            rel_path=rel_path,
            baseline_files=baseline_files,
            boxes_files=boxes_files,
            baseline_dir=baseline_dir,
            boxes_dir=boxes_dir,
            differ=differ,
        )
        for rel_path in rel_paths
    ]

    return f"""
<section id="{safe_fmt}" class="tab-panel" style="{panel_style}">
<h1>{safe_fmt}</h1>
{''.join(sections)}
</section>
"""


def collect_files(directory: Path) -> dict[Path, Path]:
    return {
        path.relative_to(directory): path
        for path in directory.rglob("*")
        if path.is_file()
    }


def build_report(
    baseline_dir: Path,
    boxes_dir: Path,
    output_html: Path,
) -> None:
    if not baseline_dir.is_dir():
        raise SystemExit(f"Baseline directory does not exist: {baseline_dir}")

    if not boxes_dir.is_dir():
        raise SystemExit(f"Boxes directory does not exist: {boxes_dir}")

    baseline_files = collect_files(baseline_dir)
    boxes_files = collect_files(boxes_dir)

    all_relative_paths = sorted(set(baseline_files) | set(boxes_files))

    if not all_relative_paths:
        raise SystemExit(
            f"No files found in either directory: {baseline_dir}, {boxes_dir}"
        )

    grouped_paths: dict[str, list[Path]] = {}

    for rel_path in all_relative_paths:
        fmt = detect_format(rel_path)
        grouped_paths.setdefault(fmt, []).append(rel_path)

    format_names = [fmt for fmt in FORMAT_ORDER if fmt in grouped_paths]

    if "other" in grouped_paths:
        format_names.append("other")

    differ = difflib.HtmlDiff(tabsize=4, wrapcolumn=120)

    tab_buttons: list[str] = []
    tab_panels: list[str] = []

    for index, fmt in enumerate(format_names):
        active = index == 0

        tab_buttons.append(make_tab_button(fmt, active))
        tab_panels.append(
            make_tab_panel(
                fmt=fmt,
                rel_paths=grouped_paths[fmt],
                active=active,
                baseline_files=baseline_files,
                boxes_files=boxes_files,
                baseline_dir=baseline_dir,
                boxes_dir=boxes_dir,
                differ=differ,
            )
        )

    html_template, css = load_template()

    page = (
        html_template
        .replace("{{ CSS }}", css)
        .replace("{{ BASELINE_DIR }}", html.escape(str(baseline_dir)))
        .replace("{{ BOXES_DIR }}", html.escape(str(boxes_dir)))
        .replace("{{ TAB_BUTTONS }}", "\n".join(tab_buttons))
        .replace("{{ TAB_PANELS }}", "\n".join(tab_panels))
    )

    output_html.parent.mkdir(parents=True, exist_ok=True)
    output_html.write_text(page, encoding="utf-8")

    print(f"Wrote HTML diff report to: {output_html}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Create a tabbed HTML side-by-side diff report for two Kraken "
            "segmentation output folders."
        )
    )

    parser.add_argument(
        "baseline_dir",
        type=Path,
        help="Directory containing baseline segmentation outputs.",
    )

    parser.add_argument(
        "boxes_dir",
        type=Path,
        help="Directory containing boxes segmentation outputs.",
    )

    parser.add_argument(
        "output_html",
        type=Path,
        help="Output HTML report path.",
    )

    args = parser.parse_args()

    build_report(
        baseline_dir=args.baseline_dir,
        boxes_dir=args.boxes_dir,
        output_html=args.output_html,
    )


if __name__ == "__main__":
    main()