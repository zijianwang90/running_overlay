# Contributing to Running Overlay Studio

Running Overlay Studio welcomes human-authored and AI-assisted contributions. The
same review, testing, privacy, and licensing requirements apply to both.

## Environment

- macOS 15 or newer
- Xcode toolchain with Swift 6
- Git
- Optional: `just`

Clone the repository and validate the checkout:

```sh
./scripts/check.sh
```

## Workflow

1. Start from the latest `main`.
2. Choose an issue with explicit acceptance criteria, or discuss larger work
   before implementation.
3. Use a short-lived branch. Independent large features should use a sibling
   worktree.
4. Read `AGENTS.md` and the documents routed from `docs/index.md`.
5. Keep the change narrowly scoped.
6. Add or update tests and documentation.
7. Run `./scripts/check.sh` and any relevant focused or visual tests.
8. Open a pull request using the repository template.

All contributions target `main` through pull requests. Keep `main` protected,
release-ready, and free of direct commits.

## AI-Assisted Contributions

AI agents may implement, test, document, and review changes. The contributor
who opens the pull request remains responsible for:

- understanding the submitted code;
- verifying generated code and third-party license compatibility;
- ensuring no secrets, personal data, private media, or private prompts are
  included;
- accurately reporting tests and limitations;
- responding to review feedback.

Do not submit unreviewed bulk-generated changes.

All contributors must read and accept the repository
[Contributor License Agreement](../CLA.md). By submitting a pull request and
affirming its CLA checkbox, you grant the project owner the rights needed to
distribute the contribution under the PolyForm Shield license and separate
commercial licenses while retaining ownership of your contribution.

Do not submit a contribution if you cannot make the representations in the
CLA, including employer authorization and third-party provenance.

## Tests

Run all checks:

```sh
./scripts/check.sh
```

Run one test or suite:

```sh
./scripts/test.sh FitFileParserTests
```

Run visual regression tests:

```sh
./scripts/visual-test.sh
```

Visual snapshots may be regenerated with:

```sh
UPDATE_VISUAL_SNAPSHOTS=1 ./scripts/visual-test.sh
```

Snapshot changes require human visual review and an explanation in the pull
request.

## Definition of Done

A pull request is ready when:

- acceptance criteria are met;
- the package builds and all tests pass;
- bug fixes include regression coverage;
- new behavior includes appropriate automated tests;
- relevant `/docs` content is updated;
- important work is recorded in the current monthly file linked from
  `docs/project-log.md`;
- no secrets, personal data, machine-specific paths, or unlicensed assets are
  present;
- the pull request describes behavior, validation, risks, and visual changes.

## Commit and Pull Request Scope

- Keep commits reviewable and purposeful.
- Avoid unrelated formatting or refactoring.
- Do not rewrite shared branch history.
- Do not commit `.build`, exports, private FIT files, videos, signing files, or
  local configuration.
- Use issue references where applicable.

## Review Priorities

Reviewers should focus on correctness before style, especially for:

- timing-domain conversions;
- project persistence and backward compatibility;
- undo/redo transaction boundaries;
- preview/export rendering parity;
- export performance and alpha output;
- credential handling, user location data, and external APIs;
- third-party asset provenance.
