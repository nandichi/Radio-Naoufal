#!/usr/bin/env bash
# Maakt een distributable .dmg installer voor Radio Naoufal.
# Voert eerst build-app.sh uit om de .app bundle te maken.
#
# Output: dist/RadioNaoufal-<version>.dmg
#
# Gebruik: ./Scripts/make-dmg.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="Radio Naoufal"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
VOLUME_NAME="$APP_NAME"
DMG_TMP="$BUILD_DIR/RadioNaoufal-temp.dmg"

cd "$PROJECT_ROOT"

# 1. Bouw de app
echo "==> Bouwen van app via build-app.sh ..."
bash Scripts/build-app.sh Release

if [ ! -d "$APP_PATH" ]; then
    echo "Fout: $APP_PATH niet gevonden"
    exit 1
fi

# 2. Lees versie uit Info.plist
VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_FILE="$DIST_DIR/RadioNaoufal-$VERSION.dmg"

echo "==> Versie: $VERSION"
mkdir -p "$DIST_DIR"
rm -f "$DMG_FILE" "$DMG_TMP"

# 3. Maak DMG staging map
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
# Symlink naar /Applications voor drag-to-install
ln -s /Applications "$STAGING_DIR/Applications"

# 4. Maak read-write DMG
echo "==> Maken DMG ..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$DMG_TMP"

# 5. Comprimeer naar read-only
hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FILE"

rm -f "$DMG_TMP"
rm -rf "$STAGING_DIR"

echo ""
echo "==> DMG klaar: $DMG_FILE"
echo "==> SHA-256:"
shasum -a 256 "$DMG_FILE"
