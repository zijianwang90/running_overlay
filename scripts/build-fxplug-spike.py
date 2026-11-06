#!/usr/bin/env python3
"""Build a local, ad-hoc FxPlug diagnostic without vendoring Apple's SDK.

Compiles the same checked-in model/Skia sources as Studio; no editor shell,
ProjectDocument, exporter, weather HTTP client, or second overlay renderer is linked.
"""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    try:
        subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"FxPlug build step failed ({args[0]}, exit {error.returncode}); see diagnostics above") from None


def plist(path, value):
    path.write_bytes(plistlib.dumps(value, sort_keys=True))


def shared_sources():
    sources = list((ROOT / "Sources/OverlayPluginCore").glob("*.swift"))
    for directory in ["FitData", "Overlay", "Render/Skia"]:
        sources += list((ROOT / "Sources/RunningOverlay" / directory).rglob("*.swift"))
    for file in [
        "App/RunningOverlayResources.swift", "App/PresetFonts.swift", "Project/FontLibraryManager.swift",
        "Project/HeartRateZonePreferences.swift", "Project/IntervalKindColorPreferences.swift",
        "Project/UserAssetStore.swift", "Weather/WeatherFetchLocationMode.swift",
        "Render/OverlayFontResolver.swift", "Render/OverlayRendererVersion.swift",
        "Render/SkiaMetalRenderSession.swift", "Export/SkiaEasyRunRenderer.swift",
        "Export/EditorIntegration/PluginDataPackageService.swift",
        "Export/EditorIntegration/PluginMetalRenderSession.swift",
    ]:
        sources.append(ROOT / "Sources/RunningOverlay" / file)
    return sorted(set(sources))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skia-dir", type=Path, default=os.environ.get("SKIA_DIR"), required="SKIA_DIR" not in os.environ)
    parser.add_argument("--package", type=Path, required=True, help="Prepared synthetic numeric-only .roplugin")
    parser.add_argument("--output", type=Path, default=ROOT / "build/fxplug-spike")
    args = parser.parse_args()
    skia = args.skia_dir.resolve()
    output = args.output.resolve()
    package = args.package.resolve()
    sdk = Path(os.environ.get("FXPLUG_SDK_DIR", "/Library/Developer/SDKs/FxPlug.sdk"))
    frameworks = Path(os.environ.get("FXPLUG_FRAMEWORK_DIR", "/Library/Developer/Frameworks"))
    if not package.is_file():
        parser.error("--package must name an existing prepared synthetic package")
    if not (sdk / "Library/Frameworks/FxPlug.framework/Headers/FxPlugSDK.h").is_file():
        parser.error("Install Apple's FxPlug SDK or set FXPLUG_SDK_DIR")
    if output.exists():
        parser.error("--output must be a new directory; existing diagnostic builds are preserved")
    run("python3", "scripts/validate-skia-sdk.py", skia)
    output.mkdir(parents=True)
    app = output / "Running Overlay FxPlug Diagnostic.app"
    service = app / "Contents/PlugIns/RunningOverlayFxPlug.pluginkit"
    for bundle in [app, service]:
        for directory in ["MacOS", "Resources", "Frameworks"]:
            (bundle / "Contents" / directory).mkdir(parents=True, exist_ok=True)
    resources = service / "Contents/Resources"
    # Current source-group sharing retains rendering-only SwiftUI icon helpers
    # and preference models; editor views and network clients are excluded.
    for source in (ROOT / "Sources/RunningOverlay/Resources").iterdir():
        destination = resources / source.name
        if source.is_dir():
            shutil.copytree(source, destination, ignore=shutil.ignore_patterns(".DS_Store"))
        elif source.name != ".DS_Store":
            shutil.copy2(source, destination)
    shutil.copy2(package, resources / "PluginDemo.roplugin")
    bridge = ROOT / "Sources/CSkiaBridge"
    objects = []
    for name in ["skia_bridge.cpp", "skia_gpu.mm"]:
        obj = output / (name + ".o")
        command = ["xcrun", "clang++", "-std=c++20", "-mmacosx-version-min=15.0", "-DSKB_ENABLE_GRAPHITE=1", "-I", skia, "-I", bridge / "include", "-c", bridge / name, "-o", obj]
        if name.endswith(".mm"):
            command.insert(2, "-fobjc-arc")
        run(*command)
        objects.append(obj)
    host = ROOT / "Plugins/FinalCutPro"
    executable = service / "Contents/MacOS/RunningOverlayFxPlug"
    run("xcrun", "swiftc", "-swift-version", "6", "-Onone", "-g", "-module-name", "RunningOverlayFxPlug",
        "-target", "arm64-apple-macos15.0", "-I", bridge / "include",
        "-F", sdk / "Library/Frameworks", "-F", frameworks,
        "-import-objc-header", host / "FxPlugBridge.h", *shared_sources(),
        host / "RunningOverlayFxPlug.swift", host / "main.swift", *objects,
        "-L", skia / "lib", "-lskia", "-lc++", "-framework", "FxPlug", "-framework", "PluginManager",
        "-framework", "Metal", "-framework", "QuartzCore",
        "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks", "-o", executable)
    run("xcrun", "-sdk", "macosx", "metal", "-c", host / "OverlayComposite.metal", "-o", output / "composite.air")
    run("xcrun", "-sdk", "macosx", "metallib", output / "composite.air", "-o", resources / "default.metallib")
    run("xcrun", "swiftc", "-swift-version", "6", "-target", "arm64-apple-macos15.0", "-parse-as-library", host / "Wrapper.swift", "-o", app / "Contents/MacOS/RunningOverlayFxPlugDiagnostic")
    common = {"CFBundleInfoDictionaryVersion": "6.0", "CFBundleShortVersionString": "0.1", "CFBundleVersion": "1", "LSMinimumSystemVersion": "15.0"}
    plist(app / "Contents/Info.plist", dict(common, CFBundleExecutable="RunningOverlayFxPlugDiagnostic", CFBundleIdentifier="io.github.zijianwang90.runningoverlay.fxplug-diagnostic", CFBundleName="Running Overlay FxPlug Diagnostic", CFBundlePackageType="APPL", NSPrincipalClass="NSApplication", LSBackgroundOnly=True))
    group = "B40ABAFE-9EDA-49D1-9B9A-02B59650512D"
    plist(service / "Contents/Info.plist", dict(common,
        CFBundleExecutable="RunningOverlayFxPlug", CFBundleIdentifier="io.github.zijianwang90.runningoverlay.fxplug-diagnostic.effect", CFBundleName="RunningOverlayFxPlug", CFBundlePackageType="XPC!",
        PlugInKit={"Attributes": {"com.apple.protocol": "FxPlug", "com.apple.version": "1.1"}, "PrincipalClass": "FxPrincipal", "Protocol": "PROXPCProtocol", "Subsystems": ["NSViewService_PKSubsystem"]},
        ProPlugDictionaryVersion="1.0", ProPlugDynamicRegistration=False,
        ProPlugPlugInGroupList=[{"groupName": "Running Overlay Diagnostics", "uuid": group}],
        ProPlugPlugInList=[{"className": "RunningOverlayFxPlug", "displayName": "Running Overlay — Diagnostic", "group": group, "infoString": "Synthetic activity/template/offset probe; normal-speed host timing verified locally; color/distribution acceptance pending", "protocolNames": ["FxFilter"], "uuid": "9822E96D-1A02-4F84-8CF2-398BD9BC52CB", "version": "0.1"}],
        XPCService={"ServiceType": "Application", "JoinExistingSession": True, "RunLoopType": "_NSApplicationMain", "_AdditionalSubServices": {"viewbridge": True}}))
    library_dir = service / "Contents/Frameworks"
    shutil.copy2(skia / "lib/libskia.dylib", library_dir / "libskia.dylib")
    legal = resources / "Legal/Skia"
    legal.mkdir(parents=True, exist_ok=True)
    for source, name in [(skia / "LICENSE", "LICENSE"), (skia / "THIRD_PARTY_NOTICES.txt", "THIRD_PARTY_NOTICES.txt"), (skia / "licenses/skcms-LICENSE", "skcms-LICENSE")]:
        shutil.copy2(source, legal / name)
    for name in ["LICENSE", "THIRD_PARTY_NOTICES.md", "TRADEMARKS.md"]:
        shutil.copy2(ROOT / name, resources / "Legal" / name)
    for name in ["FxPlug", "PluginManager"]:
        destination = library_dir / (name + ".framework")
        shutil.copytree(frameworks / (name + ".framework"), destination, symlinks=True, ignore=shutil.ignore_patterns("Headers"))
        run("codesign", "--force", "--sign", "-", destination)
    run("codesign", "--force", "--sign", "-", library_dir / "libskia.dylib")
    entitlements = output / "diagnostic.entitlements"
    plist(entitlements, {"com.apple.security.app-sandbox": True})
    run("codesign", "--force", "--sign", "-", "--entitlements", entitlements, service)
    run("codesign", "--force", "--sign", "-", "--entitlements", entitlements, app)
    run("codesign", "--verify", "--deep", "--strict", app)
    run(executable, "--self-test")
    print("Built diagnostic:", app)
    print("No installation or PlugInKit registration performed.")


if __name__ == "__main__":
    main()
