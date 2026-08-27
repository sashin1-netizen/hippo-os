#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
DEST="$ROOT/godot/assets/habitat/pbr"
mkdir -p "$DEST"
UA="HippoOS/0.2 habitat-build (https://github.com/sashin1-netizen/hippo-os)"
BASE="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k"

fetch() {
  local asset="$1"
  local file="$2"
  local expected_sha256="$3"
  local out="$DEST/$file"

  echo "Fetching Poly Haven CC0 4K asset: $asset/$file"
  curl --fail --location --retry 4 --retry-all-errors --connect-timeout 20 \
    --user-agent "$UA" \
    "$BASE/$asset/$file" \
    --output "$out"

  test -s "$out"
  local file_info
  file_info="$(file "$out")"
  echo "$file_info"
  if [[ "$file_info" != *"4096x4096"* ]]; then
    echo "::error::Expected a genuine 4096x4096 source texture for $file" >&2
    exit 1
  fi

  local actual_sha256
  actual_sha256="$(sha256sum "$out" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "::error::Checksum mismatch for $file" >&2
    echo "expected: $expected_sha256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 1
  fi
}

fetch "forrest_ground_01" "forrest_ground_01_diff_4k.jpg" "2371d84b080ed5c91c16feeaf32808693fd4e12b962ef0a55a1e2ff452bdc13d"
fetch "forrest_ground_01" "forrest_ground_01_nor_gl_4k.jpg" "baa0bfcfbd6bf7755b776494d9ae98652603fe9850eac037b5306d9b6b14069b"
fetch "forrest_ground_01" "forrest_ground_01_rough_4k.jpg" "5f5911f94e9ba500243672cd0272b01101032e4cfabece14baa78947e96cd220"
fetch "rocks_ground_08" "rocks_ground_08_diff_4k.jpg" "85534fe827293a0d79538b99355c71e58184c2e7af9697ea5244cc7b365e60f7"
fetch "rocks_ground_08" "rocks_ground_08_nor_gl_4k.jpg" "b9e945b9716f1efe193e0a7882a521fb75b9300087dcba9446a0a713e69b0f0f"
fetch "rocks_ground_08" "rocks_ground_08_rough_4k.jpg" "179d788353fe734a35b92b45e2fda05e031b237246cd72a521eca75a6ff02272"

echo "Verified genuine 4096x4096 CC0 sanctuary PBR source textures."
sha256sum "$DEST"/*_4k.jpg
