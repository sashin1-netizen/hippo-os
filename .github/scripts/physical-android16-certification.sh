#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${1:?usage: physical-android16-certification.sh <apk> [expected-sha-file] [evidence-dir]}"
SHA_FILE="${2:-${APK_PATH}.sha256}"
EVIDENCE_DIR="${3:-device-certification}"
PACKAGE_ID="com.sashin.hippoos"
mkdir -p "$EVIDENCE_DIR"

command -v adb >/dev/null
command -v sha256sum >/dev/null
adb wait-for-device

ACTUAL_SHA="$(sha256sum "$APK_PATH" | awk '{print $1}')"
EXPECTED_SHA="$(awk '{print $1}' "$SHA_FILE")"
printf '%s\n' "$ACTUAL_SHA" | tee "$EVIDENCE_DIR/apk.sha256"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"

API="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
MODEL="$(adb shell getprop ro.product.model | tr -d '\r')"
MANUFACTURER="$(adb shell getprop ro.product.manufacturer | tr -d '\r')"
GPU="$(adb shell dumpsys SurfaceFlinger 2>/dev/null | grep -Ei 'GLES|Vulkan' | head -n 10 || true)"
{
  echo "api=$API"
  echo "manufacturer=$MANUFACTURER"
  echo "model=$MODEL"
  echo "apk_sha256=$ACTUAL_SHA"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'gpu=%s\n' "${GPU//$'\n'/ ; }"
} | tee "$EVIDENCE_DIR/device.txt"
test "$API" = "36"

adb uninstall "$PACKAGE_ID" >/dev/null 2>&1 || true
adb logcat -c
adb install -r "$APK_PATH" | tee "$EVIDENCE_DIR/install.txt"
grep -q 'Success' "$EVIDENCE_DIR/install.txt"
adb shell am force-stop "$PACKAGE_ID" || true
adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 > "$EVIDENCE_DIR/launch.txt"

READY=0
for _ in $(seq 1 60); do
  PID="$(adb shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
  if [ -z "$PID" ]; then
    sleep 1
    continue
  fi
  adb logcat -d > "$EVIDENCE_DIR/logcat-live.txt" || true
  if grep -Fq 'HippoOS community showcase ready' "$EVIDENCE_DIR/logcat-live.txt"; then
    READY=1
    break
  fi
  sleep 1
done

test "$READY" = "1" || { adb logcat -d > "$EVIDENCE_DIR/logcat.txt" || true; echo 'Authoritative world-ready marker not observed on physical Android 16 device' >&2; exit 1; }

adb exec-out screencap -p > "$EVIDENCE_DIR/authoritative-frame.png"
test -s "$EVIDENCE_DIR/authoritative-frame.png"
adb shell dumpsys activity activities > "$EVIDENCE_DIR/activity.txt"
grep -q "$PACKAGE_ID" "$EVIDENCE_DIR/activity.txt"

# Basic playability smoke: exercise the centre/lower touch surface without relying on a specific desktop-only input stack.
adb shell input tap 360 900 || true
sleep 1
adb shell input swipe 180 900 540 900 500 || true
sleep 2

# Persistence/relaunch smoke: background then cold relaunch; the process must return and remain alive.
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am force-stop "$PACKAGE_ID"
adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 8
PID_AFTER="$(adb shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
test -n "$PID_AFTER"

adb logcat -d > "$EVIDENCE_DIR/logcat.txt" || true
if grep -Eiq 'FATAL EXCEPTION|SIGSEGV|signal 11|SCRIPT ERROR:|Parse Error:|Failed to instantiate an autoload|SHADER ERROR:|Shader compilation failed' "$EVIDENCE_DIR/logcat.txt"; then
  echo 'Fatal/script/shader error found during physical-device smoke' >&2
  exit 1
fi

# Run the repository visual-regression validator against the real-device screenshot when available.
if [ -f .github/scripts/visual-regression-gate.py ] && [ -f .github/visual/grasslands-reference-profile.json ]; then
  python3 .github/scripts/visual-regression-gate.py "$EVIDENCE_DIR/authoritative-frame.png" .github/visual/grasslands-reference-profile.json | tee "$EVIDENCE_DIR/visual-regression.txt"
fi

{
  echo "apk_sha256=$ACTUAL_SHA"
  echo "android_api=$API"
  echo "model=$MANUFACTURER $MODEL"
  echo "world_ready=PASS"
  echo "visual_frame=PASS"
  echo "relaunch=PASS"
  echo "fatal_runtime_errors=0"
  echo "status=DEVICE_CERTIFIED"
} | tee "$EVIDENCE_DIR/certification.txt"
