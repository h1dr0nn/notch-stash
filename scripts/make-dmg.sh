#!/bin/zsh
# Packs "build/Notch Stash.app" into build/NotchStash-<version>.dmg with an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Notch Stash.app"
STAGING="build/dmg"
DMG="build/NotchStash-${VERSION}.dmg"

[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }

rm -rf -- "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Notch Stash" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
rm -rf -- "$STAGING"
echo "Built $DMG"
