# Source-Available Publication Readiness

Last reviewed: 2026-06-25

## Repository Status

The repository is ready for public source publication under the PolyForm
Shield License after this readiness change is reviewed and merged.

Completed controls:

- PolyForm Shield 1.0.0 source-available license;
- separate commercial licensing path, trademark policy, and contributor
  license agreement;
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

1. Merge the readiness branch into `main` through a pull request.
2. Run `./scripts/check.sh`, `./scripts/visual-test.sh`, and
   `./scripts/publication-audit.sh` on the merge commit.
3. Confirm the repository owner is intentionally licensing the repository
   assets listed in `docs/assets-and-licenses.md` under PolyForm Shield.
4. Have qualified counsel review the project-specific commercial licensing,
   trademark, and CLA documents before relying on them for enforcement.
5. Review Git author email visibility and old commit metadata. No credential
   patterns were found, but public Git history is permanent.
6. Immediately after making the repository public, configure GitHub settings:
   - enable private vulnerability reporting;
   - enable secret scanning and push protection;
   - create the labels listed in `docs/issue-labels.md`;
   - protect `main`;
   - require the CI check before merge;
   - disable force pushes and branch deletion for protected branches.
7. Use `main` as the default contribution target. All subsequent changes
   should use short-lived branches and pull requests.
8. Publish an initial release only after release packaging and end-user
   installation instructions are separately verified.

## Known Non-Blocking Items

- Existing Swift 6 concurrency warnings predate this readiness change. They do
  not fail the build but should be tracked and reduced.
- PolyForm Shield is source-available but is not an OSI-approved open-source
  license. Public descriptions must not present the project as OSI open source.
- OpenWeather credentials are stored in macOS Keychain and excluded from
  project snapshots. Contributors must never include real keys in fixtures,
  issues, or saved project examples.
- Historical commits may retain ordinary author metadata and previous
  machine-path text even though the current tree is clean. Rewrite history
  only if the repository owner considers that metadata sensitive; history
  rewriting is not required for source-license compliance.
- App distribution, signing, notarization, privacy disclosures, and App Store
  readiness are separate from source publication readiness.
