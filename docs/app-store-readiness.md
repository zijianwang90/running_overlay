# Mac App Store Readiness

Last updated: 2026-06-25

This document tracks the first Mac App Store submission path for Running Overlay.

## Current Release Target

- Target channel: Mac App Store first submission.
- Target scope: existing core app capabilities, including FIT import, video import, timeline editing, overlay design, Route Map, Weather Widget, and transparent MOV export.
- Development branch: `develop` after integration of the App Store readiness work.
- Bundle identifier: `io.github.zijianwang90.runningoverlay`.
- Keychain service: `io.github.zijianwang90.runningoverlay.credentials`.

## Implemented Packaging Files

- `AppStore/Info.plist`: app bundle metadata, macOS 15 minimum, App Store video category, and ATS default-deny arbitrary loads.
- `AppStore/RunningOverlay.entitlements`: App Sandbox, user-selected file read/write access, and outbound network client access.
- `AppStore/PrivacyInfo.xcprivacy`: privacy manifest declaring no tracking and no collected data, plus required-reason API declarations for file timestamps and app-scoped user defaults.
- `AppStore/Assets.xcassets`: production Running Overlay app icon in all ten
  macOS icon slots plus the app accent color.
- `Config/AppStore.xcconfig`: release defaults for the selected bundle id,
  marketing version, build number, deployment target, and signing placeholders.
- `RunningOverlay.xcodeproj`: native macOS Application target with a shared
  scheme, Debug/Release configurations, App Sandbox entitlements, privacy
  manifest, resources, legal notices, and Archive support.
- `scripts/generate-xcode-project.rb`: deterministic project generator using
  the SwiftPM source/resource directories as the source list.
- `scripts/build-appstore-app.sh`: builds the SwiftPM release executable, assembles a macOS `.app`, copies resources and the privacy manifest, and signs with entitlements.
- `scripts/archive-appstore-app.sh`: creates a local `.xcarchive`-shaped artifact from the packaged app for preflight inspection.
- `scripts/validate-appstore-config.sh`: validates plist/json syntax and reports placeholder account/product values.

## Build And Signing

Local ad-hoc package validation:

```sh
scripts/generate-xcode-project.rb
scripts/validate-appstore-config.sh
xcodebuild -project RunningOverlay.xcodeproj -scheme RunningOverlay \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RunningOverlay.xcodeproj -scheme RunningOverlay \
  -configuration Release -archivePath /tmp/RunningOverlay.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

Distribution signing requires real Apple Developer account values:

```sh
RUNNING_OVERLAY_BUNDLE_ID="com.yourcompany.RunningOverlay" \
RUNNING_OVERLAY_MARKETING_VERSION="1.0.0" \
RUNNING_OVERLAY_BUILD_NUMBER="1" \
RUNNING_OVERLAY_SIGN_IDENTITY="3rd Party Mac Developer Application: Your Company (TEAMID)" \
scripts/build-appstore-app.sh
```

The Xcode target is the App Store release path. SwiftPM remains the normal
development and test path, and the project generator keeps both paths on the
same source and resource tree.

## Privacy Inventory

- User files: FIT files, source videos, SVG/icon assets, overlay templates, and export destinations are chosen through `NSOpenPanel` / `NSSavePanel`. The app should not scan arbitrary user directories.
- Local storage: user overlay templates are stored as JSON under Application Support.
- Network: Open-Meteo and optional user-configured OpenWeather historical weather requests, plus MapKit snapshot requests, are outbound only.
- Credentials: the optional OpenWeather API key is stored in the user's macOS Keychain, excluded from project snapshots/templates, and sent only to OpenWeather when that provider is selected.
- Location: weather lookup uses GPS coordinates from the imported FIT file. The app does not request the Mac's current location.
- Tracking/ads: none.
- User content upload: source videos and FIT files are not uploaded by the app.

## App Store Connect Metadata Draft

- Category: Photo & Video.
- Secondary category candidate: Sports.
- Subtitle draft: `Sports data overlays for running videos`.
- Description draft: Running Overlay helps runners and video creators turn FIT activity data into transparent video overlays for editors such as Final Cut Pro, DaVinci Resolve, and Premiere.
- Keywords draft: `running,FIT,overlay,video,telemetry,Garmin,route,weather`.
- Review notes should explain how to import a FIT file, import one or more videos, match clips on the timeline, add overlays, and export alpha-capable MOV files.
- Privacy policy URL, support URL, marketing URL, copyright owner, and
  production screenshots are still required.

## Remaining Release Blockers

- Register `io.github.zijianwang90.runningoverlay` in the Apple Developer
  account and fill the Apple Developer Team ID after membership activation.
- Run privacy report / App Store validation with the final dependency graph, Keychain behavior, and signing identity.
- Complete manual sandbox QA for file import, video import, template import/export, weather, MapKit, and MOV export.
- Prepare final App Store screenshots, privacy policy, support URL, review notes, and sample review assets.
