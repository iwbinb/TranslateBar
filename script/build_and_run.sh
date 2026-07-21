#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TranslateBar"
BUNDLE_ID="com.iwbinb.TranslateBar"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TranslateBar.xcodeproj"
DERIVED_DATA="$ROOT_DIR/.build/xcode"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"
ditto "$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app" "$APP_BUNDLE"
codesign --force --deep --sign - \
  --entitlements "$ROOT_DIR/AppStore/TranslateBar.entitlements" \
  --timestamp=none \
  "$APP_BUNDLE"

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
