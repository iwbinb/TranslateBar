#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/TranslateBar.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/TranslateBar"
PACKAGED_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"

swift test --package-path "$ROOT_DIR"
"$ROOT_DIR/script/build_and_run.sh" --package-only

plutil -lint "$INFO_PLIST"
test "$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")" = "TranslateBar"
test "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" = "com.translatebar.app"
test "$(plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" = "TranslateBar"
test "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" = "0.1.0"
test "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" = "1"
test "$(plutil -extract LSUIElement raw "$INFO_PLIST")" = "true"
test "$(plutil -extract NSServices.0.NSMenuItem.default raw "$INFO_PLIST")" = "Translate selection with TranslateBar"
test -x "$APP_BINARY"
test -f "$PACKAGED_ICON"
cmp -s "$ROOT_DIR/Assets/TranslateBarAppIcon.icns" "$PACKAGED_ICON"

if rg -n -i "[T]ransBar" "$ROOT_DIR/Package.swift" "$ROOT_DIR/Sources" "$ROOT_DIR/script"; then
  echo "Legacy product branding remains in product files." >&2
  exit 1
fi

echo "TranslateBar verification passed."
