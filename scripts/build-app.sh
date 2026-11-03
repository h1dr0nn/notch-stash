#!/bin/zsh
# Builds "build/Notch Stash.app" (release, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Notch Stash.app"

swift build -c release -Xswiftc -warnings-as-errors
BIN="$(swift build -c release --show-bin-path)/NotchStash"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchStash"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Notch Stash</string>
    <key>CFBundleDisplayName</key><string>Notch Stash</string>
    <key>CFBundleIdentifier</key><string>local.notch-stash</string>
    <key>CFBundleExecutable</key><string>NotchStash</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature with a fixed designated requirement, so privacy permissions survive rebuilds.
codesign --force --sign - --requirements '=designated => identifier "local.notch-stash"' "$APP"
echo "Built $APP ($VERSION)"
