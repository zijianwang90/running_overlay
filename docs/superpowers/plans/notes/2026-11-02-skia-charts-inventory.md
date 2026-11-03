# Skia Charts Porting Inventory (Phase A)

- **Date:** 2026-11-02
- **Worktree / branch:** `running_overlay_skia_charts` / `claude/skia-charts`
- **Status:** Inventory only. No production code ported. Waiting for the lead to
  freeze the `skb_*` bridge API.
- **Scope:** distance timeline (all presets/variants), running gauge, elevation
  chart. Phase A asks for 1080p golden fixtures; 720p/4K expansion is a later
  gate from the migration plan.

Sources reviewed:

- `AGENTS.md`, `docs/architecture.md`, `docs/development/overlays-and-preview.md`,
  `docs/superpowers/plans/2026-11-02-skia-renderer-migration.md`
- `docs/overlay-modules/distance-timeline-overlay.md`,
  `docs/overlay-modules/elevation-chart-overlay.md`, `docs/testing.md`
- `Sources/CSkiaBridge/include/skia_bridge.h`,
  `Sources/CSkiaBridge/skia_bridge.cpp`,
  `Sources/CSkiaBridge/skia_bridge_internal.h`
- `Sources/RunningOverlay/Export/SkiaEasyRunRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
  (`DistanceTimelineOverlayView`, `RunningGaugeOverlayView`,
  `ElevationChartOverlayView`, `SharedStatsBarContentView`)
- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
  (`DistanceTimelineStyle`, `ElevationChartStyle`)
- `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`

---

## 1. Executive summary

The three chart modules are draw-only ports: every rectangle, baseline,
progress value, sample array, and stat string already comes from
`OverlayRenderModel`. The renderer must **not** re-derive layout, timing, or
value formatting.

Current state:

| Module | SwiftUI oracle | Legacy CG reference | Skia spike coverage |
| --- | --- | --- | --- |
| Distance timeline | `DistanceTimelineOverlayView` | `renderDistanceTimeline` | Partial: value text, track, ticks, dot marker, axis labels, shadow/glow. Missing background, border, media slot, label/custom values, stats bar, pill/triangle markers, route/elevation variants, marker label. |
| Running gauge | `RunningGaugeOverlayView` | `renderRunningGauge` | None. |
| Elevation chart | `ElevationChartOverlayView` | `renderElevationChart` | None. |

Bridge coverage is roughly 55–60% of what the three modules need. Existing
primitives cover solid rects/rounded rects/circles, lines, polylines, text
glyphs, images, rounded/circular clipping, blur layers, and layered shadows.
The gaps are concentrated and can be closed with a small path API plus six
supporting calls:

1. arbitrary path fill/stroke (line + cubic segments);
2. stroked arc with cap control;
3. dashed strokes;
4. rectangular clip;
5. linear gradient shader on an arbitrary path;
6. group alpha layer and image blend/mask (feathered backgrounds, whole-module
   fade);
7. reusable cached image handles (elevation static layers, icon/SVG reuse).

The port order should be **distance timeline → running gauge → elevation
chart**, with elevation’s static-fill cache last. Distance timeline is already
partially proven in the spike and exercises text/stats-bar/shadow composition.
Running gauge is self-contained and proves arcs, circles, blur, and per-region
text. Elevation chart has the highest primitive and parity risk (smoothed cubic
paths, vertical gradients, dual-area clipping, dashed playhead, marker tooltip)
and the only meaningful static-cache design.

Three pre-existing oracle inconsistencies need a lead decision before golden
comparisons (details in §2.4):

- `element.opacity` is applied in preview and the legacy PNG renderer but **not**
  in the SwiftUI MOV exporter.
- Elevation background padding/radius in the SwiftUI view are **not** multiplied
  by `context.canvasScale`, while the legacy renderer and DT are.
- The spike’s shadow-chain order puts shadows outside the foreground glow;
  SwiftUI’s modifier order puts the glow outside the shadows.

---

## 2. Ground truth and parity rules

### 2.1 Oracle

The SwiftUI views are the visual oracle during migration:

- `OverlaySharedDistanceTimelineView` → `DistanceTimelineOverlayView`
  (`PreviewCanvasView.swift:2552`)
- `OverlaySharedRunningGaugeView` → `RunningGaugeOverlayView`
  (`PreviewCanvasView.swift:2161`)
- `OverlaySharedElevationChartView` → `ElevationChartOverlayView`
  (`PreviewCanvasView.swift:3042`)

`OverlayFrameRenderer` is a semantic reference only. It diverges from SwiftUI
in several places (listed per module), so do not copy its geometry or font
sizes blindly.

### 2.2 Layout is shared, drawing is not

Every module renderer consumes:

- `OverlayRenderContext(canvasSize:activity:elapsedTime:)`
- `OverlayRenderModel.distanceTimelineLayout(for:in:)` (`OverlayRenderModel.swift:95`)
- `OverlayRenderModel.runningGaugeLayout(for:in:)` (`OverlayRenderModel.swift:453`)
- `OverlayRenderModel.elevationChartLayout(for:in:)` (`OverlayRenderModel.swift:274`)

The elevation layout already contains smoothed / progress-prefixed `samples`.
Do not re-smooth in the renderer. The DT layout already contains projected
`routePoints` and `routeCurrentPoint`. Do not rebuild route geometry.

### 2.3 Coordinate space

- Canvas coordinates are top-left origin, pixels, matching Skia.
- `centeredRect` places `element.position` at the module center
  (`OverlayRenderModel.swift:2041`).
- DT: `rect`, `contentRect`, `trackRect`, `mediaSlotRect`, and the stats-bar rect
  are **canvas** coordinates.
- Gauge: `rect` and every `region.rect` are **canvas** coordinates.
- Elevation: `rect` is canvas; `statsBarLayout.rect` and the background/border
  rect are **card-local** and must be offset by `rect.origin`.
- Chart points, marker positions, axis labels, and the tooltip are
  **chart-local**; add `chartRect.origin`.

### 2.4 Oracle inconsistencies to resolve before goldens

1. **`element.opacity`**
   - Preview applies it once to every element:
     `PreviewCanvasView.swift:800` (`.opacity(element.opacity)`).
   - Legacy PNG applies it via `CGContext.setAlpha`
     (`OverlayFrameRenderer.swift:97`).
   - The SwiftUI MOV exporter does **not** apply it
     (`SwiftUIOverlayFrameView`, `SwiftUIOverlayVideoExporter.swift:1895`).
   - Recommendation: Skia applies `element.opacity` uniformly (preview and
     export), matching the user-visible Layout control. Pin `opacity = 1` in
     parity goldens and add one dedicated opacity fixture. Report the exporter
     gap to the lead; the fix belongs in the lead-owned exporter file.

2. **Elevation background padding/radius scaling**
   - `ElevationChartOverlayView.backgroundLocalRect` uses
     `element.style.backgroundPaddingX * element.scale` with **no**
     `context.canvasScale` (`PreviewCanvasView.swift:3188`); radius likewise
     (`:3199`).
   - `OverlayFrameRenderer.renderElevationChart` uses
     `renderContext.scaled(...)` (`OverlayFrameRenderer.swift:1164`).
   - At 1080p (`canvasScale = 1.5`) these differ by 1.5×. Match the SwiftUI view
     for parity, and flag the inconsistency as a possible existing bug.

3. **Shadow/glow chain order**
   - SwiftUI applies `.overlayLayeredShadow(...)` then
     `.overlayForegroundGlow(...)`. Later shadow modifiers draw outside earlier
     ones, so the order from inside out is:
     shadow(base), shadow(0.72×radius), shadow(0.48×radius),
     glow(18×intensity), glow(34×intensity).
   - `SkiaEasyRunRenderer.beginShadowChain` adds glow entries before shadow
     entries, which puts glow inside the shadow. The DT spike’s nested
     `skb_begin_shadow_layer` pushes shadow layers before glow layers, also
     putting glow inside the shadow.
   - The new chart helpers must use the SwiftUI order. This is a reviewed
     parity fix, not a visual redesign.

### 2.5 Text strategy

Continue the spike’s approach:

1. Resolve the AppKit font with `OverlayFontResolver.appKitFont(family:size:weight:)`.
2. Shape with CoreText (`CTLineCreateWithAttributedString`) and extract glyphs
   plus x positions.
3. Draw with `skb_draw_glyphs`.
4. Measure with `CTLineGetTypographicBounds` and align/center/right by offset.
5. For `monospacedDigit` / `.monospacedDigit()`, add the
   `kNumberSpacingType / kMonospacedNumbersSelector` feature to the font
   descriptor **before** shaping. Glyph IDs and x positions then come from the
   feature-enabled CTLine, so drawing through the typeface remains correct.
6. For SwiftUI `minimumScaleFactor`, measure at nominal size and reduce the font
   size (never below the factor) until the line fits the slot, then re-shape.
   This is deterministic but not guaranteed glyph-identical to SwiftUI’s
   algorithm; cover it with goldens.
7. SwiftUI line height is not identical to
   `ascent + descent + leading`. Where vertical placement matters (gauge region
   stack, DT value stack, elevation big-number row), use the same CoreText
   metrics for both measurement and drawing, and review the golden diff.

No new text primitive is required.

---

## 3. Existing bridge coverage

From `Sources/CSkiaBridge/include/skia_bridge.h`:

| Need | Existing primitive | Coverage |
| --- | --- | --- |
| Solid rect | `skb_fill_rect` | Yes |
| Rounded rect / capsule | `skb_fill_round_rect` | Yes (`radius = h/2` for capsule) |
| Rounded border | `skb_stroke_round_rect` | Yes (centered stroke) |
| Circle fill | `skb_fill_circle` | Yes |
| Circle stroke | `skb_stroke_round_rect` with square + `radius = side/2` | Workable, but a convenience `skb_stroke_circle` is cleaner |
| Line | `skb_stroke_line` | Yes |
| Polyline (round caps/joins) | `skb_stroke_polyline` | Yes |
| Arbitrary path fill | — | **Missing** |
| Arbitrary path stroke | — | **Missing** |
| Cubic/quadratic curve | — | **Missing** |
| Arc stroke | — | **Missing** |
| Dashed stroke | — | **Missing** |
| Rect clip | `skb_clip_round_rect` with radius 0 | Workable; explicit `skb_clip_rect` preferred |
| Rounded/circle clip | `skb_clip_circle`, `skb_clip_round_rect` | Yes |
| Linear gradient on rounded rect (diagonal) | `skb_fill_diagonal_gradient_round_rect` | Partial; only TL→BR and rounded-rect only |
| Linear gradient on arbitrary path (vertical) | — | **Missing** |
| Radial gradient | — | Not needed |
| Drop shadow layer | `skb_begin_shadow_layer` | Yes |
| Shadow chain | `skb_begin_shadow_chain` | Yes; caller must order innermost→outermost |
| Blur layer | `skb_begin_blur_layer` | Yes |
| Glyph text | `skb_draw_glyphs`, `skb_draw_text` | Yes |
| Glyph text shadow | parameters on `skb_draw_glyphs` | Yes |
| Image draw | `skb_draw_image` (premultiplied BGRA) | Yes; copies pixels each call |
| Image opacity | `skb_draw_image(opacity:)` | Yes |
| Image blend / mask | — | **Missing** (needed for feather background) |
| Cached image handle | — | **Missing** (needed for static layers) |
| Group alpha layer | — | **Missing** (needed for whole-module fade/opacity) |
| Save/restore | `skb_save`, `skb_restore` | Yes |
| GPU zero-copy | `skb_create_gpu*`, `skb_wrap_texture`, `skb_flush`, `skb_read_pixels` | Yes |

---

## 4. Shared visual elements

These recur in all three modules and should live in one new charts helper file,
not be duplicated.

### 4.1 Layered shadow + foreground glow

SwiftUI wrapper (`PreviewCanvasView.swift:267` and `:279`):

- `overlayLayeredShadow`: 3 shadows of the whole module composite:
  - radius, alpha = `opacity`
  - radius × 0.72, alpha = `opacity × max(thickness−1,0) × 0.32`
  - radius × 0.48, alpha = `opacity × max(thickness−2,0) × 0.22`
- `overlayForegroundGlow`: 2 shadows using `OverlayStyle.glow*`:
  - radius `max(glowIntensity×18,0)`, alpha `glowIntensity×0.72`
  - radius `max(glowIntensity×34,0)`, alpha `glowIntensity×0.35`

Implementation: one `skb_begin_shadow_chain` with entries ordered
**innermost→outermost**:
shadow(base), shadow(0.72), shadow(0.48), glow(18), glow(34).
Or nested `skb_begin_shadow_layer` pushes in reverse (outermost first), then
draw content, then restore.

`skb_begin_shadow_layer`/`chain` already pad the layer by `sigma×3 + offset`,
which is sufficient for the blurs.

### 4.2 Feathered background

`OverlayFeatheredBackground` (`Sources/RunningOverlay/UI/OverlayFeatheredBackground.swift`)
uses `OverlayFeatherMaskRenderer.makeCGMask` — an 8-bit distance-field rounded
rect with `smoothstep`, fade width `minDimension × 0.5 × fadeAmount`,
`fadeAmount` clamped to `0.85`. The legacy renderer uses the same mask.

Skia cannot reproduce this exactly with rounded rects. Recommended approach:

1. Generate the mask in Swift by reusing `OverlayFeatherMaskRenderer` (cache by
   size/radius/amount).
2. Upload it once as a cached 8-bit/alpha image.
3. Draw the background shape inside a saveLayer and composite the mask with
   `kDstIn`.

This needs `skb_save_layer` + `skb_draw_image_blend(..., kDstIn)` (or a
dedicated `skb_begin_alpha_mask_layer`). If the bridge freeze excludes blend
modes, fallback options are: (a) draw the un-feathered rounded rect (visible
regression when fade is enabled), or (b) keep the SwiftUI path for
fade-enabled modules. The first is not acceptable for parity; the second blocks
the module. Escalate to the lead.

`backgroundBlurRadius > 0` uses SwiftUI `.ultraThinMaterial`, which has no Skia
equivalent. The existing Glass DT preset disables its background for this
reason. For any style with `backgroundBlurRadius > 0`, either approximate with
`skb_begin_blur_layer` over a translucent fill (reviewed golden) or fall back.
List as an open question.

### 4.3 Shared stats bar

`SharedStatsBarContentView` (`PreviewCanvasView.swift:886`) is used by DT and
elevation:

- Background: rounded rect, black at `backgroundOpacity`, `cornerRadius`,
  clipped.
- Horizontal: `HStack(spacing: itemSpacing)`; vertical: `VStack`.
- Divider between items when `dividerOpacity > 0`: 1 px line, inset 6 px.
- Item: centered `VStack(spacing: 1)`:
  - value + optional space + unit, value font, weight, color, monospaced
    digits, `lineLimit(1)`, `minimumScaleFactor(0.7)`;
  - label uppercased, label font, weight, color, `lineLimit(1)`,
    `minimumScaleFactor(0.7)`.
- Cells share the bar equally.

Skia primitives: `skb_fill_round_rect`, `skb_stroke_line`,
`skb_clip_round_rect`, glyph drawing. No new primitives.

Note: DT uses the **stats-bar config** fonts/sizes/colors
(`config.valueFontName`, `config.valueFontSize × styleScale`, etc.), and
`itemSpacing × styleScale`. DT passes `cornerRadius: config.cornerRadius`
**unscaled** (`PreviewCanvasView.swift:2827`); elevation uses the already-scaled
`layout.statsBarLayout.cornerRadius`. The legacy renderer instead uses
`layout.percentFontSize` / `layout.unitFontSize` — do not copy that.

### 4.4 Media slot / icons / SVG

DT `sport` and `lowerThird` presets use `DistanceTimelineMediaSlotView`:

- Static/animated SVG through `OverlayIconRenderer.image(slot:size:elapsedTime:tintColor:)`.
- Otherwise an SF Symbol with font size `size.width × 0.48`, semibold.
- Slot background: rounded rect, accent at 0.18, radius `width × 0.28`.

For Skia, rasterize the `NSImage` through AppKit into premultiplied BGRA (same
pattern as `SkiaEasyRunRenderer.rasterizeIcon` / `rasterizeBundledImage`) and
draw with `skb_draw_image`. Cache by `(name/slot identity, size, tint, elapsed
quantum)`.

Determinism: animated SVG sampling uses `layout.elapsedTime`, so it is
deterministic per frame. Golden fixtures should avoid SF Symbols (OS-version
sensitive); use a bundled SVG fixture or disable the media slot in the pixel
golden and cover the slot with a smoke test.

### 4.5 Whole-module opacity / fade

DT applies `.opacity(layout.style.fadeEnabled ? max(1 − fadeAmount×0.35, 0.72) : 1)`
to the whole view (`PreviewCanvasView.swift:2642`). `fadeEdge` is currently
**not** used by the SwiftUI view. The legacy renderer does not implement this
fade at all.

Skia options:

- Multiply every color/alpha by the factor, including shadow/glow alphas; or
- wrap the module draw in a group alpha layer.

A group alpha layer is more faithful for shadows/glows. Add
`skb_save_layer_with_alpha(alpha, bounds)` (or equivalent) to the bridge. If it
is not frozen in, apply the factor to all colors; review the golden diff.

Also apply `element.opacity` (see §2.4) at the same outer level.

---

## 5. Module A — Distance timeline

### 5.1 Layout inputs

`OverlayDistanceTimelineRenderLayout` (`OverlayRenderModel.swift:2345`) provides:

- `style`, `valueText`, `label`, `percentText`, `customValues`,
  `startText`, `finishText`, `distancePointLabels`, `markerDistanceText`,
  `statsBarItems`
- `rect`, `contentRect`, `trackRect`, `mediaSlotRect`
- `valueFontSize`, `labelFontSize`, `percentFontSize`, `unitFontSize`,
  `cornerRadius`, `borderWidth`
- `progress`, `elapsedTime`
- `elevationSamples`, `routePoints`, `routeCurrentPoint`

Helpers: `distanceTimelineStyleScale`, `distanceTimelineContentBounds`,
`distanceTimelineStatsBarRect`.

Presets (`DistanceTimelinePreset`, `OverlayElement.swift:1345`):
`minimal`, `dense`, `sport`, `splits`, `glass`, `neon`, `lowerThird`, `route`.

### 5.2 Draw order (SwiftUI ZStack, back to front)

1. Background (`OverlayFeatheredBackground`) — `backgroundLocalRect`.
2. Border — same rect, `layout.cornerRadius`, `style.border*`.
3. Media slot (sport/lowerThird) — `layout.mediaSlotRect`.
4. Route elevation profile (route preset, `elevationProfileVisible`) — area fill.
5. Value layer — label, value, custom values.
6. Progress layer — track, route path or progress fill, ticks, marker.
7. Axis labels — start/finish and distance points.
8. Marker distance label.
9. Stats bar.
10. Selection border — preview only, never export.
11. Outer layered shadow + foreground glow.
12. Whole-module fade/opacity.

### 5.3 Element map

| Element | SwiftUI source | Skia primitives | Status |
| --- | --- | --- | --- |
| Background fill | `OverlayFeatheredBackground` | `skb_fill_round_rect` + mask blend | Missing mask/group layer |
| Background border | `RoundedRectangle.stroke` | `skb_stroke_round_rect` | Ready |
| Media slot background | rounded rect accent 0.18 | `skb_fill_round_rect` | Ready |
| Media slot icon/SVG | `DistanceTimelineMediaSlotView` | rasterize → `skb_draw_image` | Ready with AppKit rasterizer |
| Route elevation area | `elevationProfile` Path | arbitrary path fill (polygon) | Missing path fill |
| Label text | `Text(layout.label.uppercased())` | `skb_draw_glyphs` | Ready |
| Value text | `Text(layout.valueText)` | `skb_draw_glyphs` | Ready |
| Custom values | inline `Text`s | `skb_draw_glyphs` + measurement | Ready |
| Track | `RoundedRectangle` | `skb_fill_round_rect` | Ready |
| Progress fill | rounded rect, min width = track height | `skb_fill_round_rect` | Ready |
| Route path | `routePath` polyline; fallback cubic | `skb_stroke_polyline`; fallback needs cubic path or Swift sampling | Partial |
| Progress glow | `.shadow` on progress | `skb_begin_shadow_layer` | Ready |
| Ticks | `tickMarks` Path | `skb_stroke_line` per tick | Ready |
| Marker dot | `Circle` | `skb_fill_circle` | Ready |
| Marker pill | `Capsule` | `skb_fill_round_rect` radius h/2 | Ready |
| Marker triangle | `DistanceTimelineTriangleMarkerShape` | path fill | Missing path fill |
| Marker glow | `.shadow` | `skb_begin_shadow_layer` | Ready |
| Axis labels | `axisLabels` | glyphs + measurement | Ready |
| Marker distance label | `Text` | glyphs + measurement | Ready |
| Stats bar | `SharedStatsBarContentView` | rect/line/glyph primitives | Ready |
| Layered shadow/glow | view modifiers | shadow chain | Ready, order fix |
| Whole-module fade | `.opacity` | group alpha layer or alpha multiply | Missing group alpha |

### 5.4 Variant notes

- **minimal** — background + value + track; no label, ticks, marker, stats.
- **dense** — label, axis labels (START/FINISH), 3 distance points, ticks,
  marker, border, radius 6.
- **sport** — label, right-attached stats bar (progress), media slot system
  icon, radius 14, padding 16.
- **splits** — axis labels in distance mode, 4 distance points, ticks, marker,
  border.
- **glass** — background disabled, border only, fade whole-module 0.24,
  radius 16.
- **neon** — right stats bar, cyan accent, track opacity 0.18, height 5,
  marker, glow, value white 0.92, label accent 0.86.
- **lowerThird** — label, right stats bar, media slot, fade right 0.28,
  value font ×1.05.
- **route** — label, START/FINISH, elevation profile, route polyline instead of
  a bar, track height 5, marker, fade both 0.24.

Per-preset value typography overrides live in the view
(`PreviewCanvasView.swift:2848`): `lowerThird` ×1.05, `sport` ×1.12,
`dense` ×0.86; weight medium for `dense`/`neon`, bold otherwise; value color
white 0.92 for `neon`; label color accent 0.86 for `neon`.

Ticks use the computed `labelColor` (neon-aware) at 0.52, **not**
`style.labelColor`. Label text uses `style.labelColor` directly. Do not swap
them.

### 5.5 Spike gaps to fix in the port

`SkiaEasyRunRenderer.drawDistanceTimeline` (`:578`) currently:

- ignores background, border, media slot, label, custom values, stats bar,
  route/elevation variants, marker pill/triangle, marker distance label;
- draws `valueText` at `contentRect.minY + labelValueSpacing` (no label offset);
- uses foreground for ticks instead of the neon-aware label color;
- uses a dot-only marker;
- applies shadow/glow in the reversed order described in §2.4.

These are expected spike limits, not designs to preserve.

### 5.6 Legacy CG divergences (do not copy)

- Legacy DT stats-bar item fonts use `percentFontSize`/`unitFontSize`; SwiftUI
  uses the stats-bar config fonts.
- Legacy elevation-profile rect top is `maxY − 0.36h`; SwiftUI is
  `maxY − 0.37h` (`contentRect.height × 0.30` centered at `maxY − 0.22h`).
- Legacy marker geometry uses `size × 0.72` for the dot and fixed pill/triangle
  multipliers; SwiftUI uses `2.2h`, `3.4h × 1.75h`, `2.6h × 2.4h` × multiplier.
- Legacy does not implement the whole-module fade.
- Legacy media slot falls back to a placeholder glyph when no SVG is embedded.

---

## 6. Module B — Running gauge

### 6.1 Layout inputs

`OverlayRunningGaugeRenderLayout` (`OverlayRenderModel.swift:2558`):

- `style`, `rect` (canvas), `diameter`, `progress`
- `regions: [OverlayRunningGaugeRegionLayout]` — each has `config`, canvas
  `rect`, formatted `components`, and `valueFontSize` / `labelFontSize` /
  `unitFontSize`
- `outerRingWidth`, `progressRingWidth`, `tickLength`, `majorTickLength`,
  `safeRadius`

`RunningGaugeLayoutEngine` supplies region frames and divider segments
(`RunningGaugeModel.swift:804`).

Layout presets: `topBottom`, `topMiddleBottom`, `threeZones`,
`topTwoMiddleBottom`, `topThreeMiddleBottom`, `fourZones`, `fiveZones`.
Style presets: `minimalSport`, `highContrast`, `roadRun` (default),
`trailAdventure`, `techFuture`, `retroDigital`, `premiumGlass`.

### 6.2 Draw order

1. Dial background circle.
2. Glass ring (premiumGlass) — blurred white stroke.
3. Outer ring.
4. Tick marks.
5. Progress track + progress arc.
6. Dividers.
7. Data regions (label, value, unit), in layout order.
8. Selection circle — preview only.
9. Outer layered shadow + foreground glow.

### 6.3 Element map

| Element | SwiftUI source | Skia primitives | Status |
| --- | --- | --- | --- |
| Dial background | `Circle().fill` | `skb_fill_circle` | Ready |
| Glass ring | white stroke + `.blur` | `skb_begin_blur_layer` + circle stroke | Ready |
| Outer ring | `Circle().strokeBorder` | `skb_stroke_round_rect` square radius r, inset width/2 | Ready |
| Ticks | `GaugeTicksView` rotated rects | `skb_stroke_line` with computed endpoints | Ready |
| Progress track | `Circle().stroke` | `skb_stroke_round_rect` square | Ready |
| Progress arc | `Circle().trim` + rotate −90°, cap round/butt | **arc stroke** (or dense polyline) | **Missing arc primitive** |
| Dividers | `GaugeDividersView` | `skb_stroke_line` segments | Ready |
| Region label | `Text` | glyphs + measurement + shrink | Ready |
| Region value | `Text` | glyphs + measurement + shrink | Ready |
| Region unit | `Text` | glyphs + measurement + shrink | Ready |
| Value glow | `.shadow` per value | `skb_draw_glyphs` shadow or blur layer | Ready |
| Layered shadow/glow | view modifiers | shadow chain | Ready, order fix |

### 6.4 Geometry details that matter

- Outer ring: `strokeBorder` draws inside the circle edge, so
  `radius = diameter/2 − outerRingWidth/2`.
- Progress ring inset: `outerRingWidth + progressRingWidth + 2`; stroke radius
  `diameter/2 − inset`. Track and arc share the radius.
- Arc starts at top (`−90°`) and sweeps clockwise by `progress × 360°`.
  `progressRoundedCaps` selects round vs butt caps. The legacy renderer always
  uses round caps.
- Ticks: content size = `diameter − 2 × (outerRingWidth + 2)`; radius =
  contentSize/2; tick rectangle is centered at `radius − length/2` and rotated
  by `index / tickCount × 360°`; major every `majorTickEvery`. Legacy uses
  `radius − outerRingWidth − tickLength × 0.6`, which differs.
- Dividers: normalized segments mapped into a square of side
  `2 × safeRadius` centered on the gauge (`safeRadius = diameter × 0.40`).
- Regions: `VStack(spacing: max(unitFontSize × 0.10, 1))` centered in
  `region.rect`. Label text is `config.metric.compactLabel` as-is when
  `customLabel` is empty, otherwise `customLabel.uppercased()`. Value and unit
  colors:
  `config.valueColor ?? style.primaryTextColor`,
  `(config.labelColor ?? style.secondaryTextColor) × 0.78`.
  `lineLimit(1)`, `minimumScaleFactor` 0.6 (label) / 0.5 (value).
- Two independent glows exist: per-value `style.glow*` and the outer
  `OverlayStyle.glow*` foreground glow. Do not merge them.

### 6.5 Legacy CG divergences

- Legacy tick radius and region vertical anchoring differ from SwiftUI.
- Legacy always uses round progress caps.
- Legacy has no glass ring and no per-value glow.
- Legacy hardcodes some text rect offsets; use the SwiftUI stack metrics.

---

## 7. Module C — Elevation chart

### 7.1 Layout inputs

`OverlayElevationChartRenderLayout` (`OverlayRenderModel.swift:2524`):

- `style`, `bigNumberText`, `label`, `statsBarItems`, `statsBarLayout`
- `rect` (canvas), `labelFontSize`, `valueFontSize`, `unitFontSize`,
  `horizontalPadding`, `verticalPadding`, `cornerRadius`, `chartHeight`
- `lineWidth`
- `markerHaloSize`, `markerDotSize`, `markerRingSize`,
  `markerRingStrokeWidth`, `markerGlowBlurRadius`
- `progress`, `samples` (already smoothed / progress-prefixed)

Presets: `gradientArea` (default), `dualArea`, `techGlow`, `minimalWhite`,
`bigNumbers`. Chart styles: `area`, `lineOnly`. Progress modes:
`fullProfile`, `progressToCurrent`.

### 7.2 Chart geometry

`chartRect` in canvas coordinates:

```
x = rect.minX + horizontalPadding
y = rect.minY + verticalPadding
w = rect.width − 2 × horizontalPadding
h = layout.chartHeight
```

If `bigNumbersEnabled`, SwiftUI places a big-number row first in a
`VStack(spacing: verticalPadding)`, so the chart’s y becomes:

```
y = rect.minY + verticalPadding + bigNumberRowHeight + verticalPadding
```

`bigNumberRowHeight` is the SwiftUI line height of the HStack row (value, unit,
short label, first-text-baseline aligned). Approximate with the value font’s
line height and verify with goldens. The legacy renderer starts the chart at
`rect.minY + verticalPadding` even with big numbers, which overlaps the big
number row; do not copy it.

Chart points:

```
x = chartRect.minX + chartRect.width × i / (samples.count − 1)
y = chartRect.maxY − chartRect.height × (sample − min) / max(max − min, 1)
```

`chartPoints` falls back to a horizontal midline when `samples.count <= 1`.

### 7.3 Draw order

1. Background (feathered, card-local rect offset by `rect.origin`).
2. Border.
3. Big numbers (if enabled).
4. Grid (3 horizontal lines at 25/50/75%).
5. Axis line (left edge).
6. Area fill (single or dual; dual lower masked to the right of progress).
7. Line glow (if `style.glowEnabled`).
8. Line.
9. Marker: playhead dashed line, halo, dot, ring, optional tooltip.
10. Axis labels (max/min/“m”).
11. Stats bar (card-local rect offset by `rect.origin`).
12. Outer layered shadow + foreground glow.

### 7.4 Element map

| Element | SwiftUI source | Skia primitives | Status |
| --- | --- | --- | --- |
| Background | `OverlayFeatheredBackground` | rect + mask blend | Missing mask |
| Border | rounded stroke | `skb_stroke_round_rect` | Ready |
| Big number row | 3 `Text`s, baseline aligned | glyphs + measurement | Ready |
| Grid | `gridPath` | `skb_stroke_line` × 3 | Ready |
| Axis line | `axisLine` | `skb_stroke_line` | Ready |
| Area path | `areaPath` (line/cubic + close) | path fill | **Missing path fill** |
| Vertical gradient fill | `LinearGradient` top→bottom | path + linear gradient shader | **Missing path gradient** |
| Dual lower fill mask | `.mask(Rectangle offset by progress)` | `skb_clip_rect` + path fill | Missing explicit rect clip |
| Line | `chartPath` stroke round caps/joins | path stroke | **Missing path stroke** |
| Line glow | wider stroke + `.blur(5)` | `skb_begin_blur_layer` + path stroke | Missing path stroke |
| Playhead line | `VerticalDashedLine`, dash [3,4] | dashed stroke | **Missing dash** |
| Marker halo | blurred circle 0.24 | `skb_begin_blur_layer` + `skb_fill_circle` | Ready |
| Marker dot | circle | `skb_fill_circle` | Ready |
| Marker ring | white circle stroke | `skb_stroke_round_rect` square | Ready |
| Marker tooltip | text + rounded rect + border | rect + glyphs + measurement | Ready |
| Axis labels | 3 `Text`s | glyphs | Ready |
| Stats bar | `SharedStatsBarContentView` | shared stats-bar helper | Ready |
| Shadow/glow | view modifiers | shadow chain | Ready, order fix |

### 7.5 Smoothing and fill details

- `layout.samples` is already the final sample set. `chartPath` uses cubic
  Catmull-Rom (controls at ±1/6 of neighbor deltas) when
  `style.smoothingEnabled && points.count > 2`; otherwise straight segments.
- `areaPath` appends `(width, height)` and `(0, height)` and closes.
- Single-area gradient: `fillStartColor → fillEndColor`, alpha
  `fillOpacity → max(fillOpacity × 0.15, 0.04)`, top→bottom.
- Dual area: upper fill `upperFillColor → fillEndColor` across the full chart;
  lower fill `lowerFillColor → fillEndColor` drawn only to the **right** of
  `progress` (mask width `w × (1 − progress)`, offset `w × progress`).
- Line: `lineColor` at `lineOpacity`, width `layout.lineWidth`, round caps and
  joins.
- Glow: same path, width `lineWidth + 7`, `glowOpacity`, `.blur(5)`.
  Calibrate SwiftUI blur radius to Skia sigma with a golden (spike uses 0.5 for
  DT glow; verify for elevation).
- Marker point: index
  `round((samples.count − 1) × progress)` clamped; x/y from the chart mapping.
- Playhead line: only when `markerPlayheadLineEnabled` and **not**
  `bigNumbersEnabled`, and only when `x > chartRect.minX + 1.5`; dash [3,4],
  white 0.28, 1 px.
- Tooltip: font `max(labelFontSize × 0.92, 10)`, semibold; text is
  `layout.label` with `"Elevation "` removed; padding 8×5; radius 7; black
  0.68 fill + white 0.16 1 px border; center x clamped to
  `[chart.minX + 28, chart.maxX − 28]`, y `max(point.y − 25, chart.minY + 12)`.
- Axis labels: font `max(labelFontSize × 0.78, 8)` medium, foreground 0.58;
  max at `(14, 8)`, min at `(10, h − 8)`, “m” at `(w − 10, 8)` in chart-local
  coordinates.

### 7.6 Legacy CG divergences

- Legacy does not draw axis labels.
- Legacy hardcodes marker sizes 27/8/13 and ring width 2, ignoring
  `markerSizeMultiplier`; SwiftUI uses the scaled layout fields.
- Legacy halo is not blurred.
- Legacy big-number layout and chart origin differ from the SwiftUI VStack.
- Legacy recomputes stats-bar geometry instead of using
  `layout.statsBarLayout`.
- Legacy line glow is a wider stroke without blur.

---

## 8. Proposed bridge additions (for the lead to freeze)

Keep the API small and module-agnostic. Suggested signatures:

### 8.1 Paths

```c
typedef struct SkiaBridgePath SkiaBridgePath;

