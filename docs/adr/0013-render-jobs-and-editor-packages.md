# ADR 0013: Render Jobs And Editor Packages

Date: 2026-11-04

## Status

Accepted for Layers 0 and 1. Later carrier layers need their own decisions.
Amends ADR 0009 item 2.

## Context

ADR 0009 requires one renderer and thin editor bridges. ADR 0011 makes Skia
that renderer. The first editors are Final Cut Pro and DaVinci Resolve;
Premiere and CapCut wait. The app must stay distributable through the Mac App
Store. That rules out installing plugins into editor directories from the app
(guideline 2.4.5) and launching unsandboxed helpers.

ADR 0009 item 2 assumed that each editor bridge launches a bundled headless
renderer. Before any bridge exists, users already need a way to bring overlays
into an editor. Every later bridge also needs the same declarative job
description.

## Decision

Integration is built in layers. Each layer works without the next one.

1. **Layer 0: render job.** `OverlayRenderJob` is a versioned, Codable job
   description. It names its inputs: an activity file or app activity snapshot,
   a template file or built-in template, the output canvas/frame rate/codec,
   and spans. Spans are always in activity elapsed seconds; anchors that map
   other time domains onto them live in the package manifest. The job never
   contains template styling. `RunningOverlay --render-job job.json` runs a job
   headlessly. It goes through `OverlayRenderService`, which drives the same
   `SwiftUIOverlayVideoExporter` path as in-app export.
2. **Content-addressed cache.** Each span movie is keyed by a SHA-256 over the
   renderer version, job schema version, activity content hash, template
   content hash (elements, assets, reference resolution, schema version; not
   the name or timestamps), output settings, and the span. Bump
   `OverlayRendererVersion.current` whenever a renderer change alters pixels.
3. **Template manifest.** `OverlayTemplateManifest` publishes the template
   identity, schema version, content hash, renderer version, and element
   types with every render.
4. **Layer 1: Export for Editor package.** The app writes a folder containing:
   - the alpha movies, either per clip or one full-activity movie;
   - `manifest.json` (`EditorPackageManifest`): activity start (UTC), output
     settings, the template manifest, and for each clip its media name, the
     activity elapsed time at its first frame, and its overlay source range;
   - an FCPXML timeline that places each source clip with its overlay on a
     connected lane. Multi-track projects keep their overlapping tracks as
     connected lanes above the spine, packed by frame ranges. The spine hands
     over to the covering clip that ends last, so no spine item is trimmed
     and no connected clip runs past its parent; Resolve truncates such
     overflow and also misplaces children of a trimmed parent. Clips that
     cross a spine boundary are therefore split into trimmed connected pieces
     with matching media starts. Empty stretches
     of the project timeline are dropped by default; the user can keep them as
     gaps, which the Full Activity layout always does so its single overlay
     stays in activity time (that overlay fills the spine across gaps so it
     keeps running). Final Cut Pro imports it directly, and DaVinci Resolve
     imports it through File > Import > Timeline.

   Users who skip the XML can drag a movie above the matching clip.
5. **Distribution.** Layers 0 and 1 run inside the sandboxed app. They need no
   helper, entitlement change, or plugin install. Later carriers (Motion
   templates, a Resolve `.drfx`, an FxPlug 4 extension) are exported or
   embedded as their store rules allow, and they reuse the Layer 0 job schema.

## Consequences

- Editor placement is exact by construction. Each overlay frame comes from the
  same renderer and the same per-clip anchor as in-app export.
- Changing alignment in an editor still requires a new export from the app.
  The full-activity mode lets users re-slip an overlay manually in the editor.
- Inputs outside the cache key (MapKit route snapshots and the weather cache)
  can change between renders without invalidating cached movies. Clearing
  `Caches/RunningOverlay/RenderCache` forces a fresh render.
- FCPXML import behavior (frame-rate conformance, alpha interpretation,
  BT.709 handling) must be verified by hand in each editor version.
