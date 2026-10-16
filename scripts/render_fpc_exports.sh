#!/usr/bin/env bash
set -euo pipefail
out=${1:?Pass the demo output directory}
pdftoppm -r 72 -png "$out/skia_demo.pdf" "$out/atlas"
pdftoppm -r 144 -png "$out/skia_demo.pdf" "$out/atlas-aa"
pdftoppm -r 72 -singlefile -png "$out/quickstart.pdf" "$out/quickstart-pdf"
pdftoppm -r 144 -singlefile -png "$out/quickstart.pdf" "$out/quickstart-aa"
for file in "$out"/*.svg; do
  rsvg-convert "$file" -o "${file%.svg}-preview.png"
done
