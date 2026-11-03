# ADR 0010: Adopt Skia Ganesh Metal As The Overlay Renderer

Date: 2026-11-02

## Status

Proposed

## Context

ADR 0009 established one app-rendered overlay renderer for preview, export, and
editor integrations. The shipping renderer is SwiftUI rasterized by
`ImageRenderer`, which cannot run outside Apple UI frameworks and is slow for
effect-heavy templates.

The 2026-11-02 CPU Skia spike matched SwiftUI visually but was slower than
SwiftUI for the full template, because shadows and glows fall back to CPU
Gaussian blurs. The spike left GPU-backed Skia unevaluated.

A follow-up GPU spike built the same Easy Run template against Skia m152 with
the Ganesh Metal backend and measured production export and live preview.

Measured results (Easy Run template, 150 frames, ProRes 4444 unless noted):

| Case | Skia GPU | SwiftUI / CoreGraphics | Ratio |
| --- | ---: | ---: | ---: |
| 1080p ProRes | 2.55 s | 4.8-5.0 s | ~1.9x faster |
| 4K ProRes | 5.96 s (median) | 7.12 s (median) | ~1.19x faster |
| 1080p HEVC alpha | 10.42 s | 10.33 s | ~1.0x |
| 1080p preview | 8.4 ms/frame | n/a | ~119 fps |
| 4K preview | 8.5 ms/frame | n/a | ~118 fps |

At 4K the ProRes encoder is the bottleneck: the GPU render itself only grows
from 1.29 s to 1.66 s, while writer wait grows from 0.6 s to 3.4 s. HEVC with
alpha is encoder-bound at every size, so the renderer choice does not change
its throughput.

The available prebuilt Skia binary exposes Ganesh only. Graphite is absent from
the manifest, and Vulkan on macOS would require MoltenVK with no benefit over
Metal.

## Decision

1. Adopt one Skia renderer as the target for preview, export, and the editor
   helper. Preview is wired behind `RUNNING_OVERLAY_RENDERER=skia`/`swiftUI`
   and a Debug toggle. Production export still uses the SwiftUI
   `ImageRenderer`; Skia export is exercised by benchmark tests until an
   explicit export wiring change passes review.
2. Use the Ganesh Metal backend on macOS. Do not adopt Graphite or Vulkan now.
3. Keep the C bridge (`skb_*`) as the backend seam. All renderer code calls the
   bridge, never Skia C++ directly. A future Graphite or Windows backend can be
   added behind the same seam.
4. Keep the CPU raster bridge context for tests, headless golden frames, and
   machines without Metal. Preview and export use the Metal context.
5. `OverlayRenderModel` remains the single layout source of truth. Skia modules
   consume its layout functions and style fields; they do not re-derive
   geometry or style.
6. During migration, SwiftUI is the visual oracle. Every module port ships with
   golden-frame comparison against
   `SwiftUIOverlayVideoExporter.renderFrameCGImage`.
7. Preview and export consume the same renderer and render models. A module is
   not considered ported until both paths use it.

## Consequences

Benefits:

- Preview and export share one pixel pipeline, so what the user sees is what
  the export writes.
- The renderer no longer depends on SwiftUI, which unblocks the editor helper
  and a future non-Apple backend.
- GPU shadows and glows remove the CPU blur bottleneck that made the CPU spike
  slower than SwiftUI.
- The bridge seam keeps backend choice reversible.

Costs and risks:

- The app ships `libskia.dylib` (about 5.7 MB) and must include its BSD license
  notice and provenance in `docs/assets-and-licenses.md`.
- The C bridge is new maintenance surface. Keep it small and covered by the
  golden harness.
- 4K ProRes and HEVC alpha are encoder-bound, so Skia does not improve those
  cases much. Do not promise speedups there.
- Ganesh is Skia's older GPU backend. If Skia removes it, a Graphite port will
  be required; the bridge seam limits the blast radius but does not eliminate
  the work.
- Visual parity needs module-by-module review. Text anti-aliasing and shadow
  shading differ at the pixel level even when geometry agrees.

## Follow-Up

- Update ADR 0009's spike conclusion once the migration ships.
- Add the Skia license, version, and prebuilt provenance to
  `docs/assets-and-licenses.md`.
- Record the fixed benchmark suite and parity thresholds in `docs/testing.md`.
- Re-evaluate Graphite when a prebuilt with it becomes available or when a
  Windows backend is pursued.
