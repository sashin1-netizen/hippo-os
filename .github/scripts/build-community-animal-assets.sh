#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
ANYCREATURE_REPO="https://github.com/Ariescar/anyCreature.git"
ANYCREATURE_COMMIT="ab5b1ce5c13e632f00f7f7cbfdb7a746e315000d"
GOBKIT_REPO="https://github.com/Ariescar/gobkit-free-assets"
GOBKIT_COMMIT="0d654ab3306515b1b63621a5c6548554034482dc"
WORK_DIR="$(mktemp -d)"
SOURCE_DIR="$WORK_DIR/anyCreature"
SPEC_DIR="$WORK_DIR/specs"
OUTPUT_DIR="$ROOT/godot/assets/animals/community"
GOBKIT_DIR="$ROOT/godot/assets/community/gobkit"
GOBKIT_NATURE_DIR="$GOBKIT_DIR/nature"
LOG_DIR="$ROOT/build/community-animal-assets"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$GOBKIT_NATURE_DIR" "$LOG_DIR"

echo "Building Hippo OS community animal assets from pinned upstream sources"
echo "anyCreature=$ANYCREATURE_REPO@$ANYCREATURE_COMMIT"
echo "gobkit=$GOBKIT_REPO@$GOBKIT_COMMIT"

# Generated rigged fallbacks for species where the CC0 catalog does not contain the
# exact animal. The compiler mechanically validates the generated quadruped rig.
git clone --quiet --filter=blob:none "$ANYCREATURE_REPO" "$SOURCE_DIR"
git -C "$SOURCE_DIR" checkout --quiet --detach "$ANYCREATURE_COMMIT"
test "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$ANYCREATURE_COMMIT"
test -s "$SOURCE_DIR/LICENSE"
grep -qi 'MIT License' "$SOURCE_DIR/LICENSE"
test -s "$SOURCE_DIR/example/wolf.json"
test -s "$SOURCE_DIR/engine/cli.js"

node "$ROOT/tools/community_animals/make-specs.mjs" \
  "$SOURCE_DIR/example/wolf.json" \
  "$SPEC_DIR"

for species in mochi porky bao; do
  echo "Compiling $species anyCreature GLB"
  node "$SOURCE_DIR/engine/cli.js" \
    "$SPEC_DIR/$species.json" \
    "$OUTPUT_DIR/$species.glb" \
    2>&1 | tee "$LOG_DIR/$species.log"
  test -s "$OUTPUT_DIR/$species.glb"
  grep -q '"ok":true' "$LOG_DIR/$species.log"
  grep -q '"checks":"all green"' "$LOG_DIR/$species.log"
done

# A coherent authored hippo and nature set is available from Gobkit under CC0. Fetch
# exact bytes from an immutable commit. License + hero hippo have independently verified
# Git blob hashes; supporting nature files are pinned by immutable commit and are hashed
# into the build manifest after download.
fetch_gobkit_blob() {
  local source_path="$1"
  local expected_blob="$2"
  local output="$3"
  local url="https://raw.githubusercontent.com/Ariescar/gobkit-free-assets/$GOBKIT_COMMIT/$source_path"

  mkdir -p "$(dirname "$output")"
  echo "Fetching Gobkit $source_path"
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 20 \
    --user-agent 'HippoOS-Build/1.0 (+https://github.com/sashin1-netizen/hippo-os)' \
    "$url" -o "$output"
  test -s "$output"

  local actual_blob
  actual_blob="$(git hash-object "$output")"
  echo "$actual_blob  $source_path" >> "$LOG_DIR/GOBKIT-GIT-BLOBS.txt"
  if [[ -n "$expected_blob" && "$actual_blob" != "$expected_blob" ]]; then
    echo "Gobkit blob mismatch for $source_path" >&2
    echo "expected: $expected_blob" >&2
    echo "actual:   $actual_blob" >&2
    exit 1
  fi
}

