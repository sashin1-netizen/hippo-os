#!/usr/bin/env bash
set -euo pipefail

PACKAGE="com.sashin.hippoos.personal.ci"
APK="apk/HippoOS-Emulator-CI.apk"
EVIDENCE_DIR="apk"

mkdir -p "$EVIDENCE_DIR"
adb wait-for-device

android_release="$(adb shell getprop ro.build.version.release | tr -d '\r')"
android_sdk="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
printf 'release=%s\nsdk=%s\n' "$android_release" "$android_sdk" | tee "$EVIDENCE_DIR/android-version.txt"
case "$android_release" in
  16|16.*) ;;
  *)
    echo "Unexpected Android release: $android_release" >&2
    exit 1
    ;;
esac
test "$android_sdk" = "36"

# The runner uses a disposable emulator. Always begin from a clean PackageManager state.
adb uninstall "$PACKAGE" > "$EVIDENCE_DIR/adb-uninstall.txt" 2>&1 || true
adb install --no-streaming -r "$APK" | tee "$EVIDENCE_DIR/adb-install.txt"
grep -q '^Success$' "$EVIDENCE_DIR/adb-install.txt"

registered=0
for attempt in $(seq 1 45); do
  adb shell pm list packages | tr -d '\r' > "$EVIDENCE_DIR/adb-package-list.txt"
  if grep -Fxq "package:$PACKAGE" "$EVIDENCE_DIR/adb-package-list.txt"; then
    registered=1
    echo "PackageManager registered Hippo OS on attempt ${attempt}."
    break
  fi
  sleep 1
done
test "$registered" -eq 1

package_path="$(adb shell pm path "$PACKAGE" | tr -d '\r')"
printf '%s\n' "$package_path" | tee "$EVIDENCE_DIR/adb-package-path.txt"
test -n "$package_path"
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
    "$PACKAGE/"*)
      echo "Resolved launcher component on attempt ${attempt}: $component"
      break
      ;;
    *) sleep 1 ;;
  esac
done
printf '%s\n' "$component" | tee "$EVIDENCE_DIR/adb-launch-component.txt"
case "$component" in
  "$PACKAGE/"*) ;;
  *)
    echo "Unable to resolve Hippo OS launcher activity: $component" >&2
    exit 1
    ;;
esac

# Pre-confirm immersive mode where Android honours this setting. Android 16 may still
# show a one-time SystemUI education overlay; that overlay is detected and dismissed
# explicitly below before any screenshot is eligible to pass.
adb shell settings put secure immersive_mode_confirmations confirmed || true
adb logcat -c
adb shell am force-stop "$PACKAGE" || true
adb shell am start -W -n "$component" | tee "$EVIDENCE_DIR/adb-launch.txt"
grep -q 'Status: ok' "$EVIDENCE_DIR/adb-launch.txt"

