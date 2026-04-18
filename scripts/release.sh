#!/bin/bash
# Publish a release: sign the DMG with Sparkle's EdDSA key, update the appcast,
# commit + push docs/ (which GitHub Pages serves), and create a GitHub Release
# with the DMG attached.
#
# Usage:  ./scripts/release.sh <version>    e.g.  ./scripts/release.sh 1.0.1
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.1"
    exit 1
fi

APP_NAME="Marky"
REPO="detherington/Marky"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DMG_PATH="$PROJECT_DIR/build/$APP_NAME.dmg"
APPCAST="$PROJECT_DIR/docs/appcast.xml"
RELEASE_NOTES="$PROJECT_DIR/docs/release-notes/$VERSION.html"
SIGN_UPDATE="$SCRIPT_DIR/sparkle-tools/sign_update"

# --- Preflight ---
if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: $DMG_PATH not found. Run ./scripts/build-app.sh first."
    exit 1
fi
if [ ! -f "$RELEASE_NOTES" ]; then
    echo "ERROR: Release notes not found at $RELEASE_NOTES"
    echo "       Create this file before releasing."
    exit 1
fi
if [ ! -x "$SIGN_UPDATE" ]; then
    echo "ERROR: sign_update not found at $SIGN_UPDATE"
    exit 1
fi

# Verify the DMG version matches the requested version
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$PROJECT_DIR/build/$APP_NAME.app/Contents/Info.plist" 2>/dev/null || echo "?")
if [ "$APP_VERSION" != "$VERSION" ]; then
    echo "WARNING: App version in Info.plist is '$APP_VERSION', but you requested '$VERSION'."
    echo "         Did you forget to bump VERSION in build-app.sh and rebuild?"
    read -p "Continue anyway? [y/N] " confirm
    [ "$confirm" = "y" ] || exit 1
fi

# --- Sign the DMG with Sparkle's EdDSA key ---
echo "==> Signing DMG with Sparkle EdDSA key..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH")
# sign_update outputs e.g.:  sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | sed 's/length="//;s/"//')

if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
    echo "ERROR: Failed to parse sign_update output:"
    echo "$SIGN_OUTPUT"
    exit 1
fi
echo "    edSignature: ${ED_SIGNATURE:0:30}..."
echo "    length:      $LENGTH"

# --- Update appcast.xml ---
echo "==> Updating appcast.xml..."
PUBDATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/$APP_NAME.dmg"
NOTES_URL="https://detherington.github.io/Marky/release-notes/$VERSION.html"

# Build the new <item> block
NEW_ITEM="        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>$NOTES_URL</sparkle:releaseNotesLink>
            <enclosure
                url=\"$DOWNLOAD_URL\"
                sparkle:edSignature=\"$ED_SIGNATURE\"
                length=\"$LENGTH\"
                type=\"application/octet-stream\" />
        </item>"

# Insert the new item right after <channel>...</language> (top of the list)
# Use a Python helper for reliable XML editing
python3 - "$APPCAST" "$NEW_ITEM" <<'PYEOF'
import sys, re
path, new_item = sys.argv[1], sys.argv[2]
with open(path) as f:
    xml = f.read()
# Insert after the first </language> (or after <description> if no language tag)
anchor = re.search(r'(</language>|</description>)', xml)
if not anchor:
    print("ERROR: couldn't find insertion point in appcast.xml")
    sys.exit(1)
pos = anchor.end()
out = xml[:pos] + "\n" + new_item + xml[pos:]
with open(path, 'w') as f:
    f.write(out)
print(f"    Inserted new <item> into {path}")
PYEOF

# --- Commit + push ---
echo "==> Committing and pushing docs/ changes..."
cd "$PROJECT_DIR"
git add docs/appcast.xml "docs/release-notes/$VERSION.html"
git commit -m "Release $VERSION"
git push origin main

# --- Create GitHub Release with DMG attached ---
echo "==> Creating GitHub release v$VERSION..."
gh release create "v$VERSION" "$DMG_PATH" \
    --repo "$REPO" \
    --title "$APP_NAME $VERSION" \
    --notes-file "$RELEASE_NOTES"

echo ""
echo "==> Released $APP_NAME $VERSION"
echo "    https://github.com/$REPO/releases/tag/v$VERSION"
echo ""
echo "    Existing installations will be notified of the update within 24h,"
echo "    or immediately if they use Marky > Check for Updates…"
