"""Bind the validated Codemagic widget profile on the TestFlight build machine."""
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from tempfile import NamedTemporaryFile
from uuid import UUID

APP = "com.bilux.nuclearascension"
WATCH = APP + ".watchkitapp"
WIDGET = WATCH + ".nuclearlivewidget"
GROUP = "group.com.bilux.nuclearascension.watchshared"
PROJECT = "BiluxIOS.xcodeproj"
TARGET = "BiluxWatchWidget"


def check(condition, message):
    if not condition:
        raise ValueError(message)


def load_profile(path, bundle, team):
    check(path.is_file(), f"{bundle} : fichier de profil introuvable ({path.name}).")
    # Verify the embedded content signature. Xcode performs Apple's signing trust checks.
    result = subprocess.run(
        ["openssl", "smime", "-verify", "-inform", "DER", "-noverify", "-in", str(path)],
        capture_output=True,
    )
    check(result.returncode == 0, f"{bundle} : impossible de lire le profil CMS signé.")
    profile = plistlib.loads(result.stdout)
    ent = profile["Entitlements"]
    uuid = str(UUID(profile["UUID"]))
    name = profile["Name"]
    print(f"{bundle} : {name} [{uuid}]", flush=True)
    check(team in profile["TeamIdentifier"], f"{bundle} : équipe différente de celle de l’export.")
    app_id = ent.get("application-identifier") or ent.get("com.apple.application-identifier")
    check(app_id == team + "." + bundle, f"{bundle} : App ID du fichier reçu = {app_id!r}.")
    check(GROUP in ent.get("com.apple.security.application-groups", []),
          f"{bundle} : le profil {uuid} ne contient pas {GROUP}.")
    check(ent.get("get-task-allow") is False and "ProvisionedDevices" not in profile
          and not profile.get("ProvisionsAllDevices"), f"{bundle} : profil de distribution requis.")
    check(profile["ExpirationDate"].replace(tzinfo=dt.timezone.utc) > dt.datetime.now(dt.timezone.utc),
          f"{bundle} : le profil a expiré.")
    return name, uuid


# xcodeproj edits the target by name, independent of whitespace after use-profiles.
CONFIGURE_WIDGET = """
require 'xcodeproj'
project_path, target_name, team, uuid = ARGV
project = Xcodeproj::Project.open(project_path)
targets = project.targets.select { |t| t.name == target_name }
abort "Cible widget introuvable ou ambiguë" unless targets.size == 1
target = targets.first
abort "Configuration Release introuvable" unless target.build_configurations.any? { |c| c.name == 'Release' }
target.build_configurations.each do |config|
  next unless ['Debug', 'Release'].include?(config.name)
  settings = config.build_settings
  keys = %w[CODE_SIGN_STYLE CODE_SIGN_IDENTITY DEVELOPMENT_TEAM PROVISIONING_PROFILE PROVISIONING_PROFILE_SPECIFIER]
  settings.delete_if { |key, _| keys.include?(key.split('[').first) }
  settings.merge!('CODE_SIGN_STYLE' => 'Manual', 'CODE_SIGN_IDENTITY' => 'Apple Distribution',
                  'DEVELOPMENT_TEAM' => team, 'PROVISIONING_PROFILE_SPECIFIER' => uuid)
end
project.save
"""


def prepare_export(options, watch, widget):
    mapping = options["provisioningProfiles"]
    check(mapping.get(APP), "Le profil iPhone manque dans les options d’export Codemagic.")
    check(mapping.get(WATCH) in watch,
          f"Watch : le profil choisi par Codemagic ({mapping.get(WATCH)!r}) diffère du profil vérifié.")
    mapping[WIDGET] = widget[1]


def run():
    export = Path.home() / "export_options.plist"
    options = plistlib.loads(export.read_bytes())
    team = options["teamID"]
    check(re.fullmatch(r"[A-Z0-9]{10}", team), "Identifiant d’équipe Apple invalide.")
    watch = load_profile(Path(os.environ["BILUX_WATCH_PROFILE_PATH"]), WATCH, team)
    widget = load_profile(Path(os.environ["BILUX_WIDGET_PROFILE_PATH"]), WIDGET, team)
    prepare_export(options, watch, widget)

    subprocess.run(["ruby", "-e", CONFIGURE_WIDGET, PROJECT, TARGET, team, widget[1]], check=True)
    raw = subprocess.check_output(["xcodebuild", "-project", PROJECT, "-target", TARGET,
                                   "-configuration", "Release", "-sdk", "watchos",
                                   "-showBuildSettings", "-json"])
    records = [r["buildSettings"] for r in json.loads(raw) if r.get("target") == TARGET]
    check(len(records) == 1, "Xcode ne retourne pas la configuration Release du widget.")
    for key, value in {"PRODUCT_BUNDLE_IDENTIFIER": WIDGET, "CODE_SIGN_STYLE": "Manual",
                       "PROVISIONING_PROFILE_SPECIFIER": widget[1], "DEVELOPMENT_TEAM": team}.items():
        check(records[0].get(key) == value, f"Widget Release : valeur Xcode inattendue pour {key}.")
    with NamedTemporaryFile(dir=export.parent, delete=False) as tmp:
        plistlib.dump(options, tmp)
        staged = Path(tmp.name)
    staged.replace(export)
    print(f"Widget Release et export TestFlight configurés avec le profil {widget[1]}.", flush=True)


if __name__ == "__main__":
    try:
        run()
    except (KeyError, ValueError, OSError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        sys.exit(f"Signature BILUX : {error}")
