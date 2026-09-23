#!/bin/bash
# Local App Store compatibility archive. Not a distribution-signed submission.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project Beamlet.xcodeproj -scheme BeamletStore -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/StoreCheck \
  -archivePath build/BeamletStore.xcarchive CODE_SIGNING_ALLOWED=NO archive
app="$PWD/build/BeamletStore.xcarchive/Products/Applications/BeamletStore.app"
identity="${BEAMLET_LOCAL_SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$identity" --entitlements Resources/Runner-AppStore.entitlements "$app/Contents/Helpers/BeamletRunner"
codesign --force --options runtime --sign "$identity" --entitlements Resources/AppStore.entitlements "$app"
python3 scripts/validate-store-build.py "$app"
printf '\nLocal compatibility archive: %s\nNot distribution-signed or ready to submit.\n' "$app"