SkiaBridgePath *skb_path_create(void);
void skb_path_move_to(SkiaBridgePath *p, float x, float y);
void skb_path_line_to(SkiaBridgePath *p, float x, float y);
void skb_path_cubic_to(SkiaBridgePath *p,
                       float c1x, float c1y, float c2x, float c2y,
                       float x, float y);
void skb_path_close(SkiaBridgePath *p);
void skb_path_destroy(SkiaBridgePath *p);

void skb_fill_path(SkiaBridgeContext *ctx, const SkiaBridgePath *p,
                   float r, float g, float b, float a);
void skb_stroke_path(SkiaBridgeContext *ctx, const SkiaBridgePath *p,
                     float width, int cap, int join,
                     const float *dash, int dashCount,
                     float r, float g, float b, float a);
void skb_fill_path_linear_gradient(SkiaBridgeContext *ctx,
                                   const SkiaBridgePath *p,
                                   float x0, float y0, float x1, float y1,
                                   float r0, float g0, float b0, float a0,
                                   float r1, float g1, float b1, float a1);
```

`cap`/`join` can be small enums (`butt/round/square`,
`miter/round/bevel`). A path handle avoids re-parsing a command buffer per
draw and supports cached static layers.

### 8.2 Arc / circle convenience

```c
void skb_stroke_arc(SkiaBridgeContext *ctx,
                    float cx, float cy, float radius,
                    float startRadians, float sweepRadians,
                    float width, int cap,
                    float r, float g, float b, float a);
