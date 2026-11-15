#!/usr/bin/env python3
"""Apply the actual downloaded App Store watchOS-widget profile to the widget Release target.

Runs on the macOS Codemagic machine AFTER `xcode-project use-profiles`.
Does not handle secrets, upload files, or change profiles on Apple Developer.
"""
from __future__ import annotations
import datetime as dt
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

BUNDLE_ID = 'com.bilux.nuclearascension.watchkitapp.nuclearlivewidget'
PROJECT = Path('BiluxIOS.xcodeproj/project.pbxproj')


def fail(message: str) -> None:
    print(f'❌ Widget signing: {message}', file=sys.stderr)
    raise SystemExit(1)


def downloaded_profiles():
    home = Path.home()
    folders = [
        home / 'Library/MobileDevice/Provisioning Profiles',
        home / 'Library/Developer/Xcode/UserData/Provisioning Profiles',
    ]
    result = []
    for folder in folders:
        if folder.is_dir():
            for pattern in ('*.mobileprovision', '*.provisionprofile'):
                result.extend(folder.glob(pattern))
    return list(dict.fromkeys(result))


def find_matching_profile():
    candidates = []
    paths = downloaded_profiles()
    print(f'🔍 Provisioning profiles installed on macOS: {len(paths)}')
    for path in paths:
        proc = subprocess.run(['security', 'cms', '-D', '-i', str(path)],
                              capture_output=True)
        if proc.returncode != 0:
            continue
        try:
            profile = plistlib.loads(proc.stdout)
        except (ValueError, TypeError, plistlib.InvalidFileException):
            continue
        ents = profile.get('Entitlements', {})
        app_id = ents.get('application-identifier') or ents.get('com.apple.application-identifier', '')
        team = profile.get('TeamIdentifier', [''])
        team = team[0] if isinstance(team, list) and team else ''
        if app_id != f'{team}.{BUNDLE_ID}':
            continue
        if ents.get('get-task-allow', True) is not False:
            print('⚠️ A widget profile was found, but it is a Development profile, not App Store')
            continue
        if 'ProvisionedDevices' in profile or profile.get('ProvisionsAllDevices'):
            print('⚠️ A widget profile was found, but it is not an App Store distribution profile')
            continue
        expiry = profile.get('ExpirationDate')
        if isinstance(expiry, dt.datetime) and expiry.replace(tzinfo=dt.timezone.utc) <= dt.datetime.now(dt.timezone.utc):
            print('⚠️ An expired widget profile was found')
            continue
        candidates.append((expiry or dt.datetime.min, profile, path, team))
    if not candidates:
        fail('No App Store profile was downloaded for ' + BUNDLE_ID +
             '. Check Codemagic codemagic.yaml settings > Code signing identities; '
             'the widget profile must be available to this workflow, not only displayed in the dashboard.')
    _, profile, _, team = max(candidates, key=lambda x: x[0])
    name = profile.get('Name')
    if not name or not team or not re.fullmatch(r'[A-Z0-9]{10}', team):
        fail('Matching widget provisioning profile has an invalid Name or TeamIdentifier')
    return name, team, profile.get('UUID', '')


def apply_widget_profile(name: str, team: str) -> None:
    if not PROJECT.is_file():
        fail(f'Xcode project missing: {PROJECT}')
    content = PROJECT.read_text(encoding='utf-8')
    pat = re.compile(r'(?P<start>\b[A-F0-9]{24} /\* Release Widget \*/ = \{isa = XCBuildConfiguration; buildSettings = \{)(?P<body>.*?)(?P<end>\}; name = Release; \};)', re.S)
    matches = list(pat.finditer(content))
    if len(matches) != 1:
        fail(f'Expected exactly one BiluxWatchWidget Release configuration; got {len(matches)}')
    match = matches[0]
    body = match.group('body')
    if f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};' not in body:
        fail('The Release Widget target does not have the expected bundle identifier')
    # If xcode-project applied a different signing value, replace it only for this target.
    body = re.sub(r'(?m)^[ \t]*(?:PROVISIONING_PROFILE|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM|CODE_SIGN_IDENTITY)[ \t]*=[^;]*;\s*\n', '', body)
    if len(re.findall(r'CODE_SIGN_STYLE\s*=\s*\w+\s*;', body)) != 1:
        fail('Unexpected CODE_SIGN_STYLE setting in widget target')
    safe_name = name.replace('\\', '\\\\').replace('"', '\\"')
    body = re.sub(r'CODE_SIGN_STYLE\s*=\s*\w+\s*;',
                  'CODE_SIGN_STYLE = Manual;\n'
                  f'        DEVELOPMENT_TEAM = {team};\n'
                  '        CODE_SIGN_IDENTITY = "Apple Distribution";\n'
                  f'        PROVISIONING_PROFILE_SPECIFIER = "{safe_name}";',
                  body, count=1)
    updated = content[:match.start()] + match.group('start') + body + match.group('end') + content[match.end():]
    if content == updated:
        fail('Profile settings were not changed')
    PROJECT.write_text(updated, encoding='utf-8')
    print('✅ Applied the widget distribution profile to BiluxWatchWidget / Release')
    print('✅ No signing changes made to iPhone or BiluxWatch app targets')


if __name__ == '__main__':
    if sys.platform != 'darwin':
        fail('This script only runs on the macOS Codemagic builder')
    name, team, uuid = find_matching_profile()
    print(f'✅ Widget profile found: {name} (Team {team}, UUID {uuid})')
    apply_widget_profile(name, team)
