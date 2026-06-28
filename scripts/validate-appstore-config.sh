#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

plutil -lint \
  "$ROOT_DIR/AppStore/Info.plist" \
  "$ROOT_DIR/AppStore/RunningOverlay.entitlements" \
  "$ROOT_DIR/AppStore/PrivacyInfo.xcprivacy" >/dev/null

if /usr/libexec/PlistBuddy -c "Print :NSLocationWhenInUseUsageDescription" "$ROOT_DIR/AppStore/Info.plist" >/dev/null 2>&1; then
  echo "AppStore/Info.plist must not declare current-location usage." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c "Print :com.apple.security.personal-information.location" "$ROOT_DIR/AppStore/RunningOverlay.entitlements" >/dev/null 2>&1; then
  echo "AppStore/RunningOverlay.entitlements must not request location access." >&2
  exit 1
fi

python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/Contents.json" >/dev/null
python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/AccentColor.colorset/Contents.json" >/dev/null
python3 -m json.tool "$ROOT_DIR/AppStore/Assets.xcassets/AppIcon.appiconset/Contents.json" >/dev/null

for spec in \
  "icon_16x16.png:16" \
  "icon_16x16@2x.png:32" \
  "icon_32x32.png:32" \
  "icon_32x32@2x.png:64" \
  "icon_128x128.png:128" \
  "icon_128x128@2x.png:256" \
  "icon_256x256.png:256" \
  "icon_256x256@2x.png:512" \
  "icon_512x512.png:512" \
  "icon_512x512@2x.png:1024"; do
  filename="${spec%%:*}"
  expected="${spec##*:}"
  path="$ROOT_DIR/AppStore/Assets.xcassets/AppIcon.appiconset/$filename"
  width="$(/usr/bin/sips -g pixelWidth "$path" 2>/dev/null | /usr/bin/awk '/pixelWidth/ {print $2}')"
  height="$(/usr/bin/sips -g pixelHeight "$path" 2>/dev/null | /usr/bin/awk '/pixelHeight/ {print $2}')"
  if [[ "$width" != "$expected" || "$height" != "$expected" ]]; then
    echo "Invalid AppIcon size for $filename: ${width}x${height}, expected ${expected}x${expected}." >&2
    exit 1
  fi
done

/usr/bin/xcrun xcodebuild -project "$ROOT_DIR/RunningOverlay.xcodeproj" -list >/dev/null

effective_team="$(
  /usr/bin/xcrun xcodebuild \
    -project "$ROOT_DIR/RunningOverlay.xcodeproj" \
    -scheme RunningOverlay \
    -configuration Release \
    -showBuildSettings 2>/dev/null |
    /usr/bin/awk -F= '/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}'
)"

if [[ -z "$effective_team" ]]; then
  echo "App Store placeholder still needs product/account value:"
  echo "$ROOT_DIR/Config/AppStore.xcconfig:8:DEVELOPMENT_TEAM ="
fi

placeholder_pattern="support URL|privacy policy URL|TODO"
if [[ -x /opt/homebrew/bin/rg ]]; then
  placeholder_search=(/opt/homebrew/bin/rg -n "$placeholder_pattern")
elif [[ -x /usr/local/bin/rg ]]; then
  placeholder_search=(/usr/local/bin/rg -n "$placeholder_pattern")
else
  placeholder_search=(/usr/bin/grep -R -n -E "$placeholder_pattern")
fi

if "${placeholder_search[@]}" "$ROOT_DIR/AppStore" "$ROOT_DIR/Config" "$ROOT_DIR/docs/app-store-readiness.md" >/tmp/running-overlay-appstore-placeholders.txt; then
  echo "App Store placeholders still need product/account values:"
  /bin/cat /tmp/running-overlay-appstore-placeholders.txt
fi

echo "App Store configuration files are syntactically valid."
