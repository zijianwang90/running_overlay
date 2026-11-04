# ADR 0012: Staged Legacy Renderer Retirement

Date: 2026-11-04

## Status

Accepted by the maintainer. Supplements ADR 0011 and supersedes the
single-SwiftUI-renderer selection in ADR 0008.

## Context

Skia now owns product preview and export. Automated checks and maintainer
interactive acceptance have passed. The independent Core Graphics renderer
is unused by the product but remains referenced by older smoke and snapshot
tests. Its deletion branch predates the Skia integration.

## Decision

- Merge the legacy Core Graphics deletion into the Skia mainline. Remove
  `OverlayFrameRenderer`, its request/cache types and project references;
  migrate its tests to the export coordinator's selected backend.
- Preserve the pre-cleanup mainline, including the SwiftUI renderer, at
  `archive/swiftui-renderer-2026-11-04` on origin. This is a historical
  recovery point, not another maintained product engine.
- Keep the SwiftUI renderer and comparison views on main for several more
  releases, including Debug comparisons, parity tests and SDK-free builds.
  Their eventual deletion requires a separate explicit maintainer decision.
- Skia remains the product renderer. Retaining SwiftUI does not restore a
  Release renderer toggle or introduce automatic rendering fallback.
- Core Graphics framework use for images, geometry, masks and platform
  interop remains valid; the deletion concerns the standalone overlay engine.

## Consequences

There is no third overlay engine to keep in sync. SwiftUI remains available
for diagnosis during the initial Skia releases. Existing project schemas,
media timing, codecs and rendering selection are unchanged. Snapshot changes,
if needed, remain subject to the existing human review policy.
