# Skia Route + Weather Porting Inventory (Phase A)

- Date: 2026-11-02
- Branch / worktree: `claude/skia-route` — `running_overlay_skia_route`
- Scope: Group R of `docs/superpowers/plans/2026-11-02-skia-renderer-migration.md`
  (route map + weather widget)
- Status: **inventory only. No production port started.** Blocked on the lead
  freezing the `skb_*` bridge API and landing the shared asset provider.
- Owner: route-and-weather agent. Owned files after freeze:
  `Sources/RunningOverlay/Render/Skia/Modules/SkiaRouteMapModule.swift`,
  `Sources/RunningOverlay/Render/Skia/Modules/SkiaWeatherWidgetModule.swift`,
  and matching `Tests/RunningOverlayTests/SkiaRouteWeather*.swift`.
  Everything else in this document is a **request** to the lead.

---

## 1. Source map

| Concern | Current source |
| --- | --- |
| Route layout model + projection | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:1790` (`routeMapLayout`), `Overlay/RouteMapOverlay.swift:187` (`OverlayRouteMapRenderLayout`, projection) |
| Route geometry + MapKit snapshots | `Overlay/RouteMapOverlay.swift:120` (`RouteGeometryBuilder`), `:5` (`MapSnapshotProvider`), `:15` (`RouteMapSnapshotRequestBuilder`), `:35` (`MapKitMapSnapshotProvider`), `:264` (`RouteMapMaskRenderer`) |
| Route style model | `Overlay/OverlayElement.swift:668-707`, `:2895` (`RouteMapStatsMetric`), `:2997-3169` (stats bar enums/config), `:3503` (`isRouteMapEndCheckerboard`) |
| Route SwiftUI oracle | `UI/PreviewCanvasView.swift:959` (`RouteMapOverlayView`), `:32` (`OverlaySharedRouteMapView`) |
| Route CG legacy reference | `Export/OverlayFrameRenderer.swift:2678` (`renderRouteMap`) |
| Route export snapshot preload | `Export/SwiftUIOverlayVideoExporter.swift:1183` (`loadRouteMapSnapshots`), `:1917`, `:2067` |
| Weather layout model | `Overlay/OverlayRenderModel.swift:2608` (`weatherWidgetLayout`), `:2581` (`WeatherWidgetRenderLayout`) |
| Weather style model | `Overlay/OverlayElement.swift:3685` (`WeatherCondition`), `:3892` (`WeatherWidgetPreset`), `:3945` (`WeatherWidgetPalette`), `:4006` (`WeatherTextStyle`), `:4035` (`WeatherWidgetStyle`) |
| Weather SwiftUI oracle | `UI/WeatherWidgetViews.swift` (all five presets, palette tokens, card background) |
| Weather CG legacy reference | `Export/OverlayFrameRenderer.swift:1362` (`renderWeatherWidget`) |
| Icon rendering contract | `Overlay/IconRendering.swift` (`IconView`, `IconAssetResolver`) |
| Spike | `Export/SkiaEasyRunRenderer.swift:196` (`drawRouteMap`), `:326` (`drawWeatherWidget`), `:458` (`rasterizeBundledImage`), `:889` (`drawIcon`), `:929` (`rasterizeIcon`) |
| Bridge | `Sources/CSkiaBridge/include/skia_bridge.h`, `Sources/CSkiaBridge/skia_bridge.cpp` |
| Existing tests | `Tests/RunningOverlayTests/SkiaSpikeTests.swift`, `VisualRegressionTests.swift:8` (route PNG snapshot), `WeatherFetcherTests.swift`, `WeatherIconAssetTests.swift` |

The **visual oracle** for this port is the SwiftUI view tree rendered by
`SwiftUIOverlayVideoExporter` (`SwiftUIOverlayFrameView`, exporter line 1900)
and, for interactive preview, `PreviewCanvasView`'s element wrapper
(`PreviewCanvasView.swift:800`). The CG `OverlayFrameRenderer` route/weather
paths are *not* the oracle; they already diverge (see §3.4, §4.5).

---

## 2. Shared render contract

Both modules consume, unchanged:

- `OverlayRenderModel.<module>Layout(for:in:)` — no geometry or style math may
  be re-derived in the Skia module.
- `OverlayRenderContext(canvasSize:activity:elapsedTime:)`; `canvasScale =
  min(w/1280, h/720)`; `scaled(v) = v * canvasScale`.
- `OverlayElement.position` is the **center**, normalized to canvas. The layout
  returns an absolute canvas-space `rect` whose origin is already
  `canvas * position - size/2` (`centeredRect`, `OverlayRenderModel.swift:2041`).
  Skia draws at `layout.rect`, never re-centers.
- `element.opacity` is applied by `PreviewCanvasView` at the element wrapper
  (`.opacity(element.opacity)`, line 800). **The SwiftUI export tree does not
  apply it** (no `opacity` occurrence in `SwiftUIOverlayVideoExporter.swift`).
  This is a pre-existing preview/export divergence — see §9 Q1. Until the lead
  decides, Skia fixtures use `element.opacity == 1`; the renderer should apply
  opacity uniformly (preview semantics) once confirmed.
- Visibility gating (`element.isVisible`) is the caller's job, as today.

---

## 3. Route map inventory

### 3.1 Layout inputs (all already resolved by `routeMapLayout`)

- `rect` — map container **including** shared background padding.
- `contentRect` — route projection area: `rect` inset by
  `max(min(min(designW,designH)*0.12, 32), 12) * element.scale * canvasScale`
  plus background padding, then reduced for an inside stats bar
  (`OverlayRenderModel.swift:1816`, `:1992-2013`).
- `cornerRadius` — `backgroundRadius * element.scale * canvasScale` for square,
  `0` for circle.
- `shape` (`.square` / `.circle`), `edgeFade` (`.solid` / `.fadeOut`),
  `fadeAmount`, `borderVisible`, `lineWidth` (`max(4*scale*elementScale, 1.5)`),
  `glowEnabled`, `glowRadius` (`11*scale*elementScale`), `mapOpacity`,
  `progress`, `geometry`, `currentPoint`, `statsBarLayout`.
- `projectedPoints` / `projectedCurrentPoint` — Web Mercator, y-down, fitted
  inside `contentRect` with centered letterboxing. **Use these directly**; do
  not re-project.

Style fields consumed: `routeMapBackgroundStyle`, `backgroundEnabled`,
`backgroundColor`, `backgroundOpacity`, `backgroundFadeOutEnabled/Amount`,
`borderEnabled/Color/Opacity/Width`, `foregroundColor`,
`routeMapColorMode`, `routeMapGradientStart/Middle/End`,
`routeMapStart/End/RunnerMarkerStyle`, `routeMapStartMarkerColor`,
`routeMapEndMarkerColor`, `routeMapRunnerDotColor`,
`routeMapMapOpacity`, `glowEnabled`, `shadow*`, `fontName`,
`routeMapStatsBar`.

Legacy fields **not consumed by the oracle**: `routeMapEdgeFade`,
`routeMapFadeAmount`, `routeMapProvider`, `routeMapLegend*`,
`routeMapContainerPreset`, `routeMapBorderVisible`, `routeMapCornerRadius`
(the shared background fields win).

### 3.2 Exact oracle draw order (`RouteMapOverlayView`)

All coordinates are canvas pixels; `mapContent` is the `layout.rect` view.

1. **Container fill** — rounded rect at `rect` with `cornerRadius`
   (circle uses radius 0 and is later masked to a circle). Fill =
   `backgroundColor × backgroundOpacity` when `backgroundEnabled`, else
   transparent. No shadow yet.
2. **Map layer** (inside the container):
   - If `layout.provider == .mapKit` **and** a snapshot is resolved:
     `Image(nsImage:)` `.resizable().scaledToFill()` `.opacity(layout.mapOpacity)`
     `.clipped()`.
   - Else if `routeMapBackgroundStyle != .none`: local grid — 1 px lines at
     `step = max(rect.width/6, 18)`; colors: `.light` black 0.10, `.terrain`
     green 0.18, `.satellite` white 0.06, `.none`/`.dark` white 0.08.
     The grid is **not** multiplied by `mapOpacity`.
3. **Route base** (only if `projectedPoints.count > 1`):
   a. underlay: black 0.55, width `lineWidth + 3`, round cap/join;
   b. glow (if `glowEnabled`): `foregroundColor` 0.55, width
      `lineWidth * 2.3`, blurred by `glowRadius`;
   c. main stroke: solid `foregroundColor`, **or** for
      `routeMapColorMode == .gradient` a 3-stop `LinearGradient`
      (start → middle → end, `.leading` → `.trailing`), width `lineWidth`,
      round cap/join;
   d. start marker then end marker (see §3.3 marker recipe).
4. **Current marker** if `showsCurrentMarker` and a current point exists —
   same recipe with diameter × 1.18.
5. **Mask** — the whole of steps 1–4 is masked:
   - `.solid` → shape fill (rounded rect / circle);
   - `.fadeOut` with `fadeAmount > 0.001` → `RouteMapMaskRenderer.makeNSImage`
     luminance mask converted with `.luminanceToAlpha()`. Circle: radial
     gradient 1→1→0 at locations 0/0.45/1, inner radius
     `outer * (1 - fadeAmount)`. Square: rounded-rect SDF,
     `alpha = clamp(-sdf / (min(w,h)*0.5*fadeAmount))`, `fadeAmount` capped
     at 0.85.
   The mask applies to the route and markers too, not only the background.
6. **Border** — shape stroke over the masked content when `borderEnabled`:
   `borderColor × borderOpacity`, width `borderWidth * element.scale`.
   Circle = circle stroke; square = rounded-rect stroke at `cornerRadius`.
7. **Container shadow** — `overlayLayeredShadow` on the masked map view,
   three chained black shadows: `(radius, opacity)`, `(radius*0.72,
   opacity*max(thickness-1,0)*0.32)`, `(radius*0.48,
   opacity*max(thickness-2,0)*0.22)`, offsets `shadowOffsetX/Y`.
8. **Stats bar** (`layout.statsBarLayout`):
   - **Outside** (`bottomAttached`, `topAttached`, `leftAttached`,
     `rightAttached`): laid out adjacent via VStack/HStack, **not** masked by
     the container shape and **not** inside the container shadow/border.
   - **Inside** (`insideBottom`, `insideTop`): overlaid on the map, wrapped in
     `.compositingGroup().mask { shapeFill }`, so it is clipped by the
     container shape. It draws above the border stroke (the border is an
     overlay on `maskedMapView`, added before the stats-bar overlay) and
     outside the container shadow layer (the shadow was applied to
     `maskedMapView` before the overlay).
   - Content: background `black × backgroundOpacity` rounded rect
     (`cornerRadius`; forced 0 when inside), dividers `labelColor ×
     dividerOpacity` (1 px; vertical when stacked, horizontal when stacked
     rows), `itemSpacing`; HStack unless `placement.isVertical ||
     layoutMode == .stack`.
   - Each item: value + (" " + unit) with `valueFont*`, monospaced digits,
     label **uppercased** with `labelFont*`; both `lineLimit(1)`,
     `minimumScaleFactor(0.7)`; centered in an equal flex cell.
   - `blurRadius` is currently ignored by both preview and export.

### 3.3 Marker recipe (all non-hidden styles render as a dot today)

- `diameter = lineWidth * 2.7 * sizeMultiplier` (1.18 for current).
- Fill: marker color, **except** `routeMapEndCheckerboard`
  (`OverlayColor(-1,-1,-1,1)`) → 3×3 black/white checkerboard clipped to a
  circle.
- White stroke: `max(lineWidth * 0.45, 1)`.
- `.pin` / `.flag` decode but render identically to `.dot`; `.hidden` skips.
- `"NO GPS"` when geometry is empty: centered text, `fontName`,
  size `max(rect.width * 0.09, 10)`, semibold, `foregroundColor` at 0.72.

### 3.4 Variant matrix to port

| Axis | Values |
| --- | --- |
| Shape | square, circle |
| Edge | solid, fadeOut (fadeAmount 0 … 0.85) |
| Background | none, dark, light, terrain, satellite (grid); MapKit snapshot injected |
| Route color | solid, 3-stop gradient |
| Glow | off, on |
| Markers | start/end/current hidden or dot; end checkerboard |
| Background fill | enabled/disabled, padding, radius |
| Border | enabled/disabled |
| Shadow | enabled/disabled, thickness 1–3, offsets |
| Stats bar | 6 placements × inside/outside × 5 layout modes, 1–4 slots, 4 metrics + progress |
| GPS | present, absent (`NO GPS`) |

### 3.5 Spike status and gaps (`SkiaEasyRunRenderer.drawRouteMap`)

Works: clip (circle/round rect), grid, underlay, glow blur layer, solid
polyline, dots, container shadow chain.

Must fix in the port:

- Border is always stroked with radius `rect.width/2`; square containers need
  `layout.cornerRadius`, circle needs `skb_clip`-consistent stroke.
- No edge-fade mask at all (renders hard edge for `.fadeOut`).
- No gradient route stroke (falls back to solid).
- No MapKit snapshot path; grid is always white 0.08 regardless of style.
- No stats bar.
- No checkerboard end marker.
- Markers ignore `element.opacity` and use raw `color.alpha`.
- Grid/glyph coordinates are absolute while the oracle draws them in
  `mapContent` local space; equivalent only while `rect.origin` is added
  consistently — verify with goldens.
- Glow uses a blur layer over the whole rect; the oracle blurs only the glow
  stroke. Blur-layer bounds must be padded (`sigma*3`) to avoid clipping.

---

## 4. Weather widget inventory

### 4.1 Layout inputs

- `rect = centeredRect(width: scaled(style.width*element.scale),
  height: scaled(style.height*element.scale))`.
- All preset internals scale by `s = rect.width / style.width`
  (not `canvasScale`). `s` includes both canvas scale and element scale.
- Resolved content: `condition`, `temperatureFormatted`, `high/low/
  humidity/wind/feelsLikeFormatted`, `locationText`, `weekdayText`
  (`EEEE`, `en_US_POSIX`), `conditionLabel`, `metricSlots`
  (`[WeatherMetricSlotRender]` with kind/label/value), `iconSize`, `fontSize`.
- Missing API payload renders `"--"` placeholders (layout handles it; no
  renderer branch needed).
- `sfSymbolName` / `iconTint` are **not used** by the SwiftUI presets; icons
  are bundled PNGs. Keep them only for a fallback/debug path.

### 4.2 Text and icon fitting rules

- Font: `.overlayFont(family: style.fontName, size: max(1, fontSize*s),
  weight: style.fontWeight)`.
- Every `Text` is single-line with a preset-specific `minimumScaleFactor`;
  SwiftUI shrinks the font when the measured width exceeds the available
  stack width. A Skia port must reproduce: measure with CoreText, then
  multiply the font size by `min(1, availableWidth / measuredWidth)` down to
  the stated floor. Available width depends on the preset's fixed frames,
  spacers, and padding (see §4.3).
- Weather icons: `IconView(.bundledImage(name: condition.bundledImageName),
  preserveSVGColors: true)` → `Image(nsImage:).resizable()
  .interpolation(.high).scaledToFit()` inside a `size × size` frame. Assets
  are 512×512 transparent PNGs (`Sources/RunningOverlay/Resources/Icons/`).
  No tint, no SF Symbol path in the shipping presets.

### 4.3 Preset recipes (exact numbers, all × `s` unless noted)

**Palette tokens** (`WeatherWidgetPresetTokens`):

| Palette | Gradient (topLeading→bottomTrailing) | Stroke | Shadow |
| --- | --- | --- | --- |
| blueGlass | (0.38,0.68,1.0) → (0.22,0.50,0.92) | white 0.18 | black 0.22 |
| lightGlass | (0.96,0.98,1.0) → (0.82,0.91,1.0) | (0.42,0.64,0.90) 0.26 | black 0.12 |
| graphite | (0.07,0.10,0.15) → (0.13,0.20,0.28) | white 0.16 | black 0.25 |
| minimalWhite | clear → clear | none | black 0.45 |

Gradient stop alpha = `cardBackgroundOpacity`. Preset→palette defaults:
simpleCard→blueGlass, compactStrip→lightGlass, forecastTile→graphite,
minimalText→minimalWhite, dashboardBar→graphite; an explicit
`style.palette` overrides.

**Card background** (all presets): rounded rect, corner radius
`cardCornerRadius * s` with **`.continuous`** corner style, gradient fill,
inset stroke width `max(1, s)` at palette color/opacity, shadow radius
`max(4, rect.width*0.025)`, y `max(2, rect.height*0.04)`.

**simpleCard** (300×110 default): HStack.
- Left VStack, width `0.40*rect.width`, height full, leading padding 18,
  spacing 7: condition label (if shown, min scale 0.72), icon in an
  82×54 frame (icon size 58, leading padding 4).
- Vertical divider if enabled: width `max(1, dividerThickness*s)`, vertical
  padding 18, `dividerColor × dividerOpacity`.
- Right VStack, leading 16, trailing 18, spacing 3, fill: location
  (min 0.65), weekday (if shown/non-empty), temperature (min 0.72), first
  metric only (`Feels x` prefix when kind == `.feelsLike`).
- No extra vertical padding beyond stack centering in the full-height frame.

**compactStrip** (220×56): HStack spacing 10, horizontal padding 16,
leading alignment: icon 34 (if shown), temperature (min 0.75), VStack
spacing 1 with condition label then location.

**forecastTile** (180×180): VStack spacing 0, horizontal padding 12:
location (top 15, min 0.68); weekday (top 2); divider (h padding 8, top 8,
bottom 7) or 5-pt spacer; icon 54 in a 58-high frame; temperature (top 4,
min 0.72); divider (top 7, bottom 8) or 5-pt spacer; metrics HStack
spacing 7, each `maxWidth: .infinity`, vertical dividers
`width max(1, thickness*s), height 18`, horizontal padding 8, bottom 14.
Metric text min scale 0.75.

**minimalText** (160×92): VStack leading spacing 4, horizontal padding 4:
location (min 0.7); HStack spacing 7 with temperature (min 0.7) and icon 30;
condition label. Whole view gets a readability shadow (black 0.55, radius 8,
y 2) — applied to text/icon only because the card is transparent.

**dashboardBar** (560×112): HStack spacing 16, horizontal padding 20:
left VStack spacing 3, width `0.27*rect.width` (location min 0.62,
condition); icon 44; temperature (min 0.72); Spacer; metric chips HStack
spacing `slotSpacing`. Each chip: VStack spacing 4 (label `slotTitle` min
0.68, value `slotLabel` min 0.58), horizontal padding 8, frame 68×58,
background `slotBackgroundColor × slotBackgroundOpacity`, clip
RoundedRectangle radius `8*s` **`.continuous`**.

### 4.4 Variant matrix

| Axis | Values |
| --- | --- |
| Preset | simpleCard, compactStrip, forecastTile, minimalText, dashboardBar |
| Palette | presetDefault (resolves per preset), blueGlass, lightGlass, graphite, minimalWhite |
| Icon | shown/hidden; 10 conditions (PNG assets) |
| Condition label | shown/hidden/override |
| Location / weekday | shown/hidden, placeholder/real |
| Metric slots | 0–3 per preset; none/humidity/highLow/wind/feelsLike |
| Units | °C / °F |
| Dividers | enabled/disabled (color, thickness, opacity) |
| Data source | manual / FIT temperature / Open-Meteo / OpenWeather (layout-resolved) |

### 4.5 Spike status and gaps (`SkiaEasyRunRenderer.drawWeatherWidget`)

Works: simpleCard card gradient (hardcoded blue), corner clip, icon PNG,
condition label, divider, location/weekday/temperature/metric.

Must fix in the port:

- `guard style.preset == .simpleCard else { return }` — other four presets
  render nothing.
- Palette is hardcoded to blueGlass colors/stroke/shadow; all four palettes
  and per-preset defaults must be honored.
- Icon placement approximates the 82×54 frame with manual centering; use the
  exact frame math.
- Text does not implement `minimumScaleFactor` shrink-to-fit.
- `element.opacity` is multiplied into every draw; matches preview but not
  the export oracle (§9 Q1).
- No `.continuous` corner radius; bridge uses circular RRect.
- Text stack spacing/leading is approximated (`conditionHeight` clamp); the
  simple-card right column can drift from SwiftUI at large scale factors.
- No dashboard chips, forecast dividers, or minimal-text readability shadow.

---

## 5. Asset provider design (proposal for the lead/foundation)

### 5.1 Goal

Guarantee **zero network, zero async work, and no AppKit rasterization during
a frame**. All images/fonts are resolved into bridge-owned handles before the
frame loop (export) or swapped in asynchronously between frames (preview).

### 5.2 Shape

```swift
// Shared foundation file (lead-owned): Sources/RunningOverlay/Render/Skia/SkiaRenderAssets.swift

