# Running Overlay Agent Guide

This is the canonical instruction file for humans and AI agents contributing
to Running Overlay. Do not add tool-specific instruction files that duplicate
these rules.

## Project

Running Overlay is a native macOS application that combines FIT activity data
with source video and exports transparent sports-data overlay videos.

- Language: Swift 6
- UI: SwiftUI with focused AppKit interop
- Package manager: Swift Package Manager
- Minimum platform: macOS 15
- Tests: Swift Testing
- Default branch: `main`

## Start Here

Read only the documents needed for the task:

1. `docs/index.md` for document routing.
2. `docs/architecture.md` before changing subsystem boundaries or data flow.
3. `docs/development.md`, then the relevant subsystem guide it links, before
   changing implementation conventions.
4. The relevant file under `docs/overlay-modules/` for overlay work.
5. `docs/testing.md` before adding fixtures or visual snapshots.

Do not treat project-log archives as current design authority. They are
historical records. Read only the current month by default; open older months
only when tracing specific history.

## Commands

Use the repository commands instead of inventing one-off validation flows:

```sh
./scripts/check.sh                 # build and all tests
./scripts/test.sh                  # all tests
./scripts/test.sh FilterName       # focused test
./scripts/visual-test.sh           # visual regression tests
./scripts/check-doc-links.rb       # local Markdown links
./scripts/publication-audit.sh     # source-publication and licensing checks
```

If `just` is installed, the equivalent commands are `just check`,
`just test`, `just test-one FilterName`, `just visual-test`,
`just docs-check`, and `just audit`.

## Architecture Invariants

- Route project mutations through `ProjectDocument` methods so undo/redo,
  persistence, and validation remain consistent.
- Keep real timestamps, activity elapsed time, media source time, project
  timeline time, FIT-axis time, and render-frame time explicit. Do not perform
  implicit conversions between them.
- Store timeline state as time values, never pixels.
- Keep domain models independent from view geometry where practical.
- Preview and export must consume the same render models and style fields.
- Preserve deterministic, Codable project and template data.
- Discrete edits register one undo point. Continuous edits begin, update, and
  finish one continuous undo transaction.
- Tests must not require private files, network access, API keys, or a specific
  developer machine.

## Change Rules

- Make the smallest coherent change that satisfies the issue acceptance
  criteria.
- Do not perform unrelated cleanup.
- Add regression tests for bug fixes and tests for new behavior.
- Update relevant files under `docs/` in the same change.
- Update the current monthly file linked from `docs/project-log.md` for
  important features, bug fixes, architecture changes, or repository-wide
  contributor tooling changes.
- Add an ADR under `docs/adr/` when a decision constrains future architecture.
- Do not commit secrets, API keys, private FIT files, user GPS traces, source
  videos, generated exports, signing identities, or machine-specific paths.
- Keep public fixtures synthetic or explicitly licensed and document their
  provenance in `docs/testing.md`.

## Branches And Worktrees

- Start all changes from the latest `main`.
- Use short-lived branches and merge through pull requests.
- Independent large features should use a sibling worktree.
- Keep `main` protected and release-ready; do not commit directly to it.
- Never rewrite contributor history or discard unrelated working-tree changes.

## Definition Of Done

A change is complete only when:

- the requested behavior and acceptance criteria are satisfied;
- `./scripts/check.sh` passes;
- relevant focused and visual tests pass;
- behavior changes have tests;
- related documentation is current;
- important work is recorded in the current monthly project log;
- no secrets, private data, unlicensed assets, or absolute developer paths were
  introduced;
- the final report lists changed behavior, validation performed, and known
  limitations.

## Human Review Required

Request focused human review for changes involving:

- project-file compatibility or migrations;
- timing-domain conversions and media alignment;
- undo/redo semantics;
- video codecs, alpha-channel output, or export performance;
- security, credentials, privacy, or external APIs;
- fonts, icons, media, fixtures, or other licensed assets;
- visual snapshot updates.
