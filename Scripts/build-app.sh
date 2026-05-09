#!/usr/bin/env bash
# Build script: compiles the Swift package and wraps the binary into a .app bundle.
# Without full Xcode we cannot produce a notarized build, but this produces a
# locally-runnable app with ad-hoc code signing — enough for development.
set -euo pipefail

CONFIG="${1:-release}"           # debug | release
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Free Mac Screen Recorder"
EXEC_NAME="FreeMacScreenRecorder"
BUNDLE_ID="com.freemacscreenrecorder.app"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

echo "==> Building Swift package ($CONFIG)..."
cd "$ROOT"
swift build -c "$CONFIG" --arch arm64

BIN_PATH="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"
BIN="$BIN_PATH/$EXEC_NAME"
test -f "$BIN" || { echo "Binary not found at $BIN"; exit 1; }

echo "==> Assembling .app bundle at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$EXEC_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# PkgInfo (legacy but expected)
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "==> Ad-hoc code signing (development only)..."
codesign --force --deep --sign - \
    --entitlements "$ROOT/Resources/FreeMacScreenRecorder.entitlements" \
    --options runtime \
    "$APP_DIR" || {
        echo "WARN: ad-hoc signing failed; bundle is unsigned." >&2
    }

echo ""
echo "✓ Built: $APP_DIR"
echo ""
echo "Run with:  open \"$APP_DIR\""
echo "Or:        \"$APP_DIR/Contents/MacOS/$EXEC_NAME\""
echo ""
echo "First launch: macOS will prompt for Screen Recording, Camera, Microphone"
echo "permissions. Grant them in System Settings → Privacy & Security, then"
echo "relaunch the app."
