#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ScreenTurn"
APP_VERSION="${APP_VERSION:-0.1.0}"
RELEASE_ARCH="arm64"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/$APP_NAME-$APP_VERSION"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION-macos.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

if [[ ! "$APP_VERSION" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "APP_VERSION may only contain letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi

cd "$ROOT_DIR"
APP_VERSION="$APP_VERSION" BUILD_ARCH="$RELEASE_ARCH" ./scripts/build-app.sh

BIN_DIR="$(swift build -c release --arch "$RELEASE_ARCH" --show-bin-path)"
CLI_BINARY="$BIN_DIR/screenturn"

if [[ ! -x "$CLI_BINARY" ]]; then
  CLI_BINARY="$BIN_DIR/ScreenTurnCLI"
fi

rm -rf "$STAGE_DIR" "$ARCHIVE_PATH" "$CHECKSUM_PATH"
mkdir -p "$STAGE_DIR/bin"

ditto "$ROOT_DIR/build/$APP_NAME.app" "$STAGE_DIR/$APP_NAME.app"
install -m 755 "$CLI_BINARY" "$STAGE_DIR/bin/screenturn"
ln -s screenturn "$STAGE_DIR/bin/st"
install -m 755 "$ROOT_DIR/scripts/install.sh" "$STAGE_DIR/install.sh"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$ROOT_DIR/README.zh-CN.md" "$STAGE_DIR/README.zh-CN.md"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE"

APP_ARCHS="$(lipo -archs "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
CLI_ARCHS="$(lipo -archs "$STAGE_DIR/bin/screenturn")"
if [[ "$APP_ARCHS" != "$RELEASE_ARCH" || "$CLI_ARCHS" != "$RELEASE_ARCH" ]]; then
  echo "Expected ARM64-only release binaries, got app: $APP_ARCHS, CLI: $CLI_ARCHS" >&2
  exit 1
fi

ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$STAGE_DIR" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" > "$CHECKSUM_PATH"

echo "Built $ARCHIVE_PATH"
echo "Checksum: $CHECKSUM_PATH"
