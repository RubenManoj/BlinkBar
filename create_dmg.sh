#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0"
APP_NAME="BlinkBar"
APP_PATH=".build/release/${APP_NAME}.app"
DIST_DIR="dist"
DMG_ROOT=".build/dmg-root"
RW_DMG="${DIST_DIR}/${APP_NAME}-${VERSION}-rw.dmg"
FINAL_DMG="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

if [[ ! -d "$APP_PATH" ]]; then
  ./build_app.sh
fi

rm -rf "$DMG_ROOT" "$RW_DMG" "$FINAL_DMG"
mkdir -p "$DIST_DIR" "$DMG_ROOT"

cp -R "$APP_PATH" "$DMG_ROOT/${APP_NAME}.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$FINAL_DMG" >/dev/null

rm -f "$RW_DMG"

echo "Created: $FINAL_DMG"
