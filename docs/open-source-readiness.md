# Open-Source Readiness

Last reviewed: 2026-06-25

## Repository Status

The repository is ready for public source publication after this readiness
change is reviewed and merged.

Completed controls:

- MIT project license;
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

## Publication Checklist

Before changing repository visibility:

1. Merge the readiness branch into `develop`.
2. Run `./scripts/check.sh`, `./scripts/visual-test.sh`, and
   `./scripts/open-source-audit.sh` on the merge commit.
3. Confirm the repository owner is intentionally licensing the repository
   assets listed in `docs/assets-and-licenses.md` under MIT.
4. Review Git author email visibility and old commit metadata. No credential
   patterns were found, but public Git history is permanent.
5. Immediately after making the repository public, configure GitHub settings:
   - enable private vulnerability reporting;
   - enable secret scanning and push protection;
   - create the labels listed in `docs/issue-labels.md`;
   - protect `main`;
   - require the CI check before merge;
   - disable force pushes and branch deletion for protected branches.
6. After final integration, use `main` as the default contribution target and
   remove the long-lived `develop` branch. All subsequent changes should use
   short-lived branches and pull requests.
7. Publish an initial release only after release packaging and end-user
   installation instructions are separately verified.

## Known Non-Blocking Items

- Existing Swift 6 concurrency warnings predate this readiness change. They do
  not fail the build but should be tracked and reduced.
- OpenWeather credentials are stored in macOS Keychain and excluded from
  project snapshots. Contributors must never include real keys in fixtures,
  issues, or saved project examples.
- Historical commits may retain ordinary author metadata and previous
  machine-path text even though the current tree is clean. Rewrite history
  only if the repository owner considers that metadata sensitive; history
  rewriting is not required for source-license compliance.
- App distribution, signing, notarization, privacy disclosures, and App Store
  readiness are separate from source publication readiness.
