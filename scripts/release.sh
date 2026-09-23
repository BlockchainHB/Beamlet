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
    # Xcode's exporter preserves code-signing flags from the archive. Seed
    # hardened runtime on our otherwise unsigned executables before export.
    archive_app="$archive/Products/Applications/Beamlet.app"
    codesign --force --sign - --options runtime "$archive_app/Contents/Helpers/BeamletRunner"
    codesign --force --sign - --options runtime "$archive_app"
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
  notarize-xcode)
    # Reuse Xcode's signed-in account; no password or API key is read by this script.
    python3 scripts/validate-release.py "$app"
    python3 - <<'PY'
import plistlib
from pathlib import Path
options=plistlib.loads(Path('build/DeveloperID-ExportOptions.plist').read_bytes())
options['destination']='upload'
Path('build/Notarize-ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
    xcodebuild -exportArchive -archivePath "$archive" \
      -exportOptionsPlist build/Notarize-ExportOptions.plist -exportPath build/NotaryExport
    echo 'Uploaded. Use finish-notarization-xcode after Apple finishes processing; do not resubmit.'
    ;;
  finish-notarization-xcode)
    xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath build/Notarized
    python3 scripts/validate-release.py build/Notarized/Beamlet.app --notarized
    ditto build/Notarized/Beamlet.app "$app"
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
    echo 'Usage: bash scripts/release.sh {archive|export|notarize-xcode|finish-notarization-xcode|notarize|finish-notarization|package}'
    echo 'See docs/DIRECT-RELEASE.md. Publication is a separate, explicit operation.'
    ;;
esac