void skb_stroke_circle(SkiaBridgeContext *ctx,
                       float cx, float cy, float radius,
                       float width, float r, float g, float b, float a);
```

Arc is needed for the gauge progress ring with configurable round/butt caps.
A dense polyline can approximate it, but the exact cap geometry at 0% and 100%
is easier with a real arc.

### 8.3 Clip and layers

```c
void skb_clip_rect(SkiaBridgeContext *ctx,
                   float x, float y, float w, float h);
void skb_save_layer(SkiaBridgeContext *ctx,
                    float x, float y, float w, float h);
void skb_save_layer_with_alpha(SkiaBridgeContext *ctx, float alpha,
                               float x, float y, float w, float h);
```

`skb_clip_round_rect(..., 0)` already works as a rect clip; an explicit call is
clearer and avoids relying on a rounded-rect path. Group alpha is needed for
DT whole-module fade and `element.opacity`.

### 8.4 Image blend and cached images

```c
typedef struct SkiaBridgeImage SkiaBridgeImage;

SkiaBridgeImage *skb_image_create(const uint8_t *premulBGRA,
                                  int width, int height);
void skb_image_destroy(SkiaBridgeImage *image);

void skb_draw_cached_image(SkiaBridgeContext *ctx,
                           const SkiaBridgeImage *image,
                           float x, float y, float w, float h,
                           float opacity);
