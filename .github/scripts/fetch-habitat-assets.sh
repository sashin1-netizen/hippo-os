#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
DEST="$ROOT/godot/assets/habitat/pbr"
mkdir -p "$DEST"
UA="HippoOS/0.2 habitat-build (https://github.com/sashin1-netizen/hippo-os)"
BASE="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k"

fetch() {
  local asset="$1"
  local file="$2"
  local out="$DEST/$file"
  echo "Fetching Poly Haven CC0 asset: $asset/$file"
  curl --fail --location --retry 4 --retry-all-errors --connect-timeout 20 \
    --user-agent "$UA" \
    "$BASE/$asset/$file" \
    --output "$out"
  test -s "$out"
  file "$out"
  sha256sum "$out"
}

fetch "forrest_ground_01" "forrest_ground_01_diff_1k.jpg"
fetch "forrest_ground_01" "forrest_ground_01_nor_gl_1k.jpg"
fetch "forrest_ground_01" "forrest_ground_01_rough_1k.jpg"
fetch "rocks_ground_08" "rocks_ground_08_diff_1k.jpg"
fetch "rocks_ground_08" "rocks_ground_08_nor_gl_1k.jpg"
fetch "rocks_ground_08" "rocks_ground_08_rough_1k.jpg"

echo "CC0 habitat PBR assets fetched successfully."
