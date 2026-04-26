# ADR 0001: Documentation-First Development

Date: 2026-04-24

## Status

Accepted

## Context

Running Overlay is expected to grow beyond the first brief. The app touches multiple complex areas: FIT activity data, media metadata, timeline editing, overlay layout, playback, and video export. Product behavior and engineering decisions need to stay synchronized during iterative development.

## Decision

The project will maintain product and engineering documentation from the beginning.

Required documents:

- `docs/requirements.md` for user-facing product requirements.
- `docs/development.md` for implementation workflow and engineering notes.
- `docs/architecture.md` for subsystem boundaries and data flow.
- `docs/roadmap.md` for milestone status.
- `docs/project-log.md` for chronological work history.
- `docs/adr/` for decisions that affect future implementation.

Every meaningful development step should update the relevant documentation in the same step as code changes.

## Consequences

Benefits:

- Requirements stay explicit as the product becomes more complex.
- Future implementation work has a stable reference.
- Expensive decisions are recorded with context.

Costs:

- Each development step has a small documentation overhead.
- Documents must be kept concise enough to remain useful.
