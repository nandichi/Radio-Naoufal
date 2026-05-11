#!/usr/bin/env bash
# Wikkelt de SPM-build van Radio Naoufal in een minimale .app bundle
# en start hem direct. Werkt met enkel Command Line Tools (geen Xcode).
#
# Gebruik: ./Scripts/run-app.sh [debug|release]

set -euo pipefail

CONFIG="${1:-release}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Radio Naoufal"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE_NAME="RadioNaoufal"

cd "$PROJECT_ROOT"

# 1. Bouw via SPM
echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

SPM_EXEC="$PROJECT_ROOT/.build/$CONFIG/$EXECUTABLE_NAME"
SPM_BUNDLE="$PROJECT_ROOT/.build/$CONFIG/RadioNaoufal_RadioNaoufal.bundle"

if [ ! -f "$SPM_EXEC" ]; then
    echo "Fout: executable niet gevonden op $SPM_EXEC"
    exit 1
fi

# 2. Genereer app icons als nog niet aanwezig
if [ ! -f "$PROJECT_ROOT/RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" ]; then
    echo "==> Genereren app icons..."
    swift Scripts/generate-app-icon.swift >/dev/null
fi

# 3. Maak .app bundle structuur
echo "==> Wrappen als .app bundle: $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp "$SPM_EXEC" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"

# Copy resources from SPM bundle naar Contents/Resources (flat)
if [ -d "$SPM_BUNDLE" ]; then
    cp -R "$SPM_BUNDLE/." "$APP_PATH/Contents/Resources/"
fi

# Copy app icon als .icns (genereer uit PNG set)
ICONSET_SRC="$PROJECT_ROOT/RadioNaoufal/Resources/Assets.xcassets/AppIcon.appiconset"
ICONSET_TMP="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_TMP"
mkdir -p "$ICONSET_TMP"
cp "$ICONSET_SRC/icon_16x16.png"       "$ICONSET_TMP/icon_16x16.png"
cp "$ICONSET_SRC/icon_16x16@2x.png"    "$ICONSET_TMP/icon_16x16@2x.png"
cp "$ICONSET_SRC/icon_32x32.png"       "$ICONSET_TMP/icon_32x32.png"
cp "$ICONSET_SRC/icon_32x32@2x.png"    "$ICONSET_TMP/icon_32x32@2x.png"
cp "$ICONSET_SRC/icon_128x128.png"     "$ICONSET_TMP/icon_128x128.png"
cp "$ICONSET_SRC/icon_128x128@2x.png"  "$ICONSET_TMP/icon_128x128@2x.png"
cp "$ICONSET_SRC/icon_256x256.png"     "$ICONSET_TMP/icon_256x256.png"
cp "$ICONSET_SRC/icon_256x256@2x.png"  "$ICONSET_TMP/icon_256x256@2x.png"
cp "$ICONSET_SRC/icon_512x512.png"     "$ICONSET_TMP/icon_512x512.png"
cp "$ICONSET_SRC/icon_512x512@2x.png"  "$ICONSET_TMP/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_TMP" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_TMP"

# Write Info.plist (minimal, gebruikt onze project Info.plist als basis)
cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>nl</string>
    <key>CFBundleDisplayName</key>
    <string>Radio Naoufal</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>nl.naoufal.radio-naoufal</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Radio Naoufal</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Naoufal Andichi</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Radio Naoufal gebruikt het lokale netwerk om Chromecast-apparaten te ontdekken.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_googlecast._tcp</string>
    </array>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign zodat hardened-runtime / TCC permission prompts werken
echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$APP_PATH" 2>&1 | tail -3 || true

echo ""
echo "==> App klaar: $APP_PATH"
echo "==> Starten met: open \"$APP_PATH\""
echo ""

# 4. Start de app
if [ "${OPEN_AFTER:-1}" = "1" ]; then
    open "$APP_PATH"
fi
