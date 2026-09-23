#!/bin/bash
# Explicit stages: never publish an unsigned or unnotarized app.
set -euo pipefail
cd "$(dirname "$0")/.."
archive="$PWD/build/Beamlet.xcarchive"
export_dir="$PWD/build/DeveloperID"
app="$export_dir/Beamlet.app"
case "${1:-help}" in
  archive)
    xcodegen generate
    xcodebuild -project Beamlet.xcodeproj -scheme Beamlet -configuration Release \
      -destination 'generic/platform=macOS' -derivedDataPath build/DirectRelease \
      -archivePath "$archive" CODE_SIGNING_ALLOWED=NO archive
    python3 scripts/validate-release.py "$archive/Products/Applications/Beamlet.app" --unsigned
    ;;
  export)
    : "${BEAMLET_TEAM_ID:?Set your Apple Developer Team ID}"
    # A pre-existing Developer ID certificate with its private key is required.
    security find-identity -v -p codesigning | grep -q 'Developer ID Application:' || {
      echo 'Missing Developer ID Application signing identity. Create it in Xcode first.' >&2; exit 1;
    }
    python3 - "$BEAMLET_TEAM_ID" <<'PY'
import plistlib, sys
from pathlib import Path
options={'method':'developer-id','destination':'export','signingStyle':'manual',
         'signingCertificate':'Developer ID Application','teamID':sys.argv[1]}
Path('build/DeveloperID-ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
    xcodebuild -exportArchive -archivePath "$archive" \
      -exportPath "$export_dir" -exportOptionsPlist build/DeveloperID-ExportOptions.plist
    python3 scripts/validate-release.py "$app"
    ;;
  notarize)
    : "${BEAMLET_NOTARY_PROFILE:?Set the name of an existing notarytool Keychain profile}"
    python3 scripts/validate-release.py "$app"
    ditto -c -k --sequesterRsrc --keepParent "$app" build/Beamlet-notarization.zip
    # Submission is separate from waiting, so an interrupted wait does not resubmit.
    xcrun notarytool submit build/Beamlet-notarization.zip \
      --keychain-profile "$BEAMLET_NOTARY_PROFILE" --output-format json > build/notarization-submission.json
    python3 - <<'PY'
import json
from pathlib import Path
print('Submitted:',json.loads(Path('build/notarization-submission.json').read_text())['id'])
print('Run the finish-notarization stage to wait for this submission.')
PY
    ;;
  finish-notarization)
    : "${BEAMLET_NOTARY_PROFILE:?Set the name of an existing notarytool Keychain profile}"
    submission_id="$(python3 -c 'import json; print(json.load(open("build/notarization-submission.json"))["id"])')"
    xcrun notarytool wait "$submission_id" --keychain-profile "$BEAMLET_NOTARY_PROFILE" \
      --output-format json > build/notarization-result.json
    python3 - <<'PY'
import json
from pathlib import Path
r=json.loads(Path('build/notarization-result.json').read_text())
if r.get('status')!='Accepted': raise SystemExit('Not accepted. Inspect the submission log before retrying.')
PY
    xcrun stapler staple "$app"
    python3 scripts/validate-release.py "$app" --notarized
    ;;
  package)
    python3 scripts/validate-release.py "$app" --notarized
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unexpected version'; exit 1; }
    mkdir -p build/release
    asset="Beamlet-$version-universal.zip"
    ditto -c -k --sequesterRsrc --keepParent "$app" "build/release/$asset"
    (cd build/release && shasum -a 256 "$asset" > "$asset.sha256")
    printf 'Verified release assets: build/release/%s and .sha256\n' "$asset"
    ;;
  *)
    echo 'Usage: bash scripts/release.sh {archive|export|notarize|finish-notarization|package}'
    echo 'See docs/DIRECT-RELEASE.md. Publication is a separate, explicit operation.'
    ;;
esac
