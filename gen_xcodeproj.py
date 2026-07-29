#!/usr/bin/env python3
"""
Generates CalorieAI.xcodeproj/project.pbxproj from the source tree.

Why a generator instead of a hand-typed pbxproj: this project was authored
without Xcode available (no macOS in the build environment — see
README.md). Xcode's project file is a big cross-referenced UUID graph;
generating it from a directory scan means every file reference, build file,
and group entry is guaranteed self-consistent, instead of hoping a few
hundred hand-typed UUIDs all match up. Re-run this whenever files are
added/removed:

    python3 scripts/gen_xcodeproj.py

Uses the classic (pre-Xcode-16) project format deliberately — it's the
most widely-documented, most tooling-compatible pbxproj shape, which
matters more here than the newer file-system-synchronized-groups format
since nobody can click-test this in an Xcode GUI before merging.
"""

import os
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_NAME = "CalorieAI"
TESTS_NAME = "CalorieAITests"
BUNDLE_ID_PREFIX = "com.calorieai"
DEPLOYMENT_TARGET = "17.0"


def new_id():
    return uuid.uuid4().hex[:24].upper()


class PBXProjGenerator:
    def __init__(self):
        self.objects = {}  # uuid -> dict(isa=..., other fields as python values)
        self.order = []    # preserve insertion order per isa for readability

    def add(self, isa, fields):
        oid = new_id()
        fields = dict(fields)
        fields["isa"] = isa
        self.objects[oid] = fields
        self.order.append(oid)
        return oid

    # ---- file/group helpers -------------------------------------------------

    def file_type_for(self, path):
        if path.endswith(".swift"):
            return "sourcecode.swift"
        if path.endswith(".metal"):
            return "sourcecode.metal"
        if path.endswith(".json"):
            return "text.json"
        if path.endswith(".xcassets"):
            return "folder.assetcatalog"
        return "text"

    def add_file_reference(self, name, path_from_group):
        return self.add("PBXFileReference", {
            "lastKnownFileType": self.file_type_for(name),
            "path": name,
            "sourceTree": "<group>",
        })

    def add_group(self, name, child_ids, path=None):
        fields = {"children": child_ids, "sourceTree": "<group>"}
        if path is not None:
            fields["path"] = path
        else:
            fields["name"] = name
        return self.add("PBXGroup", fields)

    def build_group_tree(self, dir_path, extensions):
        """Recursively mirrors a directory into PBXGroup/PBXFileReference
        objects. Returns (group_id, [source_file_ids in this subtree])."""
        entries = sorted(os.listdir(dir_path))
        child_ids = []
        source_ids = []
        for entry in entries:
            full = os.path.join(dir_path, entry)
            if os.path.isdir(full):
                if entry.endswith(".xcassets"):
                    fid = self.add_file_reference(entry, entry)
                    child_ids.append(fid)
                    source_ids.append(("resource", fid))
                else:
                    gid, nested = self.build_group_tree(full, extensions)
                    child_ids.append(gid)
                    source_ids.extend(nested)
            else:
                ext = os.path.splitext(entry)[1]
                if ext in extensions:
                    fid = self.add_file_reference(entry, entry)
                    child_ids.append(fid)
                    kind = "source" if ext in (".swift", ".metal") else "resource"
                    source_ids.append((kind, fid))
        gid = self.add_group(os.path.basename(dir_path), child_ids, path=os.path.basename(dir_path))
        return gid, source_ids

    # ---- serialization -------------------------------------------------------

    def serialize_value(self, value, indent):
        pad = "\t" * indent
        if isinstance(value, dict):
            lines = ["{"]
            for k in sorted(value.keys()):
                v = value[k]
                lines.append(f"{pad}\t{self.quote_key(k)} = {self.serialize_value(v, indent + 1)};")
            lines.append(pad + "}")
            return "\n".join(lines)
        if isinstance(value, (list, tuple)):
            if not value:
                return "(\n" + pad + ")"
            lines = ["("]
            for item in value:
                lines.append(f"{pad}\t{self.serialize_value(item, indent + 1)},")
            lines.append(pad + ")")
            return "\n".join(lines)
        return self.quote_value(str(value))

    @staticmethod
    def needs_quotes(s):
        if s == "":
            return True
        safe = all(c.isalnum() or c in "_./" for c in s)
        return not safe

    def quote_key(self, s):
        return self.quote_value(s)

    def quote_value(self, s):
        if self.needs_quotes(s):
            escaped = s.replace("\\", "\\\\").replace('"', '\\"')
            return f'"{escaped}"'
        return s

    def render(self, root_object_id):
        lines = []
        lines.append("// !$*UTF8*$!")
        lines.append("{")
        lines.append("\tarchiveVersion = 1;")
        lines.append("\tclasses = {")
        lines.append("\t};")
        lines.append("\tobjectVersion = 56;")
        lines.append("\tobjects = {")

        by_isa = {}
        for oid in self.order:
            by_isa.setdefault(self.objects[oid]["isa"], []).append(oid)

        for isa in sorted(by_isa.keys()):
            lines.append(f"\n/* Begin {isa} section */")
            for oid in sorted(by_isa[isa]):
                fields = {k: v for k, v in self.objects[oid].items() if k != "isa"}
                body_lines = []
                for k in sorted(fields.keys()):
                    v = fields[k]
                    body_lines.append(f"\t\t\t{self.quote_key(k)} = {self.serialize_value(v, 3)};")
                lines.append(f"\t\t{oid} /* {isa} */ = {{")
                lines.append(f"\t\t\tisa = {isa};")
                lines.extend(body_lines)
                lines.append("\t\t};")
            lines.append(f"/* End {isa} section */")

        lines.append("\t};")
        lines.append(f"\trootObject = {root_object_id};")
        lines.append("}")
        return "\n".join(lines) + "\n"


