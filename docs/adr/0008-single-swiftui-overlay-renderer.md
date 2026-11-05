# ADR 0008: Single SwiftUI Overlay Renderer

Date: 2026-11-02

## Status

Superseded for renderer selection by [ADR 0011](0011-skia-product-renderer.md).
The legacy Core Graphics deletion remains accepted;
[ADR 0012](0012-staged-legacy-renderer-retirement.md) records the integration
and temporary SwiftUI retention policy.

The decision below records the pre-Skia design.

## Context

The initial commit added `OverlayFrameRenderer`, a Core Graphics frame
renderer used by the export path. Commit `aff7989` ("Unify export on SwiftUI
renderer", 2026-04-29) moved production export to `SwiftUIOverlayVideoExporter`,
which rasterizes shared SwiftUI overlay views with `ImageRenderer`.

The Core Graphics file was not removed. It kept receiving feature updates
until 2026-07-14 because eight tests still called it, so every overlay change
risked updating two renderers. Preview, export, and the tests could disagree,
and a dead path remained available as a tempting baseline for future work.

## Decision

- `SwiftUIOverlayVideoExporter` is the only overlay renderer. Preview and
  export consume the same shared SwiftUI overlay views and render models.
- Remove `OverlayFrameRenderer` and its project references. Do not keep it as
  a fallback, test double, or reference implementation.
- Renderer tests and visual regression snapshots exercise
  `SwiftUIOverlayVideoExporter.exportFramePNG` so they validate the shipping
  path.
- Do not add a second pixel renderer without a new ADR that explains why the
  shared SwiftUI path cannot satisfy the requirement.

## Consequences

Benefits:

- One renderer means preview/export parity is structural, not a per-feature
  comparison.
- Overlay changes update one drawing path and one snapshot baseline.
- New integrations cannot accidentally target a renderer the app no longer
  ships.

Costs:

- Visual regression snapshots must be regenerated when the renderer changes;
  this is a reviewed change, not routine maintenance.
- Any future need for a non-SwiftUI renderer (for example an editor plugin
  that cannot run Apple frameworks) requires an explicit decision and a
  shared, serializable display-list contract rather than a parallel drawing
  implementation.
