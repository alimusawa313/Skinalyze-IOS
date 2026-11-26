#!/bin/zsh
# Frames the raw screens from scripts/store-shots.sh into the App Store set (StoreShotArt, a debug-only renderer in the
# app) and flattens every PNG to RGB (App Store Connect rejects an alpha channel).
# usage: scripts/store-render.sh <raw folder (holds iphone/, duo-outer/, duo-inner/)> <out folder>
RAW="${1:a}"; OUT="${2:a}"
UDID=$(xcrun simctl list devices | grep -F "    iPhone 18 Pro (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
cd "${0:a:h}/.."
APP=build/sim/Build/Products/Debug-iphonesimulator/Skinalyze.app
[ -d "$APP" ] || { echo "build the app first (build/sim)"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
mkdir -p "$OUT"
xcrun simctl terminate "$UDID" com.Patani.Skinalyze 2>/dev/null
xcrun simctl launch "$UDID" com.Patani.Skinalyze -seedDemoData -storeShotsDump "$OUT" -storeShotsSource "$RAW" > /dev/null
# Wait until the files stop appearing.
LAST=-1
for _ in {1..60}; do
  sleep 3
  NOW=$(find "$OUT" -name '*.png' | wc -l)
  [ "$NOW" -eq "$LAST" ] && [ "$NOW" -gt 0 ] && break
  LAST=$NOW
done
xcrun simctl terminate "$UDID" com.Patani.Skinalyze 2>/dev/null
python3 - "$OUT" <<'PY'
import glob, sys
from PIL import Image
for path in glob.glob(f"{sys.argv[1]}/**/*.png", recursive=True):
    image = Image.open(path)
    if image.mode != "RGB":
        image.convert("RGB").save(path)
    print(path.split("/")[-2], path.split("/")[-1], image.size)
PY
