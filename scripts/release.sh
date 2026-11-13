#!/bin/bash
#
# Build, sign, notarize, and package a release.
#
#   scripts/release.sh 1.0.0 1
#
# Requires:
#   - "Developer ID Application" certificate in the login keychain
#   - notarytool keychain profile (xcrun notarytool store-credentials)
#   - xcodegen
#
# Outputs:
#   dist/Mullion-<version>.dmg
#   dist/Mullion-<version>.dmg.sha256
#   dist/Mullion.xcarchive
#
# It stops on the first failure. Nothing is uploaded here; see docs/WEBSITE.md.

set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <marketing-version> <build-number>}"
BUILD="${2:?usage: scripts/release.sh <marketing-version> <build-number>}"

TEAM_ID="${TEAM_ID:-NZJ6XP9B66}"
SIGN_ID="${SIGN_ID:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-mullion-notary}"
BUNDLE_ID="com.kyanhpham.mullion"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/export/Mullion.app"
ARCHIVE="dist/Mullion.xcarchive"
DMG="dist/Mullion-$VERSION.dmg"
ZIP="dist/Mullion.zip"

fail() { echo "error: $*" >&2; exit 1; }

if ! security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
    fail "no \"$SIGN_ID\" certificate found. Create one in Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates."
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    fail "notarytool profile \"$NOTARY_PROFILE\" is missing. See docs/LAUNCH.md §2."
fi

mkdir -p dist
rm -rf build/Mullion.xcarchive build/export build/dmg "$ARCHIVE" "$DMG" "$ZIP"
mkdir -p dist

echo "==> Generating project"
xcodegen generate

echo "==> Archiving $VERSION ($BUILD)"
xcodebuild archive \
    -project Mullion.xcodeproj \
    -scheme Mullion \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -destination "generic/platform=macOS" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

echo "==> Exporting Developer ID build"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist

# Sparkle ships ad-hoc signed helpers. Notarization rejects them unless they are
# re-signed with the same Developer ID and hardened runtime as the app. Sign
# inside-out, and never use --deep.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [ -d "$SPARKLE" ]; then
    echo "==> Re-signing Sparkle helpers"
    codesign -f -s "$SIGN_ID" -o runtime --timestamp "$SPARKLE/XPCServices/Installer.xpc"
    codesign -f -s "$SIGN_ID" -o runtime --timestamp \
        --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
    codesign -f -s "$SIGN_ID" -o runtime --timestamp "$SPARKLE/Autoupdate"
    codesign -f -s "$SIGN_ID" -o runtime --timestamp "$SPARKLE/Updater.app"
    codesign -f -s "$SIGN_ID" -o runtime --timestamp "$SPARKLE"
fi

echo "==> Signing app"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "get-task-allow"; then
    fail "release build carries the debug get-task-allow entitlement"
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" != "$BUNDLE_ID" ]; then
    fail "unexpected bundle identifier; TCC grants and licenses depend on $BUNDLE_ID"
fi

echo "==> Notarizing app"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Building disk image"
mkdir -p build/dmg
ditto "$APP" build/dmg/Mullion.app
ln -sfn /Applications build/dmg/Applications
hdiutil create -volname "Mullion $VERSION" -srcfolder build/dmg \
    -ov -format UDZO "$DMG"

codesign --force --sign "$SIGN_ID" --timestamp "$DMG"

echo "==> Notarizing disk image"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl -a -t open --context context:primary-signature -v "$DMG"

shasum -a 256 "$DMG" | awk '{print $1}' > "$DMG.sha256"

echo
echo "Release ready:"
echo "  $DMG"
echo "  $DMG.sha256"
echo
echo "Next:"
echo "  1. Test on a clean macOS user account (download, open, grant TCC, ⌘⇥)."
echo "  2. Generate the appcast with Sparkle's generate_appcast (docs/LAUNCH.md §7)."
echo "  3. Upload the DMG and appcast (docs/WEBSITE.md §6)."
echo "  4. Tag the release: git tag v$VERSION && git push --tags"
