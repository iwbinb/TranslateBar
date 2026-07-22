#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TranslateBar.xcodeproj"
APP_BUNDLE="$ROOT_DIR/dist/TranslateBar.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/TranslateBar"
PRIVACY_MANIFEST="$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
ARCHIVE_PATH="$ROOT_DIR/.build/archive/TranslateBar.xcarchive"
ENTITLEMENTS_OUTPUT="$ROOT_DIR/.build/verified-entitlements.plist"

swift test --package-path "$ROOT_DIR"
"$ROOT_DIR/script/build_and_run.sh" --package-only
xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme TranslateBar \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  archive

plutil -lint "$INFO_PLIST"
plutil -lint "$ROOT_DIR/AppStore/PrivacyInfo.xcprivacy"
plutil -lint "$ROOT_DIR/AppStore/TranslateBar.entitlements"
test "$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")" = "TranslateBar"
test "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" = "com.iwbinb.TranslateBar"
test "$(plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" = "TranslateBar"
test "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" = "0.2.0"
test "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" = "2"
test "$(plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST")" = "15.0"
test "$(plutil -extract LSUIElement raw "$INFO_PLIST")" = "true"
test "$(plutil -extract NSServices.0.NSMenuItem.default raw "$INFO_PLIST")" = "Translate selection with TranslateBar"
test -x "$APP_BINARY"
test -f "$PRIVACY_MANIFEST"
test -d "$ARCHIVE_PATH/Products/Applications/TranslateBar.app"
codesign --verify --deep --strict "$APP_BUNDLE"
codesign -d --entitlements :- "$APP_BUNDLE" >"$ENTITLEMENTS_OUTPUT" 2>/dev/null
test "$(plutil -extract 'com\.apple\.security\.app-sandbox' raw "$ENTITLEMENTS_OUTPUT")" = "true"
test "$(plutil -extract 'com\.apple\.security\.device\.audio-input' raw "$ENTITLEMENTS_OUTPUT")" = "true"

if rg -n -i "[T]ransBar|Translate[[:space:]]+Tab|translate\.google|googleapis" \
  "$ROOT_DIR/Package.swift" "$ROOT_DIR/Sources" "$ROOT_DIR/AppStore" "$ROOT_DIR/script" "$ROOT_DIR/README.md" "$ROOT_DIR/PRIVACY.md" \
  --glob '!verify_all.sh'; then
  echo "Legacy product branding remains in product files." >&2
  exit 1
fi

echo "TranslateBar verification passed."
