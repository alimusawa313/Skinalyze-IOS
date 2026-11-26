#!/bin/sh
# Xcode Cloud: the Xcode project is generated from project.yml (XcodeGen) and isn't in git, so make it right after
# the clone, before Xcode Cloud looks for Skinalyze.xcodeproj.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"
if ! command -v xcodegen > /dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen
fi
xcodegen generate --spec project.yml
ls -d Skinalyze.xcodeproj
