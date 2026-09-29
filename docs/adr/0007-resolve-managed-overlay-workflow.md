# ADR 0007: Managed Resolve Compositions And Immutable Sync Revisions

Date: 2026-09-13

## Status

Implemented for development validation; focused human review required before merge.

## Context

The independent P0 can render Numeric widgets but requires users to create and
wire compositions manually. Resolve 21's direct composition insertion does not
expose arbitrary clip duration, and its Workflow bridge does not marshal Fusion
Tool objects or void returns consistently. A saved timeline must also keep
working after the panel closes or new data is compiled.

## Decision

- Create a dedicated Fusion carrier using an authored OTIO duration setup and a
  generated transparent still. Render graphics with Fuse; never render an
  intermediate overlay movie. Remove temporary setup timelines after placement.
- Identify managed clips with project/timeline-scoped custom-data markers.
  Preserve the existing Fusion composition during range replacement. Prepare and
  verify its replacement before deleting only the old owned clip without ripple.
- Run Fusion node operations as a checked Lua transaction with literal data,
  rollback, and an operation-specific scalar acknowledgment. Keep main-thread
  Workflow scripting out of render callbacks.
- Save validated settings under a dedicated product Application Support
  directory. Key them by stable Resolve project and timeline IDs. Publish new
  immutable data revisions on each successful compilation and retain old ones.
- Treat timeline scans and compiled maps as derived data. Require explicit user
  apply after changes; polling remains read-only. Reject unknown source timing.

## Consequences

Fusion node styles, connections, and keyframes survive data updates and duration
changes. Source timeline clips are not altered. First creation and duration
replacement are multiple Resolve timeline SDK actions, so they are not one
atomic timeline undo step. Separate Edit-page effects on the managed carrier are
not copied during replacement; supported widget editing happens in Fusion.

Data revisions consume disk space until a future ownership-aware cleanup feature
exists. Settings and referenced bundles are local; this is not a cross-machine
project archive or migration format for Running Overlay Studio.

Focused review must cover time conversion, file persistence, ownership and
failure recovery, Fusion undo behavior, and real preview/Deliver output. Production
signing, OFX, broad camera metadata parsing, and full visual parity remain separate.
