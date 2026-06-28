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
- `scripts/build-appstore-app.sh` packages the SwiftPM-built executable as
  `Running Overlay Studio.app` and converts the AppIcon renditions into
  `Contents/Resources/AppIcon.icns` so GitHub Release downloads show the
  production Finder icon and product name. Keep the internal executable,
  target, and module name as `RunningOverlay`.
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

The `scripts/build-appstore-app.sh` and `scripts/archive-appstore-app.sh`
commands remain useful for SwiftPM-based bundle preflight and GitHub Release
packaging. The Xcode archive remains the App Store upload path.

Current submission blockers and metadata drafts are tracked in
`docs/app-store-readiness.md`.

## GitHub Release Candidate Tags

The first public version is `0.1.0`. Use release-candidate tags to validate the
GitHub release path before creating the final `v0.1.0` tag:

```sh
git checkout main
git tag -a v0.1.0-rc.1 -m "Running Overlay v0.1.0-rc.1"
git push origin v0.1.0-rc.1
```

The `Release Candidate` workflow accepts only tags matching `v*-rc.*`. It
verifies that the tag's marketing version matches `Config/AppStore.xcconfig`,
runs the full check, visual regression, publication audit, App Store
configuration validation, optimized SwiftPM product build, Developer ID
signing, Apple notarization, stapling, and Gatekeeper validation, then creates a
draft GitHub pre-release with a macOS arm64 zip and a SHA-256 checksum. The zip
keeps the repository-oriented asset name, while the app bundle inside is
`Running Overlay Studio.app`.

GitHub release candidates use a Developer ID Application certificate and App
Store Connect API key stored in GitHub Actions secrets. Do not commit signing
certificates, `.p8` keys, notarization credentials, temporary keychains, or
derived release archives.

If an RC fails because code changes are needed, fix the issue, merge the new
commit to `main`, and create the next RC tag, for example `v0.1.0-rc.2`. When
the App Store submission build is accepted without further code changes, create
the final `v0.1.0` tag on the same commit:

```sh
git tag -a v0.1.0 -m "Running Overlay v0.1.0"
git push origin v0.1.0
```

If only App Store metadata changes are required, do not create a new source tag.
Increment `CFBundleVersion` as needed for App Store uploads while keeping the
same `CFBundleShortVersionString` and source commit.

Required GitHub Actions secrets for notarized release assets:

- `DEVELOPER_ID_APPLICATION_CERTIFICATE_P12`: base64-encoded Developer ID
  Application `.p12`.
- `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`: password used when exporting
  the `.p12`.
- `DEVELOPER_ID_APPLICATION_SIGNING_IDENTITY`: full signing identity, for
  example `Developer ID Application: ZIJIAN WANG (TEAMID)`.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `ASC_KEY_ID`: App Store Connect API key id.
- `ASC_ISSUER_ID`: App Store Connect issuer id.
- `ASC_API_KEY_P8`: full App Store Connect `.p8` private key contents.
