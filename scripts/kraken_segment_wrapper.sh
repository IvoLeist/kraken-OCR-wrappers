#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 INPUT_IMAGE [OUT_FORMATS] [segment options...]"
    echo "Example: $0 output/input_bw.png alto,abbyy --boxes --text-direction horizontal-lr"
    echo ""
    echo "Supported output formats:"
    echo "  hocr    -> HTML"
    echo "  alto    -> XML"
    echo "  abbyy   -> XML"
    echo "  pagexml -> XML"
    echo "  native  -> JSON"
    exit 1
fi

input="$1"
shift

if [[ ! -f "$input" ]]; then
    echo "Input image does not exist: $input"
    exit 1
fi

# Default output formats.
out_formats="native,alto,abbyy,pagexml,hocr"

# If the next argument does not look like an option, treat it as the format list.
if [[ $# -gt 0 && "$1" != -* ]]; then
    out_formats="$1"
    shift
fi

# Default segment options.
if [[ $# -eq 0 ]]; then
    segment_args=(--boxes --text-direction horizontal-lr)
else
    segment_args=("$@")
fi

IFS=',' read -r -a formats <<< "$out_formats"

basename="${input%.*}"

for format in "${formats[@]}"; do
    # Trim possible whitespace around comma-separated values.
    format="$(echo "$format" | xargs)"

    case "$format" in
        hocr)
            flag="-h"
            extension="html"
            output_format_name="hocr"
            ;;
        alto)
            flag="-a"
            extension="xml"
            output_format_name="alto"
            ;;
        abbyy)
            flag="-y"
            extension="xml"
            output_format_name="abbyy"
            ;;
        pagexml)
            flag="-x"
            extension="xml"
            output_format_name="pagexml"
            ;;
        native)
            flag=""
            extension="json"
            output_format_name="native"
            ;;
        *)
            echo "Unsupported output format: $format"
            echo "Supported formats: hocr, alto, abbyy, pagexml, native"
            exit 1
            ;;
    esac

    output="${basename}_${output_format_name}.${extension}"

    echo "Creating ${output}..."

    if [[ -n "$flag" ]]; then
        kraken \
            "$flag" \
            -i "$input" "$output" \
            segment "${segment_args[@]}"
    else
        kraken \
            -i "$input" "$output" \
            segment "${segment_args[@]}"
    fi
done

echo "Done."