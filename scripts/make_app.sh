#!/usr/bin/env bash
# Build biblego and assemble a runnable .app bundle (agent app, no Dock icon).
# Usage: scripts/make_app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="biblego"
BUNDLE_ID="com.biblego.app"
VERSION="0.1.0"

echo "▶ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_DIR/$APP_NAME"
RES_BUNDLE="$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"

[ -f "$EXEC" ] || { echo "executable not found: $EXEC"; exit 1; }
[ -d "$RES_BUNDLE" ] || { echo "resource bundle not found: $RES_BUNDLE"; exit 1; }

APP="$ROOT/build/$APP_NAME.app"
echo "▶ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/$APP_NAME"
cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>biblego</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>개역개정 © 대한성서공회. 개인 사용 전용.</string>
</dict>
</plist>
PLIST

# Sign with a stable identity so the Accessibility (TCC) grant persists across
# rebuilds. Prefer a Developer ID / Apple Development cert (override with SIGN_ID);
# fall back to ad-hoc ('-'), which resets the grant on every rebuild.
SIGN_ID="${SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' | head -1)"
fi
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)"
fi
SIGN_ID="${SIGN_ID:--}"
echo "▶ codesign ($SIGN_ID)"
codesign --force --deep --sign "$SIGN_ID" "$APP"

echo "✅ built $APP"
echo "   open with:  open \"$APP\""
