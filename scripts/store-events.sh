#!/bin/zsh
# The App Store in-app event films (StoreEvents, a debug-only renderer in the app): for each event, the event card
# (1920x1080) and the details page (1080x1920), as PNG stills and seamless 10-second MP4 loops.
# usage: scripts/store-events.sh <raw folder (holds iphone/light/)> <out folder> [event]
RAW="${1:a}"; OUT="${2:a}"; ONLY="$3"
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
ARGS=(-seedDemoData -storeEventsDump "$WORK" -storeShotsSource "$RAW")
[ -n "$ONLY" ] && ARGS+=(-storeEventsOnly "$ONLY")
[ -n "$STILLS_ONLY" ] && ARGS+=(-storeEventsStillsOnly YES)
xcrun simctl launch "$UDID" com.Patani.Skinalyze "${ARGS[@]}" > /dev/null
for _ in {1..600}; do [ -f "$WORK/done.txt" ] && break; sleep 3; done
xcrun simctl terminate "$UDID" com.Patani.Skinalyze 2>/dev/null
[ -f "$WORK/done.txt" ] || { echo "rendering didn't finish"; exit 1; }
# Stills: RGB, no alpha (App Store Connect rejects transparency).
python3 - "$WORK" "$OUT" <<'PY'
import sys, glob, os
from PIL import Image
work, out = sys.argv[1:3]
for path in glob.glob(f"{work}/*.png"):
    Image.open(path).convert("RGB").save(f"{out}/{os.path.basename(path)}")
PY
[ -n "$STILLS_ONLY" ] && { ls -la "$OUT"; exit 0; }
# Loops: H.264 High, 30 fps, a silent stereo AAC track (Apple: 256 kbps AAC), fast start.
for DIR in "$WORK"/*-frames(N); do
  NAME=${DIR:t:r}; NAME=${NAME%-frames}
  "$FFMPEG" -hide_banner -loglevel error -y -framerate 30 -i "$DIR/f%04d.jpg" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest \
    -c:v libx264 -profile:v high -preset slow -crf 15 -pix_fmt yuv420p -r 30 \
    -c:a aac -b:a 256k -movflags +faststart "$OUT/$NAME.mp4"
done
ls -la "$OUT"