void skb_draw_image_blend(SkiaBridgeContext *ctx,
                          const SkiaBridgeImage *image,
                          float x, float y, float w, float h,
                          float opacity, int blendMode);
```

- `skb_draw_image_blend` with `kDstIn` implements the feather background mask
  inside a saveLayer.
- `skb_draw_cached_image` avoids re-uploading the same BGRA pixels every frame
  for elevation static layers and icon caches.
- For the GPU zero-copy path, the cached image should ideally be texture-backed
  (`SkImage::MakeFromTexture`) rather than re-uploaded. This matters for the
  elevation static cache at 4K; flag it in the bridge freeze discussion.

### 8.5 Not needed

- Radial gradients.
- Multi-stop gradients (all fills here use two stops).
- Text truncation (modules use shrink, not truncate).
- Transform stack (coordinates can be computed in Swift).
- Path effects beyond dash.

---

## 9. Static-cache layer plan

### 9.1 Elevation chart (clear win; mirror the existing SwiftUI cache)

Eligibility is already encoded in
`SwiftUIOverlayVideoExporter.canUseElevationChartStaticFillCache`
(`:176`):

- `progressMode == .fullProfile`
- `fillEnabled && chartStyle == .area`
- not `bigNumbersEnabled`
- not `element.style.glowEnabled` (outer glow)
- `layout.statsBarLayout == nil`

Layers (`ElevationChartLayerVisibility`, `:1408`):

1. **Base** — chrome, grid, axis line, base (upper/single) fill, outer shadow.
2. **Lower** — dual-area lower fill only, full width (nil for single area).
3. **Line** — chart line + chart glow.
4. **Dynamic** — marker + axis labels, rendered every frame.

Per-frame composite:

1. draw base;
2. if dual, clip to `x ≥ chartRect.minX + chartWidth × progress` and draw the
   lower layer;
3. draw line;
4. draw dynamic marker layer.

The SwiftUI exporter crops the baked lower image at the pixel boundary; Skia can
use `skb_clip_rect` and draw the full lower layer, which avoids CPU cropping and
is visually identical (modulo the half-pixel boundary; verify with goldens).

Build the layers once per export at the project resolution. On the GPU path,
keep them as cached image/texture handles, not per-frame BGRA uploads.

### 9.2 Distance timeline (defer)

Value text, custom values, progress, marker, and stats values change per frame.
Potential cacheable pieces: background, border, ticks, axis labels, stats-bar
labels/background. The progress track and marker are dynamic. Given the GPU
full-frame target, measure first. Recommendation: **no DT static cache in the
first port**; add only if benchmarks show a win.

### 9.3 Running gauge (defer)

Dial, rings, ticks, and dividers are static; region labels are static; values
and progress arc are dynamic. Potential cache: dial chrome + labels. Again,
measure after the straight port. Recommendation: no cache initially.

---

## 10. Proposed port order

Each step is gated by focused goldens against the SwiftUI oracle before moving
on. Do not port the next module while the previous module’s diff is unexplained.

0. **Bridge freeze (lead).** Land the path/arc/dash/clip/gradient/mask/cached
   image additions from §8 and the shadow-order helper. No module code until
   this is stable.
1. **Shared chart helpers** (new module file):
   - font resolution, CTLine shaping, measurement, alignment, shrink;
   - shadow/glow chain in SwiftUI order;
   - shared stats bar;
   - feathered background mask;
   - image/SVG rasterization cache.
2. **Distance timeline**
   1. `minimal` (finish the spike path correctly: label/value/custom values,
      background/border, stats bar absent).
   2. `dense`, `splits` (ticks, axis labels, distance points, marker).
   3. `glass`, `neon` (fade, glow, neon colors, stats bar).
   4. `sport`, `lowerThird` (media slot + stats bar).
   5. `route` (route polyline, current point, elevation profile, fallback).
   6. Marker variants (dot/pill/triangle) and marker distance label.
3. **Running gauge**
   1. Dial, rings, ticks, dividers, regions (`roadRun`).
   2. All seven layout presets.
   3. All style presets, including `premiumGlass` (blur) and `retroDigital`
      (butt caps, digital font, glow).
   4. Progress modes (distance/time/zone/custom) and 0/50/100% arcs.
4. **Elevation chart**
   1. Single-area `gradientArea` (path fill, vertical gradient, line, grid,
      axis).
   2. `lineOnly` (`minimalWhite`).
   3. Dual area + progress mask.
   4. Marker (playhead dash, halo blur, dot, ring, tooltip) and axis labels.
   5. Big numbers and stats bar (inside/outside).
   6. `progressToCurrent` mode.
   7. Static-fill cache + parity test against the uncached renderer.

Why this order: DT is already partially implemented and proves text/shadow/
stats-bar composition; gauge is a compact, self-contained arc/blur test; the
elevation chart combines every hard primitive (cubic paths, gradients, masks,
dashes, blur, tooltip) and is the only module with a static-cache design, so it
goes last.

---

## 11. Golden-frame fixtures (1080p, deterministic, no network)

### 11.1 Deterministic activity fixture

Add a shared test fixture builder (new test file) rather than reusing the
Easy Run 60 s fixture, which is too short for a meaningful elevation profile.

Proposed `SkiaChartsFixture.activity`:

- `startDate = Date(timeIntervalSince1970: 1_735_689_600)` (2025-01-01T00:00:00Z).
- `duration = 600` s; `distanceMeters = 2400`.
- 301 records at 2 s intervals (`0...600` by 2):
  - `distanceMeters = t × 4.0`
  - `elevationMeters = 40 + 18 × sin(t / 55) + 0.03 × t` (varied, smoothable)
  - `heartRate = 120 + 30 × sin(t / 90)`
  - `paceSecondsPerKilometer = 270 + 30 × sin(t / 70)`
  - `cadence = 172 + 6 × sin(t / 30)`
  - `powerWatts = 230 + 40 × sin(t / 45)`
  - `calories = t / 3.6`
  - GPS: a small deterministic loop around fictional coordinates near
    `(40.75, −73.99)`; no real traces.
- `laps: []`.
- Sample times: `0`, `210` (35%), `300` (50%), `480` (80%), `600` (100%).
- Canvas: `CGSize(width: 1920, height: 1080)`.
- `OverlayRenderContext` uses the same activity and elapsed time as the SwiftUI
  oracle.

The fixture must be built in code (no JSON/FIT fixture needed) and committed as
synthetic data. It contains no private GPS or device data.

### 11.2 Fixture matrix

Full matrix (generated on demand to a temp directory; not all committed):

**Distance timeline**

- `dt-minimal` at 0/50/100%
- `dt-dense`, `dt-splits`, `dt-glass`, `dt-neon`, `dt-sport`,
  `dt-lowerThird`, `dt-route` at 50%
- `dt-marker-dot`, `dt-marker-pill`, `dt-marker-triangle` at 50%
- `dt-axis-startFinish`, `dt-axis-distance` at 50%
- `dt-statsbar-top`, `-bottom`, `-left`, `-right`, `-inside` at 50%
- `dt-custom-values` at 50%
- `dt-features` (ticks + marker label + axis labels + stats bar + fade +
  background fade) at 50%
- `dt-route-no-gps` (fallback path)
- `dt-media-slot-svg` (bundled SVG fixture; keep out of the SF Symbol path)

**Running gauge**

- `gauge-roadRun` at 0/50/100%
- `gauge-minimalSport`, `gauge-highContrast`, `gauge-trail`,
  `gauge-techFuture`, `gauge-retroDigital`, `gauge-premiumGlass` at 50%
- `gauge-layout-topBottom`, `-topMiddleBottom`, `-threeZones`,
  `-topTwoMiddleBottom`, `-topThreeMiddleBottom`, `-fourZones`, `-fiveZones`
- `gauge-progress-customPercentage` (fixed 0.5)
- `gauge-no-labels`, `gauge-no-units`, `gauge-custom-labels`
- `gauge-round-caps`, `gauge-butt-caps`
- `gauge-glow` (techFuture)

**Elevation chart**

- `elev-gradientArea` at 50%
- `elev-dualArea` at 0/25/50/80/100%
- `elev-techGlow` at 50%
- `elev-minimalWhite` at 50%
- `elev-bigNumbers` at 50%
- `elev-progressToCurrent` at 50%
- `elev-smoothing-off` at 50%
- `elev-statsbar-inside`, `-outside`
- `elev-marker-label`, `-no-label`
- `elev-playhead-on`, `-off`
- `elev-axis-labels-on`, `-off`
- `elev-dualArea-progress-0`, `-100`
- `elev-static-cache` vs uncached at 0/25/50/80/100%

**Opacity**

- `opacity-50` for one DT, one gauge, one elevation fixture, to validate the
  §2.4 decision.

### 11.3 Committed reviewed goldens

Keep a small reviewed set in
`Tests/RunningOverlayTests/Fixtures/VisualSnapshots/SkiaCharts/`:

- `dt-minimal-1080p.png`
- `dt-route-1080p.png`
- `dt-features-1080p.png`
- `gauge-roadRun-1080p.png`
- `gauge-techFuture-1080p.png`
- `gauge-premiumGlass-1080p.png`
- `elev-gradientArea-1080p.png`
- `elev-dualArea-1080p.png`
- `elev-techGlow-1080p.png`
- `elev-bigNumbers-1080p.png`

Rationale: 10 full-canvas transparent PNGs are small, reviewable, and cover
every primitive family. The full matrix runs against the SwiftUI oracle in a
temporary directory during the focused test and is not committed.

### 11.4 Comparison rules

Reuse the existing visual-regression metric
(`VisualRegressionTests.swift:70`):

- premultiplied BGRA comparison;
- `changedPixelRatio ≤ 0.03`;
- `meanChannelDelta ≤ 4.0`;
- treat pixels where both images are transparent (alpha < 1/255) as unchanged;
- restrict the diff to the module’s bounds expanded by
  `max(shadow/glow pad, 8 px)`;
- gauge text may need `changedPixelRatio ≤ 0.04`, `meanChannelDelta ≤ 5.0`
  until the shrink/line-height calibration is reviewed; record the chosen
  threshold per module.

Snapshot updates follow `docs/testing.md`: `UPDATE_VISUAL_SNAPSHOTS=1` through
`./scripts/visual-test.sh`, before/after images in the PR, human review.

### 11.5 No network / determinism rules

- No MapKit, weather, or network calls. The DT route preset uses only activity
  GPS.
- No SF Symbols in pixel goldens; use a bundled SVG fixture or disable the media
  slot. A separate smoke test may cover an SF Symbol rasterization.
- Use the app’s default font family (`PT Mono`) or a documented macOS system
  font. Do not use locale-sensitive date/number formatting.
- Fix all times and positions; never use `Date()` or the current playhead.
- Avoid animated SVG in goldens; if tested, pin `elapsedTime`.

---

## 12. Test and file plan

Proposed new files (module-owned; lead approves paths and dispatch):

- `Sources/RunningOverlay/Render/Skia/Modules/SkiaChartsCommon.swift`
  - CTLine shaping/measurement/alignment/shrink
  - shadow/glow chain
  - shared stats bar
  - feathered background
  - image/SVG rasterization cache
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaDistanceTimelineRenderer.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaRunningGaugeRenderer.swift`
- `Sources/RunningOverlay/Render/Skia/Modules/SkiaElevationChartRenderer.swift`
- `Tests/RunningOverlayTests/SkiaChartsFixtures.swift`
- `Tests/RunningOverlayTests/SkiaChartsGoldenTests.swift`
- `Tests/RunningOverlayTests/SkiaChartsLayoutTests.swift`
  (layout-consumption and edge cases: zero samples, no GPS, 0/100% progress,
  empty custom values, missing stats slots)

