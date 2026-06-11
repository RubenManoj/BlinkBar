#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.4"
APP_NAME="BlinkBar"
APP_PATH=".build/release/${APP_NAME}.app"
DIST_DIR="dist"
DMG_ROOT=".build/dmg-root"
RW_DMG="${DIST_DIR}/${APP_NAME}-${VERSION}-rw.dmg"
FINAL_DMG="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
BACKGROUND_NAME="background.png"
BACKGROUND_PATH="${DMG_ROOT}/.background/${BACKGROUND_NAME}"

if [[ ! -d "$APP_PATH" ]]; then
  ./build_app.sh
fi

rm -rf "$DMG_ROOT" "$RW_DMG" "$FINAL_DMG"
mkdir -p "$DIST_DIR" "$DMG_ROOT"
mkdir -p "$DMG_ROOT/.background"

cp -R "$APP_PATH" "$DMG_ROOT/${APP_NAME}.app"
ln -s /Applications "$DMG_ROOT/Applications"
swift scripts/create_dmg_background.swift "$BACKGROUND_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -nobrowse)"
VOLUME_PATH="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -z "$VOLUME_PATH" ]]; then
  echo "Failed to mount writable DMG" >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 780, 520}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set background picture of theViewOptions to file ".background:$BACKGROUND_NAME"
    set position of item "${APP_NAME}.app" of container window to {145, 205}
    set position of item "Applications" of container window to {515, 205}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$VOLUME_PATH" >/dev/null

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$FINAL_DMG" >/dev/null

rm -f "$RW_DMG"

echo "Created: $FINAL_DMG"
