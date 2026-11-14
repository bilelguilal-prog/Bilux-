from pathlib import Path
from hashlib import sha1
import json, textwrap
root=Path(__file__).parent
src=root/'BiluxIOS'
proj=root/'BiluxIOS.xcodeproj'
# V4.1 : ce vieux générateur mono-cible ne doit jamais écraser le projet watchOS.
# Conserver le project.pbxproj livré, qui contient les cibles BiluxIOS et BiluxWatch.
if (proj/'project.pbxproj').exists():
 print('Le projet Xcode existe déjà. Génération ignorée pour préserver BiluxWatch.')
 raise SystemExit(0)
proj.mkdir(exist_ok=True)
files=['BiluxApp.swift','Models.swift','BiluxStore.swift','V3Import.swift','HealthKitManager.swift','BiluxScreens.swift','EntryForms.swift','Assets.xcassets','BiluxIOS.entitlements']
getid=lambda s:sha1(s.encode('utf8')).hexdigest()[:24].upper()
ids={f:getid('REF '+f) for f in files}
buildids={f:getid('BUILD '+f) for f in files[:-1]}
projectid=getid('PROJECT'); targetid=getid('TARGET'); mainid=getid('GROUPMAIN'); appgrp=getid('APPGROUP'); prodsid=getid('PRODUCTS'); productid=getid('PRODUCT'); phasesid=getid('SOURCES'); resourcesid=getid('RESOURCES'); frameworks=getid('FRAMEWORKS'); cfgpr=getid('CFGPROJ'); cfgtg=getid('CFGTARGET'); cfgpb=getid('CFGPROJDEBUG'); cfgprl=getid('CFGPROJRELEASE'); cfgtd=getid('CFGTARGETDEBUG'); cfgtr=getid('CFGTARGETRELEASE');
lines=['// !$*UTF8*$!','{',' archiveVersion = 1;',' classes = {};',' objectVersion = 60;',' objects = {']
def section(title,rows):
 lines.append(f'/* Begin {title} section */'); lines.extend(rows); lines.append(f'/* End {title} section */')
section('PBXBuildFile',[f'{buildids[f]} /* {f} in {"Resources" if f=="Assets.xcassets" else "Sources"} */ = {{isa = PBXBuildFile; fileRef = {ids[f]} /* {f} */; }};' for f in files[:-1]])
section('PBXFileReference',[f'{ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {"folder.assetcatalog" if f=="Assets.xcassets" else "text.plist.entitlements" if f.endswith(".entitlements") else "sourcecode.swift"}; path = {f}; sourceTree = "<group>"; }};' for f in files]+[f'{productid} /* BiluxIOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BiluxIOS.app; sourceTree = BUILT_PRODUCTS_DIR; }};'])
section('PBXFrameworksBuildPhase',[f'{frameworks} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};'])
section('PBXGroup',[f'{mainid} = {{isa = PBXGroup; children = ({appgrp} /* BiluxIOS */, {prodsid} /* Products */); sourceTree = "<group>"; }};',f'{appgrp} /* BiluxIOS */ = {{isa = PBXGroup; children = ('+','.join(ids[f]+' /* '+f+' */' for f in files)+'); path = BiluxIOS; sourceTree = "<group>"; };',f'{prodsid} /* Products */ = {{isa = PBXGroup; children = ({productid} /* BiluxIOS.app */); name = Products; sourceTree = "<group>"; }};'])
section('PBXNativeTarget',[f'{targetid} /* BiluxIOS */ = {{isa = PBXNativeTarget; buildConfigurationList = {cfgtg} /* Build config list */; buildPhases = ({phasesid}, {frameworks}, {resourcesid}); buildRules = (); dependencies = (); name = BiluxIOS; productName = BiluxIOS; productReference = {productid}; productType = "com.apple.product-type.application"; }};'])
section('PBXProject',[f'{projectid} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; TargetAttributes = {{{targetid} = {{CreatedOnToolsVersion = 16.0; }};}}; }}; buildConfigurationList = {cfgpr}; compatibilityVersion = "Xcode 15.0"; developmentRegion = fr; hasScannedForEncodings = 0; knownRegions = (fr, en, Base); mainGroup = {mainid}; productRefGroup = {prodsid}; projectDirPath = ""; projectRoot = ""; targets = ({targetid}); }};'])
section('PBXResourcesBuildPhase',[f'{resourcesid} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({buildids["Assets.xcassets"]}); runOnlyForDeploymentPostprocessing = 0; }};'])
section('PBXSourcesBuildPhase',[f'{phasesid} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(buildids[f] for f in files if f.endswith('.swift'))+'); runOnlyForDeploymentPostprocessing = 0; };'])
section('XCBuildConfiguration',[f'{cfgpb} /* Project Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; DEBUG_INFORMATION_FORMAT = dwarf; GCC_OPTIMIZATION_LEVEL = 0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_VERSION = 5.0; }}; name = Debug; }};',f'{cfgprl} /* Project Release */ = {{isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_VERSION = 5.0; }}; name = Release; }};']+[f'{key} /* App {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_ENTITLEMENTS = BiluxIOS/BiluxIOS.entitlements; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; DEVELOPMENT_TEAM = ""; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = "BILUX"; INFOPLIST_KEY_LSRequiresIPhoneOS = YES; INFOPLIST_KEY_NSHealthShareUsageDescription = "Bilux lit, avec votre autorisation, les données de forme, de sommeil et de nutrition d’Apple Santé pour votre suivi personnel."; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 4.0; PRODUCT_BUNDLE_IDENTIFIER = com.bilux.nuclearascension; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; }}; name = {name}; }};' for key,name in [(cfgtd,'Debug'),(cfgtr,'Release')]])
section('XCConfigurationList',[f'{cfgpr} = {{isa = XCConfigurationList; buildConfigurations = ({cfgpb}, {cfgprl}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};',f'{cfgtg} = {{isa = XCConfigurationList; buildConfigurations = ({cfgtd}, {cfgtr}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};'])
lines+=[' };',f' rootObject = {projectid};','}']
(proj/'project.pbxproj').write_text('\n'.join(lines))
(src/'BiluxIOS.entitlements').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>
''')
print('created',proj/'project.pbxproj')
