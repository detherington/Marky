#!/bin/bash
set -euo pipefail

# Parse flags
SKIP_NOTARIZE=false
for arg in "$@"; do
    case $arg in
        --skip-notarize) SKIP_NOTARIZE=true ;;
    esac
done

# --- Configuration ---
APP_NAME="Marky"
BUNDLE_ID="com.marky.app"
VERSION="1.0.4"
SHORT_VERSION="1.0.4"
MIN_MACOS="14.0"
SIGNING_IDENTITY="Developer ID Application: Darrell Etherington (8B29CDK832)"
NOTARIZE_PROFILE="notary"

# Sparkle config
SPARKLE_FEED_URL="https://detherington.github.io/Marky/appcast.xml"
SPARKLE_PUBLIC_KEY="ODjAca9kR1OJ8SuY35WtdhSjO7BM+sPltxEVWNBjqyo="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "==> Building $APP_NAME release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Find the built binary and resource bundle
RELEASE_DIR="$(swift build -c release --show-bin-path)"
BINARY="$RELEASE_DIR/$APP_NAME"
RESOURCE_BUNDLE="$RELEASE_DIR/${APP_NAME}_${APP_NAME}.bundle"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "==> Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Add rpath so the binary can find Sparkle.framework in Contents/Frameworks/
# (SPM doesn't set this automatically — the default rpath is Contents/MacOS/)
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>&1 || \
    echo "    (rpath may already exist)"

# Copy resource bundle (contains WebView HTML/JS/CSS and icon)
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "    Copied resource bundle"
fi

# Copy icon to Resources for Info.plist CFBundleIconFile
ICON_SOURCE="$PROJECT_DIR/Sources/MarkdownEditor/App/AppIcon.icns"
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "    Copied app icon"
fi

# Embed Sparkle.framework into Contents/Frameworks/
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_SRC="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_SRC" ]; then
    cp -R "$SPARKLE_SRC" "$APP_BUNDLE/Contents/Frameworks/"
    echo "    Embedded Sparkle.framework"
else
    echo "ERROR: Sparkle.framework not found at $SPARKLE_SRC"
    echo "       Run 'swift package resolve' first"
    exit 1
fi

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.plain-text</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdown</string>
                <string>mkd</string>
                <string>txt</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST
echo "    Wrote Info.plist"

# Write PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> App bundle created: $APP_BUNDLE"

# --- Code Sign ---
echo "==> Signing app bundle..."

# Create entitlements file (needed for hardened runtime)
ENTITLEMENTS="$BUILD_DIR/entitlements.plist"
cat > "$ENTITLEMENTS" << ENTPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
</dict>
</plist>
ENTPLIST

# Sign Sparkle's inner components first (XPC services, Autoupdate, Updater)
# These must be signed individually before the outer framework/app for hardened runtime.
SPARKLE_FW="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
SPARKLE_INNER="$SPARKLE_FW/Versions/B"

if [ -d "$SPARKLE_INNER/XPCServices" ]; then
    for xpc in "$SPARKLE_INNER/XPCServices"/*.xpc; do
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" "$xpc"
    done
    echo "    Signed Sparkle XPC services"
fi

# Autoupdate is a standalone binary (helper process), not an .app
if [ -f "$SPARKLE_INNER/Autoupdate" ]; then
    codesign --force --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" "$SPARKLE_INNER/Autoupdate"
    echo "    Signed Sparkle Autoupdate"
fi

# Updater.app is a bundle — signing the bundle recursively handles its binary
if [ -d "$SPARKLE_INNER/Updater.app" ]; then
    codesign --force --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" "$SPARKLE_INNER/Updater.app"
    echo "    Signed Sparkle Updater.app"
fi

# Sign the Sparkle framework itself
codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" "$SPARKLE_FW"
echo "    Signed Sparkle.framework"

# Sign the main app bundle with hardened runtime + entitlements
# (not using --deep because we already signed the framework explicitly)
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_BUNDLE"
echo "    Signed app bundle"

# Verify the signature
codesign --verify --deep --strict "$APP_BUNDLE" 2>&1
echo "    Signature verified"

# --- Create styled DMG ---
echo "==> Creating styled DMG..."
rm -f "$DMG_PATH"

DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_TEMP="$BUILD_DIR/${APP_NAME}_temp.dmg"
BG_IMAGE="$SCRIPT_DIR/dmg-resources/background.png"
DMG_WINDOW_W=660
DMG_WINDOW_H=440
ICON_SIZE=128

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy the app and create Applications symlink
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Create a read-write DMG first so we can style it
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDRW \
    "$DMG_TEMP" 2>&1

rm -rf "$DMG_STAGING"

# Detach any previously mounted volumes with the same name
hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true
sleep 1

# Mount the read-write DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)
echo "    Mounted at: $MOUNT_DIR"

# Copy background image into a hidden folder
mkdir -p "$MOUNT_DIR/.background"
cp "$BG_IMAGE" "$MOUNT_DIR/.background/background.png"

# Use AppleScript to style the DMG Finder window
echo "    Applying visual styling..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, $((100 + DMG_WINDOW_W)), $((100 + DMG_WINDOW_H))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 13
        set label position of viewOptions to bottom
        set background picture of viewOptions to file ".background:background.png"
        -- Position app icon on the left, Applications on the right
        set position of item "$APP_NAME.app" of container window to {165, 195}
        set position of item "Applications" of container window to {495, 195}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Also manually set .DS_Store dark mode background hint via Python
python3 -c "
import struct, os
# Touch the .DS_Store to force Finder to re-read it on next open
ds_store = '$MOUNT_DIR/.DS_Store'
if os.path.exists(ds_store):
    os.utime(ds_store)
" 2>/dev/null || true

# Make sure Finder writes .DS_Store
sync

# Detach
hdiutil detach "$MOUNT_DIR" 2>&1

# Convert to compressed read-only DMG
rm -f "$DMG_PATH"
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH" 2>&1
rm -f "$DMG_TEMP"

# Sign the DMG itself
echo "==> Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
echo "    DMG signed"

# --- Notarize ---
if [ "$SKIP_NOTARIZE" = "true" ]; then
    echo "==> Skipping notarization (--skip-notarize flag)"
else
    echo "==> Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait 2>&1

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH" 2>&1
fi

echo ""
echo "==> Done! App is built, signed$([ "$SKIP_NOTARIZE" = "true" ] || echo ", notarized") and ready."
echo "    App:  $APP_BUNDLE"
echo "    DMG:  $DMG_PATH"
echo ""
echo "    To install: open $DMG_PATH and drag $APP_NAME to Applications"
