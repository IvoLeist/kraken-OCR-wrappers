## Run Kraken

The generic runner is:
```bash
make run-kraken
```

By default it runs:
```bash
kraken --help
```

You can pass Kraken arguments with `KRAKEN_ARGS`:
```bash
make run-kraken KRAKEN_ARGS="--version"
```

Run from the local `uv` environment:
```bash
make run-kraken RUN_METHOD=local USED_ENV=uv KRAKEN_ARGS="--version"
```

Run from a conda/mamba environment:

```bash
make run-kraken RUN_METHOD=local USED_ENV=conda KRAKEN_ARGS="--version"
```

Run through Docker by setting `RUN_METHOD` to `docker`
```bash
make run-kraken RUN_METHOD=docker KRAKEN_ARGS="--version"
```

Hint: all the below introduced make targets support the `RUN_METHOD` and `USED_ENV` variables.

## Run a different command

The runner uses the `CMD` variable.

By default:
```make
CMD ?= kraken
```

To run a Bash script instead of the `kraken` executable set `CMD` to `bash` and pass the script and its arguments through `KRAKEN_ARGS`:

```bash
make run-kraken \
  CMD=bash \
  KRAKEN_ARGS="scripts/kraken_segment_wrapper.sh output/input_bw.png alto,abbyy --boxes --text-direction horizontal-lr"
```

## Binarise an image

Run Kraken binarisation locally:

```bash
make binarise \
  BIN_INPUT=example_input/kraken_input.png \
  BIN_OUTPUT=output/input_bw.png
```

## Segment an image (into multiple output formats)

The `segment` target runs the segmentation wrapper script.

Example:

```bash
make segment \
  SEG_INPUT=output/input_bw.png \
  SEG_OUT_FORMATS=alto,abbyy \
  SEG_ARGS="--boxes --text-direction horizontal-lr"
```

## Supported segmentation output formats

The segmentation wrapper accepts a comma-separated list of output formats:

```text
hocr,alto,abbyy,pagexml,native
```

| Format    | Output type        | File extension |
| --------- | ------------------ | -------------- |
| `hocr`    | hOCR HTML          | `.html`        |
| `alto`    | ALTO XML           | `.xml`         |
| `abbyy`   | ABBYY XML          | `.xml`         |
| `pagexml` | PAGE XML           | `.xml`         |
| `native`  | Kraken native JSON | `.json`        |

Example:

```bash
make segment \
  SEG_INPUT=output/input_bw.png \
  SEG_OUT_FORMATS=hocr,alto,abbyy,pagexml,native \
  SEG_ARGS="--boxes --text-direction horizontal-lr"
```

This creates files such as:

```text
output/input_bw_hocr.html
output/input_bw_alto.xml
output/input_bw_abbyy.xml
output/input_bw_pagexml.xml
output/input_bw_native.json
```

## Segment with baseline segmentation

Use Kraken baseline segmentation by changing `SEG_ARGS`:

```bash
make seg \
  SEG_INPUT=output/input_bw.png \
  SEG_OUT_FORMATS=pagexml,native \
  SEG_ARGS="--baseline --text-direction horizontal-lr"
```
