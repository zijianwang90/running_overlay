#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIGURATION="${RUNNING_OVERLAY_CONFIGURATION:-release}"
PRODUCT_NAME="RunningOverlay"
APPSTORE_DIR="$ROOT_DIR/AppStore"
INFO_PLIST_TEMPLATE="$APPSTORE_DIR/Info.plist"
PRIVACY_MANIFEST="$APPSTORE_DIR/PrivacyInfo.xcprivacy"
ENTITLEMENTS="$APPSTORE_DIR/RunningOverlay.entitlements"
OUTPUT_DIR="$ROOT_DIR/build/AppStore"
APP_DIR="$OUTPUT_DIR/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

BUNDLE_ID="${RUNNING_OVERLAY_BUNDLE_ID:-io.github.zijianwang90.runningoverlay}"
MARKETING_VERSION="${RUNNING_OVERLAY_MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${RUNNING_OVERLAY_BUILD_NUMBER:-1}"
SIGN_IDENTITY="${RUNNING_OVERLAY_SIGN_IDENTITY:--}"

cd "$ROOT_DIR"

swift build -c "$BUILD_CONFIGURATION" >&2

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/$BUILD_CONFIGURATION/$PRODUCT_NAME" "$MACOS_DIR/$PRODUCT_NAME"

RESOURCE_BUNDLE=".build/$BUILD_CONFIGURATION/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE/." "$RESOURCES_DIR/"
fi

cp "$PRIVACY_MANIFEST" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"

INFO_PLIST="$CONTENTS_DIR/Info.plist"
cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST" >/dev/null

chmod +x "$MACOS_DIR/$PRODUCT_NAME"

codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_DIR" >&2
codesign --verify --deep --strict --verbose=2 "$APP_DIR" >&2

echo "$APP_DIR"
