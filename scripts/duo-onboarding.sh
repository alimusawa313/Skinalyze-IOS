#!/bin/zsh
# Runs the onboarding UI test on the iPhone Duo simulator in each pose and saves the display in use at every
# scene as <out>/<pose>/<scene>.png (ONBOARDING-PLAN.md O5). Folding is done by pressing Device Hub's
# buttons (scripts/duo-pose.swift, from Sandboxy's Tools/): Device Hub comes to the front, and the terminal needs
# the Accessibility permission. If Device Hub's inspector panel is open, pass its width: DUO_INSPECTOR=280.
# usage: scripts/duo-onboarding.sh <out dir> <pose…>     poses: closed, flat (open, wide), flat-tall, book (half,
#   wide), laptop (half, tall)
OUT="$1"; shift
UDID=$(xcrun simctl list devices available | grep -F "    iPhone Duo (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -z "$UDID" ] && { echo "no simulator named iPhone Duo"; exit 1; }
cd "${0:a:h}/.."
POSER="${TMPDIR:-/tmp}/skinalyze-duo-pose"
[ "$POSER" -nt scripts/duo-pose.swift ] || swiftc -O scripts/duo-pose.swift -o "$POSER" || exit 1
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b > /dev/null
pgrep -q -f "DeviceHub.app/Contents/MacOS/DeviceHub" || { open -a "$(xcode-select -p)/../Applications/DeviceHub.app"; sleep 6; }
hub() { osascript -e 'tell application id "com.apple.dt.Devices" to reopen' -e 'tell application id "com.apple.dt.Devices" to activate' > /dev/null 2>&1; sleep 1; }
for POSE in "$@"; do
  case "$POSE" in
    closed) FOLD=closed; WANT=tall; DISPLAY_ID=1;;
    closed-wide) FOLD=closed; WANT=wide; DISPLAY_ID=1;;
    flat) FOLD=open; WANT=wide; DISPLAY_ID=3;;
    flat-tall) FOLD=open; WANT=tall; DISPLAY_ID=3;;
    book) FOLD=half; WANT=wide; DISPLAY_ID=3;;
    laptop) FOLD=half; WANT=tall; DISPLAY_ID=3;;
    *) echo "unknown pose $POSE"; exit 1;;
  esac
  hub; "$POSER" closed > /dev/null; sleep 2
  # The outer display's picture doesn't turn on the home screen, so a shut phone is turned while open (upright when
  # shut is wide when open), then shut again (as Sandboxy's Tools/duo-ui.sh does).
  TURNED=$WANT
  if [ "$FOLD" = closed ]; then
    if [ "$WANT" = tall ]; then TURNED=wide; else TURNED=tall; fi
    "$POSER" open > /dev/null; sleep 3
  else
    "$POSER" "$FOLD" > /dev/null; sleep 3
  fi
  if true; then
    # A quarter turn at a time until the inner display is the way round the pose wants.
    for _ in 1 2 3; do
      xcrun simctl io "$UDID" screenshot --display=3 "$OUT/.turn.png" > /dev/null 2>&1
      W=$(sips -g pixelWidth "$OUT/.turn.png" 2>/dev/null | awk '/pixelWidth/ {print $2}')
      H=$(sips -g pixelHeight "$OUT/.turn.png" 2>/dev/null | awk '/pixelHeight/ {print $2}')
      if [ "${W:-0}" -gt "${H:-0}" ]; then NOW=wide; else NOW=tall; fi
      [ "$NOW" = "$TURNED" ] && break
      hub; "$POSER" turn > /dev/null; sleep 3
    done
  fi
  [ "$FOLD" = closed ] && { hub; "$POSER" closed > /dev/null; sleep 3; }
  mkdir -p "$OUT/$POSE"
  # The test attaches every display at each scene (OnboardingUITests.snap); the one in use is kept per scene.
  RESULT="$OUT/$POSE/r-$(date +%s).xcresult"
  xcodebuild test -project Skinalyze.xcodeproj -scheme Skinalyze -destination "id=$UDID" -derivedDataPath build/sim \
    -only-testing:SkinalyzeUITests/OnboardingUITests/testEveryScene -resultBundlePath "$RESULT" 2>&1 \
    | grep -E "Test Case.*(passed|failed)" | sed "s/^/$POSE: /"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$POSE/att-${RESULT:t:r}" > /dev/null 2>&1
  python3 -I - "$OUT/$POSE" "$DISPLAY_ID" "att-${RESULT:t:r}" <<'PY'
import json, shutil, sys
folder, display, att = sys.argv[1], sys.argv[2], sys.argv[3]
# Each scene is attached once per display; the display not in use is black (a tiny PNG), so the bigger file wins.
import os
best = {}
for test in json.load(open(f"{folder}/{att}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_0_")[0].replace(" · screen 2", "")
        if not name[:2].isdigit():
            continue
        path = f"{folder}/{att}/{a['exportedFileName']}"
        if os.path.getsize(path) > best.get(name, ("", 0))[1]:
            best[name] = (path, os.path.getsize(path))
for name, (path, _) in best.items():
    shutil.copy(path, f"{folder}/{name.replace(' ', '_')}.png")
PY
done
