# Running Overlay Development Guide

Last updated: 2026-06-25

The development guide is split by subsystem so contributors and AI agents can
load only the conventions relevant to their task.

## Guides

| Area | Document |
|---|---|
| Engineering principles, technology, modules, and core models | [Overview](development/overview.md) |
| App bootstrap, FIT import, and media import | [App Bootstrap and Data Import](development/app-and-import.md) |
| Tracks, clips, timing edits, and timeline interaction | [Timeline](development/timeline.md) |
| Overlay editing, preview behavior, and templates | [Overlays and Preview](development/overlays-and-preview.md) |
| Project persistence, undo, and redo | [Persistence](development/persistence.md) |
| Video rendering, diagnostics, and performance direction | [Export](development/export.md) |
| Reliability, testing strategy, and documentation rules | [Quality](development/quality.md) |

## Reading Rules

- Start with [Overview](development/overview.md) for structural changes.
- Read only the subsystem guide affected by a focused implementation.
- Read `docs/architecture.md` before changing data flow or subsystem
  responsibilities.
- Read the matching `docs/overlay-modules/` and `docs/design/` files for
  overlay or UI work.
- Use `docs/project-log.md` only when historical implementation context is
  necessary.
