#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/FindKey.app"
DMG_PATH="$ROOT_DIR/dist/FindKey-${VERSION}.dmg"
LATEST_DMG_PATH="$ROOT_DIR/dist/FindKey.dmg"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"

bash "$ROOT_DIR/scripts/build-app.sh" "$VERSION"

rm -rf "$STAGING_DIR" "$DMG_PATH" "$LATEST_DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"

hdiutil create \
  -volname "FindKey" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

cp "$DMG_PATH" "$LATEST_DMG_PATH"

echo "Built unsigned DMG: $DMG_PATH"
echo "Built latest DMG alias: $LATEST_DMG_PATH"
