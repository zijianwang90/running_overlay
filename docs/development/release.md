# Release and Mac App Store Packaging

The App Store release path uses `RunningOverlay.xcodeproj` with configuration
under `AppStore/` and `Config/`. SwiftPM remains available for fast development
and tests; both build paths compile the same files under
`Sources/RunningOverlay`.

## Release Configuration

- Keep App Store-only bundle metadata in `AppStore/Info.plist`.
- Keep `CFBundleDisplayName` and `CFBundleName` aligned with the App Store
  Connect product name. The internal target, executable, and module name can
  remain `RunningOverlay`.
- Keep sandbox permissions in `AppStore/RunningOverlay.entitlements`.
- Keep privacy declarations in `AppStore/PrivacyInfo.xcprivacy`. Update them
  whenever file access, network services, location use, credential handling,
  analytics, or third-party SDK behavior changes.
- Use `Config/AppStore.xcconfig` for product defaults and placeholders that must
  be replaced by real Apple Developer account values before submission.
- Keep account-specific signing overrides in ignored
  `Config/LocalSigning.xcconfig`. Copy
  `Config/LocalSigning.xcconfig.example`, set `DEVELOPMENT_TEAM`, and let
  `Config/AppStore.xcconfig` include it locally.
- Regenerate `RunningOverlay.xcodeproj` with
  `scripts/generate-xcode-project.rb` after adding or removing Swift source
  files, bundled resources, or legal notices. The shared `RunningOverlay`
  scheme supports Build, Run, Profile, Analyze, and Archive.
- Keep all ten macOS icon renditions in
  `AppStore/Assets.xcassets/AppIcon.appiconset`; the 1024 px
  `icon_512x512@2x.png` rendition is the production master.
- Keep signing certificates, provisioning profiles, archives, API keys, and
  other release secrets out of the repository.
- The app-bundle build copies the PolyForm Shield license, commercial
  licensing notice, trademark policy, and third-party notices into
  `Contents/Resources/Legal/`. Do not remove those files from distributed
  builds.

## Preflight Commands

```sh
scripts/generate-xcode-project.rb
scripts/validate-appstore-config.sh
xcodebuild \
  -project RunningOverlay.xcodeproj \
  -scheme RunningOverlay \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild \
  -project RunningOverlay.xcodeproj \
  -scheme RunningOverlay \
  -configuration Release \
  -archivePath /tmp/RunningOverlay.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  archive
```

The unsigned commands verify the complete app and archive structure before an
Apple Developer team is available. For App Store upload, copy
`Config/LocalSigning.xcconfig.example` to `Config/LocalSigning.xcconfig`, set
`DEVELOPMENT_TEAM`, select the registered App ID in Xcode, archive without
`CODE_SIGNING_ALLOWED=NO`, then validate and distribute through Organizer.

The older `scripts/build-appstore-app.sh` and
`scripts/archive-appstore-app.sh` remain useful for SwiftPM-based bundle
preflight, but the Xcode archive is the release/upload path.

Current submission blockers and metadata drafts are tracked in
`docs/app-store-readiness.md`.
