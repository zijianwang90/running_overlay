# ADR 0009: Resolve Template Library Before Mac Template Interchange

Date: 2026-11-01

## Status

Accepted

## Context

The Resolve panel started from three fixed built-in templates and could not
reuse a layout the user had tuned in Fusion. The Mac app stores reusable layouts
as `.rotemplate` files, but those files embed SwiftUI style models that the
Fuse renderer does not map yet, and they embed assets. Copying that schema would
either lose styles silently or require a full style-conversion layer before the
first usable feature.

Templates also have to work on a cut overlay, where each piece owns a separate
Fusion composition and composition data is not a reliable source of live state.

## Decision

- Keep one saved-template library per machine, shared by every Resolve project,
  in the panel's user-data directory.
- Capture templates from the live overlay: read each active slot's metric,
  position and style inputs, pair slots with widgets by metric and slot order,
  and store them as portable Fuse style keys.
- Store an applied copy of the template in the project configuration so deleting
  a library entry never invalidates a timeline.
- Export a versioned `running-overlay-resolve-template` JSON file.
- Import Mac `.rotemplate` files by transferring visible element types and
  positions only, and say so in the panel; do not invent style conversions.
- Never store instance identity, enabled flags, the metric selector, timing
  offsets or data-file paths in a template.

## Consequences

Benefits:

- Users can reuse and share a tuned overlay with one action.
- Templates survive cuts because capture reads Fusion slots, not composition
  data.
- The Mac interchange contract is explicit; nothing is lost silently because
  only positions are claimed.

Costs:

- Mac style, asset and animation parity needs a separate conversion decision.
- Capture follows the first overlay piece with active slots, so per-piece style
  differences after cuts are not merged.
- The portable format is not yet read by the Mac app.
