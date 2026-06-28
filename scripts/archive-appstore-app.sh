#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/scripts/build-appstore-app.sh")"
ARCHIVE_DIR="$ROOT_DIR/build/AppStore/RunningOverlay.xcarchive"
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_BUNDLE_BASENAME="$(basename "$APP_PATH")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_INFO_PLIST")"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_INFO_PLIST")"
DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$APP_INFO_PLIST")"
SIGNING_IDENTITY="${RUNNING_OVERLAY_SIGN_IDENTITY:-Ad Hoc}"

rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR/Products/Applications"
cp -R "$APP_PATH" "$ARCHIVE_DIR/Products/Applications/"

cat > "$ARCHIVE_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ApplicationProperties</key>
	<dict>
		<key>ApplicationPath</key>
		<string>Applications/$APP_BUNDLE_BASENAME</string>
		<key>ArchiveVersion</key>
		<integer>2</integer>
		<key>CFBundleIdentifier</key>
		<string>$BUNDLE_ID</string>
		<key>CFBundleShortVersionString</key>
		<string>$MARKETING_VERSION</string>
		<key>CFBundleVersion</key>
		<string>$BUILD_NUMBER</string>
		<key>SigningIdentity</key>
		<string>$SIGNING_IDENTITY</string>
	</dict>
	<key>ArchiveVersion</key>
	<integer>2</integer>
	<key>CreationDate</key>
	<date>2026-06-22T00:00:00Z</date>
	<key>Name</key>
	<string>$DISPLAY_NAME</string>
	<key>SchemeName</key>
	<string>RunningOverlay</string>
</dict>
</plist>
PLIST

echo "$ARCHIVE_DIR"