Lead-owned files that must change but are **not** mine:

- `Sources/CSkiaBridge/**` (bridge primitives)
- `SkiaFrameRendererBackend.swift` (dispatch table / feature flag)
- `Package.swift` (if new module paths require it)
- `OverlayRenderModel.swift` (only if a layout bug is found; otherwise no)
- `docs/architecture.md`, ADR

Focused tests:

- `./scripts/test.sh SkiaChartsGoldenTests`
- `./scripts/test.sh SkiaChartsLayoutTests`
- `./scripts/visual-test.sh` for the committed snapshots
- `./scripts/check.sh` before handoff

Edge cases to cover:

- `samples.count == 0/1/2`
- no GPS route (`routePoints.isEmpty`)
- progress 0 and 1 (arc caps, minimum progress width, dual-area mask edges)
- stats bar with 0/1/4 visible slots
- label/value/unit disabled
- `element.opacity` 0/0.5/1
- background fade 0 and max
- big numbers on/off with chart height clamping
- static-cache eligibility true/false

---

## 13. Open questions for the lead

1. **Bridge freeze scope:** can §8 land before module work? Specifically the
   path API, arc, dash, rect clip, path gradient, `save_layer_with_alpha`, image
   blend, and cached image handle. Without the mask/blend call, feathered
   backgrounds cannot reach parity.
