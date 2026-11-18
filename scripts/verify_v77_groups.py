#!/usr/bin/env python3
# Non-mutating, runs on Codemagic before archive. Never prints secrets or profile contents.
import plistlib, subprocess, datetime
from pathlib import Path
base='com.bilux.nuclearascension.watchkitapp'
group='group.com.bilux.nuclearascension.watchshared'
expected={base,base+'.nuclearlivewidget'}
found=set(); invalid=set()
for folder in ('Library/MobileDevice/Provisioning Profiles','Library/Developer/Xcode/UserData/Provisioning Profiles'):
    for path in (Path.home()/folder).glob('*'):
        if path.suffix not in ('.mobileprovision','.provisionprofile'): continue
        p=subprocess.run(['security','cms','-D','-i',str(path)],capture_output=True)
        if p.returncode: continue
        try: profile=plistlib.loads(p.stdout)
        except (ValueError, TypeError, plistlib.InvalidFileException): continue
        ent=profile.get('Entitlements',{}); team=(profile.get('TeamIdentifier') or [''])[0]
        aid=ent.get('application-identifier') or ent.get('com.apple.application-identifier','')
        bundle=aid[len(team)+1:] if team and aid.startswith(team+'.') else ''
        if bundle not in expected: continue
        expiry=profile.get('ExpirationDate')
        valid=bool(group in ent.get('com.apple.security.application-groups',[]) and ent.get('get-task-allow') is False and 'ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices') and isinstance(expiry,datetime.datetime) and expiry.replace(tzinfo=datetime.timezone.utc)>datetime.datetime.now(datetime.timezone.utc))
        if valid: found.add(bundle)
        else: invalid.add(bundle)
if found!=expected or invalid:
    raise SystemExit('App Groups : profils Watch/Widget manquants ou anciens profils concurrents. Vérifier les nouvelles références V7.7 AVANT de compiler. Les données BILUX ne sont pas concernées.')
print('App Groups : deux profils de distribution vérifiés.')
