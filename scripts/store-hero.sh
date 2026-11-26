#!/bin/zsh
# The App Store's product page header (3840x1646) and search result (3840x2560 still, 1920x1280 video), as PNG stills
# and seamless MP4 loops, from the raw screens of scripts/store-shots.sh (StoreHero, a debug-only renderer in the app).
# usage: scripts/store-hero.sh <raw folder (holds iphone/, duo-inner/)> <out folder>
RAW="${1:a}"; OUT="${2:a}"
UDID=$(xcrun simctl list devices | grep -F "    iPhone 18 Pro (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
FFMPEG=/opt/homebrew/bin/ffmpeg
cd "${0:a:h}/.."
APP=build/sim/Build/Products/Debug-iphonesimulator/Skinalyze.app
[ -d "$APP" ] || { echo "build the app first (build/sim)"; exit 1; }
WORK="$OUT/.frames"
mkdir -p "$WORK" "$OUT"
rm -f "$WORK/done.txt"
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" com.Patani.Skinalyze 2>/dev/null
xcrun simctl launch "$UDID" com.Patani.Skinalyze -seedDemoData -storeHeroDump "$WORK" -storeShotsSource "$RAW" > /dev/null
for _ in {1..300}; do [ -f "$WORK/done.txt" ] && break; sleep 3; done
xcrun simctl terminate "$UDID" com.Patani.Skinalyze 2>/dev/null
[ -f "$WORK/done.txt" ] || { echo "rendering didn't finish"; exit 1; }
# Stills: RGB, no alpha (App Store Connect rejects transparency).
python3 - "$WORK" "$OUT" <<'PY'
import sys
from PIL import Image
work, out = sys.argv[1:3]
for name in ["header", "search"]:
    Image.open(f"{work}/{name}.png").convert("RGB").save(f"{out}/{name}.png")
PY
# Loops: H.264, 30 fps, a silent stereo track, fast start.
for NAME in header search; do
  "$FFMPEG" -hide_banner -loglevel error -y -framerate 30 -i "$WORK/$NAME-frames/f%04d.jpg" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest \
    -c:v libx264 -profile:v high -preset slow -crf 15 -pix_fmt yuv420p -r 30 \
    -c:a aac -b:a 128k -movflags +faststart "$OUT/$NAME.mp4"
done
ls -la "$OUT"
