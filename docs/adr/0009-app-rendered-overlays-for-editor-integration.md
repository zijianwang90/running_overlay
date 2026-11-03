# ADR 0009: App-Rendered Overlays For Editor Integration

Date: 2026-11-02

## Status

Proposed

## Context

Running Overlay Studio ships editor integrations (DaVinci Resolve first, later
Final Cut Pro, Premiere, and CapCut) together with the app. Users edit
templates in the app, so an editor integration only needs to apply an
app-authored template to footage and place the result on the timeline.

The `codex/resolve-plugin-poc` branch re-implemented overlay rendering in
JavaScript and Fuse (independent live rendering, numeric widget renderer, map
cache, weather and credentials). Every overlay module then needs two
implementations, and visual parity with the app can never be guaranteed.

Preview and export in the app currently share SwiftUI views rasterized with
`ImageRenderer`, then drawn into pixel buffers with CoreGraphics. That renderer
cannot run outside Apple frameworks, so a second renderer would use different
text layout and anti-aliasing.

## Decision

1. There is exactly one overlay renderer. Editor integrations never draw
   overlay pixels and never parse template styling.
2. An editor integration is a thin bridge. It reads the selected clip and time
   range, hands a render job to a headless renderer bundled in the app, and
   places the resulting transparent video on the track above the clip. The user
   does not open or operate the app window.
3. Templates are edited only in the app. Editors apply templates read-only.
4. A job file separate from the template records the FIT reference, time
   offsets, media-to-FIT alignment, output size, and frame rate. Time domains
   stay explicit as required by `AGENTS.md`.
5. Integrations contain no network access, API keys, or template editing UI.
   Map and weather data are resolved by the app and cached before rendering.
6. The `codex/resolve-plugin-poc` JavaScript renderer is frozen and not merged.
   This ADR supersedes its ADRs 0008, 0010, 0011, and 0012 in spirit; those
   ADRs live only on that branch.
7. Run a time-boxed spike that renders the Easy Run template with Skia in the
   app target. Its purpose is to measure performance and visual deviation from
   the SwiftUI renderer. The spike does not change the shipping renderer.
   Whether to migrate to Skia is a separate decision made after the spike.

## Consequences

Benefits:

- Visual parity with the app is by construction, not by testing two renderers.
- Plugin surface shrinks, which simplifies Mac App Store review and security
  audits.
- Each editor needs only a small adapter.

Costs and risks:

- Parameters cannot be changed live inside the editor. Changing the clip range
  or alignment triggers a re-render, mitigated by content-hash caching and
  rendering the whole activity span.
- A helper bundled in a sandboxed app must be launchable from an editor
  plugin. This needs an early proof of concept for Resolve (plugin directory
  access, XPC or command-line invocation, user authorization).
- Alpha encoding and editor color handling (for example the roughly 16/255
  background lift seen in Resolve) must be verified per editor.
- If the spike leads to a Skia migration, SwiftUI views and `ImageRenderer`
  must be replaced, and preview must move with export to stay consistent.

## Follow-Up

- Define the job file schema and a template capability/version manifest.
- Extract a headless render entry point from the app target.
- Resolve proof of concept: launch the bundled helper from a panel, render one
  frame, import it.
- Golden-frame tests comparing app export against editor-imported frames.

## Spike Results

Measured 2026-11-02 with the prebuilt Skia m151 arm64 binary (CPU raster),
1920x1080, Easy Run template with all nine elements. MapKit snapshots are
disabled so both renderers draw the same content without network access.

Visual deviation from the shipping SwiftUI `ImageRenderer` at the last frame:

| Region | Changed pixels | Mean channel delta |
| --- | ---: | ---: |
| Whole canvas | 99,446 / 2,073,600 (4.8%) | 1.13 / 255 |
| Distance timeline, effects off | 4,054 | 0.18 / 255 |
| Weather widget | 5,516 | — |
| Route map | 18,196 | — |

The distance timeline matches almost exactly when shadows and glows are
disabled, so geometry, text shaping, and icon placement agree. The remaining
deviation is faint shadow and glow shading.

Performance (ms per frame, 60 frames, one module at a time):

| Module | Skia | SwiftUI |
| --- | ---: | ---: |
| Text modules (each) | 0.66–1.44 | 0.65–1.34 |
| Weather widget | 4.4 | 1.2 |
| Route map | 4.8 | 0.7 |
| Distance timeline | 13.7 | 1.2 |
| Full template | 26.3 | 6.5 |

Text rendering is at parity. The gap comes from CPU Gaussian blurs for
shadows and glows. A chained `SkImageFilters` variant was eight times slower
than nested `saveLayer` calls in the raster backend, so the spike keeps nested
layers. A GPU backend (Graphite/Metal) was not evaluated.

Conclusion: CPU Skia is not a performance win for the current effects-heavy
templates. The app-rendered approach in this ADR stands. If a shared or plugin
renderer is pursued, evaluate a GPU-backed Skia before committing.

## GPU Follow-Up

A Ganesh Metal spike followed this CPU result and measured production export
and live preview. It is about 1.9x faster at 1080p ProRes, about 1.19x faster
at 4K ProRes, and encoder-bound at 1080p HEVC alpha; live preview holds about
8.4 ms per frame at both 1080p and 4K. Based on those results, ADR 0010 adopts
Skia with the Ganesh Metal backend for preview, export, and the editor helper.
