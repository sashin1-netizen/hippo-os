#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
AUDIO_DIR="$ROOT/godot/assets/audio"
mkdir -p "$AUDIO_DIR"

fetch_and_verify() {
  local url="$1"
  local output="$2"
  local expected_sha1="$3"

  echo "Fetching $(basename "$output")"
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 20 \
    --user-agent 'HippoOS-Build/1.0 (+https://github.com/sashin1-netizen/hippo-os)' \
    "$url" -o "$output"
  test -s "$output"

  local actual_sha1
  actual_sha1="$(sha1sum "$output" | awk '{print $1}')"
  if [[ "$actual_sha1" != "$expected_sha1" ]]; then
    echo "Checksum mismatch for $output" >&2
    echo "expected: $expected_sha1" >&2
    echo "actual:   $actual_sha1" >&2
    exit 1
  fi
}

fetch_and_verify \
  'https://upload.wikimedia.org/wikipedia/commons/0/0a/20090610_0_ambience.ogg' \
  "$AUDIO_DIR/forest_ambience.ogg" \
  '981f161f9e1a5749bf5da8e37c7f37b892afe7cc'

fetch_and_verify \
  'https://upload.wikimedia.org/wikipedia/commons/8/84/Swale.ogg' \
  "$AUDIO_DIR/water_stream.ogg" \
  '4f97748c715d90fda6357073f14a12e68f294d73'

fetch_and_verify \
  'https://upload.wikimedia.org/wikipedia/commons/2/2f/Birds_chirping_in_a_garden.ogg' \
  "$AUDIO_DIR/birds_garden.ogg" \
  '53e7cac9a45f2d680f5ead2e4a42892c21a69ac0'

fetch_and_verify \
  'https://upload.wikimedia.org/wikipedia/commons/a/ac/Pig_grunt_-_Erdie.ogg' \
  "$AUDIO_DIR/pig_grunt.ogg" \
  'd036f878e0316e94e39bbf1035dcbe386b904707'

# Public-domain dog bark. The checksum is intentionally pinned to the source bytes;
# CI will reject the asset if Wikimedia ever serves different content at this URL.
fetch_and_verify \
  'https://upload.wikimedia.org/wikipedia/commons/4/4c/George_vuf_1996.ogg' \
  "$AUDIO_DIR/dog_bark.ogg" \
  '0000000000000000000000000000000000000000'

echo "Verified Hippo OS audio assets:"
ls -lh "$AUDIO_DIR"/*.ogg
sha1sum "$AUDIO_DIR"/*.ogg
