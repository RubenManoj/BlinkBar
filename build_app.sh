#!/usr/bin/env bash
set -euo pipefail

swift build -c release

APP_DIR=".build/release/BlinkBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR=".build/BlinkBar.iconset"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp ".build/release/BlinkBar" "$MACOS_DIR/BlinkBar"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 Assets/AppIcon.png --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 Assets/AppIcon.png --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 Assets/AppIcon.png --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 Assets/AppIcon.png --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 Assets/AppIcon.png --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 Assets/AppIcon.png --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 Assets/AppIcon.png --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 Assets/AppIcon.png --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 Assets/AppIcon.png --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 Assets/AppIcon.png --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>BlinkBar</string>
  <key>CFBundleIdentifier</key>
  <string>personal.BlinkBar</string>
  <key>CFBundleName</key>
  <string>BlinkBar</string>
  <key>CFBundleDisplayName</key>
  <string>BlinkBar</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSUserNotificationAlertStyle</key>
  <string>alert</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

echo "Built: $APP_DIR"
