#!/usr/bin/env python3
"""Generate the native, dependency-free Xcode project from explicit Swift modules."""
from pathlib import Path
import hashlib
import json
from xml.sax.saxutils import quoteattr

ROOT = Path(__file__).resolve().parents[1]
objects = {}

def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def add(key, content):
    identity = uid(key)
    objects[identity] = content
    return identity

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

def seq(values):
    values = list(values)
    return "(" + ", ".join(values) + (",)" if values else ")")

modules = {
    "CTreeSitter": [],
    "HarnessDomain": [],
    "HarnessInfrastructure": ["HarnessDomain", "CTreeSitter"],
    "HarnessProviders": ["HarnessDomain", "HarnessInfrastructure"],
    "HarnessCore": ["HarnessDomain", "HarnessInfrastructure", "HarnessProviders"],
    "HarnessIPC": ["HarnessDomain", "HarnessInfrastructure"],
    "HarnessService": ["CTreeSitter", "HarnessDomain", "HarnessInfrastructure", "HarnessProviders", "HarnessCore", "HarnessIPC"],
    "HarnessCLI": ["CTreeSitter", "HarnessDomain", "HarnessInfrastructure", "HarnessIPC"],
    "HarnessUI": ["CTreeSitter", "HarnessDomain", "HarnessInfrastructure", "HarnessIPC"],
    "HarnessTests": ["CTreeSitter", "HarnessDomain", "HarnessInfrastructure", "HarnessProviders", "HarnessCore"],
    "HarnessUITests": ["CTreeSitter", "HarnessDomain", "HarnessInfrastructure"],
}
library_names = list(modules)[:6]
test_names = ["HarnessTests", "HarnessUITests"]
products = {}
for name in modules:
    product_name = "Fronda.app" if name == "HarnessUI" else name if name not in library_names else "lib" + name + ".a"
    product_type = "wrapper.application" if name == "HarnessUI" else "compiled.mach-o.executable" if name not in library_names else "archive.ar"
    if name in test_names:
        product_name, product_type = name + ".xctest", "wrapper.cfbundle"
    products[name] = add("product:" + name, f"isa = PBXFileReference; explicitFileType = {q(product_type)}; path = {q(product_name)}; sourceTree = BUILT_PRODUCTS_DIR;")

