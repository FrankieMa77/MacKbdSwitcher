#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/MacKbdGlobe.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG=dist/MacKbdGlobe-$VERSION.dmg

if [ ! -f Resources/AppIcon.icns ]; then
    swift tools/make-icon.swift Resources/AppIcon.icns
fi

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist

swiftc -O -swift-version 5 -target arm64-apple-macos14.0 \
    Sources/*.swift Sources/Core/*.swift \
    -o "$APP/Contents/MacOS/MacKbdGlobe" \
    -framework Carbon -framework IOKit -framework AppKit -framework ServiceManagement

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/ngrams-*.tsv "$APP/Contents/Resources/"

ID="${SIGN_IDENTITY:-}"
if [ -z "$ID" ]; then
    ID=$(security find-certificate -c MacKbdSwitcher -Z 2>/dev/null | awk '/SHA-1/{print $3; exit}' || true)
fi
if [ -z "$ID" ]; then
    echo "warning: no MacKbdSwitcher certificate found, using ad-hoc" >&2
    ID="-"
fi
codesign --force --options runtime --sign "$ID" "$APP"
codesign --verify --strict "$APP"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname MacKbdGlobe -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "identity: $ID"
echo "app: $PWD/$APP"
echo "dmg: $PWD/$DMG"
