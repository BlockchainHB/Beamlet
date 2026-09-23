#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The Xcode 27 SwiftPM backend currently stamps these executables with the
# deployment target as their SDK version, opting AppKit into legacy appearance.
# Use the native backend so LC_BUILD_VERSION records the actual selected SDK.
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift build --build-system native --sdk "$sdk_path" --product Beamlet
swift build --build-system native --sdk "$sdk_path" --product BeamletRunner
bin="$(swift build --build-system native --sdk "$sdk_path" --show-bin-path)"
app="$PWD/build/Beamlet.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin/Beamlet" "$app/Contents/MacOS/Beamlet"
cp "$bin/BeamletRunner" "$app/Contents/Helpers/BeamletRunner"
framework="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
# Compile the layered Icon Composer source for system-rendered appearances.
# actool also produces the fallback .icns for macOS versions before Liquid Glass.
xcrun actool Resources/Beamlet.icon \
  --compile "$app/Contents/Resources" \
  --output-format human-readable-text \
  --app-icon Beamlet --include-all-app-icons \
  --platform macosx --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$PWD/build/icon-info.plist"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Beamlet' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier app.beamlet.mac' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.1.0' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 1' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 14.0' "$app/Contents/Info.plist"
# Local development only. Public releases use Developer ID and preserve library validation.
codesign --force --sign - "$app/Contents/Helpers/BeamletRunner"
codesign --force --sign - --entitlements Resources/Debug.entitlements "$app"
printf 'Local app: %s\n' "$app"
