#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ART="$ROOT_DIR/assets/icon-source/ScreenTurn-original-art.png"
RENDERER="$ROOT_DIR/scripts/render-icon.swift"
OUTPUT_ICNS="$ROOT_DIR/assets/ScreenTurn.icns"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/screenturn-icon.XXXXXX")"
ICONSET_DIR="$WORK_DIR/ScreenTurn.iconset"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_ART" ]]; then
  echo "Icon source not found: $SOURCE_ART" >&2
  exit 1
fi

if [[ ! -f "$RENDERER" ]]; then
  echo "Icon renderer not found: $RENDERER" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"
MASTER_PNG="$WORK_DIR/ScreenTurn.png"
swift "$RENDERER" "$SOURCE_ART" "$MASTER_PNG"

render_size() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$MASTER_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

render_size 16 icon_16x16.png
render_size 32 icon_16x16@2x.png
render_size 32 icon_32x32.png
render_size 64 icon_32x32@2x.png
render_size 128 icon_128x128.png
render_size 256 icon_128x128@2x.png
render_size 256 icon_256x256.png
render_size 512 icon_256x256@2x.png
render_size 512 icon_512x512.png
render_size 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "Built $OUTPUT_ICNS"