2. **`element.opacity` in export:** should the SwiftUI exporter be fixed to
   apply it, and should Skia apply it everywhere? Recommendation: yes, apply
   uniformly; pin 1.0 in parity goldens.
3. **Elevation background padding scaling:** match the SwiftUI view (unscaled)
   for parity, or fix both to use `context.canvasScale`? This is a visible
   difference at 1080p/4K. Recommendation: match SwiftUI in the port and file a
   separate bug/decision.
4. **Shadow-order correction:** confirm the reviewed order (shadow inner, glow
   outer) and whether the existing route/weather spike helper should be
   corrected at the same time.
5. **Gradient color space:** should the elevation area gradient use sRGB or
   linear interpolation? Golden diffs will reveal; decide before freezing the
   path-gradient signature (an interpolation flag may be needed).
6. **`backgroundBlurRadius` / glass material:** approximate with a blur layer or
   fall back to SwiftUI for those styles? The Glass DT preset already disables
   its background; document the policy.
7. **Media slot goldens:** bundled SVG only, or also an SF Symbol smoke test?
   SF Symbols are OS-version sensitive.
8. **Cached image on GPU:** confirm the bridge can keep static elevation layers
   as texture-backed images, not per-frame CPU uploads.
9. **Module file paths:** confirm
   `Sources/RunningOverlay/Render/Skia/Modules/` is acceptable, or place files
   under `Export/Skia/`.
