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
- Preserve `RunningOverlay_RunningOverlay.bundle` as a complete bundle under
  the app's `Contents/Resources`. SwiftPM may produce either a flat bundle or
  a macOS `Contents/Resources` layout; copying only its contents can nest the
  resources outside the runtime lookup path. The bundle build runs
  `scripts/validate-packaged-resources.swift` to load all built-in templates,
  the symbol catalog, and weather icons through Foundation `Bundle` before signing.
- Keep signing certificates, provisioning profiles, archives, API keys, and
  other release secrets out of the repository.
- The app-bundle build copies the MIT License, trademark policy, and
  third-party notices into `Contents/Resources/Legal/`. Do not remove those files from distributed
  builds.

## Preflight Commands

```sh
scripts/generate-xcode-project.rb
scripts/validate-appstore-config.sh
xcodebuild \
  -project RunningOverlay.xcodeproj \
  -scheme RunningOverlay \
  -configuration Debug \
  SKIA_DIR=/path/to/pinned-skia-sdk ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild \
  -project RunningOverlay.xcodeproj \
  -scheme RunningOverlay \
  -configuration Release \
  -archivePath /tmp/RunningOverlay.xcarchive \
  SKIA_DIR=/path/to/pinned-skia-sdk ARCHS=arm64 \
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

Mac App Store marketing captures use the deterministic layout, copy, source
handling, and export workflow in `docs/app-store-screenshot-template.md`.

## GitHub Release Tags

The first public version is `0.1.0`. Use release-candidate tags to validate the
GitHub release path before creating the final `v0.1.0` tag:

```sh
git checkout main
git tag -a v0.1.0-rc.1 -m "Running Overlay Studio v0.1.0-rc.1"
git push origin v0.1.0-rc.1
```

The `Release` workflow accepts release-candidate tags matching `v*-rc.*` and
final release tags matching `vMAJOR.MINOR.PATCH`. It verifies that the tag's
marketing version matches `Config/AppStore.xcconfig`, runs the full check,
visual regression, publication audit, App Store configuration validation,
optimized SwiftPM product build, Developer ID signing, Apple notarization,
stapling, and Gatekeeper validation, then uploads a macOS arm64 zip and a
SHA-256 checksum. Release-candidate tags create draft pre-releases; final tags
create published releases marked as latest. The zip uses
`RunningOverlayStudio-${tag}-macOS-arm64.zip`, while the app bundle inside is
`Running Overlay Studio.app`.

Every GitHub Release must have handwritten notes committed before the tag is
pushed. Add `docs/releases/${tag}.md`, for example
`docs/releases/v0.1.6.md`, using the established release-page structure:
opening release sentence with marketing version and build number, a concise
summary paragraph, `## Highlights` grouped by user-facing area, and `## Assets`
that names both `RunningOverlayStudio-${tag}-macOS-arm64.zip` and
`RunningOverlayStudio-${tag}-macOS-arm64.zip.sha256`. The release workflow fails
when the matching note file is missing, empty, or does not mention the uploaded
zip and checksum asset names.

GitHub release candidates use a Developer ID Application certificate and App
Store Connect API key stored in GitHub Actions secrets. Do not commit signing
certificates, `.p8` keys, notarization credentials, temporary keychains, or
derived release archives.

If an RC fails because code changes are needed, fix the issue, merge the new
commit to `main`, and create the next RC tag, for example `v0.1.0-rc.2`. When
the App Store submission build is accepted without further code changes, create
the final `v0.1.0` tag on the same commit:

```sh
git tag -a v0.1.0 -m "Running Overlay Studio v0.1.0"
git push origin v0.1.0
```

Only create the final source tag after the release-candidate artifact has been
downloaded and accepted. If only App Store metadata changes are required after
the final source tag, do not create a new source tag. Increment
`CFBundleVersion` as needed for App Store uploads while keeping the same
`CFBundleShortVersionString` and source commit.

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

## Skia Development Cutover Bundle

With the pinned m159 SDK unpacked outside the repository:

```sh
SKIA_DIR=/path/to/skia-sdk SKIA_GPU=1 SKIA_GRAPHITE=1 \
  scripts/build-appstore-app.sh
```

This packages the Release Skia preview/export path, embeds `libskia.dylib` in
`Contents/Frameworks`, removes SwiftPM's absolute SDK rpath, adds the relative
Frameworks rpath, and signs the dylib before signing the app. The default `-`
identity is local ad-hoc preflight. That mode omits Hardened Runtime because
ad-hoc signatures have no Team ID for validating embedded libraries. Real
certificate identities keep Hardened Runtime on both app and dylib; Developer
ID/notarization validation remains a distribution gate. SDK-free
bundles are still available for CI but are not the Skia product configuration.
The native Xcode target now compiles the same C bridge with C++20 and Graphite,
links the SDK dylib, and embeds/signs it before Xcode signs the application.
Pass `SKIA_DIR` as an Xcode build setting, or define it in ignored
`Config/LocalSigning.xcconfig`. Native builds default to `SKIA_ENABLED=YES`;
missing SDK inputs fail the build. Explicit `SKIA_ENABLED=NO` is reserved for
SDK-free editor development. The generated project is independent of local
SDK paths. The embed phase disables Xcode script sandboxing to validate Mach-O
files and sign the externally supplied SDK; application sandboxing stays on.
For local ad-hoc native builds, also use `ENABLE_HARDENED_RUNTIME=NO`; real
certificate builds retain Hardened Runtime. Unsigned archives are structural
preflight only and cannot establish distribution-signing acceptance.

Both packaging paths validate the source commit, recipe/builder identity and
binary digest from the SDK manifest, and include the SDK's Skia/skcms license
texts. The CI `skia-product` check aggregates parallel jobs that build/cache the pinned SDK on arm64, run the
Graphite tests and creates an ad-hoc signed native archive plus an ad-hoc SwiftPM
bundle. It also smoke-exports all three built-in templates from a disposable
sandboxed archive copy; the harness grants only its temporary output directory.
The release workflow uses the same SDK setup so tags cannot silently
produce the SDK-free renderer. Cache keys include the recipe, builder, CPU and
Xcode version. The existing SDK-free job remains independent.

For sandboxed headless bundle smoke tests, stage a copy of the app with synthetic
FIT/template inputs inside its Resources and re-sign that test copy with the
same sandbox entitlements. Write test exports into a unique subdirectory of
the app's container temporary directory. Raw repository input paths have no
Powerbox grant and are correctly denied by the sandbox. Keep the distributable
bundle free of these injected test fixtures.
