# Skia Bridge Freeze and Phase B Decisions

Date: 2026-11-02
Baseline: `claude/skia-gpu-spike` at `d6d0125`

This note freezes the bridge API for the module ports and records the lead
decisions from the Phase A inventories. Read it before starting Phase B.
Rebase your branch onto `claude/skia-gpu-spike` first.

## 1. Frozen bridge API

Already available and unchanged:

- Contexts: `skb_create`, `skb_create_gpu`, `skb_create_gpu_context`,
  `skb_wrap_texture`, `skb_flush`, `skb_read_pixels`, `skb_destroy`
- State: `skb_save`, `skb_restore`, `skb_clear`
- Shapes: `skb_fill_rect`, `skb_fill_circle`, `skb_fill_round_rect`,
  `skb_stroke_line`, `skb_stroke_round_rect`, `skb_stroke_polyline`,
  `skb_fill_diagonal_gradient_round_rect`
- Clips: `skb_clip_circle`, `skb_clip_round_rect`
- Effects: `skb_begin_shadow_layer`, `skb_begin_shadow_chain`,
  `skb_begin_blur_layer`
- Text: `skb_draw_text`, `skb_draw_glyphs`
- Images: `skb_draw_image`

Added in `980e211` and `d6d0125`:

```c
void skb_clip_rect(ctx, x, y, w, h);

typedef struct SkiaBridgePath SkiaBridgePath;
SkiaBridgePath *skb_path_create(void);
void skb_path_destroy(SkiaBridgePath *path);
void skb_path_move_to(path, x, y);
void skb_path_line_to(path, x, y);
void skb_path_quad_to(path, cx, cy, x, y);
void skb_path_cubic_to(path, c1x, c1y, c2x, c2y, x, y);
void skb_path_close(path);
void skb_path_add_arc(path, cx, cy, radius, startDegrees, sweepDegrees,
                      forceMoveTo);
void skb_draw_path(ctx, path, fill, r, g, b, a,
                   strokeWidth, cap, join, dashLength, dashGap);
void skb_draw_path_gradient(ctx, path, fill, strokeWidth, cap, join,
                            stops, stopCount, x0, y0, x1, y1);
void skb_clip_path(ctx, path);

void skb_fill_linear_gradient_rect(ctx, x, y, w, h, x0, y0, x1, y1, ...);
void skb_fill_radial_gradient_circle(ctx, cx, cy, radius, ...);

typedef struct SkiaBridgeImage SkiaBridgeImage;
SkiaBridgeImage *skb_image_create(const uint8_t *bgra, int width, int height);
void skb_image_destroy(SkiaBridgeImage *image);
void skb_draw_image_handle(ctx, image, x, y, w, h, opacity,
                           shadowSigma, shadowDX, shadowDY, shadowAlpha);
void skb_clip_image_mask(ctx, mask, x, y, w, h);
void skb_draw_image_dst_in(ctx, image, x, y, w, h);

void skb_begin_opacity_layer(ctx, alpha, x, y, w, h);
```

### Semantics

- Coordinates are top-left canvas pixels; text baselines are y-down.
- Colors are unpremultiplied RGBA in `0...1`; Skia premultiplies internally.
- `stops` for `skb_draw_path_gradient` is interleaved
  `(offset, r, g, b, a)` and must be ordered by offset.
- `cap` and `join` use Skia enum values: cap `0=butt, 1=round, 2=square`;
  join `0=miter, 1=round, 2=bevel`.
- `skb_clip_image_mask` uses the image's alpha channel. Convert luminance
  masks to alpha in Swift before creating the handle.
- `skb_draw_image_dst_in` is for masked groups: save layer, draw content,
  draw the mask with destination-in, restore.
- Image handles own an immutable CPU copy. They are independent of the
  context, but destroy them before the context if a future GPU-backed handle
  is introduced. No texture-backed handle exists yet; static-layer GPU
  caching is deferred.
- `skb_begin_shadow_chain` takes entries innermost first, matching SwiftUI's
  first `.shadow` being closest to the content. Validate with a golden.
- `skb_begin_opacity_layer` is the canonical `element.opacity` wrapper.

## 2. Common decisions

1. **Golden oracle is the SwiftUI export tree**, rendered through
   `SwiftUIOverlayVideoExporter.renderFrameCGImage`. The legacy
   `OverlayFrameRenderer` is only a semantic reference.
2. **`element.opacity` is applied uniformly by Skia** using
   `skb_begin_opacity_layer`. Parity goldens pin `opacity = 1` until the
   SwiftUI MOV exporter opacity divergence is fixed separately.
3. **Do not duplicate geometry already in `OverlayRenderModel`.** Module-local
   composition helpers are allowed where the model has no row/segment
   geometry. Adding module-specific layout functions to
   `OverlayRenderModel.swift` is allowed with lead review; keep each module's
   additions in its own section.
4. **Deterministic preferences** use `OverlayPreferenceFixtures.withDefaults`
   in tests. Pin fonts explicitly; `PT Mono` is not bundled.
5. **No commits or pushes from module agents.** Report with `hc send t2t`.
6. **Benchmarks run serially.** Do not run GPU export benchmarks while other
   agents are rendering.