groups = []
targets = []
for name, dependencies in modules.items():
    references, builds = [], []
    source_files = sorted((ROOT / ("Tests" if name in test_names else "Sources") / name).rglob("*.swift"))
    if name == "CTreeSitter":
        source_files = sorted((ROOT / "Vendor/CTreeSitter/wrappers").rglob("*.c"))
    for file in source_files:
        path = str(file.relative_to(ROOT))
        file_type = "sourcecode.c.c" if file.suffix == ".c" else "sourcecode.swift"
        ref = add("file:" + path, f"isa = PBXFileReference; lastKnownFileType = {file_type}; path = {q(path)}; sourceTree = SOURCE_ROOT;")
        references.append(ref)
        builds.append(add("source:" + path, f"isa = PBXBuildFile; fileRef = {ref};"))
    groups.append(add("group:" + name, f"isa = PBXGroup; name = {name}; children = {seq(references)}; sourceTree = \"<group>\";"))
    source_phase = add("sources:" + name, f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {seq(builds)}; runOnlyForDeploymentPostprocessing = 0;")
    links = []
    if name not in library_names:
        for dependency in dependencies:
            links.append(add("link:" + name + dependency, f"isa = PBXBuildFile; fileRef = {products[dependency]};"))
    framework_phase = add("frameworks:" + name, f"isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {seq(links)}; runOnlyForDeploymentPostprocessing = 0;")
    deps = dependencies + (["HarnessService", "HarnessCLI"] if name == "HarnessUI" else [])
    if name == "HarnessUITests":
        deps += ["HarnessUI"]
    target_deps = []
    for dep in deps:
        proxy = add("proxy:" + name + dep, f"isa = PBXContainerItemProxy; containerPortal = {uid('project')}; proxyType = 1; remoteGlobalIDString = {uid('target:' + dep)}; remoteInfo = {dep};")
        target_deps.append(add("dependency:" + name + dep, f"isa = PBXTargetDependency; target = {uid('target:' + dep)}; targetProxy = {proxy};"))
    phases = [source_phase, framework_phase]
    if name == "HarnessUI":
        resource_refs, resource_builds = [], []
        for resource_name, file_type in [("Fronda.icns", "image.icns"), ("FrondaWordmark.png", "image.png"), ("FrondaMascot.png", "image.png"), ("FrondaSymbolLight.png", "image.png"), ("FrondaSymbolDark.png", "image.png"), ("FrondaAnimation", "folder")]:
            resource_path = "Resources/" + resource_name
            resource_ref = add("file:" + resource_path, f"isa = PBXFileReference; lastKnownFileType = {file_type}; path = {q(resource_path)}; sourceTree = SOURCE_ROOT;")
            resource_refs.append(resource_ref)
            resource_builds.append(add("resource:" + resource_path, f"isa = PBXBuildFile; fileRef = {resource_ref};"))
        groups.append(add("group:Resources", f"isa = PBXGroup; name = Resources; children = {seq(resource_refs)}; sourceTree = \"<group>\";"))
        phases.append(add("resources:" + name, f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {seq(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;"))
        shell = 'set -eu\nmkdir -p "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"\ncp "$BUILT_PRODUCTS_DIR/HarnessService" "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/HarnessService"\ncp "$BUILT_PRODUCTS_DIR/HarnessCLI" "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers/harness"\nln -sf harness "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers/fronda"\n'
        phases.append(add("embed", f"isa = PBXShellScriptBuildPhase; name = \"Embed coordinator and CLI\"; buildActionMask = 2147483647; files = (); inputPaths = (\"$(BUILT_PRODUCTS_DIR)/HarnessService\", \"$(BUILT_PRODUCTS_DIR)/HarnessCLI\"); outputPaths = (\"$(TARGET_BUILD_DIR)/$(EXECUTABLE_FOLDER_PATH)/HarnessService\", \"$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Helpers/harness\", \"$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Helpers/fronda\"); runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = {q(shell)};"))
    configurations = []
    for config in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME": "Fronda" if name == "HarnessUI" else name,
            "PRODUCT_MODULE_NAME": name,
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config == "Debug" else "-O",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG" if config == "Debug" else "",
            "SWIFT_INCLUDE_PATHS": "$(SRCROOT)/Sources/CSQLite $(SRCROOT)/Vendor/CTreeSitter/include",
            "OTHER_SWIFT_FLAGS": "$(inherited) -Xcc -fmodule-map-file=$(SRCROOT)/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=$(SRCROOT)/Vendor/CTreeSitter/include/module.modulemap",
            "HEADER_SEARCH_PATHS": "$(SRCROOT)/Vendor/CTreeSitter/include $(SRCROOT)/Vendor/CTreeSitter/runtime $(SRCROOT)/Vendor/CTreeSitter/grammars/typescript/src",
            "GCC_C_LANGUAGE_STANDARD": "c11",
            "OTHER_LDFLAGS": "$(inherited) -lsqlite3",
            "CODE_SIGN_STYLE": "Manual",
            "CODE_SIGN_IDENTITY": "-",
            "ENABLE_HARDENED_RUNTIME": "YES",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "SWIFT_INSTALL_OBJC_HEADER": "NO",
            "ENABLE_TESTABILITY": "YES" if config == "Debug" else "NO",
            "SKIP_INSTALL": "NO" if name == "HarnessUI" else "YES",
            "SDKROOT": "macosx",
            "SUPPORTED_PLATFORMS": "macosx",
        }
        if name in library_names:
            settings.update({"MACH_O_TYPE": "staticlib", "DEFINES_MODULE": "YES", "EXECUTABLE_PREFIX": "lib"})
        elif name == "HarnessUI":
            settings.update({"EXECUTABLE_NAME": "Harness", "PRODUCT_BUNDLE_IDENTIFIER": "com.harness.app", "INFOPLIST_FILE": "Resources/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks"})
        elif name in test_names:
            settings.update({"PRODUCT_BUNDLE_IDENTIFIER": "com.harness." + name.lower(), "GENERATE_INFOPLIST_FILE": "YES", "ENABLE_HARDENED_RUNTIME": "NO", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks", "SWIFT_EMIT_LOC_STRINGS": "NO", "COPY_PHASE_STRIP": "NO", "STRIP_INSTALLED_PRODUCT": "NO"})
            if name == "HarnessUITests":
                settings["TEST_TARGET_NAME"] = "HarnessUI"
        else:
            settings.update({"PRODUCT_BUNDLE_IDENTIFIER": "com.harness." + name.lower(), "GENERATE_INFOPLIST_FILE": "YES"})
        body = " ".join(q(k) + " = " + q(v) + ";" for k,v in settings.items())
        configurations.append(add("config:" + name + config, f"isa = XCBuildConfiguration; name = {config}; buildSettings = {{ {body} }};"))
    config_list = add("configs:" + name, f"isa = XCConfigurationList; buildConfigurations = {seq(configurations)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;")
    product_type = "com.apple.product-type.application" if name == "HarnessUI" else "com.apple.product-type.library.static" if name in library_names else "com.apple.product-type.tool"
    if name in test_names:
        product_type = "com.apple.product-type.bundle.ui-testing" if name == "HarnessUITests" else "com.apple.product-type.bundle.unit-test"
    targets.append(add("target:" + name, f"isa = PBXNativeTarget; name = {name}; productName = {name}; productReference = {products[name]}; productType = {q(product_type)}; buildConfigurationList = {config_list}; buildPhases = {seq(phases)}; buildRules = (); dependencies = {seq(target_deps)};"))

product_group = add("products", f"isa = PBXGroup; name = Products; children = {seq(products.values())}; sourceTree = \"<group>\";")
main_group = add("main", f"isa = PBXGroup; children = {seq(groups + [product_group])}; sourceTree = \"<group>\";")
project_configs = []
for config in ["Debug", "Release"]:
    project_configs.append(add("projectconfig:" + config, f"isa = XCBuildConfiguration; name = {config}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; MACOSX_DEPLOYMENT_TARGET = 15.0; }};"))
project_config_list = add("projectconfigs", f"isa = XCConfigurationList; buildConfigurations = {seq(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;")
add("project", f"isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = \"Xcode 16.0\"; developmentRegion = pt_BR; knownRegions = (pt_BR, en, Base); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = \"\"; projectRoot = \"\"; targets = {seq(targets)};")
project = ROOT / "Harness.xcodeproj"
project.mkdir(exist_ok=True)
text = "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n"
text += "\n".join(f"{key} = {{ {value} }};" for key, value in objects.items())
text += f"\n}}; rootObject = {uid('project')}; }}\n"
(project / "project.pbxproj").write_text(text)
scheme_dir = project / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:HarnessUI")}" BuildableName="Fronda.app" BlueprintName="HarnessUI" ReferencedContainer="container:Harness.xcodeproj"/>'
test_references = "".join(f'<TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:" + name)}" BuildableName="{name}.xctest" BlueprintName="{name}" ReferencedContainer="container:Harness.xcodeproj"/></TestableReference>' for name in test_names)
def test_action_script(title, command):
    script = 'set -eu\ncd "$SRCROOT"\n' + command + '\n'
    return f'<ExecutionAction ActionType="Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"><ActionContent title={quoteattr(title)} scriptText={quoteattr(script)}><EnvironmentBuildable>{reference}</EnvironmentBuildable></ActionContent></ExecutionAction>'
prepare_ui = test_action_script("Prepare isolated UI fixtures", 'python3 script/ui_test_fixtures.py prepare "$BUILT_PRODUCTS_DIR/Fronda.app"')
cleanup_ui = test_action_script("Clean isolated UI fixtures", 'python3 script/ui_test_fixtures.py cleanup')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><PreActions>{prepare_ui}</PreActions><PostActions>{cleanup_ui}</PostActions><Testables>{test_references}</Testables><MacroExpansion>{reference}</MacroExpansion><EnvironmentVariables><EnvironmentVariable key="HARNESS_UI_FIXTURE_MANIFEST" value="$(PROJECT_DIR)/.qa/ui-tests/manifest.json" isEnabled="YES"/></EnvironmentVariables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(scheme_dir / "Harness.xcscheme").write_text(scheme)
print(f"Generated Harness.xcodeproj: {len(modules)} native targets")