struct SkiaImageKey: Hashable {
    enum Source: Hashable {
        case mapSnapshot(MapSnapshotRequest, pixelSize: Int)      // dedupe by request+scale
        case weatherIcon(WeatherCondition, pixelSize: Int)        // bundled PNG, preserve colors
        case symbol(name: String, pointSize: Int, weight: Int, color: RGBAKey)
        case bundled(name: String, fileExtension: String, pixelSize: Int, tint: RGBAKey?)
    }
    let source: Source
}

final class SkiaRenderAssets {
    let displayScale: CGFloat            // 1 for headless, backing scale for preview
    func image(for key: SkiaImageKey) -> SkbImageHandle?   // opaque bridge pointer
    func font(family: String, size: Double, weight: NSFont.Weight) -> NSFont
}

// Export-time factory (lead-owned, used by SkiaOverlayVideoExporter)
static func preload(
    overlays: [OverlayElement], activity: ActivityTimeline,
    canvasSize: CGSize, displayScale: CGFloat,
    mapSnapshots: [MapSnapshotRequest: NSImage]   // injected by tests or MapKit loader
) -> SkiaRenderAssets
```

- `MapSnapshotRequest` already hashes on bounds + size + background style
  (`RouteMapOverlay.swift:9`). Extend the **cache key only** with pixel size;
  do not change the request type.
- Handle creation is `skb_image_create(bgra, w, h, rowBytes)`; the store owns
  and destroys handles on deinit. `NSImage → premultiplied BGRA` conversion
  lives in the provider (reuse the spike's `CGContext` recipe,
  `SkiaEasyRunRenderer.swift:458`).
- Pixel size for MapKit = `ceil(layout.rect.size × displayScale)` so 4K/Retina
  previews stay crisp. `RouteMapSnapshotRequestBuilder` currently puts the
  point size in `MapSnapshotRequest.size`; the provider must either build a
  display-scale-adjusted request and key the cache separately, or extend
  `MapSnapshotRequest` with an explicit pixel-size/scale field (lead
  decision — this touches the oracle's request builder). Tests inject a
  fixture image and never construct `MapKitMapSnapshotProvider`.
- Icon pixel size = `ceil(pointSize × displayScale)`, bucketed to whole pixels
  (optionally render at 2× and downsample). Weather PNGs preserve color; SF
  Symbols are tinted during rasterization and keyed by color.
- Fonts: cache `NSFont` by `(family, size, weight)`; the bridge converts to
  `CTFont` per draw (or cache `CTFont`).
- Preview: hold a `SkiaRenderAssets` snapshot in the host; on
  `MapSnapshotRequest` change, load asynchronously, then atomically replace
  the store. Frames render with the current store; a missing snapshot falls
  back to the grid. Never `await` in the draw path.
- Export: resolve all requests once before the first frame (reuse
  `loadRouteMapSnapshots` request collection), then reuse the store for the
  whole clip.
- Determinism: fixtures use a fixed synthetic route + fixed timestamp;
  MapKit/Open-Meteo are never called from tests.
- Memory: cap preview map snapshots (e.g. 4 entries, LRU); a 4K BGRA snapshot
  is ~33 MB. Weather icons are ≤ 512².

### 5.3 Ownership

This file and the bridge image-handle API are **shared foundation** — the
route/weather agent only consumes them. Until they exist, the port cannot
start (see §6).

---

## 6. Bridge gap analysis (freeze requests)

Current header: `Sources/CSkiaBridge/include/skia_bridge.h` (125 lines).

| Need (module) | Available today | Gap | Proposed minimal addition |
| --- | --- | --- | --- |
| **Images** (route snapshot, weather icons) | `skb_draw_image` copies BGRA into a new `SkImage` on every call | Per-frame copy is a severe perf regression; no tint; no source-rect; no aspect fit | `skb_image_create` / `skb_image_destroy` / `skb_draw_image_handle(handle, dstRect, opacity, shadow…)`. Tint can stay CPU-side in the provider. |
| **Polylines** (route) | `skb_stroke_polyline` round cap/join, solid color | No shader/gradient, no dash, no per-segment color | Either `skb_stroke_polyline_shader(..., shaderId)` or a linear-gradient variant `skb_stroke_polyline_linear_gradient(xy, count, width, start, end, stops…)`. Dashed is Phase H, not required now. |
| **Clipping** (container, inside stats bar) | `skb_clip_circle`, `skb_clip_round_rect` | No arbitrary-path clip; no alpha-mask clip for edge fade | `skb_clip_path(xy, count, close)` and `skb_clip_image_mask(bgra, w, h, dstRect)` **or** a blend-mode draw (`DST_IN`) so a prebuilt mask can be applied. |
| **Gradients** | 2-stop diagonal rounded-rect fill only | No arbitrary linear gradient (angle/3 stops) for route stroke; no radial gradient for circle fade; no gradient on arbitrary path/rect | Generic `skb_fill_path_linear_gradient(path, stops…)`, `skb_fill_radial_gradient(...)`, and the stroke-shader variant above. A stop array (offset,r,g,b,a) is preferable to fixed 2/3-stop signatures. |
| **Shadows** | `skb_begin_shadow_layer`, `skb_begin_shadow_chain`, per-draw drop shadow for text/image | Chain order/bounds are unverified against SwiftUI; no shadow around masked groups | Keep the API; add a golden test that compares chain order and sigma mapping. Route map needs the shadow applied **after** the mask (saveLayer around masked content). |
| **Blur** | `skb_begin_blur_layer` | Bounds pad fixed at 3σ | Fine for route glow; verify the glow stroke is drawn inside a padded layer. |
| **Text** (weather, stats bar) | `skb_draw_text`, `skb_draw_glyphs` with CTFont | No shrink-to-fit, no truncation, no measured line metrics returned, no monospaced-digit control | Shrink-to-fit can be implemented in Swift (measure with CoreText, scale font size, then draw). If the bridge is extended, expose `skb_measure_text`; not strictly required. |
| **Continuous corners** | `SkRRect::MakeRectXY` (circular) | Weather cards/chips use `.continuous` (squircle) | Either accept the small delta (documented threshold) or add `skb_fill_superellipse_rect`. Recommend accepting for 1.0 and flagging. |
| **Checkerboard marker** | — | None | Compose from 9 `skb_fill_rect` + circle clip in the module. No bridge change. |
| **Blend modes** | — | Needed only if mask/tint is done on GPU | Prefer `skb_clip_image_mask`; avoid a general blend-mode API unless another module needs it. |

Also confirm for the lead:

- Bridge y-down matches CoreText baselines (spike already assumes it).
- `skb_begin_shadow_chain` entry order is innermost→outermost; SwiftUI chains
  the first `.shadow` closest to content. Spike's `beginShadowChain` already
  appends in that order; validate with a golden.
- Image handle lifetime is tied to the `SkiaBridgeContext`; the asset store
  must outlive all frames and be destroyed before the context.

---

## 7. Port order (proposed)

Each step lands with golden frames and focused layout tests; nothing becomes
the default until its parity gate passes.

1. **Asset provider + image handles** (foundation dependency; lead).
2. **Route map, no-map solid variant**: container fill, clip, route underlay,
   solid stroke, markers, `NO GPS`, border, container shadow.
3. **Route map map background**: deterministic grid first, then injected
   MapKit snapshot + `mapOpacity`.
4. **Route map richness**: glow, gradient stroke, circle shape, edge-fade
   alpha mask, checkerboard end marker.
5. **Route map stats bar**: reuse the shared text/rect primitives; cover all
   6 placements, inside/outside, stack modes, 1–4 slots, progress metric.
6. **Weather simpleCard**: fix the spike against the oracle (palette tokens,
   exact frames, text shrink, corner style).
7. **Weather compactStrip → minimalText → dashboardBar → forecastTile**
   (increasing layout complexity; minimalText adds the readability shadow).
8. **Weather cross-product**: 5 presets × 5 palettes × 10 conditions ×
   °C/°F × metric slots; placeholder (`--`) and missing-GPS states.

Rationale: route map without a map snapshot is fully deterministic and
exercises clip/stroke/shadow; weather simpleCard is already partly in the
spike and de-risks text fitting before the four remaining presets.

---

## 8. Golden-frame fixture plan

### 8.1 Determinism

- Synthetic activity only: reuse/extend
  `VisualRegressionTests.syntheticRouteActivity()` (fixed epoch
  `1_735_689_600`, 7 GPS points, fixed HR/pace/elevation). No private FIT,
  no network, no machine paths.
- Fixed timestamps for weekday text (`EEEE` is deterministic from the fixed
  `startDate`).
- Weather data injected through `cachedWeather` or manual fields; never call
  Open-Meteo/OpenWeather.
- MapKit snapshots injected as a bundled fixture PNG; the test path must not
  instantiate `MapKitMapSnapshotProvider`. Use the local grid for the default
  route golden.
- Fixtures stored under
  `Tests/RunningOverlayTests/Fixtures/SkiaGolden/` with provenance recorded in
  `docs/testing.md`.

### 8.2 Scenes

Route map:

- `route-solid-square`, `route-solid-circle`
- `route-glow`, `route-gradient`
- `route-fade-0.30` (square), `route-fade-0.34` (circle)
- `route-grid-dark`, `route-grid-light`, `route-grid-terrain`,
  `route-grid-satellite`
- `route-snapshot-injected` (fixture PNG, `mapOpacity` 0.58/0.72)
- `route-no-gps`
- `route-markers-hidden`, `route-end-checkerboard`
- `route-stats-bottom-outside`, `-bottom-inside`, `-top`, `-left`, `-right`,
  `-stack`, `-progress`
- `route-background-off`, `route-background-padding`

Weather:

- `weather-<preset>` for all 5 presets
- `weather-<preset>-<palette>` for the 5 palettes on simpleCard and
  dashboardBar (others sampled)
- `weather-conditions` (all 10 icons on compactStrip)
- `weather-units-c` / `-f`
- `weather-placeholders` (missing API payload)
- `weather-minimal-shadow`
- `weather-forecast-dividers-on/off`

### 8.3 Resolutions and times

- 1280×720, 1920×1080, 3840×2160.
- Sample `elapsedTime` at 0, mid-route, and end (marker position + stats
  progress).
- Compare against the SwiftUI oracle rendered by
  `SwiftUIOverlayVideoExporter.renderFrameCGImage` (same path as
  `SkiaSpikeTests`), with:
  - changed-pixel ratio ≤ 3% and mean channel delta ≤ 4.0 for the first
    pass (same thresholds as `VisualRegressionTests`), tightened after
    review;
  - diff PNGs + per-region stats written to a temp directory;
  - human review for any snapshot update (`./scripts/visual-test.sh`).

### 8.4 Suggested test files

- `Tests/RunningOverlayTests/SkiaRouteMapGoldenTests.swift`
- `Tests/RunningOverlayTests/SkiaWeatherWidgetGoldenTests.swift`
- Shared fixture helpers (synthetic activity, deterministic element
  builders) in a new `SkiaRouteWeatherFixtures.swift` owned by this module
  group.

---

## 9. Parity risks and open questions for the lead

1. **`element.opacity` preview/export divergence** — preview applies it,
   export does not. Which is the oracle for goldens? Recommendation: apply
   uniformly (preview semantics, matches the architecture invariant that
   preview and export share render inputs) and add a regression test.
2. **Gradient-on-path resolution** — SwiftUI resolves
   `LinearGradient(.leading→.trailing)` for a stroked `Path` in the shape's
   bounds. Confirm with a golden whether that is the map-content bounds or the
   tight path bounds; this determines the Skia gradient endpoints.
3. **SwiftUI text layout fidelity** — line height, baseline placement,
   `minimumScaleFactor` shrink, and stack centering are the highest-risk
   parity area. Plan for per-preset tuning against goldens; consider porting a
   tiny measured-text helper rather than trusting CTLine metrics alone.
4. **`.continuous` corner radius** — circular SkRRect vs squircle. Accept the
   delta or add a superellipse primitive; needs a threshold decision.
5. **Map snapshot pixel size** — the current exporter requests
   `layout.rect.size` (points) regardless of render scale. The Skia provider
   should request at `size × displayScale`; decide whether to fix the SwiftUI
   exporter too for oracle fairness.
6. **Fade mask semantics** — SwiftUI masks the whole map content (route +
   markers) with a luminance mask. Confirm Skia should do the same (yes) and
   whether the mask needs to be exact per-pixel or can use a shader/SDF.
7. **Stats bar blur** — `blurRadius` is persisted and exposed but ignored by
   both current renderers. Keep ignoring it in 1.0 (documented), or implement
   with `skb_begin_blur_layer`; needs a product decision.
8. **Route marker alpha** — markers use `color.alpha` but not element opacity;
   confirm the global opacity decision in Q1 covers this.

---

## 10. Files this agent will own after the freeze

- `Sources/RunningOverlay/Render/Skia/Modules/SkiaRouteMapModule.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaWeatherWidgetModule.swift`
- `Tests/RunningOverlayTests/SkiaRouteWeatherGoldenTests.swift`
- `Tests/RunningOverlayTests/SkiaRenderAssetTests.swift`
- Updates to `docs/overlay-modules/route-map-overlay.md`,
  `docs/overlay-modules/weather-widget-overlay.md`, and the current monthly
  project log, after the port lands.

**Not touched:** `Sources/CSkiaBridge/**`, `SkiaFrameRendererBackend.swift`,
`SkiaEasyRunRenderer.swift`, `OverlayRenderModel.swift`, `Package.swift`,
`docs/architecture.md`, the ADR, and any shared renderer/export file.

---

## 11. Phase B implementation status (2026-11-02)

Implemented on `claude/skia-route` against bridge freeze `cdb4aba`:

- `Sources/RunningOverlay/Render/Skia/Shared/SkiaRenderAssets.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaRouteWeatherText.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaRouteMapModule.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaWeatherWidgetModule.swift`
- `Tests/RunningOverlayTests/SkiaRouteWeatherGoldenTests.swift`
- `Tests/RunningOverlayTests/SkiaRenderAssetTests.swift`

### Entry points for `SkiaEasyRunRenderer`

Call `preloadAssets` once per render session (after the layout/activity are
known, before the first frame), then `draw` per visible element per frame:

```swift
enum SkiaRouteMapModule {
    static func preloadAssets(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        mapSnapshots: [MapSnapshotRequest: NSImage],
        into assets: SkiaRenderAssets
    )
    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    )
}

enum SkiaWeatherWidgetModule {
    static func preloadAssets(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        into assets: SkiaRenderAssets
    )
    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    )
}
```

`SkiaRenderAssets` owns every image handle (`skb_image_create`) and font
instance. The renderer must keep one store alive for the render session and
call `releaseImages()` before destroying the bridge context. `draw` performs
no AppKit work, no MapKit work, and no allocation beyond path/text shaping.

The route module does not fetch map tiles. The host must preload
`MapSnapshotRequest` images through the existing `MapKitMapSnapshotProvider`
(or a test fixture) and hand them in. When a snapshot is absent the module
still draws the background fill, grid, route, markers, and stats bar, so
`routeMapBackgroundStyle == .none` is fully functional without MapKit.

### Bridge-freeze decisions as implemented

- MapKit snapshots, weather PNGs, SF Symbols, and the edge-fade mask are all
  `skb_image_create` handles; no `skb_draw_image` per frame.
- Fade mask comes from `RouteMapMaskRenderer.makeCGMask`, luminance converted
  to alpha, applied with `skb_clip_image_mask` around the whole map content
  (background, snapshot/grid, route, markers).
- Container shadow is chained after the mask and wraps the masked group.
- Marker alpha follows the uniform `element.opacity` layer.
- `statsBar.blurRadius` remains ignored in 1.0 (documented here).
- Route gradient endpoints are `layout.contentRect`. The SwiftUI
  `LinearGradient(.leading→.trailing)` is attached to a shape occupying the
  full map content frame, not the tight path bounds. The
  `route-gradient-space` golden uses a near-vertical route to pin this: using
  tight path bounds produces visibly different colors.
- Forecast tile: SwiftUI's card hugs its intrinsic content height. When that
  exceeds `layout.rect.height`, SwiftUI collapses every text with a
  `minimumScaleFactor` to its minimum and centers the overflow; the card
  background follows the content height. The module reproduces this, then
  centers the card on `layout.rect.midY`.

### Golden results

SwiftUI export-tree oracle, 1280x720, synthetic fixture, opacity 1, fonts
pinned to Menlo, total-opacity changed-pixel ratio (channel delta > 8):

| golden | changed | mean delta |
| --- | ---: | ---: |
| route-solid-square | 0.080% | 0.016 |
| route-border-shadow-glow | 0.561% | 0.051 |
| route-gradient | 0.155% | 0.022 |
| route-gradient-space | 0.064% | 0.014 |
| route-fade | 0.087% | 0.037 |
| route-circle | 0.258% | 0.048 |
| route-stats-outside | 0.385% | 0.188 |
| route-stats-inside | 0.262% | 0.163 |
| route-no-gps | 0.076% | 0.034 |
| weather-simpleCard | 0.189% | 0.047 |
| weather-compactStrip | 0.079% | 0.015 |
| weather-forecastTile | 0.256% | 0.044 |
| weather-minimalText | 0.085% | 0.045 |
| weather-dashboardBar | 0.177% | 0.138 |
| weather-payload-rain | 0.235% | 0.052 |
| weather-palette-blueGlass | 0.189% | 0.047 |
| weather-palette-lightGlass | 0.158% | 0.029 |
| weather-palette-graphite | 0.198% | 0.068 |
| weather-palette-minimalWhite | 0.190% | 0.074 |
| weather-fahrenheit-snow | 0.246% | 0.054 |

All deltas are concentrated on 1px text baselines, route-stroke antialiasing,
and marker-ring antialiasing. Gate: changed ratio <= 10%, mean delta <= 8.
These thresholds are intentionally loose for the first port; tighten after a
human visual review.

### Text helper consolidation

`SkiaRouteWeatherText` is module-local and should be replaced by the shared
`SkiaTextComposer` when it lands. All call sites go through five small
functions (`makeLine`, `fittedLine`, `truncatedLine`, `monospacedDigitFont`,
`draw*`), so the swap is mechanical. `fittedLine` now reproduces
`minimumScaleFactor` shrink plus ellipsis truncation, with a 0.5pt rounding
tolerance so exact-fit text is not spuriously truncated.

### Remaining gaps / asks

- `SkiaEasyRunRenderer` dispatch and preview host wiring are outside this
  agent's file ownership; module entry points above are ready.
- Snapshot-provider wiring: the renderer must preload map snapshots; the
  module intentionally has no async path.
- `.continuous` corners use circular `SkRRect`; the measured delta stays below
  the weather threshold, so no AppKit card rasterization is needed in 1.0.
- `statsBar.blurRadius` is still ignored by both renderers.

---

## 12. GPU-path parity (2026-11-02)

After fast-forwarding onto `claude/skia-gpu-spike` (`024d4c8`), route and
weather are dispatched from `SkiaEasyRunRenderer` with a shared preloaded
`SkiaRenderAssets`. `Tests/RunningOverlayTests/SkiaRouteWeatherGPUParityTests.swift`
renders the same fixtures through the CPU raster bridge and an offscreen Metal
context (`skb_create_gpu`), then compares the readback byte-for-byte.

Scenes: route with gradient + glow + fade mask + border/shadow + outside stats
bar; the same route with a synthetic preloaded map snapshot (image upload); and
all five weather presets (icons are uploaded handles). The test returns early
without failing when no Metal device or GPU Skia context is available.

| scene | changed | mean delta | max channel delta | worst location |
| --- | ---: | ---: | ---: | --- |
| route-gradient-glow-fade-stats | 0.093% | 0.0197 | 57 | route end marker, (724,238) |
| route-snapshot-upload | 0.125% | 0.0376 | 59 | route end marker, (724,238) |
| weather-simpleCard | 0.012% | 0.0114 | 61 | bottom-right card corner, (785,413) |
| weather-compactStrip | 0.031% | 0.0084 | 60 | card edge, (729,386) |
| weather-forecastTile | 0.053% | 0.0129 | 61 | card top edge, (722,260) |
| weather-minimalText | 0.000% | 0.0012 | 3 | shadow tail, (567,369) |
| weather-dashboardBar | 0.017% | 0.0311 | 24 | top-left card corner, (368,304) |

Findings:

- No vertical flip or channel-order difference in `skb_read_pixels`; CPU and
  GPU frames align structurally.
- Differences are confined to analytic-AA edges: rounded card corners, the
  route end marker ring, and the fade-mask boundary. Maximum channel delta is
  61/255, and every changed pixel is an edge pixel.
- Synthetic snapshot upload adds no new error class beyond the same edge AA;
  the image is drawn at `mapOpacity` with the expected orientation and colors.
- Gate: changed ratio <= 2%, mean delta <= 0.5. Actual values are ~20x under
  the gate, so regressions in orientation, upload, or dispatch fail loudly.
- `displayLinkDrivesFramesInAWindow` (pre-existing preview test) was observed
  timing-flaky once under the full merged suite and passes on rerun; unrelated
  to route/weather.
