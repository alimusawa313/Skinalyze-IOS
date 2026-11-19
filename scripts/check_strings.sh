#!/bin/zsh
# Keeps the string catalog complete: every user-facing string (app + SkinalyzeKit) must be in
# Skinalyze/Localizable.xcstrings with an Indonesian translation, or be marked do-not-translate.
#
# It builds once with the compiler's string extraction on, syncs any newly found keys into the catalog (existing
# translations are untouched, nothing is removed), then fails listing the keys that still need Indonesian.
#
# Usage: scripts/check_strings.sh [simulator name]     (default: iPhone 17)
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${1:-iPhone 17}"
DERIVED=".build/LocData"
CATALOG="Skinalyze/Localizable.xcstrings"

echo "▶ Extracting strings (build with SWIFT_EMIT_LOC_STRINGS)…"
xcodebuild -project Skinalyze.xcodeproj -scheme Skinalyze \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$DERIVED" SWIFT_EMIT_LOC_STRINGS=YES build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true

files=()
while IFS= read -r file; do files+=("$file"); done < <(
  find "$DERIVED/Build/Intermediates.noindex" \
    \( -path "*Skinalyze.build/*/Skinalyze.build*" -o -path "*SkinalyzeKit.build*" \) -name "*.stringsdata"
)
if (( ${#files[@]} == 0 )); then
  echo "✘ No extracted strings found — did the build fail?" >&2
  exit 1
fi

echo "▶ Syncing ${#files[@]} extraction files into $CATALOG"
xcrun xcstringstool sync "$CATALOG" --stringsdata "${files[@]}" --skip-marking-strings-stale

python3 -I - "$CATALOG" <<'PY'
import json, sys
catalog = json.load(open(sys.argv[1], encoding="utf-8"))
missing = sorted(
    key for key, entry in catalog["strings"].items()
    if entry.get("shouldTranslate", True) and "id" not in entry.get("localizations", {})
)
total = len(catalog["strings"])
if missing:
    print(f"✘ {len(missing)} of {total} strings have no Indonesian translation:")
    for key in missing:
        print(f"   {key!r}")
    sys.exit(1)
print(f"✔ All {total} strings have Indonesian (or are marked do-not-translate).")
PY