10. **Golden threshold for text-heavy gauge:** approve the provisional
    0.04 / 5.0 until the shrink/line-height calibration is reviewed.

---

## Appendix — key references

| Item | Location |
| --- | --- |
| DT layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:95` |
| Gauge layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:453` |
| Elevation layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:274` |
| DT render layout struct | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2345` |
| Elevation render layout struct | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2524` |
| Gauge render layout struct | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2558` |
| DT SwiftUI view | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:2552` |
| Gauge SwiftUI view | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:2161` |
| Elevation SwiftUI view | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:3042` |
| Shared stats bar | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:886` |
| Global element opacity (preview) | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:800` |
| Shadow/glow modifiers | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:267` |
| Feather mask | `Sources/RunningOverlay/Overlay/OverlayFeatherMaskRenderer.swift` |
| Feathered background view | `Sources/RunningOverlay/UI/OverlayFeatheredBackground.swift` |
| DT legacy renderer | `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift:763` |
| Elevation legacy renderer | `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift:1157` |
| Gauge legacy renderer | `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift:1413` |
| Elevation static-cache eligibility | `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift:176` |
| Elevation layer visibility | `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift:1408` |
| Elevation cache composite | `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift:1481` |
| Skia spike DT | `Sources/RunningOverlay/Export/SkiaEasyRunRenderer.swift:578` |
| Bridge header | `Sources/CSkiaBridge/include/skia_bridge.h` |
| Bridge implementation | `Sources/CSkiaBridge/skia_bridge.cpp` |
| Visual regression harness | `Tests/RunningOverlayTests/VisualRegressionTests.swift` |
| Spike fixture activity | `Tests/RunningOverlayTests/SkiaSpikeTests.swift:305` |
