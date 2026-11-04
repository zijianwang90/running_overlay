#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIGURATION="${RUNNING_OVERLAY_CONFIGURATION:-release}"
PRODUCT_NAME="RunningOverlay"
APP_BUNDLE_NAME="Running Overlay Studio"
APPSTORE_DIR="$ROOT_DIR/AppStore"
INFO_PLIST_TEMPLATE="$APPSTORE_DIR/Info.plist"
PRIVACY_MANIFEST="$APPSTORE_DIR/PrivacyInfo.xcprivacy"
ENTITLEMENTS="$APPSTORE_DIR/RunningOverlay.entitlements"
APP_ICON_SOURCE="$APPSTORE_DIR/Assets.xcassets/AppIcon.appiconset"
OUTPUT_DIR="$ROOT_DIR/build/AppStore"
APP_DIR="$OUTPUT_DIR/$APP_BUNDLE_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LEGAL_DIR="$RESOURCES_DIR/Legal"

BUNDLE_ID="${RUNNING_OVERLAY_BUNDLE_ID:-io.github.zijianwang90.runningoverlay}"
MARKETING_VERSION="${RUNNING_OVERLAY_MARKETING_VERSION:-0.1.6}"
BUILD_NUMBER="${RUNNING_OVERLAY_BUILD_NUMBER:-10}"
SIGN_IDENTITY="${RUNNING_OVERLAY_SIGN_IDENTITY:--}"
SIGN_OPTIONS=(--options runtime)
# Ad-hoc signatures have no Team ID, so hardened library validation cannot
# match the app and embedded dylib. Real distribution identities stay hardened.
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  SIGN_OPTIONS=()
fi

cd "$ROOT_DIR"

swift build -c "$BUILD_CONFIGURATION" >&2

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$LEGAL_DIR"

cp ".build/$BUILD_CONFIGURATION/$PRODUCT_NAME" "$MACOS_DIR/$PRODUCT_NAME"

# A Skia-enabled executable must load the signed, bundled SDK rather than the
# developer SDK's absolute SwiftPM rpath. SDK-free builds remain a CI utility.
if [[ -n "${SKIA_DIR:-}" ]]; then
  if [[ "${SKIA_GPU:-}" != "1" || ! -f "$SKIA_DIR/lib/libskia.dylib" ]]; then
    echo "App packaging requires the Metal Skia SDK (SKIA_GPU=1)." >&2
    exit 1
  fi
  python3 "$ROOT_DIR/scripts/validate-skia-sdk.py" "$SKIA_DIR"
  mkdir -p "$LEGAL_DIR/Skia"
  cp "$SKIA_DIR/LICENSE" "$LEGAL_DIR/Skia/LICENSE"
  cp "$SKIA_DIR/THIRD_PARTY_NOTICES.txt" "$LEGAL_DIR/Skia/THIRD_PARTY_NOTICES.txt"
  cp "$SKIA_DIR/licenses/skcms-LICENSE" "$LEGAL_DIR/Skia/skcms-LICENSE"
  FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
  mkdir -p "$FRAMEWORKS_DIR"
  cp "$SKIA_DIR/lib/libskia.dylib" "$FRAMEWORKS_DIR/libskia.dylib"
  # SwiftPM can also add an absolute Xcode toolchain rpath. Keep only the
  # system Swift runtime and relative paths, so Xcode/the SDK are not needed.
  python3 - "$MACOS_DIR/$PRODUCT_NAME" <<'PY'
import re
import subprocess
import sys

binary = sys.argv[1]
commands = subprocess.check_output(["otool", "-l", binary], text=True)
for path in re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", commands):
    if path.startswith("/") and path != "/usr/lib/swift":
        subprocess.run(["install_name_tool", "-delete_rpath", path, binary], check=True)
PY
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$MACOS_DIR/$PRODUCT_NAME"
  codesign --force "${SIGN_OPTIONS[@]}" --sign "$SIGN_IDENTITY" "$FRAMEWORKS_DIR/libskia.dylib" >&2
fi

RESOURCE_BUNDLE=".build/$BUILD_CONFIGURATION/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
# Stdout must stay the app path alone: the release workflow captures it.
swift "$ROOT_DIR/scripts/validate-packaged-resources.swift" "$APP_DIR" >&2

cp "$PRIVACY_MANIFEST" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
cp "$ROOT_DIR/LICENSE" "$LEGAL_DIR/LICENSE"
cp "$ROOT_DIR/TRADEMARKS.md" "$LEGAL_DIR/TRADEMARKS.md"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$LEGAL_DIR/THIRD_PARTY_NOTICES.md"

ICONSET_DIR="$(mktemp -d "$OUTPUT_DIR/AppIcon.XXXXXX.iconset")"
trap 'rm -rf "$ICONSET_DIR"' EXIT
cp "$APP_ICON_SOURCE"/icon_*.png "$ICONSET_DIR/"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

INFO_PLIST="$CONTENTS_DIR/Info.plist"
cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST" >/dev/null

chmod +x "$MACOS_DIR/$PRODUCT_NAME"

if [[ -n "${SKIA_DIR:-}" ]]; then
  python3 "$ROOT_DIR/scripts/validate-packaged-skia.py" "$APP_DIR"
fi

codesign --force --deep "${SIGN_OPTIONS[@]}" --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_DIR" >&2
codesign --verify --deep --strict --verbose=2 "$APP_DIR" >&2

echo "$APP_DIR"
