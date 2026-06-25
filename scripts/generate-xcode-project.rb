#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"

root = File.expand_path("..", __dir__)
project_dir = File.join(root, "RunningOverlay.xcodeproj")
project_file = File.join(project_dir, "project.pbxproj")
scheme_dir = File.join(project_dir, "xcshareddata", "xcschemes")

swift_files = Dir.glob(File.join(root, "Sources/RunningOverlay/**/*.swift"))
  .map { |path| path.delete_prefix("#{root}/") }
  .sort
resource_files = Dir.glob(File.join(root, "Sources/RunningOverlay/Resources/**/*"))
  .select { |path| File.file?(path) }
  .reject { |path| [".DS_Store", ".gitkeep"].include?(File.basename(path)) }
  .map { |path| path.delete_prefix("#{root}/") }
  .sort
legal_files = [
  "LICENSE",
  "COMMERCIAL-LICENSE.md",
  "TRADEMARKS.md",
  "THIRD_PARTY_NOTICES.md"
]

def pbx_id(key)
  Digest::SHA1.hexdigest(key)[0, 24].upcase
end

def quote(value)
  %("#{value.gsub("\\", "\\\\").gsub('"', '\\"')}")
end

def file_type(path)
  return "folder.assetcatalog" if path.end_with?(".xcassets")

  {
    ".swift" => "sourcecode.swift",
    ".png" => "image.png",
    ".json" => "text.json",
    ".plist" => "text.plist.xml",
    ".entitlements" => "text.plist.entitlements",
    ".xcconfig" => "text.xcconfig",
    ".xcprivacy" => "text.xml",
    ".rotemplate" => "text.json"
  }.fetch(File.extname(path), "file")
end

product_ref = pbx_id("product")
config_ref = pbx_id("config")
info_ref = pbx_id("info")
entitlements_ref = pbx_id("entitlements")
privacy_ref = pbx_id("privacy")
assets_ref = pbx_id("assets")
main_group = pbx_id("main-group")
sources_group = pbx_id("sources-group")
resources_group = pbx_id("resources-group")
app_store_group = pbx_id("app-store-group")
config_group = pbx_id("config-group")
products_group = pbx_id("products-group")
legal_group = pbx_id("legal-group")
sources_phase = pbx_id("sources-phase")
frameworks_phase = pbx_id("frameworks-phase")
resources_phase = pbx_id("resources-phase")
legal_phase = pbx_id("legal-phase")
target = pbx_id("target")
project = pbx_id("project")
project_configs = pbx_id("project-config-list")
target_configs = pbx_id("target-config-list")
project_debug = pbx_id("project-debug")
project_release = pbx_id("project-release")
target_debug = pbx_id("target-debug")
target_release = pbx_id("target-release")

source_refs = swift_files.to_h { |path| [path, pbx_id("source-ref:#{path}")] }
source_builds = swift_files.to_h { |path| [path, pbx_id("source-build:#{path}")] }
resource_refs = resource_files.to_h { |path| [path, pbx_id("resource-ref:#{path}")] }
resource_builds = resource_files.to_h { |path| [path, pbx_id("resource-build:#{path}")] }
legal_refs = legal_files.to_h { |path| [path, pbx_id("legal-ref:#{path}")] }
legal_builds = legal_files.to_h { |path| [path, pbx_id("legal-build:#{path}")] }
privacy_build = pbx_id("privacy-build")
assets_build = pbx_id("assets-build")

lines = []
lines << "// !$*UTF8*$!"
lines << "{"
lines << "\tarchiveVersion = 1;"
lines << "\tclasses = {};"
lines << "\tobjectVersion = 56;"
lines << "\tobjects = {"
lines << ""
lines << "/* Begin PBXBuildFile section */"
swift_files.each do |path|
  lines << "\t\t#{source_builds.fetch(path)} /* #{File.basename(path)} in Sources */ = {isa = PBXBuildFile; fileRef = #{source_refs.fetch(path)} /* #{File.basename(path)} */; };"
end
resource_files.each do |path|
  lines << "\t\t#{resource_builds.fetch(path)} /* #{File.basename(path)} in Resources */ = {isa = PBXBuildFile; fileRef = #{resource_refs.fetch(path)} /* #{File.basename(path)} */; };"
end
lines << "\t\t#{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile; fileRef = #{privacy_ref} /* PrivacyInfo.xcprivacy */; };"
lines << "\t\t#{assets_build} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = #{assets_ref} /* Assets.xcassets */; };"
legal_files.each do |path|
  lines << "\t\t#{legal_builds.fetch(path)} /* #{File.basename(path)} in Legal */ = {isa = PBXBuildFile; fileRef = #{legal_refs.fetch(path)} /* #{File.basename(path)} */; };"
