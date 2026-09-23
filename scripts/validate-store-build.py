"""Validate store packaging, not App Review acceptance or live Claude functionality."""
import plistlib, subprocess, sys
from pathlib import Path
app=Path(sys.argv[1])
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['LSApplicationCategoryType']=='public.app-category.developer-tools'
assert not any(k.startswith(('SU','BeamletPreview','BeamletDesignPreview')) for k in info)
assert not any('sparkle' in str(p).lower() for p in app.rglob('*'))
manifest=plistlib.loads((app/'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert manifest['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons']==['CA92.1']
for path,inherit in [(app,False),(app/'Contents/Helpers/BeamletRunner',True)]:
 data=subprocess.check_output(['codesign','-d','--entitlements',':-',str(path)],stderr=subprocess.DEVNULL)
 ent=plistlib.loads(data)
 assert ent.get('com.apple.security.app-sandbox') is True,(path,ent)
 assert ent.get('com.apple.security.inherit',False)==inherit,(path,ent)
 assert not any('temporary-exception' in k or 'disable-library-validation' in k or 'get-task-allow' in k for k in ent),(path,ent)
 subprocess.run(['codesign','--verify','--strict',str(path)],check=True)
links=subprocess.check_output(['otool','-L',str(app/'Contents/MacOS'/info['CFBundleExecutable'])],text=True)
assert 'Sparkle' not in links
print('PASS: sandbox + helper inheritance, signatures, privacy manifest, category, no Sparkle, no preview keys or exception entitlements.')
print('NOT VALIDATED: external CLI grants, sign-in, live Remote Control, distribution signing or review eligibility.')
