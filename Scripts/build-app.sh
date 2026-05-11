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

cd "$PROJECT_ROOT"

# 1. Genereer Xcode project via xcodegen (idempotent)
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Fout: xcodegen niet gevonden. Installeer met: brew install xcodegen"
    exit 1
fi

echo "==> Generating Xcode project via xcodegen..."
xcodegen generate

# 2. Genereer app icons als ze nog niet bestaan
ICON_DIR="$PROJECT_ROOT/RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset"
if [ ! -f "$ICON_DIR/icon_512x512@2x.png" ]; then
    echo "==> Generating app icons..."
    swift Scripts/generate-app-icon.swift
fi

# 3. Bouw met xcodebuild
echo "==> Building $SCHEME ($CONFIG) ..."
mkdir -p "$BUILD_DIR"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/Radio Naoufal.app"
if [ ! -d "$APP_PATH" ]; then
    # Fallback to underscore name
    APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/RadioNaoufal.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Fout: kon gebouwde .app niet vinden in $DERIVED_DATA"
    exit 1
fi

DEST="$BUILD_DIR/Radio Naoufal.app"
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"
echo "==> App gebouwd: $DEST"