7. **Hosts preload assets before drawing.** Call
   `SkiaEasyRunRenderer.preloadAssets` whenever layout, activity, canvas size,
   or available map snapshots change. The one-time auto-preload inside `draw`
   is only a safety net for tests and must not become the display-link path.
8. **Skia draws strictly in `layout.elements` order.** Layout order is the
   canonical z-order. The SwiftUI exporter keeps its numeric batching
   optimization but now batches only contiguous runs, so an interleaved
   non-numeric element is never moved above or below a batch.
   `renderPlanPreservesLayoutOrderWhenNumericOverlaysAreSplit` guards this.

## 3. Route + weather decisions

- Use `skb_image_create` for MapKit snapshots and weather PNGs; do not call
  `skb_draw_image` per frame.
- Build the edge-fade mask in Swift from `RouteMapMaskRenderer`, convert
  luminance to alpha, and apply it with `skb_clip_image_mask` around the whole
  map content (route, markers, grid).
- Route gradient: follow the SwiftUI source for gradient coordinate space. If
  it is resolved in the shape's bounds, pass the tight path bounds; if it is
  resolved in the map content, pass `layout.contentRect`. Add a golden that
  distinguishes the two.
- Snapshot size is canvas pixels: request `layout.rect.size` at 1x. Cache keys
  include rounded pixel size, map style, and route hash. No async work during
  a frame.
- Accept circular `SkRRect` corners for 1.0. If a weather card golden exceeds
  the threshold at large radii, rasterize the card shape through AppKit and
  cache it.
- Keep ignoring `statsBar.blurRadius` in 1.0; document it.
- Container shadow is applied after the mask, around the masked group.
- Marker alpha follows the uniform opacity layer.

## 4. Text + decor decisions

- **D1:** Group T owns `SkiaTextComposer` under
  `Sources/RunningOverlay/Render/Skia/Shared/`. It composes rows from
  `OverlayTextRenderLayout` and CoreText measurements; it does not re-derive
  style values. Other groups consume it after it lands.
- **D2:** Only `.minimal` is runtime-reachable. Port minimal first. Port the
  10 canonical presets next through a direct-layout oracle for compatibility.
  Deprecated presets are last and must not be re-enabled without a product
  decision.
- **D3:** `backgroundBlurRadius` / material blur has no backdrop in export.
  Reproduce the SwiftUI oracle's transparent-canvas fallback with a
  translucent fill and add a dedicated fixture.
- **D4:** Approximate continuous corners with circular corners first. If a
  golden exceeds the threshold, rasterize the decor shape through AppKit and
  cache it.
- **D5:** Rasterize stroked decor text through AppKit into a cached BGRA image.
- **D6:** `skb_begin_opacity_layer` is available.
- **D7:** Pin fonts in fixtures; document machine-dependent missing-font
  fallback.
- **D8:** Seed HR-zone preferences with `OverlayPreferenceFixtures`.

## 5. Charts decisions

- **Opacity:** apply uniformly; pin `opacity = 1` in parity goldens.
- **Elevation padding/radius:** match the SwiftUI oracle, even where it is not
  canvas-scaled. File the scaling divergence as a separate bug; do not fix it
  inside the port.
- **Shadow order:** shadow inner, glow outer. Validate with a golden.
- Port correctness first. Re-evaluate the elevation static-fill cache only
  after the GPU full-frame path is measured; do not block the port on it.

## 6. Interval decisions

- B1/B2/B3/B5 are covered by the frozen path, arc, opacity-layer, and
  stroked-path primitives. B4 (independent shadow layers) stays optional until
  a golden shows it matters.
- Use `SkiaTextComposer` for text-heavy modules once Group T publishes it.
  Start with Zone Edge Bar and Interval Timeline (shape-heavy).
- Lift interval layout math into `OverlayRenderModel` in an interval-specific
  section with lead review. If a piece is too large for 1.0, keep it
  module-local with a TODO; do not silently fork shared geometry.
- Seed zone and interval-kind preferences with
  `OverlayPreferenceFixtures`.
- Port order: Zone Edge Bar, Interval Timeline, Interval Countdown, HUD Bar,
  Work Summary. Fixtures: synthetic 6-lap workout and 1 min x25;
  default/effects/plain; 720p and 1080p full, 4K subset.

## 7. Preview next step

The preview host POC is complete: CAMetalLayer presentation, persistent
context, 1080p/4K at roughly 8.4 ms per frame. Next:

1. Wire it behind `RUNNING_OVERLAY_RENDERER=skia` plus a debug toggle.
2. Composite the video layer beneath the transparent Skia canvas.
3. Use `OverlayRenderModel` rects for hit testing and keep SwiftUI selection
   and drag affordances on top.
4. Commit the regenerated `RunningOverlay.xcodeproj/project.pbxproj` with the
   new file; do not leave `check.sh`'s generated-project check failing.

The temporary SwiftUI fallback has been removed: every overlay module now has
a Skia port and preview renders 100% through Skia. The all-Skia cutover is
still behind the debug flag; the SwiftUI preview remains the default until
parity review. Selection styling is currently the generic rectangle in Skia
mode; module-specific selected treatments are editor-only affordances and are
not part of the rendered pixels.
