# ADR 0011: Skia As The Product Overlay Renderer

Date: 2026-11-03

## Status

Accepted for the development cutover; distribution gates remain open.
Supersedes ADR 0010's default-backend and migration-flag decisions.

## Context

The maintainer accepted the m159 Graphite sample and authorized moving toward
Skia as the only product overlay engine, with limited further performance work.
The fixed synthetic Easy Run suite already exports 25 seconds of media faster
than real time for 1080p/4K with both codecs at 30 fps/5 Hz Layer Data. Graphite
has no demonstrated engine-only speedup; HEVC is predominantly encoder-bound.

## Decision

1. Skia-enabled builds default to Skia for preview, MOV and PNG export. Release
   ignores the SwiftUI renderer environment override and offers no renderer
   toggle. SDK-free builds remain useful for model/UI development and CI.
2. The pinned m159 dual-backend SDK defaults to Graphite Metal. Ganesh remains
   available through the same C bridge for diagnosis and compatibility; an
   explicitly selected unavailable backend fails instead of substituting it.
3. SwiftUI continues to own the editor UI and interactive affordances. Existing
   overlay views and `ImageRenderer` remain as Debug/test comparison oracles
   during migration. Remove them after packaging and full-template acceptance;
   do not maintain two product engines or add new SwiftUI-only overlay features.
4. Preserve all project schema, timing, frame reuse, color/alpha, cancellation,
   undo and destination authorization contracts. No persistence migration.
5. Limit pipeline optimization to a bounded one-sample prefetch experiment.
   Require meaningful throughput benefit without output regressions to retain
   its complexity. Do not pursue dual contexts or deeper queues once the fixed
   suite is faster than real time on the development Mac.
6. Skia app bundles must embed and sign `libskia.dylib`, load it with a relative
   Frameworks rpath and include the SDK's notices. No machine-specific SDK path
   may be required at runtime.

## Consequences And Remaining Gates

The Release preview and exporter share one pixel engine. Legacy SwiftUI
comparison code is deliberately retained until all presets and packaging are
accepted; this is a cutover milestone, not completed deletion of the oracle.
The SDK stays reproducibly source-built outside Git. Native Xcode archive/CI SDK integration is implemented; remote CI acceptance,
oldest supported macOS, full-template interactive acceptance,
Developer ID signing, notarization and App Store validation remain before
shipping. No release, upload or store submission is authorized by this ADR.
