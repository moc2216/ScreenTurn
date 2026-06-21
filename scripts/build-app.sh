#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_ARCH="${BUILD_ARCH:-}"
APP_NAME="ScreenTurn"
APP_IDENTIFIER="${APP_IDENTIFIER:-com.salt.ScreenTurn}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

SWIFT_BUILD_ARGS=(-c "$CONFIGURATION")
if [[ -n "$BUILD_ARCH" ]]; then
  SWIFT_BUILD_ARGS+=(--arch "$BUILD_ARCH")
fi

swift build "${SWIFT_BUILD_ARGS[@]}" --product ScreenTurnApp
swift build "${SWIFT_BUILD_ARGS[@]}" --product screenturn

BIN_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
CLI_BINARY="$BIN_DIR/screenturn"

if [[ ! -x "$CLI_BINARY" ]]; then
  CLI_BINARY="$BIN_DIR/ScreenTurnCLI"
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

install -m 755 "$BIN_DIR/ScreenTurnApp" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/assets/ScreenTurn.icns" "$APP_DIR/Contents/Resources/ScreenTurn.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>ScreenTurn</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Built $APP_DIR"
echo "CLI binary: $CLI_BINARY"
