# Credentials

Last updated: 2026-11-01

Running Overlay Studio never ships a provider credential. Every API key and
access token belongs to the person running the app, is entered in the app or
the Resolve panel, and stays in user-level storage on that Mac. Repository
contributors, test fixtures, templates, render bundles, and packaged builds
must not contain one.

## Policy

- Users paste their own tokens. The project does not include, proxy, embed, or
  distribute shared keys.
- A credential never enters a project file, project snapshot, template, render
  data bundle, log, test fixture, screenshot, or committed configuration file.
- If a real credential is committed, treat it as compromised: remove it from
  the working tree and from history, rotate it at the provider, and only then
  push the cleaned history.
- Test and documentation examples use synthetic values that no provider would
  accept.

## Where Tokens Live

### macOS app

The OpenWeather API key is stored as a generic password in the macOS Keychain:

- service: `io.github.zijianwang90.runningoverlay.credentials`
- account: `openweather-api-key`

The app reads it from Keychain on launch and writes it back only when the user
edits the field in Project Settings. It is not encoded into `.roproj` files,
templates, autosave copies, or exported videos. Project files that still carry
the retired `openWeatherAPIKey` field are migrated to Keychain on open and the
field is removed on the next save. See [Persistence](../development/persistence.md)
and the [privacy policy](../../PRIVACY.md).

Development builds run with `swift run` have no bundle identifier, so they use
an in-memory credential store instead of touching Keychain. Set
`RUNNING_OVERLAY_DISABLE_KEYCHAIN=1` to force that behavior in any build.

### Resolve plugin

The Mapbox token is a user-level setting, not a project setting. The panel
accepts only a public token (`pk.*`), not a secret token (`sk.*`), and stores it
in:

```text
~/Library/Application Support/Running Overlay Resolve/settings.json
```

The directory is created with mode `0700` and the settings file with mode
`0600`. The token is not written into per-project configuration files, render
data bundles, templates, or exports. Older per-project tokens are migrated to
the settings file once and removed from the project configuration. See
`RunningOverlayResolve/docs/architecture.md`.

## What the Audit Scans

`./scripts/publication-audit.sh` runs `./scripts/scan-credentials.sh` over the
files that can ship:

- tracked source: `Sources/`, `RunningOverlayResolve/src/`,
  `RunningOverlayResolve/workflow-plugin/`, `RunningOverlayResolve/fusion/`,
  `scripts/`, `Package.swift`, and every `*.entitlements` file;
- packaged output when present: `RunningOverlayResolve/workflow-plugin/lib/`,
  `RunningOverlayResolve/dist/`, and `build/AppStore/`.

It fails the audit when it finds:

| Kind | Pattern |
|---|---|
| Mapbox public or secret token | `pk.` or `sk.` followed by a long token run |
| AWS access key ID | `AKIA` plus 16 uppercase letters or digits |
| GitHub token | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, or `github_pat_` plus a long run |
| Slack token | `xoxb-`, `xoxa-`, `xoxp-`, `xoxr-`, or `xoxs-` plus a long run |
| PEM private key | a `BEGIN ... PRIVATE KEY` header |
| Credential assignment | `client_secret` or `api_key` (and their common case variants) set to a long quoted value |

The scan does not flag the literal parameter name `access_token` or the
`validToken` regular expression used by the Mapbox client. Assignment matches
require a quoted value, so a variable reference such as
`apiKey: openWeatherAPIKey` is not a finding. Values that read as placeholders
(for example `YOUR_API_KEY_HERE`, `example`, `placeholder`, or anything with a
`$`, `{`, or `<` interpolation marker) are ignored.

A finding names the file, line number, and credential kind. The value is
redacted to its first four characters, so the audit never prints the
credential. The audit exits non-zero with
`Credential scan failed. Remove the credential and rotate it at the provider.`

### Excluded Directories

The scan skips `test/`, `fixtures/`, `docs/`, and `.git/`. Synthetic tokens are
legitimate in tests, documentation, and examples, and those paths are not
shipped in a build or plugin bundle. Excluding them keeps the matcher strict
for the files that can actually reach a user. The scanner and audit scripts
themselves are also excluded because they contain the pattern literals.

## Validating the Scan

```sh
./scripts/publication-audit.sh            # full publication audit
./scripts/scan-credentials.sh             # credential scan only
./scripts/scan-credentials.sh --self-test # planted fake token must fail
./scripts/scan-credentials.sh --scan-file path/to/file
```

The self-test writes its fixtures to a temporary directory outside the
repository, asserts that a planted fake `pk.` token is detected and redacted,
and asserts that a clean file passes. It leaves no fixtures behind.

## Rotating or Clearing a Token

macOS app:

1. Open Project Settings and clear the OpenWeather API Key field. Saving an
   empty value deletes the Keychain item.
2. If the key may have been exposed, revoke it in the OpenWeather account and
   create a replacement.
3. To remove the item without launching the app, delete the generic password
   for service `io.github.zijianwang90.runningoverlay.credentials` in Keychain
   Access.

Resolve plugin:

1. Clear the Mapbox token field in the panel and save the settings. The empty
   value replaces the stored token.
2. If the token may have been exposed, rotate it in the Mapbox account and
   paste the replacement.
3. To remove the token without the panel, delete
   `~/Library/Application Support/Running Overlay Resolve/settings.json`.
