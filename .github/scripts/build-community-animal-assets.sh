#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
ANYCREATURE_REPO="https://github.com/Ariescar/anyCreature.git"
ANYCREATURE_COMMIT="ab5b1ce5c13e632f00f7f7cbfdb7a746e315000d"
WORK_DIR="$(mktemp -d)"
SOURCE_DIR="$WORK_DIR/anyCreature"
SPEC_DIR="$WORK_DIR/specs"
OUTPUT_DIR="$ROOT/godot/assets/animals/community"
LOG_DIR="$ROOT/build/community-animal-assets"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

echo "Building Hippo OS community animal assets from pinned upstream source"
echo "source=$ANYCREATURE_REPO"
echo "commit=$ANYCREATURE_COMMIT"

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
  echo "Compiling $species community GLB"
  node "$SOURCE_DIR/engine/cli.js" \
    "$SPEC_DIR/$species.json" \
    "$OUTPUT_DIR/$species.glb" \
    2>&1 | tee "$LOG_DIR/$species.log"
  test -s "$OUTPUT_DIR/$species.glb"
  grep -q '"ok":true' "$LOG_DIR/$species.log"
  grep -q '"checks":"all green"' "$LOG_DIR/$species.log"
done

sha256sum \
  "$OUTPUT_DIR/mochi.glb" \
  "$OUTPUT_DIR/porky.glb" \
  "$OUTPUT_DIR/bao.glb" | tee "$LOG_DIR/SHA256SUMS.txt"

cat > "$OUTPUT_DIR/PROVENANCE.txt" <<EOF
Hippo OS community animal generation fallback
Generator: Ariescar/anyCreature
Pinned upstream commit: $ANYCREATURE_COMMIT
Upstream licence: MIT
Generated from the upstream validated quadruped example through Hippo OS species transforms.
These generated GLBs are an interim coherent/rigged fallback and do not replace the final 4K PBR production-art requirement.
EOF

cp "$OUTPUT_DIR/PROVENANCE.txt" "$LOG_DIR/PROVENANCE.txt"
echo "Community animal GLBs generated successfully."
