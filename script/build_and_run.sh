#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TranslateBar"
BUNDLE_ID="com.translatebar.app"
APP_VERSION="0.1.0"
BUILD_VERSION="1"
MIN_SYSTEM_VERSION="14.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build --package-path "$ROOT_DIR"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Assets/TranslateBarAppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>TranslateBar uses the microphone to dictate text for translation.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>TranslateBar uses speech recognition to turn dictated words into text.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSServices</key><array><dict>
    <key>NSMenuItem</key><dict><key>default</key><string>Translate selection with TranslateBar</string></dict>
    <key>NSMessage</key><string>performTranslateService</string>
    <key>NSPortName</key><string>TranslateBarService</string>
    <key>NSSendTypes</key><array><string>NSStringPboardType</string></array>
  </dict></array>
</dict></plist>
PLIST

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }
case "$MODE" in
  run) open_app ;;
  --package-only|package-only) ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--package-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
