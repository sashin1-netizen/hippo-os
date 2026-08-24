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
  local expected_sha256="$3"
  local out="$DEST/$file"
  echo "Fetching Poly Haven CC0 asset: $asset/$file"
  curl --fail --location --retry 4 --retry-all-errors --connect-timeout 20 \
    --user-agent "$UA" \
    "$BASE/$asset/$file" \
    --output "$out"
  test -s "$out"
  file "$out"
  printf '%s  %s\n' "$expected_sha256" "$out" | sha256sum --check --strict
}

fetch "forrest_ground_01" "forrest_ground_01_diff_1k.jpg" "3dd6875cb3908e022a3c45ebbffa5e84c670ff2691fbbb6dc9ea4bff88523800"
fetch "forrest_ground_01" "forrest_ground_01_nor_gl_1k.jpg" "32528a7cdee962cc0b248ee4023a74d0df175737ea90e1eb425122351e0bdab4"
fetch "forrest_ground_01" "forrest_ground_01_rough_1k.jpg" "30d8b56a03d7b12da16f58011b675662a40e58e1cdc768119a5f03968140058c"
fetch "rocks_ground_08" "rocks_ground_08_diff_1k.jpg" "854f22105dd5a85fbc27e840704576e1fc99353bf6d881ded71c6100d15cc57d"
fetch "rocks_ground_08" "rocks_ground_08_nor_gl_1k.jpg" "15661239defd2560d0fd9cbc295d08774b3c039ba8dd643fca562c4674ea29e4"
fetch "rocks_ground_08" "rocks_ground_08_rough_1k.jpg" "b2df91701d9ac8a988e7d1637ca7aed93dd1d3a6b88015cc0014c97c73b981bf"

echo "CC0 habitat PBR assets fetched and SHA-256 verified successfully."