: > "$LOG_DIR/GOBKIT-GIT-BLOBS.txt"

fetch_gobkit_blob "LICENSE" \
  "31e15c68af2daa2cb6e9310f7054cfd3d5f24e4b" \
  "$GOBKIT_DIR/LICENSE.txt"
grep -q 'CC0 1.0 Universal' "$GOBKIT_DIR/LICENSE.txt"
grep -q 'commercial' "$GOBKIT_DIR/LICENSE.txt"

# Verified by GitHub Actions against the immutable raw file on 2026-08-25.
fetch_gobkit_blob "animal/Hippo.glb" \
  "4d16ded37c22ad061e36b1fb2105e10ad8c25de1" \
  "$OUTPUT_DIR/gobkit_mochi.glb"

fetch_gobkit_blob "nature/MountainFar001.glb" "" "$GOBKIT_NATURE_DIR/MountainFar001.glb"
fetch_gobkit_blob "nature/MountainFar002.glb" "" "$GOBKIT_NATURE_DIR/MountainFar002.glb"
fetch_gobkit_blob "nature/MountainFar003.glb" "" "$GOBKIT_NATURE_DIR/MountainFar003.glb"
fetch_gobkit_blob "nature/TreeHigh001.glb" "" "$GOBKIT_NATURE_DIR/TreeHigh001.glb"
fetch_gobkit_blob "nature/TreeLow002.glb" "" "$GOBKIT_NATURE_DIR/TreeLow002.glb"
fetch_gobkit_blob "nature/Bush001.glb" "" "$GOBKIT_NATURE_DIR/Bush001.glb"
fetch_gobkit_blob "nature/Bush002.glb" "" "$GOBKIT_NATURE_DIR/Bush002.glb"
fetch_gobkit_blob "nature/Reed001.glb" "" "$GOBKIT_NATURE_DIR/Reed001.glb"
fetch_gobkit_blob "nature/Reed002.glb" "" "$GOBKIT_NATURE_DIR/Reed002.glb"
fetch_gobkit_blob "nature/Rock001.glb" "" "$GOBKIT_NATURE_DIR/Rock001.glb"
fetch_gobkit_blob "nature/Rock002.glb" "" "$GOBKIT_NATURE_DIR/Rock002.glb"
fetch_gobkit_blob "nature/Rock003.glb" "" "$GOBKIT_NATURE_DIR/Rock003.glb"

sha256sum \
  "$OUTPUT_DIR/mochi.glb" \
  "$OUTPUT_DIR/porky.glb" \
  "$OUTPUT_DIR/bao.glb" \
  "$OUTPUT_DIR/gobkit_mochi.glb" \
  "$GOBKIT_NATURE_DIR"/*.glb | tee "$LOG_DIR/SHA256SUMS.txt"

cat > "$OUTPUT_DIR/PROVENANCE.txt" <<EOF
Hippo OS community asset fallback

anyCreature generator
Repository: $ANYCREATURE_REPO
Pinned commit: $ANYCREATURE_COMMIT
Licence: MIT
Use: generated Porky/Bao fallbacks and mechanically validated generated animal backups.

Gobkit free assets
Repository: $GOBKIT_REPO
Pinned commit: $GOBKIT_COMMIT
Licence: CC0 1.0 Universal
Use: authored rigged Hippo fallback plus static nature-kit scenery.

All downloads come from immutable commit URLs. The Gobkit license and hero Hippo are
independently verified by Git blob hash; all supporting scenery is recorded in both a
Git-blob manifest and SHA-256 manifest on every build. Final Hippo OS production GLBs
remain authoritative whenever present.
EOF

cp "$OUTPUT_DIR/PROVENANCE.txt" "$LOG_DIR/PROVENANCE.txt"
cp "$GOBKIT_DIR/LICENSE.txt" "$LOG_DIR/GOBKIT-LICENSE.txt"
echo "Community animal and nature assets prepared successfully."