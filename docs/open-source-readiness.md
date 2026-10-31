# Open Source Publication Readiness

Last reviewed: 2026-10-31

## Repository Status

The repository is open source under the OSI-approved MIT License. The Mac App
Store build is free of charge.

Completed controls:

- MIT License for project code, documentation, fixtures, and templates;
- trademark policy and documented asset exclusions for project branding and
  donation images;
- Developer Certificate of Origin for contributions;
- user-facing privacy, support, and maintainer policies;
- third-party dependency and asset provenance;
- no bundled font binaries with undocumented redistribution rights;
- no undeclared third-party runtime dependencies;
- tool-neutral contributor and AI-agent instructions;
- contribution, security, and conduct policies;
- deterministic build, test, visual regression, and audit commands;
- GitHub Actions validation;
- weekly Dependabot checks for GitHub Actions and Swift packages;
- synthetic FIT and visual test fixtures;
- issue and pull request templates;
- current-tree scan for credentials, sensitive file types, absolute developer
  paths, and undocumented font files;
- Git history scan for common private-key and service-token patterns.

## Maintenance Checklist

Before a source or binary release:

1. Run `./scripts/check.sh`, `./scripts/visual-test.sh`, and
   `./scripts/publication-audit.sh` on the release commit.
2. Confirm `docs/assets-and-licenses.md` covers every new asset and states any
   exclusion from the MIT License.
3. Keep the following GitHub settings enabled:
   - private vulnerability reporting;
   - secret scanning and push protection;
   - the labels listed in `docs/issue-labels.md`;
   - protection for `main`, with the CI check required before merge;
   - no force pushes or branch deletion on protected branches.
4. Use `main` as the default contribution target. All changes should use
   short-lived branches and pull requests.

## Known Non-Blocking Items

- Existing Swift 6 concurrency warnings do not fail the build but should be
  tracked and reduced.
- OpenWeather credentials are stored in macOS Keychain and excluded from
  project snapshots. Contributors must never include real keys in fixtures,
  issues, or saved project examples.
- Historical commits may retain ordinary author metadata and previous
  machine-path text even though the current tree is clean. Rewrite history
  only if the repository owner considers that metadata sensitive.
- App distribution, signing, notarization, privacy disclosures, and App Store
  readiness are separate from source publication readiness.