# Dismiss Android's first-run "Viewing full screen" education bubble without hardcoded
# device coordinates. UiAutomator supplies the actual Got it button bounds.
for dismiss_attempt in $(seq 1 5); do
  adb shell uiautomator dump /sdcard/hippo-window.xml >/dev/null 2>&1 || true
  adb shell cat /sdcard/hippo-window.xml 2>/dev/null | tr -d '\r' > "$EVIDENCE_DIR/window.xml" || true
  if ! grep -q 'Viewing full screen' "$EVIDENCE_DIR/window.xml"; then
    break
  fi

  read -r tap_x tap_y < <(python3 - "$EVIDENCE_DIR/window.xml" <<'PY'
import re
import sys
text = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
match = re.search(r'text="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', text)
if not match:
    match = re.search(r'content-desc="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', text)
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

visible=0
for attempt in $(seq 1 18); do
  sleep 5
  pid="$(adb shell pidof "$PACKAGE" | tr -d '\r' || true)"
  printf '%s\n' "$pid" | tee "$EVIDENCE_DIR/adb-pid.txt"
  adb logcat -d -t 1200 > "$EVIDENCE_DIR/adb-logcat.txt"

  if [[ -z "$pid" ]]; then
    if grep -Eiq 'FATAL EXCEPTION|Process: com\.sashin\.hippoos\.personal\.ci.*has died|Unable to instantiate application' "$EVIDENCE_DIR/adb-logcat.txt"; then
      echo 'Hippo OS process crashed during Android 16 launch proof.' >&2
      exit 1
    fi
    echo "Hippo OS process not resident yet on attempt ${attempt}; retrying."
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

  # Android 16 no longer provides a stable mCurrentFocus/mFocusedApp signal for this
  # immersive Godot activity. ActivityManager's resumed/top activity is the correct
  # lifecycle source of truth for whether Hippo OS owns the foreground task.
  adb shell dumpsys activity activities | tr -d '\r' > "$EVIDENCE_DIR/activity-state.txt"
  adb shell dumpsys activity top | tr -d '\r' > "$EVIDENCE_DIR/activity-top.txt"
  resumed_lines="$(grep -E 'topResumedActivity|mResumedActivity|ResumedActivity|ACTIVITY ' "$EVIDENCE_DIR/activity-state.txt" "$EVIDENCE_DIR/activity-top.txt" || true)"
  printf '%s\n' "$resumed_lines" > "$EVIDENCE_DIR/activity-resumed.txt"
  if ! grep -q "$PACKAGE" "$EVIDENCE_DIR/activity-resumed.txt"; then
    echo "Hippo OS is not the resumed foreground activity on attempt ${attempt}; relaunching."
    adb shell am start -n "$component" >/dev/null 2>&1 || true
    continue
  fi

  # Keep WindowManager evidence for diagnostics, but do not use its deprecated focus
  # fields as a release gate.
  adb shell dumpsys window windows | tr -d '\r' > "$EVIDENCE_DIR/window-focus.txt"

  adb shell uiautomator dump /sdcard/hippo-window.xml >/dev/null 2>&1 || true
  adb shell cat /sdcard/hippo-window.xml 2>/dev/null | tr -d '\r' > "$EVIDENCE_DIR/window.xml" || true
  if grep -q 'Viewing full screen' "$EVIDENCE_DIR/window.xml"; then
    echo "Android immersive-mode tutorial still covers Hippo OS on attempt ${attempt}; dismissing."
    read -r tap_x tap_y < <(python3 - "$EVIDENCE_DIR/window.xml" <<'PY'
import re
import sys
text = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
match = re.search(r'text="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', text)
if not match:
    match = re.search(r'content-desc="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', text)
if match:
    x1, y1, x2, y2 = map(int, match.groups())
    print((x1 + x2) // 2, (y1 + y2) // 2)
else:
    print(0, 0)
PY
    )
    if [[ "$tap_x" -gt 0 && "$tap_y" -gt 0 ]]; then
      adb shell input tap "$tap_x" "$tap_y"
    fi
    continue
  fi

  adb exec-out screencap -p > "$EVIDENCE_DIR/launch-attempt.png"
  test -s "$EVIDENCE_DIR/launch-attempt.png"

  if python3 - "$EVIDENCE_DIR/launch-attempt.png" <<'PY'
from PIL import Image, ImageStat
import sys
image = Image.open(sys.argv[1]).convert('RGB')
stat = ImageStat.Stat(image)
extrema = image.getextrema()
spread = max(high - low for low, high in extrema)
deviation = max(stat.stddev)
mean = sum(stat.mean) / 3.0
pixels = list(image.getdata())
near_white = sum(1 for r, g, b in pixels if r >= 238 and g >= 238 and b >= 238)
near_black = sum(1 for r, g, b in pixels if r <= 6 and g <= 6 and b <= 6)
white_fraction = near_white / float(image.width * image.height)
black_fraction = near_black / float(image.width * image.height)
print(
    f'visual-proof mean={mean:.2f} max_stddev={deviation:.2f} '
    f'spread={spread} near_white={white_fraction:.4f} near_black={black_fraction:.4f}'
)
if deviation < 8.0 or spread < 30 or mean < 8.0:
    raise SystemExit(1)
# Android education/dialog surfaces can have excellent contrast and otherwise fool a
# variance-only validator. Likewise a mostly black frame is not a sanctuary render.
if white_fraction > 0.18 or black_fraction > 0.72:
    raise SystemExit(1)
PY
  then
    cp "$EVIDENCE_DIR/launch-attempt.png" "$EVIDENCE_DIR/launch.png"
    visible=1
    echo "Visible Hippo OS foreground frame proven on attempt ${attempt}."
    break
  fi
done

test "$visible" -eq 1
adb shell dumpsys window displays > "$EVIDENCE_DIR/window-displays.txt"
bytes="$(stat -c%s "$EVIDENCE_DIR/launch.png")"
echo "Launch screenshot bytes: $bytes"
test "$bytes" -ge 30000

echo 'Android 16 Hippo OS foreground and visible-render proof: PASS.'
