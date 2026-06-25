#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

plutil -lint \
  "$ROOT_DIR/AppStore/Info.plist" \
  "$ROOT_DIR/AppStore/RunningOverlay.entitlements" \
  "$ROOT_DIR/AppStore/PrivacyInfo.xcprivacy" >/dev/null

python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/Contents.json" >/dev/null
python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/AccentColor.colorset/Contents.json" >/dev/null
python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/AppIcon.appiconset/Contents.json" >/dev/null

if rg -n "DEVELOPMENT_TEAM =\\s*$|support URL|privacy policy URL|TODO" "$ROOT_DIR/AppStore" "$ROOT_DIR/Config" "$ROOT_DIR/docs/app-store-readiness.md" >/tmp/running-overlay-appstore-placeholders.txt; then
  echo "App Store placeholders still need product/account values:"
  cat /tmp/running-overlay-appstore-placeholders.txt
fi

echo "App Store configuration files are syntactically valid."
