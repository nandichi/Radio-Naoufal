#!/usr/bin/env bash
# Bouwt Radio Naoufal als een redistributable .app bundle.
# Vereist: volledige Xcode + xcodegen (`brew install xcodegen`).
#
# Output: build/RadioNaoufal.app
#
# Gebruik: ./Scripts/build-app.sh [Debug|Release]

set -euo pipefail

CONFIG="${1:-Release}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA="$PROJECT_ROOT/build/DerivedData"
SCHEME="RadioNaoufal"
PROJECT="RadioNaoufal.xcodeproj"
ENTITLEMENTS="$PROJECT_ROOT/RadioNaoufal/RadioNaoufal.entitlements"

cd "$PROJECT_ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Fout: xcodegen niet gevonden. Installeer met: brew install xcodegen"
    exit 1
fi

echo "==> Generating Xcode project via xcodegen..."
xcodegen generate

ICON_DIR="$PROJECT_ROOT/RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset"
if [ ! -f "$ICON_DIR/icon_512x512@2x.png" ]; then
    echo "==> Generating app icons..."
    swift Scripts/generate-app-icon.swift
fi

# Bouw zonder signing - we doen ad-hoc signing zelf in een post-build step.
# Dat is robuuster dan xcodebuild's automatische signing zonder Developer ID.
echo "==> Building $SCHEME ($CONFIG) ..."
mkdir -p "$BUILD_DIR"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/Radio Naoufal.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/RadioNaoufal.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Fout: kon gebouwde .app niet vinden in $DERIVED_DATA"
    exit 1
fi

DEST="$BUILD_DIR/Radio Naoufal.app"
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"

# Kritisch: ad-hoc signing MET hardened runtime + entitlements.
# Zonder deze stap wordt de app op macOS Tahoe (en strikt op macOS 15+) direct
# door de kernel gekilt wegens "code signature invalid" - het project heeft
# ENABLE_HARDENED_RUNTIME=YES en een hardened-runtime binary zonder enige
# (zelfs ad-hoc) signature wordt onmiddellijk geweigerd door SIP.
#
# We zetten quarantine attribuut UIT op de gebouwde app zelf zodat lokaal
# openen geen Gatekeeper-popup geeft. Bij download via DMG voegt macOS
# alsnog quarantine toe; daarvoor staat in de DMG een 'EERSTE GEBRUIK.txt'.
echo "==> Ad-hoc signing met hardened runtime + entitlements..."
# Eerst eventuele bestaande quarantine attrs verwijderen
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

if [ ! -f "$ENTITLEMENTS" ]; then
    echo "Fout: entitlements bestand niet gevonden op $ENTITLEMENTS"
    exit 1
fi

codesign --force --deep \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp=none \
    "$DEST"

# Verifieer dat de signature klopt; faal hard als dat niet zo is.
echo "==> Verificatie codesign..."
codesign --verify --deep --strict --verbose=2 "$DEST"

echo "==> App gebouwd en getekend: $DEST"
