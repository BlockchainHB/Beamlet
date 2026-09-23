"""Fail closed on release packaging, signing and optional notarization checks."""
import argparse
import plistlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', type=Path)
parser.add_argument('--unsigned', action='store_true', help='Validate archive layout only; not releasable')
parser.add_argument('--notarized', action='store_true', help='Also require stapling and Gatekeeper acceptance')
args = parser.parse_args()
if args.unsigned and args.notarized:
    parser.error('--unsigned and --notarized cannot be combined')
app = args.app.resolve()

def run(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT)

def require(condition, message):
    if not condition:
        raise SystemExit('FAIL: ' + message)

info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
require(info['CFBundleIdentifier'] == 'app.beamlet.mac', 'unexpected app identifier')
require(not any('Preview' in key for key in info), 'preview configuration in app')
require(info['LSApplicationCategoryType'] == 'public.app-category.developer-tools', 'missing category')
resources = app / 'Contents/Resources'
for filename in ['PrivacyInfo.xcprivacy', 'Sparkle-LICENSE.txt', 'Beamlet-LICENSE.txt']:
    require((resources / filename).is_file(), 'missing ' + filename)
for path in [app / 'Contents/MacOS' / info['CFBundleExecutable'], app / 'Contents/Helpers/BeamletRunner']:
    require(set(run('lipo', '-archs', str(path)).split()) == {'arm64', 'x86_64'}, 'app and runner must be universal')

if args.unsigned:
    print('PASS: universal archive, identity, privacy and license resources. UNSIGNED: not releasable.')
    raise SystemExit(0)

# Inspect every Mach-O leaf, including nested Sparkle services. No --deep signing.
magics = {b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
          b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca', b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}
team = None
count = 0
for path in app.rglob('*'):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open('rb') as stream:
        if stream.read(4) not in magics:
            continue
    details = run('codesign', '-dv', '--verbose=4', str(path))
    require('Authority=Developer ID Application:' in details, 'not Developer ID signed: ' + str(path))
    require('runtime' in details and 'Timestamp=' in details, 'missing runtime/timestamp: ' + str(path))
    signed_team = next((s.split('=', 1)[1] for s in details.splitlines() if s.startswith('TeamIdentifier=')), None)
    require(bool(signed_team), 'missing team')
    if team is None:
        team = signed_team
    require(signed_team == team, 'mixed signing teams')
    ent_data = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(path)], stderr=subprocess.DEVNULL)
    ent = plistlib.loads(ent_data) if ent_data.strip() else {}
    for key in ['com.apple.security.get-task-allow', 'com.apple.security.cs.disable-library-validation',
                'com.apple.security.cs.allow-unsigned-executable-memory', 'com.apple.security.cs.disable-executable-page-protection']:
        require(not ent.get(key), 'development or weakened entitlement: ' + key)
    count += 1
require(count >= 3, 'missing app, runner or framework executable')
run('codesign', '--verify', '--deep', '--strict', '--all-architectures', str(app))
if args.notarized:
    run('xcrun', 'stapler', 'validate', str(app))
    run('spctl', '--assess', '--type', 'execute', '--verbose=4', str(app))
print(f'PASS: {count} Developer ID executables, consistent team, timestamped hardened runtime, nested signatures.'
      + (' Notarization ticket and Gatekeeper accepted.' if args.notarized else ' Notarization not checked.'))
