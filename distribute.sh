#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0"
APP_NAME="BlinkBar"
APP_PATH=".build/release/${APP_NAME}.app"
DIST_DIR="dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

./build_app.sh

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Keep the app bundle layout without adding AppleDouble resource-fork files.
ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$ZIP_PATH"
./create_dmg.sh

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Created: $ZIP_PATH"
echo "Created: $DMG_PATH"
