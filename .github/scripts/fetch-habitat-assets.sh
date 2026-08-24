#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
DEST="$ROOT/godot/assets/habitat/pbr"
mkdir -p "$DEST"
UA="HippoOS/0.2 habitat-build (https://github.com/sashin1-netizen/hippo-os)"
BASE="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k"

mismatch=0
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
  file "$out"
  local actual_sha256
  actual_sha256="$(sha256sum "$out" | awk '{print $1}')"
  echo "HIPPOOS_4K_SHA256 $file $actual_sha256"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    mismatch=1
  fi
}

# First CI run intentionally records the upstream SHA-256 values. Replace the
# zero sentinels with the emitted HIPPOOS_4K_SHA256 values before merge.
ZERO="0000000000000000000000000000000000000000000000000000000000000000"
fetch "forrest_ground_01" "forrest_ground_01_diff_4k.jpg" "$ZERO"
fetch "forrest_ground_01" "forrest_ground_01_nor_gl_4k.jpg" "$ZERO"
fetch "forrest_ground_01" "forrest_ground_01_rough_4k.jpg" "$ZERO"
fetch "rocks_ground_08" "rocks_ground_08_diff_4k.jpg" "$ZERO"
fetch "rocks_ground_08" "rocks_ground_08_nor_gl_4k.jpg" "$ZERO"
fetch "rocks_ground_08" "rocks_ground_08_rough_4k.jpg" "$ZERO"

if [[ "$mismatch" -ne 0 ]]; then
  echo "::error::4K checksum probe complete; pin the emitted SHA-256 values before merge." >&2
  exit 1
fi

echo "CC0 4K habitat PBR assets fetched and SHA-256 verified successfully."
