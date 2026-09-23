#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/build/BeamletSandboxProbe.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.beamlet.sandbox-probe</string>
<key>CFBundleExecutable</key><string>BeamletSandboxProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
xcrun swiftc Tools/SandboxProbe/main.swift -o "$app/Contents/MacOS/BeamletSandboxProbe"
xcrun clang Sources/Runner/main.c -o "$app/Contents/Helpers/BeamletRunner"
codesign --force --sign - --entitlements Resources/Runner-AppStore.entitlements "$app/Contents/Helpers/BeamletRunner"
codesign --force --sign - --entitlements Resources/AppStore.entitlements "$app"
"$app/Contents/MacOS/BeamletSandboxProbe" "$@"
