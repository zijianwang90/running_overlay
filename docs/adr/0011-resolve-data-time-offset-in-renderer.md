# ADR 0011: The Fusion Renderer Owns The Data Time Offset

Date: 2026-10-17

## Status

Implemented for development validation; focused human review required before merge.

## Context

Users rarely know the exact recording start of each source file. Filename or
metadata clocks usually place clips within a few seconds of the activity, and
the remaining error is one camera-clock difference shared by the clips. Users
judge that difference by watching the video and overlay together, which only
Resolve's Edit page viewer shows. The Workflow panel cannot show that picture,
and rebuilding immutable data bundles for each nudge would be slow and would
create a new revision per click.

## Decision

- File or metadata times, accepted explicitly in one panel action, form the
  base mapping. The sync compiler still consumes only confirmed absolute times.
- The Numeric Fuse has a `TimeOffset` input in seconds. It is added to the
  activity time after segment lookup and before activity sampling, so gaps stay
  transparent and every cut keeps its own source mapping. Positive values show
  later activity data at the same frame.
- Once a managed overlay exists, that Fuse input is the only authority. The
  Workflow panel reads and writes it through a small Fusion transaction outside
  the scan queue, never while an apply runs. Ordinary resyncs and range
  replacement preserve it with the composition's other inputs.
- Before creation, the panel stores a draft offset in its configuration and
  writes it once into a newly created renderer. Afterwards the configuration
  only mirrors the renderer value; a stale panel draft cannot overwrite it.
- An animated offset is left to Fusion; the panel refuses to overwrite it.

## Consequences

The base mapping, bundles, and timeline fingerprints are unaffected by offset
changes, so nudges never make the overlay stale. Offset changes are saved with
the Resolve project and use Fusion undo; each panel write is one undo step.
An uncut overlay has one offset. Per-file differences still use Clip details.

Cutting the overlay belongs to the editing stage, after basic alignment. Each
piece has its own composition and keeps its source frames, so it stays correct
through ripple edits without new data (validated in Resolve 21.1.1). The panel
adjusts the piece under the playhead, and updates are refused while the overlay
is cut, because replacement would leave pieces behind as a second overlay. To
change data, widgets, or layout, undo the cuts first.

Exposing the offset in the Edit page Inspector is not yet established. An
experimental generator macro tests that path; until it is verified, the panel
and the Fusion inspector are the supported controls.
