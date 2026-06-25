# Maintainers

Running Overlay is currently maintained by
[@zijianwang90](https://github.com/zijianwang90).

## Review Policy

Before merging a pull request, maintainers should confirm:

- the change is focused and its acceptance criteria are satisfied;
- `./scripts/check.sh` and `./scripts/open-source-audit.sh` pass;
- new behavior and bug fixes have appropriate tests;
- GUI-visible changes include manual or visual verification;
- relevant requirements, architecture, development, and monthly project-log
  documents are updated;
- no private activity data, credentials, machine state, generated exports, or
  unlicensed assets are included;
- new dependencies and externally sourced assets have compatible license
  provenance in `THIRD_PARTY_NOTICES.md` or `docs/assets-and-licenses.md`.

## High-Risk Changes

Focused maintainer review is required for:

- FIT parsing, GPS, health metrics, media paths, or project-file compatibility;
- timing-domain conversion, media alignment, undo/redo, and persistence;
- preview/export parity, codecs, alpha output, and performance;
- network access, weather providers, Keychain, analytics, crash reporting, or
  other privacy/security behavior;
- dependencies, copied assets, fonts, fixtures, generated code, and licensing;
- CI, release automation, signing, notarization, and legal/policy files.

High-risk pull requests must explain affected data flows, compatibility risks,
and exact verification performed.

## Merge Discipline

Do not merge draft pull requests, failing required checks, unresolved review
threads, unrelated generated diffs, or changes without a clear summary.
Exceptions require a maintainer to document the reason and remaining risk.

Normal contributions target `develop`. `main` remains release-only. Force
pushes and deletion should be disabled for both protected branches.

## Release Policy

Before a source or binary release:

- run the repository checks on the release commit;
- verify license, privacy, security, and third-party notices;
- confirm release artifacts contain required legal files;
- verify signing/notarization separately when distributing a macOS app bundle;
- publish release notes that identify compatibility or data-handling changes.
