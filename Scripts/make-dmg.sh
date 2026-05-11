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

echo "==> Bouwen van app via build-app.sh ..."
bash Scripts/build-app.sh Release

if [ ! -d "$APP_PATH" ]; then
    echo "Fout: $APP_PATH niet gevonden"
    exit 1
fi

VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_FILE="$DIST_DIR/RadioNaoufal-$VERSION.dmg"

echo "==> Versie: $VERSION"
mkdir -p "$DIST_DIR"
rm -f "$DMG_FILE" "$DMG_TMP"

STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Strip quarantine attributen voor we de app in de DMG zetten.
# Bij download wordt quarantine toch opnieuw toegevoegd, maar zo verspreiden
# we tenminste geen onnodige quarantine flag mee.
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Instructie-bestand in de DMG voor first-launch op macOS 15+ / Tahoe.
# Een unsigned/ad-hoc-signed app krijgt op nieuwere macOS versies een
# Gatekeeper-blokkade. Dit bestand legt uit hoe gebruikers dat oplossen
# zonder dat ze de instructies in de GitHub README hoeven te zoeken.
cat > "$STAGING_DIR/EERSTE GEBRUIK - lees dit eerst.txt" <<'EOF'
EERSTE GEBRUIK VAN RADIO NAOUFAL
================================

Deze app is gratis en open-source. Omdat ik geen betaalde Apple Developer
ID heb (kost 99 euro per jaar), is de app niet "notarized" door Apple.
Daardoor toont macOS bij de eerste keer openen een waarschuwing of weigert
hij de app helemaal.

DE OPLOSSING (kost 10 seconden):

1. Sleep "Radio Naoufal.app" naar de Programma's-map.

2. Open de Terminal-app (vind je via Spotlight - cmd+spatie - "Terminal").

3. Plak het volgende commando en druk op Enter:

   xattr -dr com.apple.quarantine "/Applications/Radio Naoufal.app"

4. Klaar - de app start nu normaal vanuit Programma's of Launchpad.

ALTERNATIEF (zonder Terminal):

1. Sleep "Radio Naoufal.app" naar de Programma's-map.
2. Open Finder, ga naar Programma's.
3. RECHTS-klik op Radio Naoufal en kies "Open".
4. Klik in het dialoogvenster opnieuw op "Open".
5. Vanaf nu start de app gewoon met dubbelklikken.

Op macOS 15 (Sequoia) en macOS 26 (Tahoe) kan het zijn dat stap 4 in
het alternatief niet zichtbaar is. Dan moet je naar:

   Systeeminstellingen > Privacy & beveiliging
   Scroll naar beneden: "Radio Naoufal werd geblokkeerd..."
   Klik op "Open toch".

Bij vragen: https://github.com/naoufalandichi/Radio-Naoufal/issues
EOF

echo "==> Maken DMG ..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$DMG_TMP"

hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FILE"

rm -f "$DMG_TMP"
rm -rf "$STAGING_DIR"

# Ad-hoc sign de DMG zelf zodat de signature op het volume klopt.
# Dit voorkomt 'image not recognized' errors op nieuwere macOS versies.
codesign --force --sign - "$DMG_FILE" 2>/dev/null || true

echo ""
echo "==> DMG klaar: $DMG_FILE"
echo "==> SHA-256:"
shasum -a 256 "$DMG_FILE"