def main():
    gen = PBXProjGenerator()

    app_src_root = os.path.join(ROOT, APP_NAME)
    tests_src_root = os.path.join(ROOT, TESTS_NAME)

    app_group_id, app_entries = gen.build_group_tree(app_src_root, {".swift", ".metal", ".json", ".xcassets"})
    tests_group_id, tests_entries = gen.build_group_tree(tests_src_root, {".swift"})

    app_source_ids = [fid for kind, fid in app_entries if kind == "source"]
    app_resource_ids = [fid for kind, fid in app_entries if kind == "resource"]
    tests_source_ids = [fid for kind, fid in tests_entries if kind == "source"]

    # Products
    app_product_id = gen.add("PBXFileReference", {
        "explicitFileType": "wrapper.application",
        "includeInIndex": 0,
        "path": f"{APP_NAME}.app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    })
    tests_product_id = gen.add("PBXFileReference", {
        "explicitFileType": "wrapper.cfbundle",
        "includeInIndex": 0,
        "path": f"{TESTS_NAME}.xctest",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    })
    products_group_id = gen.add_group("Products", [app_product_id, tests_product_id])

    # Docs (visual only, not part of any target — nice to see in the navigator)
    docs_dir = os.path.join(ROOT, "docs")
    doc_children = []
    if os.path.isdir(docs_dir):
        for entry in sorted(os.listdir(docs_dir)):
            if entry.endswith(".md"):
                doc_children.append(gen.add_file_reference(entry, entry))
    docs_group_id = gen.add_group("docs", doc_children, path="docs") if doc_children else None

    top_children = [app_group_id, tests_group_id, products_group_id]
    if docs_group_id:
        top_children.insert(2, docs_group_id)
    main_group_id = gen.add("PBXGroup", {"children": top_children, "sourceTree": "<group>"})

    # Build files
    app_build_file_ids = [gen.add("PBXBuildFile", {"fileRef": fid}) for fid in app_source_ids]
    app_resource_build_file_ids = [gen.add("PBXBuildFile", {"fileRef": fid}) for fid in app_resource_ids]
    tests_build_file_ids = [gen.add("PBXBuildFile", {"fileRef": fid}) for fid in tests_source_ids]
    app_product_build_file_id = gen.add("PBXBuildFile", {"fileRef": app_product_id})

    # Build phases
    app_sources_phase = gen.add("PBXSourcesBuildPhase", {"buildActionMask": 2147483647, "files": app_build_file_ids, "runOnlyForDeploymentPostprocessing": 0})
    app_resources_phase = gen.add("PBXResourcesBuildPhase", {"buildActionMask": 2147483647, "files": app_resource_build_file_ids, "runOnlyForDeploymentPostprocessing": 0})
    app_frameworks_phase = gen.add("PBXFrameworksBuildPhase", {"buildActionMask": 2147483647, "files": [], "runOnlyForDeploymentPostprocessing": 0})

    tests_sources_phase = gen.add("PBXSourcesBuildPhase", {"buildActionMask": 2147483647, "files": tests_build_file_ids, "runOnlyForDeploymentPostprocessing": 0})
    tests_resources_phase = gen.add("PBXResourcesBuildPhase", {"buildActionMask": 2147483647, "files": [], "runOnlyForDeploymentPostprocessing": 0})
    tests_frameworks_phase = gen.add("PBXFrameworksBuildPhase", {"buildActionMask": 2147483647, "files": [app_product_build_file_id], "runOnlyForDeploymentPostprocessing": 0})

    # Target dependency (tests -> app)
    container_proxy = gen.add("PBXContainerItemProxy", {
        "containerPortal": "PLACEHOLDER_PROJECT",  # patched below once project id exists
        "proxyType": 1,
        "remoteGlobalIDString": "PLACEHOLDER_APP_TARGET",
        "remoteInfo": APP_NAME,
    })

    # Build settings
    common_settings = {
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CODE_SIGN_STYLE": "Automatic",
        "ENABLE_PREVIEWS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    debug_only = {
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": 0,
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    }
    release_only = {
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    }
    project_shared = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
    }

    proj_debug = gen.add("XCBuildConfiguration", {"name": "Debug", "buildSettings": {**project_shared, **debug_only}})
    proj_release = gen.add("XCBuildConfiguration", {"name": "Release", "buildSettings": {**project_shared, **release_only}})
    proj_config_list = gen.add("XCConfigurationList", {
        "buildConfigurations": [proj_debug, proj_release],
        "defaultConfigurationIsVisible": 0,
        "defaultConfigurationName": "Release",
    })

    app_settings_base = {
        **common_settings,
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CURRENT_PROJECT_VERSION": 1,
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "CalorieAI",
        "INFOPLIST_KEY_NSCameraUsageDescription": "Snap a photo of your plate so the agent can identify what you're eating.",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID_PREFIX}.app",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        # Deliberately left at Xcode's default (minimal) strict-concurrency
        # checking rather than "complete" — this codebase was never
        # compiled here, and "complete" mode's much stricter Sendable/actor
        # isolation checks are the kind of thing best turned on once it's
        # already building cleanly, not baked in blind.
    }
    app_debug = gen.add("XCBuildConfiguration", {"name": "Debug", "buildSettings": {**app_settings_base, **debug_only, "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"}})
    app_release = gen.add("XCBuildConfiguration", {"name": "Release", "buildSettings": {**app_settings_base}})
    app_config_list = gen.add("XCConfigurationList", {
        "buildConfigurations": [app_debug, app_release],
        "defaultConfigurationIsVisible": 0,
        "defaultConfigurationName": "Release",
    })

    tests_settings_base = {
        **common_settings,
        "BUNDLE_LOADER": f"$(TEST_HOST)",
        "CURRENT_PROJECT_VERSION": 1,
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID_PREFIX}.tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{APP_NAME}.app/{APP_NAME}",
    }
    tests_debug = gen.add("XCBuildConfiguration", {"name": "Debug", "buildSettings": {**tests_settings_base, **debug_only}})
    tests_release = gen.add("XCBuildConfiguration", {"name": "Release", "buildSettings": {**tests_settings_base}})
    tests_config_list = gen.add("XCConfigurationList", {
        "buildConfigurations": [tests_debug, tests_release],
        "defaultConfigurationIsVisible": 0,
        "defaultConfigurationName": "Release",
    })

    # Targets
    app_target_id = gen.add("PBXNativeTarget", {
        "buildConfigurationList": app_config_list,
        "buildPhases": [app_sources_phase, app_frameworks_phase, app_resources_phase],
        "buildRules": [],
        "dependencies": [],
        "name": APP_NAME,
        "productName": APP_NAME,
        "productReference": app_product_id,
        "productType": "com.apple.product-type.application",
    })

    target_dependency_id = gen.add("PBXTargetDependency", {
        "target": app_target_id,
        "targetProxy": container_proxy,
    })

    tests_target_id = gen.add("PBXNativeTarget", {
        "buildConfigurationList": tests_config_list,
        "buildPhases": [tests_sources_phase, tests_frameworks_phase, tests_resources_phase],
        "buildRules": [],
        "dependencies": [target_dependency_id],
        "name": TESTS_NAME,
        "productName": TESTS_NAME,
        "productReference": tests_product_id,
        "productType": "com.apple.product-type.bundle.unit-test",
    })

    project_id = gen.add("PBXProject", {
        "attributes": {
            "BuildIndependentTargetsInParallel": "YES",
            "LastSwiftUpdateCheck": 1600,
            "LastUpgradeCheck": 1600,
            "TargetAttributes": {
                app_target_id: {"CreatedOnToolsVersion": "16.0"},
                tests_target_id: {
                    "CreatedOnToolsVersion": "16.0",
                    "TestTargetID": app_target_id,
                },
            },
        },
        "buildConfigurationList": proj_config_list,
        "compatibilityVersion": "Xcode 14.0",
        "developmentRegion": "en",
        "hasScannedForEncodings": 0,
        "knownRegions": ["en", "Base"],
        "mainGroup": main_group_id,
        "productRefGroup": products_group_id,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [app_target_id, tests_target_id],
    })

    # Patch the container proxy placeholders now that we have real ids.
    gen.objects[container_proxy]["containerPortal"] = project_id
    gen.objects[container_proxy]["remoteGlobalIDString"] = app_target_id

    output_path = os.path.join(ROOT, f"{APP_NAME}.xcodeproj", "project.pbxproj")
    with open(output_path, "w") as f:
        f.write(gen.render(project_id))

    write_workspace(ROOT)
    write_scheme(ROOT, app_target_id)

    total_objects = len(gen.objects)
    print(f"Wrote {output_path}")
    print(f"  {len(app_source_ids)} app source files, {len(app_resource_ids)} app resources, {len(tests_source_ids)} test files")
    print(f"  {total_objects} total pbxproj objects")


def write_workspace(root):
    path = os.path.join(root, f"{APP_NAME}.xcodeproj", "project.xcworkspace", "contents.xcworkspacedata")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Workspace\n'
            '   version = "1.0">\n'
            '   <FileRef\n'
            '      location = "self:">\n'
            '   </FileRef>\n'
            '</Workspace>\n'
        )
    print(f"Wrote {path}")


def write_scheme(root, app_target_id):
    path = os.path.join(root, f"{APP_NAME}.xcodeproj", "xcshareddata", "xcschemes", f"{APP_NAME}.xcscheme")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    buildable_ref = (
        f'      <BuildableReference\n'
        f'         BuildableIdentifier = "primary"\n'
        f'         BlueprintIdentifier = "{app_target_id}"\n'
        f'         BuildableName = "{APP_NAME}.app"\n'
        f'         BlueprintName = "{APP_NAME}"\n'
        f'         ReferencedContainer = "container:{APP_NAME}.xcodeproj">\n'
        f'      </BuildableReference>\n'
    )
    content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
{buildable_ref}         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{buildable_ref}      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{buildable_ref}      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    with open(path, "w") as f:
        f.write(content)
    print(f"Wrote {path}")


if __name__ == "__main__":
    main()
