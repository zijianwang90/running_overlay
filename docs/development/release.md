# Release and Mac App Store Packaging

The App Store release path uses configuration under `AppStore/`, `Config/`,
and `scripts/`. SwiftPM remains the source-of-truth build graph for normal
development, while `scripts/build-appstore-app.sh` assembles a macOS app bundle
for sandbox and signing preflight.

## Release Configuration

- Keep App Store-only bundle metadata in `AppStore/Info.plist`.
- Keep sandbox permissions in `AppStore/RunningOverlay.entitlements`.
- Keep privacy declarations in `AppStore/PrivacyInfo.xcprivacy`. Update them
  whenever file access, network services, location use, credential handling,
  analytics, or third-party SDK behavior changes.
- Use `Config/AppStore.xcconfig` for product defaults and placeholders that must
  be replaced by real Apple Developer account values before submission.
- Keep signing certificates, provisioning profiles, archives, API keys, and
  other release secrets out of the repository.

## Preflight Commands

```sh
scripts/validate-appstore-config.sh
scripts/build-appstore-app.sh
scripts/archive-appstore-app.sh
```

Without `RUNNING_OVERLAY_SIGN_IDENTITY`, the build script uses ad-hoc signing
only and is not suitable for App Store upload. The archive script creates a
local archive-shaped artifact for inspection; it does not replace Organizer or
App Store Connect validation with a real distribution identity.

Current submission blockers and metadata drafts are tracked in
`docs/app-store-readiness.md`.
