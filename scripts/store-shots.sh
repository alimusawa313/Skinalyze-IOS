#!/bin/zsh
# Captures the raw screens for the App Store set (StoreShotsUITests) on one simulator, in light and dark, with a
# clean 9:41 status bar. The display in use is kept per screen (iPhone Duo attaches every display).
# usage: [STORE_TEST=testApp] scripts/store-shots.sh <simulator udid> <out dir> [appearance…]   (default: light dark)
UDID="$1"; OUT="$2"; shift 2
APPEARANCES=("$@")
[ ${#APPEARANCES} -eq 0 ] && APPEARANCES=(light dark)
mkdir -p "$OUT"
cd "${0:a:h}/.."
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active \
  --cellularBars 4 --batteryState charged --batteryLevel 100
for LOOK in $APPEARANCES; do
  xcrun simctl ui "$UDID" appearance "$LOOK"
  RESULT="$OUT/$LOOK-$(date +%s).xcresult"
  xcodebuild test -project Skinalyze.xcodeproj -scheme Skinalyze -destination "id=$UDID" -derivedDataPath build/sim \
    -only-testing:SkinalyzeUITests/StoreShotsUITests${STORE_TEST:+/$STORE_TEST} -resultBundlePath "$RESULT" 2>&1 \
    | grep -E "error:|Test Case.*(passed|failed)" | sed "s/^/$LOOK: /"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/att-${RESULT:t:r}" > /dev/null 2>&1
  python3 -I - "$OUT" "att-${RESULT:t:r}" "$LOOK" <<'PY'
import json, os, shutil, sys
out, att, look = sys.argv[1:4]
best = {}
for test in json.load(open(f"{out}/{att}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_0_")[0].split(" · screen")[0]
        path = f"{out}/{att}/{a['exportedFileName']}"
        # On iPhone Duo the display not in use is black (a tiny file): the bigger file wins.
        if os.path.getsize(path) > best.get(name, ("", 0))[1]:
            best[name] = (path, os.path.getsize(path))
os.makedirs(f"{out}/{look}", exist_ok=True)
for name, (path, _) in best.items():
    shutil.copy(path, f"{out}/{look}/{name}.png")
PY
done
xcrun simctl ui "$UDID" appearance light