end
lines << "/* End PBXBuildFile section */"
lines << ""
lines << "/* Begin PBXCopyFilesBuildPhase section */"
lines << "\t\t#{legal_phase} /* Legal Notices */ = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = Legal; dstSubfolderSpec = 7; files = ("
legal_files.each { |path| lines << "\t\t\t#{legal_builds.fetch(path)} /* #{File.basename(path)} in Legal */," }
lines << "\t\t); name = \"Legal Notices\"; runOnlyForDeploymentPostprocessing = 0; };"
lines << "/* End PBXCopyFilesBuildPhase section */"
lines << ""
lines << "/* Begin PBXFileReference section */"
swift_files.each do |path|
  lines << "\t\t#{source_refs.fetch(path)} /* #{File.basename(path)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{quote(path)}; sourceTree = SOURCE_ROOT; };"
end
resource_files.each do |path|
  lines << "\t\t#{resource_refs.fetch(path)} /* #{File.basename(path)} */ = {isa = PBXFileReference; lastKnownFileType = #{file_type(path)}; path = #{quote(path)}; sourceTree = SOURCE_ROOT; };"
end
lines << "\t\t#{info_ref} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = AppStore/Info.plist; sourceTree = SOURCE_ROOT; };"
lines << "\t\t#{entitlements_ref} /* RunningOverlay.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = AppStore/RunningOverlay.entitlements; sourceTree = SOURCE_ROOT; };"
lines << "\t\t#{privacy_ref} /* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference; lastKnownFileType = text.xml; path = AppStore/PrivacyInfo.xcprivacy; sourceTree = SOURCE_ROOT; };"
lines << "\t\t#{assets_ref} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = AppStore/Assets.xcassets; sourceTree = SOURCE_ROOT; };"
lines << "\t\t#{config_ref} /* AppStore.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/AppStore.xcconfig; sourceTree = SOURCE_ROOT; };"
lines << "\t\t#{product_ref} /* RunningOverlay.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RunningOverlay.app; sourceTree = BUILT_PRODUCTS_DIR; };"
legal_files.each do |path|
  lines << "\t\t#{legal_refs.fetch(path)} /* #{File.basename(path)} */ = {isa = PBXFileReference; lastKnownFileType = text; path = #{quote(path)}; sourceTree = SOURCE_ROOT; };"
