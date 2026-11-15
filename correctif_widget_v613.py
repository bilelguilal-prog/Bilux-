from pathlib import Path
p = Path('scripts/assign_widget_signing.py')
if not p.is_file():
    raise SystemExit('❌ Fichier scripts/assign_widget_signing.py introuvable. Aucune modification.')
s = p.read_text(encoding='utf-8')
marker = 'def apply_widget_profile'
if marker not in s:
    raise SystemExit('❌ Fonction de signature introuvable. Aucune modification.')
start = s.find('    pat = re.compile(', s.index(marker))
end = s.find('    if len(matches) != 1:', start)
if start < 0 or end < 0 or end <= start:
    raise SystemExit('❌ Script différent de la version attendue. Aucune modification.')
replacement = r'''    # Identifier la vraie configuration Release depuis les références Xcode,
    # sans supposer que le commentaire s'appelle "Release Widget".
    import json
    info = subprocess.run(
        ['plutil', '-convert', 'json', '-o', '-', str(PROJECT)],
        capture_output=True, text=True
    )
    if info.returncode != 0:
        fail('Impossible de lire la structure du projet Xcode : ' + info.stderr[:500])
    objects = json.loads(info.stdout)['objects']
    widget_targets = [obj for obj in objects.values()
                      if obj.get('isa') == 'PBXNativeTarget'
                      and obj.get('name') == 'BiluxWatchWidget']
    if len(widget_targets) != 1:
        fail('La cible BiluxWatchWidget est absente ou en double')
    configs = objects[widget_targets[0]['buildConfigurationList']]['buildConfigurations']
    release_ids = [cid for cid in configs if objects[cid].get('name') == 'Release']
    if len(release_ids) != 1:
        fail('Configuration Release introuvable ou en double dans BiluxWatchWidget')
    release_id = release_ids[0]
    print('✅ Configuration Release du widget identifiée : ' + release_id)
    pat = re.compile(
        rf'(?P<start>^[ \\t]*{re.escape(release_id)}[^\\n]*=\\s*\\{{\\s*isa\\s*=\\s*XCBuildConfiguration\\s*;\\s*buildSettings\\s*=\\s*\\{{)'
        r'(?P<body>.*?)'
        r'(?P<end>\\}\\s*;\\s*name\\s*=\\s*Release\\s*;\\s*\\}\\s*;)',
        re.S | re.M
    )
    matches = list(pat.finditer(content))
'''
# The raw heredoc's escaped whitespace is normalized here for the nested code's raw regex strings.
replacement = replacement.replace('\\\\', '\\')
result = s[:start] + replacement + s[end:]
compile(result, str(p), 'exec')
p.write_text(result, encoding='utf-8')
print('✅ Recherche de configuration Release corrigée sans toucher au code de l’app.')
