#!/usr/bin/env bash
set -euo pipefail

PACKAGE="com.sashin.hippoos.personal.ci"
APK="apk/HippoOS-Emulator-CI.apk"
EVIDENCE_DIR="apk"
READY_MARKER="HippoOS community showcase ready"
PROFILE=".github/visual/grasslands-reference-profile.json"

mkdir -p "$EVIDENCE_DIR"
adb wait-for-device

android_release="$(adb shell getprop ro.build.version.release | tr -d '\r')"
android_sdk="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
printf 'release=%s\nsdk=%s\n' "$android_release" "$android_sdk" | tee "$EVIDENCE_DIR/android-version.txt"
case "$android_release" in
  16|16.*) ;;
  *) echo "Unexpected Android release: $android_release" >&2; exit 1 ;;
esac
test "$android_sdk" = "36"

adb uninstall "$PACKAGE" > "$EVIDENCE_DIR/adb-uninstall.txt" 2>&1 || true
adb install --no-streaming -r "$APK" | tee "$EVIDENCE_DIR/adb-install.txt"
grep -q '^Success$' "$EVIDENCE_DIR/adb-install.txt"

registered=0
for attempt in $(seq 1 45); do
  adb shell pm list packages | tr -d '\r' > "$EVIDENCE_DIR/adb-package-list.txt"
  if grep -Fxq "package:$PACKAGE" "$EVIDENCE_DIR/adb-package-list.txt"; then
    registered=1
    break
  fi
  sleep 1
done
test "$registered" -eq 1

package_path="$(adb shell pm path "$PACKAGE" | tr -d '\r')"
printf '%s\n' "$package_path" | tee "$EVIDENCE_DIR/adb-package-path.txt"
grep -q '^package:' "$EVIDENCE_DIR/adb-package-path.txt"

adb shell dumpsys package "$PACKAGE" > "$EVIDENCE_DIR/adb-package.txt"
grep -q 'versionCode=4' "$EVIDENCE_DIR/adb-package.txt"
grep -q 'targetSdk=36' "$EVIDENCE_DIR/adb-package.txt"

component=""
for attempt in $(seq 1 30); do
  component="$(adb shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN \
    -c android.intent.category.LAUNCHER \
    "$PACKAGE" 2>/dev/null | tr -d '\r' | tail -n 1 || true)"
  case "$component" in
    "$PACKAGE/"*) break ;;
    *) sleep 1 ;;
  esac
done
printf '%s\n' "$component" | tee "$EVIDENCE_DIR/adb-launch-component.txt"
case "$component" in
  "$PACKAGE/"*) ;;
  *) echo "Unable to resolve Hippo OS launcher activity: $component" >&2; exit 1 ;;
esac

adb shell settings put secure immersive_mode_confirmations confirmed || true
adb logcat -c
adb shell am force-stop "$PACKAGE" || true
adb shell am start -W -n "$component" | tee "$EVIDENCE_DIR/adb-launch.txt"
grep -q 'Status: ok' "$EVIDENCE_DIR/adb-launch.txt"

