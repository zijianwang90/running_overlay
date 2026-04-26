# ADR 0005: Overlay Templates Before Full Project Files

Date: 2026-04-24

## Status

Accepted

## Context

Full project persistence is useful, but the near-term user need is different: after a user finds an overlay layout and visual style they like, they will likely reuse it across many activities and video batches. That reusable state is smaller and more stable than a full editing project.

## Decision

Implement overlay template persistence before full project file persistence.

Overlay templates will save reusable overlay layout and style only:

- overlay element types
- normalized positions
- scale
- font and visual style
- future formatting and chart style fields

Templates will not save:

- FIT paths or parsed FIT data
- video paths or metadata
- timeline tracks or clips
- playhead
- sampled activity values

## Consequences

Benefits:

- Users can reuse their preferred overlay design without needing full project save/load.
- Template schema can stay focused and stable.
- Export workflows can start from a reusable visual preset.

Costs:

- Template persistence and future project persistence will be separate schemas.
- Applying a template needs careful undo behavior because it replaces the current overlay layout.
- Future style migrations need schema versioning from the start.
