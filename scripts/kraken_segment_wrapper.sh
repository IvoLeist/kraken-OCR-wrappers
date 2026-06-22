#!/usr/bin/env bash
set -euo pipefail

echo "Running Kraken segmentation wrapper with arguments: $*"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 INPUT_IMAGE [segment options...]"
    echo "Example: $0 input_bw.png -x"
    exit 1
fi

input="$1"
shift

basename="${input%.*}"

# Default segment options if none were provided
if [[ $# -eq 0 ]]; then
    segment_args=(--native)
else
    segment_args=("$@")
fi

declare -A formats=(
  [alto]="-a"
  [abbyy]="-y"
)

for format in "${!formats[@]}"; do
    flag="${formats[$format]}"
    output="${basename}_${format}.xml"

    echo "Creating ${output}..."

    kraken \
        "$flag" \
        -i "$input" "$output" \
        segment "${segment_args[@]}"
done

echo "Done."