# Remove Android's one-time immersive education overlay before visual proof.
for dismiss_attempt in $(seq 1 5); do
  adb shell uiautomator dump /sdcard/hippo-window.xml >/dev/null 2>&1 || true
  adb shell cat /sdcard/hippo-window.xml 2>/dev/null | tr -d '\r' > "$EVIDENCE_DIR/window.xml" || true
  if ! grep -q 'Viewing full screen' "$EVIDENCE_DIR/window.xml"; then
    break
  fi
  read -r tap_x tap_y < <(python3 - "$EVIDENCE_DIR/window.xml" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
match = re.search(r'(?:text|content-desc)="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', text)
if match:
    x1, y1, x2, y2 = map(int, match.groups())
    print((x1 + x2) // 2, (y1 + y2) // 2)
else:
    print(0, 0)
PY
  )
  if [[ "$tap_x" -gt 0 && "$tap_y" -gt 0 ]]; then
    adb shell input tap "$tap_x" "$tap_y"
  else
    adb shell input keyevent 66 || true
    adb shell input keyevent 4 || true
  fi
  sleep 1
done

# A screenshot is not eligible until Hippo OS confirms that the authored community/
# production companion visuals and the final world are active. This prevents CI from
# accepting an early prototype frame simply because it is non-black.
authoritative_ready=0
visible=0
for attempt in $(seq 1 30); do
  sleep 5
  pid="$(adb shell pidof "$PACKAGE" | tr -d '\r' || true)"
  printf '%s\n' "$pid" | tee "$EVIDENCE_DIR/adb-pid.txt"
  adb logcat -d -t 1800 > "$EVIDENCE_DIR/adb-logcat.txt"

  if [[ -z "$pid" ]]; then
    if grep -Eiq 'FATAL EXCEPTION|Process: com\.sashin\.hippoos\.personal\.ci.*has died|Unable to instantiate application' "$EVIDENCE_DIR/adb-logcat.txt"; then
      echo 'Hippo OS process crashed during Android 16 launch proof.' >&2
      exit 1
    fi
    continue
  fi

  adb logcat -d --pid="$pid" > "$EVIDENCE_DIR/adb-app-logcat.txt"
  if grep -Eiq 'FATAL EXCEPTION|Process: com\.sashin\.hippoos\.personal\.ci.*has died|Unable to instantiate application' "$EVIDENCE_DIR/adb-logcat.txt"; then
    echo 'Hippo OS process crashed during Android 16 render proof.' >&2
    exit 1
  fi
  if grep -Eiq 'Program linking failed|GL_MAX_FRAGMENT_UNIFORM_VECTORS|SHADER ERROR:|Shader compilation failed|SCRIPT ERROR:|Parse Error:' "$EVIDENCE_DIR/adb-app-logcat.txt"; then
    echo 'Hippo OS reported a fatal runtime rendering/script error.' >&2
    exit 1
  fi

  adb shell dumpsys activity activities | tr -d '\r' > "$EVIDENCE_DIR/activity-state.txt"
  adb shell dumpsys activity top | tr -d '\r' > "$EVIDENCE_DIR/activity-top.txt"
  resumed_lines="$(grep -E 'topResumedActivity|mResumedActivity|ResumedActivity|ACTIVITY ' "$EVIDENCE_DIR/activity-state.txt" "$EVIDENCE_DIR/activity-top.txt" || true)"
  printf '%s\n' "$resumed_lines" > "$EVIDENCE_DIR/activity-resumed.txt"
  if ! grep -q "$PACKAGE" "$EVIDENCE_DIR/activity-resumed.txt"; then
    adb shell am start -n "$component" >/dev/null 2>&1 || true
    continue
  fi

  adb shell dumpsys window windows | tr -d '\r' > "$EVIDENCE_DIR/window-focus.txt"
  adb shell uiautomator dump /sdcard/hippo-window.xml >/dev/null 2>&1 || true
  adb shell cat /sdcard/hippo-window.xml 2>/dev/null | tr -d '\r' > "$EVIDENCE_DIR/window.xml" || true
  if grep -q 'Viewing full screen' "$EVIDENCE_DIR/window.xml"; then
    adb shell input keyevent 66 || true
    continue
  fi

  if ! grep -Fq "$READY_MARKER" "$EVIDENCE_DIR/adb-app-logcat.txt"; then
    echo "Authoritative presentation not ready on attempt ${attempt}; waiting for marker."
    continue
  fi
  authoritative_ready=1
  printf '%s\n' "$READY_MARKER" > "$EVIDENCE_DIR/authoritative-frame-marker.txt"

  adb exec-out screencap -p > "$EVIDENCE_DIR/launch-attempt.png"
  test -s "$EVIDENCE_DIR/launch-attempt.png"

  if python3 .github/scripts/visual-regression-gate.py \
      "$EVIDENCE_DIR/launch-attempt.png" \
      "$PROFILE" \
      "$EVIDENCE_DIR/visual-regression.json"; then
    cp "$EVIDENCE_DIR/launch-attempt.png" "$EVIDENCE_DIR/launch.png"
    visible=1
    echo "Authoritative Hippo OS frame passed visual regression on attempt ${attempt}."
    break
  fi
done

test "$authoritative_ready" -eq 1 || {
  echo "Hippo OS never emitted required readiness marker: $READY_MARKER" >&2
  exit 1
}
test "$visible" -eq 1 || {
  echo 'Hippo OS authoritative frame never satisfied the Grasslands visual-regression profile.' >&2
  exit 1
}

adb shell dumpsys window displays > "$EVIDENCE_DIR/window-displays.txt"
bytes="$(stat -c%s "$EVIDENCE_DIR/launch.png")"
echo "Launch screenshot bytes: $bytes"
test "$bytes" -ge 30000

echo 'Android 16 authoritative-frame + visual-regression proof: PASS.'
