#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${1:-apk/HippoOS-Emulator-CI.apk}"
PACKAGE_ID="com.sashin.hippoos"
EVIDENCE_DIR="${2:-apk/android16-install-proof}"
mkdir -p "$EVIDENCE_DIR"

adb wait-for-device
adb shell getprop ro.build.version.sdk | tr -d '\r' | tee "$EVIDENCE_DIR/api-level.txt"
API_LEVEL="$(cat "$EVIDENCE_DIR/api-level.txt")"
test "$API_LEVEL" = "36"
adb shell getprop ro.product.manufacturer | tr -d '\r' > "$EVIDENCE_DIR/manufacturer.txt"
adb shell getprop ro.product.model | tr -d '\r' > "$EVIDENCE_DIR/model.txt"
adb shell getprop ro.hardware | tr -d '\r' > "$EVIDENCE_DIR/hardware.txt"

adb uninstall "$PACKAGE_ID" >/dev/null 2>&1 || true
adb logcat -c
adb install -r -t "$APK_PATH" | tee "$EVIDENCE_DIR/install.txt"
grep -q 'Success' "$EVIDENCE_DIR/install.txt"

adb shell am force-stop "$PACKAGE_ID" || true
adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 | tee "$EVIDENCE_DIR/launch.txt"

PID=""
for _ in $(seq 1 40); do
  PID="$(adb shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
  [ -n "$PID" ] && break
  sleep 1
done
[ -n "$PID" ] || { adb logcat -d > "$EVIDENCE_DIR/logcat.txt" || true; echo 'App process never became alive' >&2; exit 1; }
printf '%s\n' "$PID" > "$EVIDENCE_DIR/pid.txt"

adb shell dumpsys activity activities > "$EVIDENCE_DIR/activity.txt"
grep -Eq 'mResumedActivity|topResumedActivity' "$EVIDENCE_DIR/activity.txt"
grep -q "$PACKAGE_ID" "$EVIDENCE_DIR/activity.txt"

# Give the runtime time to initialize and prove it remains alive through Android lifecycle startup.
sleep 12
PID_AFTER="$(adb shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
[ -n "$PID_AFTER" ] || { adb logcat -d > "$EVIDENCE_DIR/logcat.txt" || true; echo 'App process died during cold-launch smoke' >&2; exit 1; }
printf '%s\n' "$PID_AFTER" > "$EVIDENCE_DIR/pid-after.txt"

adb logcat -d > "$EVIDENCE_DIR/logcat.txt" || true
# Fail only on app/runtime fatal conditions. Emulator graphics presentation is deliberately not a visual release authority.
if grep -Eiq 'FATAL EXCEPTION|SIGSEGV|signal 11|SCRIPT ERROR:|Parse Error:|Failed to instantiate an autoload' "$EVIDENCE_DIR/logcat.txt"; then
  echo 'Fatal runtime condition found in Android 16 logcat' >&2
  exit 1
fi

{
  echo "package=$PACKAGE_ID"
  echo "api=$API_LEVEL"
  echo "pid=$PID_AFTER"
  echo "status=PASS"
} | tee "$EVIDENCE_DIR/summary.txt"
