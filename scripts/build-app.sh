#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
ICON_DIR="$ROOT_DIR/.build/brand"
ICON_PATH="$ICON_DIR/AppIcon.icns"
APP_DIR="$ROOT_DIR/dist/FindKey.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$ROOT_DIR/dist"
mkdir -p "$ICON_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICON_PATH"
swift build -c release --package-path "$ROOT_DIR"
cp "$BUILD_DIR/FindKey" "$MACOS_DIR/FindKey"
chmod +x "$MACOS_DIR/FindKey"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>FindKey</string>
  <key>CFBundleIdentifier</key>
  <string>org.bssmoss.findkey</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>FindKey</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

echo "Built unsigned app bundle: $APP_DIR"
