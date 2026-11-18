#!/usr/bin/env bash
# One-command local verification: package tests (fast, host Mac) + app build and app-hosted tests (simulator)
# + copy lint report. Usage: scripts/test.sh [simulator name]   (default: iPhone 17)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIMULATOR="${1:-iPhone 17}"
DERIVED="${DERIVED_DATA:-$ROOT/.build/DerivedData}"

echo "▶ SkinalyzeKit (swift test)"
(cd "$ROOT/SkinalyzeKit" && swift test)

echo "▶ Generate project"
(cd "$ROOT" && xcodegen generate --quiet)

echo "▶ App build + tests on $SIMULATOR"
xcodebuild -project "$ROOT/Skinalyze.xcodeproj" -scheme Skinalyze \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$DERIVED" test CODE_SIGNING_ALLOWED=NO

echo "▶ Copy lint (report)"
python3 -I "$ROOT/scripts/lint_copy.py" --report "$ROOT/Skinalyze"
