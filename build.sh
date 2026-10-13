#!/usr/bin/env bash
# Build main.tex with pdflatex. Intermediate files go to build/, the PDF to the project root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="main"
OUTPUT="cse755"
BUILD_DIR="$ROOT/build"
UPLOAD=false

cd "$ROOT"

for arg in "$@"; do
    case "$arg" in
        -u)
            UPLOAD=true
            ;;
        *)
            echo "error: unknown argument: $arg" >&2
            echo "usage: $0 [-u]" >&2
            exit 1
            ;;
    esac
done

if ! command -v pdflatex >/dev/null 2>&1; then
    echo "error: pdflatex not found in PATH" >&2
    exit 1
fi

# build/lectures is needed if lectures are ever pulled in with \include (it writes per-file .aux)
mkdir -p "$BUILD_DIR/lectures"

# Two passes so the table of contents and cross-references resolve
for pass in 1 2; do
    echo "==> pdflatex pass $pass"
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error \
        -output-directory="$BUILD_DIR" "$MAIN.tex" >/dev/null || {
        echo "error: pdflatex failed, see $BUILD_DIR/$MAIN.log" >&2
        grep -E '^.+:[0-9]+:|^!' "$BUILD_DIR/$MAIN.log" | head -n 20 >&2 || true
        exit 1
    }
done

mv -f "$BUILD_DIR/$MAIN.pdf" "$ROOT/$OUTPUT.pdf"
echo "==> built $ROOT/$OUTPUT.pdf"

if [[ ! -f "$ROOT/$OUTPUT.pdf" ]]; then
    echo "error: expected PDF was not generated at $ROOT/$OUTPUT.pdf" >&2
    exit 1
fi

if [[ "$UPLOAD" == true ]]; then
    echo "==> uploading $ROOT/$OUTPUT.pdf"
    uv run upload.py
fi
