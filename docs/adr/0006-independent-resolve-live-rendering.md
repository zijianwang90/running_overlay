# ADR 0006: Independent Resolve Product With Live In-Host Rendering

Date: 2026-08-16

## Status

Accepted for prototype validation

## Context

Running Overlay Studio exports transparent overlay media from a native macOS
renderer. A DaVinci Resolve product has a different primary need: users should
edit and position widgets inside Resolve and render graphics once with the
finished program. Making the Resolve workflow depend on Studio's process,
SwiftUI renderer, or pre-rendered ProRes 4444 files would compromise that goal
and couple two products with different host constraints.

An edited Resolve timeline also cannot be aligned to activity data with one
global offset. Source trims, jump cuts, and multiple camera files require a
piecewise mapping from record frames through source media time to FIT/GPX real
timestamps.

## Decision

Build `RunningOverlayResolve/` as an independent sibling product inside the
repository:

- no runtime or build dependency on the macOS app;
- independent activity parsing, persistence, Workflow UI, Fusion scene graph,
  renderer nodes, packaging, and tests;
- the main app supplies visual and semantic reference material only;
- Resolve preview and Deliver call live Fuse/OFX renderers; normal operation
  produces no intermediate overlay video;
- a sandboxed Workflow panel performs file parsing and timeline analysis;
- render callbacks consume only immutable compiled activity and sync data;
- alignment authority uses integer frames, rational frame rates, integer
  microseconds, and piecewise segments;
- P0 uses Fuse to validate native controls and viewer placement; production
  modules may move independently to OFX after host and performance validation.

## Consequences

Benefits:

- Resolve users receive an in-host editing and one-render workflow.
- Main-app changes cannot break the plugin build or installation.
- Renderer technology can evolve per widget without changing sync contracts.
- Cut and trim behavior remains correct after editing.
- Deterministic synthetic fixtures can compare both products without sharing
  private data or application code.

Costs:

- FIT/GPX parsing and overlay rendering logic will be implemented separately.
- Visual parity is verified through specifications and golden images rather
  than guaranteed by shared code.
- Workflow, Fusion/Fuse, and OFX packaging require separate security,
  licensing, signing, and host-version review.
- Timeline/source-time behavior, alpha/color output, and viewer interactions
  require focused human review before release.