end
lines << "/* End PBXFileReference section */"
lines << ""
lines << "/* Begin PBXFrameworksBuildPhase section */"
lines << "\t\t#{frameworks_phase} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
lines << "/* End PBXFrameworksBuildPhase section */"
lines << ""
lines << "/* Begin PBXGroup section */"
lines << "\t\t#{main_group} = {isa = PBXGroup; children = (#{sources_group}, #{resources_group}, #{app_store_group}, #{config_group}, #{legal_group}, #{products_group}); sourceTree = \"<group>\"; };"
lines << "\t\t#{sources_group} /* Sources */ = {isa = PBXGroup; children = ("
swift_files.each { |path| lines << "\t\t\t#{source_refs.fetch(path)} /* #{File.basename(path)} */," }
lines << "\t\t); name = Sources; sourceTree = \"<group>\"; };"
lines << "\t\t#{resources_group} /* Resources */ = {isa = PBXGroup; children = ("
resource_files.each { |path| lines << "\t\t\t#{resource_refs.fetch(path)} /* #{File.basename(path)} */," }
lines << "\t\t); name = Resources; sourceTree = \"<group>\"; };"
lines << "\t\t#{app_store_group} /* AppStore */ = {isa = PBXGroup; children = (#{info_ref}, #{entitlements_ref}, #{privacy_ref}, #{assets_ref}); name = AppStore; sourceTree = \"<group>\"; };"
lines << "\t\t#{config_group} /* Config */ = {isa = PBXGroup; children = (#{config_ref}); name = Config; sourceTree = \"<group>\"; };"
lines << "\t\t#{legal_group} /* Legal */ = {isa = PBXGroup; children = ("
legal_files.each { |path| lines << "\t\t\t#{legal_refs.fetch(path)} /* #{File.basename(path)} */," }
lines << "\t\t); name = Legal; sourceTree = \"<group>\"; };"
lines << "\t\t#{products_group} /* Products */ = {isa = PBXGroup; children = (#{product_ref}); name = Products; sourceTree = \"<group>\"; };"
lines << "/* End PBXGroup section */"
lines << ""
lines << "/* Begin PBXNativeTarget section */"
lines << "\t\t#{target} /* RunningOverlay */ = {isa = PBXNativeTarget; buildConfigurationList = #{target_configs}; buildPhases = (#{sources_phase}, #{frameworks_phase}, #{resources_phase}, #{legal_phase}); buildRules = (); dependencies = (); name = RunningOverlay; productName = RunningOverlay; productReference = #{product_ref}; productType = \"com.apple.product-type.application\"; };"
lines << "/* End PBXNativeTarget section */"
lines << ""
lines << "/* Begin PBXProject section */"
lines << "\t\t#{project} /* Project object */ = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 2650; LastUpgradeCheck = 2650; TargetAttributes = {#{target} = {CreatedOnToolsVersion = 26.5; }; }; }; buildConfigurationList = #{project_configs}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = #{main_group}; productRefGroup = #{products_group}; projectDirPath = \"\"; projectRoot = \"\"; targets = (#{target}); };"
lines << "/* End PBXProject section */"
lines << ""
lines << "/* Begin PBXResourcesBuildPhase section */"
lines << "\t\t#{resources_phase} /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ("
resource_files.each { |path| lines << "\t\t\t#{resource_builds.fetch(path)} /* #{File.basename(path)} in Resources */," }
lines << "\t\t\t#{privacy_build} /* PrivacyInfo.xcprivacy in Resources */,"
lines << "\t\t\t#{assets_build} /* Assets.xcassets in Resources */,"
lines << "\t\t); runOnlyForDeploymentPostprocessing = 0; };"
lines << "/* End PBXResourcesBuildPhase section */"
lines << ""
lines << "/* Begin PBXSourcesBuildPhase section */"
lines << "\t\t#{sources_phase} /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ("
swift_files.each { |path| lines << "\t\t\t#{source_builds.fetch(path)} /* #{File.basename(path)} in Sources */," }
lines << "\t\t); runOnlyForDeploymentPostprocessing = 0; };"
lines << "/* End PBXSourcesBuildPhase section */"
lines << ""
lines << "/* Begin XCBuildConfiguration section */"
lines << "\t\t#{project_debug} /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_C_LANGUAGE_STANDARD = gnu17; MACOSX_DEPLOYMENT_TARGET = 15.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = \"-Onone\"; }; name = Debug; };"
lines << "\t\t#{project_release} /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\"; GCC_C_LANGUAGE_STANDARD = gnu17; MACOSX_DEPLOYMENT_TARGET = 15.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = \"-O\"; }; name = Release; };"
target_settings = [
  "ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME = AccentColor",
  "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon",
  "CODE_SIGN_STYLE = Automatic",
  "ENABLE_APP_SANDBOX = YES",
  "ENABLE_HARDENED_RUNTIME = YES",
  "ENABLE_USER_SCRIPT_SANDBOXING = YES",
  "GENERATE_INFOPLIST_FILE = NO",
  "INFOPLIST_FILE = AppStore/Info.plist",
  "LD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/../Frameworks\")",
  "PRODUCT_MODULE_NAME = RunningOverlay",
  "PRODUCT_NAME = \"$(TARGET_NAME)\"",
  "SDKROOT = macosx",
  "SWIFT_EMIT_LOC_STRINGS = YES",
  "SWIFT_VERSION = 6.0"
].join("; ")
lines << "\t\t#{target_debug} /* Debug */ = {isa = XCBuildConfiguration; baseConfigurationReference = #{config_ref}; buildSettings = {#{target_settings}; }; name = Debug; };"
lines << "\t\t#{target_release} /* Release */ = {isa = XCBuildConfiguration; baseConfigurationReference = #{config_ref}; buildSettings = {#{target_settings}; }; name = Release; };"
lines << "/* End XCBuildConfiguration section */"
lines << ""
lines << "/* Begin XCConfigurationList section */"
lines << "\t\t#{project_configs} /* Build configuration list for PBXProject \"RunningOverlay\" */ = {isa = XCConfigurationList; buildConfigurations = (#{project_debug}, #{project_release}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
lines << "\t\t#{target_configs} /* Build configuration list for PBXNativeTarget \"RunningOverlay\" */ = {isa = XCConfigurationList; buildConfigurations = (#{target_debug}, #{target_release}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
lines << "/* End XCConfigurationList section */"
lines << ""
lines << "\t};"
lines << "\trootObject = #{project} /* Project object */;"
lines << "}"

scheme = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <Scheme LastUpgradeVersion="2650" version="1.7">
     <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
        <BuildActionEntries>
           <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
              <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target}" BuildableName="RunningOverlay.app" BlueprintName="RunningOverlay" ReferencedContainer="container:RunningOverlay.xcodeproj"/>
           </BuildActionEntry>
        </BuildActionEntries>
     </BuildAction>
     <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
     <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
        <BuildableProductRunnable runnableDebuggingMode="0">
           <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target}" BuildableName="RunningOverlay.app" BlueprintName="RunningOverlay" ReferencedContainer="container:RunningOverlay.xcodeproj"/>
        </BuildableProductRunnable>
     </LaunchAction>
     <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
        <BuildableProductRunnable runnableDebuggingMode="0">
           <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target}" BuildableName="RunningOverlay.app" BlueprintName="RunningOverlay" ReferencedContainer="container:RunningOverlay.xcodeproj"/>
        </BuildableProductRunnable>
     </ProfileAction>
     <AnalyzeAction buildConfiguration="Debug"/>
     <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
  </Scheme>
XML

FileUtils.mkdir_p(scheme_dir)
File.write(project_file, "#{lines.join("\n")}\n")
File.write(File.join(scheme_dir, "RunningOverlay.xcscheme"), scheme)

puts "Generated #{project_file}"
puts "Generated #{File.join(scheme_dir, 'RunningOverlay.xcscheme')}"
