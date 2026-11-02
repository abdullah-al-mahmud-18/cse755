#!/usr/bin/env bash
# Build a single .tex file with pdflatex and move the PDF to an output directory.
# Intermediate files go to a temp directory, deleted on success and kept on failure so the log can be read.
# Usage: ./build_file.sh <file>[.tex] <output-dir>
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <file>[.tex] <output-dir>" >&2
    exit 1
fi

TEX_FILE="${1%.tex}.tex"
OUTPUT_DIR="$2"

if ! command -v pdflatex >/dev/null 2>&1; then
    echo "error: pdflatex not found in PATH" >&2
    exit 1
fi

if [[ ! -f "$TEX_FILE" ]]; then
    echo "error: $TEX_FILE not found" >&2
    exit 1
fi

MAIN="$(basename "$TEX_FILE" .tex)"
TEX_DIR="$(dirname "$TEX_FILE")"
BUILD_DIR="$(mktemp -d)"

# Two passes so cross-references resolve. Run from the file's directory so its relative \input paths work.
for pass in 1 2; do
    echo "==> pdflatex pass $pass"
    (cd "$TEX_DIR" && pdflatex -interaction=nonstopmode -halt-on-error -file-line-error \
        -output-directory="$BUILD_DIR" "$MAIN.tex" >/dev/null) || {
        echo "error: pdflatex failed, see $BUILD_DIR/$MAIN.log" >&2
        grep -E '^.+:[0-9]+:|^!' "$BUILD_DIR/$MAIN.log" | head -n 20 >&2 || true
        exit 1
    }
done

if [[ ! -f "$BUILD_DIR/$MAIN.pdf" ]]; then
    echo "error: expected PDF was not generated at $BUILD_DIR/$MAIN.pdf" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mv -f "$BUILD_DIR/$MAIN.pdf" "$OUTPUT_DIR/$MAIN.pdf"
rm -rf "$BUILD_DIR"
echo "==> built $OUTPUT_DIR/$MAIN.pdf"
