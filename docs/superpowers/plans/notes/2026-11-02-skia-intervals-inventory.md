# Skia Interval Family Porting Inventory

- Date: 2026-11-02
- Owner: interval-module agent (`claude/skia-intervals`)
- Scope: Interval HUD Bar, Interval Timeline, Interval Countdown, Interval Work
  Summary, Zone Edge Bar
- Status: Phase A inventory complete. No production code ported. Waiting for the
  lead to freeze the bridge API and resolve the decisions in §12.

## 1. Sources inspected

Views (the visual oracle):

- `Sources/RunningOverlay/UI/IntervalHUDBarOverlayView.swift`
- `Sources/RunningOverlay/UI/IntervalTimelineOverlayView.swift`
- `Sources/RunningOverlay/UI/IntervalCountdownOverlayView.swift`
- `Sources/RunningOverlay/UI/IntervalWorkSummaryOverlayView.swift`
- `Sources/RunningOverlay/UI/ZoneEdgeBarOverlayView.swift`
- `Sources/RunningOverlay/UI/OverlaySharedViews.swift:116-174` (export/preview wrappers)
- `Sources/RunningOverlay/UI/OverlayFeatheredBackground.swift`

Layout and models (the geometry source):

- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:508-599`
  (`intervalHUDBarLayout`), `601-686` (`intervalCountdownLayout`),
  `688-758` (`intervalWorkSummaryLayout`), `760-807` (`zoneEdgeBarLayout`),
  `809-972` (`intervalTimelineLayout`), plus private helpers `974-1784`
  and `1558-1583` (`intervalZoneSegmentFrames`).
- `Sources/RunningOverlay/Overlay/IntervalHUDBarModel.swift`
- `Sources/RunningOverlay/Overlay/IntervalTimelineModel.swift`
- `Sources/RunningOverlay/Overlay/IntervalCountdownModel.swift`
- `Sources/RunningOverlay/Overlay/IntervalWorkSummaryModel.swift`
- `Sources/RunningOverlay/Overlay/ZoneEdgeBarModel.swift`

Reference renderers:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift:1485-2531` (legacy
  Core Graphics interval drawing) and helpers `2533-2570`, `3608-3670`.
- `Sources/RunningOverlay/Export/SkiaEasyRunRenderer.swift` (spike bridge usage,
  CoreText line shaping, shadow chains, icon rasterization).
- `Sources/CSkiaBridge/include/skia_bridge.h` and `skia_bridge.cpp` (frozen
  primitive surface at the time of writing).

## 2. Ground rules

1. **SwiftUI is the oracle.** The Core Graphics export path is only a semantic
   reference. It already diverges from the SwiftUI views in several places
   (HUD content insets, phase-detail alpha, marker placement, text stacking,
   shadow counts). Do not port CG constants; port the SwiftUI view math.
2. **`OverlayRenderModel` stays the layout source of truth.** The Skia module
   should consume `layout.rect`, segment rects, marker fields, and resolved
   colors from the layout functions and only draw. See §7 for the places where
   geometry currently lives in the views instead of the model.
3. **All coordinates are canvas coordinates.** The SwiftUI views use local
   offsets (`-layout.rect.minX`, `-layout.rect.minY`) because they are positioned
   by the parent. The Skia renderer should use the absolute `layout.rect`,
   `layout.barRect`, and segment rects directly, exactly as
   `OverlayFrameRenderer` does.
4. **Group effects are applied at the same boundaries as SwiftUI.** Container
   shadows/glows wrap a group; text itself carries no per-glyph shadow for these
   modules. Use `skb_begin_shadow_chain` / `skb_begin_blur_layer` around the
   group, and pass zero shadow to `skb_draw_glyphs`.
5. **No new shared-file edits from this agent.** Shared bridge, renderer,
   `OverlayRenderModel`, `Package.swift`, architecture docs, and ADRs stay with
   the lead. This agent owns the notes file and, later, new
   `Render/Skia/Modules/Interval*.swift` files and focused tests.

## 3. Existing `skb_*` primitives

| Primitive | Signature summary | Interval use |
| --- | --- | --- |
| `skb_create` / `skb_create_gpu*` / `skb_destroy` | raster or Metal context | host setup |
| `skb_clear` | clear transparent | frame start |
| `skb_save` / `skb_restore` | canvas state stack | clips, layers, shadow groups |
| `skb_fill_rect` | solid rect | dividers, tick lines, segment gaps |
| `skb_fill_round_rect` | solid rounded rect, uniform radius | backgrounds, bars, pills, capsules |
| `skb_stroke_round_rect` | centered rounded-rect stroke | overlay borders, bottom-bar border |
| `skb_stroke_line` | solid line | not used directly by these modules |
| `skb_fill_circle` | solid circle | countdown center only if needed |
| `skb_stroke_polyline` | round-cap/join polyline | possible arc fallback only |
| `skb_fill_diagonal_gradient_round_rect` | two-stop diagonal gradient | not used |
| `skb_clip_circle` | circular clip | not used |
| `skb_clip_round_rect` | rounded-rect clip | feathered background, pill clip if needed |
| `skb_draw_text` | one CTFont string, left baseline, optional drop shadow | fallback only |
| `skb_draw_glyphs` | pre-shaped glyph IDs + x positions, one CTFont, optional drop shadow | **primary text path** |
| `skb_draw_image` | premultiplied BGRA rect, opacity, optional drop shadow | feathered background bitmap |
| `skb_begin_shadow_layer` | single drop shadow save-layer | single-shadow groups |
| `skb_begin_shadow_chain` | nested drop-shadow save-layer | layered shadows/glows |
| `skb_begin_blur_layer` | Gaussian blur save-layer | active-zone glow |
| `skb_pixels` / `skb_read_pixels` / `skb_flush` | readback / submit | export/parity harness |

## 4. Missing primitives and shared helpers

### 4.1 Bridge additions (priority order)

| ID | Needed primitive | Why | Consumers |
| --- | --- | --- | --- |
| B1 | **Generic filled path** (`skb_fill_path` with move/line/close/cubic) or, minimally, `skb_fill_triangle` | Zone marker arrows (up/down/left/right), timeline marker triangle. Work Summary's continuous corners can also be built as a cubic path. | HUD Bar, Timeline, Zone Edge Bar, Work Summary |
| B2 | **Stroked arc** (`skb_stroke_arc(cx, cy, radius, startDegrees, sweepDegrees, width, cap)`) | Countdown track + progress ring; also reusable by Running Gauge (Group D). | Countdown |
| B3 | **Group opacity layer** (`skb_begin_opacity_layer(alpha, bounds)`) | `element.opacity` is applied to the whole element by SwiftUI preview/export and by CG `context.setAlpha`; the spike currently applies opacity only to text/icons, so shapes would be wrong. | All five |
| B4 | **Independent stacked shadow layers** (optional) `skb_begin_shadow_layers(count, …)` | `skb_begin_shadow_chain` nests filters; SwiftUI stacked `.shadow` also nests, so this may be unnecessary. Keep as a calibration fallback only if golden diffs show the chain is wrong. | HUD Bar, Countdown, Work Summary |
| B5 | **Stroked path** (`skb_stroke_path`) | Only if continuous-corner border is built as a path rather than a rounded rect; otherwise B1 fill + `skb_stroke_round_rect` covers the module. | Work Summary |

Notes:

- B1 should be the frozen shape for both triangles and squircle corners. A
  command-buffer path is preferable to a triangle-only API because Group E/D
  (charts, gauge) will need arbitrary paths.
- B2 should expose the line cap (`butt` / `round`) because Countdown has
  `roundedLineCap`. Skia `SkPaint::kRound_Cap` is the exact analog.
- B3 is required for parity, not optional. Multiplying each color's alpha by
  `element.opacity` is not equivalent when shapes overlap (bars, glows, borders)
  and would also miss shadow alpha scaling.
- B4 is **not** assumed. SwiftUI's stacked `.shadow` composes each shadow over
  the previous result, which is structurally close to a nested Skia
  `DropShadow` chain. Validate with golden frames before adding API surface.

### 4.2 Swift-side shared helpers (foundation-owned)

These are not C primitives but are required for parity and to avoid five copies
of CoreText code:

1. **`SkiaTextLine` / text engine** — extract and generalize
   `SkiaEasyRunRenderer.makeLine` (`SkiaEasyRunRenderer.swift:991-1027`) plus
   `drawGlyphs` (`849-880`), `cachedFont` (`970-978`), and
   `OverlayFontResolver.appKitFont`. Required features:
   - single-line shaping via `CTLineCreateWithAttributedString`;
   - explicit font family, size, and `OverlayFontWeight`;
   - `monospacedDigit` via `kNumberSpacingType` /
     `kMonospacedNumbersSelector` (mirror `drawGaugePlainText`,
     `OverlayFrameRenderer.swift:2641-2676`);
   - measured `ascent`, `descent`, `leading`, `width`;
   - horizontal alignment (leading / center / trailing) within a rect;
   - baseline placement and baseline-aligned multi-run rows;
   - optional tail truncation with ellipsis;
   - **shrink-to-fit** honoring `minimumScaleFactor` per call site
     (0.72, 0.70, 0.68, 0.64, 0.62, 0.55 in these views);
   - uppercase transform where SwiftUI uses `.textCase(.uppercase)` or
     `.uppercased()`.
2. **Group shadow helper** — a wrapper that mirrors the spike's
   `beginShadowChain` (`SkiaEasyRunRenderer.swift:498-574`) but takes an
   explicit shadow list, because each interval module has a different count and
   set of conditions (§5).
3. **Feathered background helper** — precompose color × `OverlayFeatherMaskRenderer`
   mask (`OverlayFeatherMaskRenderer.swift:8`) into a cached premultiplied BGRA
   bitmap, then draw with `skb_draw_image`. No new C primitive is strictly
   needed. Cache by (size, color, radius, fadeAmount, opacity).
4. **Zone-bar geometry helper** — one pure function that turns
   `intervalZoneSegmentFrames` into per-segment rects for horizontal and
   vertical orientations, including the 0.18 × pitch gap clamp and active
   thickness scale. Today this math exists four times:
   `IntervalHUDBarOverlayView.swift:409-430`,
   `ZoneEdgeBarOverlayView.swift:73-118`,
   `OverlayFrameRenderer.swift:2320-2348`, and `2350-2392`.

## 5. Module inventories

Legend: ✅ existing primitive sufficient · ⚠️ existing primitive plus helper
or calibration · ❌ missing primitive.

### 5.1 Interval HUD Bar

Layout: `OverlayRenderModel.intervalHUDBarLayout` (`OverlayRenderModel.swift:508-599`).
View: `IntervalHUDBarOverlayView.swift`.

| Visual element | SwiftUI source | Geometry source | Skia mapping | Status |
| --- | --- | --- | --- | --- |
| Feathered background (color, opacity, radius, fade, blur) | `11-25`, `OverlayFeatheredBackground` | `backgroundLocalRect` `66-75`; `backgroundPaddingX/Y` from layout | precomposed BGRA + `skb_draw_image`; blur/material ignored to match CG export | ⚠️ |
| Background layered shadow (3 independent `.shadow`) | `24`, `564-587` | element style | `skb_begin_shadow_chain` around background image/fill | ⚠️ calibration |
| Overlay border | `56-63` | `layout.backgroundRadius`, `layout.borderWidth`, expanded rect | `skb_stroke_round_rect` | ✅ |
| Content layered shadow (only when no bg **and** no border) | `50-53` | element style | `skb_begin_shadow_chain` around content group | ⚠️ |
| Main cell row (HStack, equal columns, dividers) | `27-38` | view-local: horizontal padding `rect.width*0.035`, divider width + `rect.width*0.025` each side, HStack equal distribution | text engine + `skb_fill_rect` dividers | ⚠️ view-local layout |
| Vertical content layout (top/bottom padding, main height, bottom-bar spacing) | `77-126` | view-local algorithm using `layout.baseHeight`, not `rect.height` | replicate in module helper | ⚠️ view-local layout |
| REP cell (label + value, centered stack, spacing 4) | `194`, `241-254` | cell rect | two `skb_draw_glyphs` lines, centered, shrink 0.70 | ⚠️ text |
| Phase cell (phase + detail, spacing 3, min scale 0.72) | `204-218` | cell rect | two centered lines | ⚠️ text |
| Remaining cell (value + label/secondary row, spacing 3/6, min 0.70) | `220-239` | cell rect | three runs; second row is an inline HStack | ⚠️ text |
| Metric cell (label + value/unit baseline row, spacing 4/3, min 0.68) | `256-277` | cell rect | label line + baseline-aligned value/unit runs | ⚠️ text |
| Zone item cell | `183-187` | `layout.zoneItem` | same as metric cell | ⚠️ text |
| Divider | `165-170` | width `layout.dividerThickness`, height `basis*0.48`, horizontal padding `rect.width*0.025` | `skb_fill_rect` | ✅ |
| Bottom bar: lap progress track + fill | `287-306` | bar rect from `rect.width*0.035` inset; `layout.progress`, `layout.barHeight`, `layout.bottomBarCornerRadius` | `skb_fill_round_rect` ×2; optional glow via `skb_begin_shadow_layer`/blur | ✅ |
| Bottom bar: zone segments | `307-366` | `intervalZoneSegmentFrames` + `intervalZoneRects` `409-430` | shared zone-bar helper + `skb_fill_round_rect` per segment; `skb_begin_blur_layer` for active glow | ⚠️ shared helper |
| Bottom bar border | `394-403` | `layout.bottomBarBorderWidth` | `skb_stroke_round_rect` | ✅ |
| Current-zone marker: triangle | `432-457`, `498-521` | `IntervalHUDBarZoneMarkerMetrics.current` (`IntervalHUDBarModel.swift:613-631`), `zoneMarkerY` `371-388` | B1 filled path | ❌ B1 |
| Current-zone marker: value pill | `473-484` | metrics; text size measured | `skb_fill_round_rect` (black 0.55) + centered text | ⚠️ text |
| Threshold marker: capsule tick + `T` label | `459-471` | `IntervalHUDBarZoneMarkerMetrics.threshold` (`633-651`) | `skb_fill_round_rect` capsule + text | ✅ / ⚠️ text |
| Element group opacity | preview/export container | `element.opacity` | B3 | ❌ B3 |

Module notes:

- The bottom-bar track/fill use the same corner radius, so the fill is a
  narrower rounded rect, not a clipped progress bar. Do not clip.
- `layout.barHeight` is a fixed `context.scaled(10 * scale)`; it is not
  user-configurable.
- The zone-marker triangle floats outside the HUD rect and may overlap cells or
  extend past the background. Do not clip it.
- `intervalZoneSegmentFrames` expands the active zone up to 50% width. The
  active-height scale raises it around the bar centerline; the bar row height
  does not change.
- HUD bar is the only interval module that combines a feathered background,
  layered shadows, a multi-column text grid, a segmented bar, and markers. It
  is the integration stress test, not a good first port.

### 5.2 Interval Timeline

Layout: `OverlayRenderModel.intervalTimelineLayout` (`OverlayRenderModel.swift:809-972`),
helpers `974-1180`.
View: `IntervalTimelineOverlayView.swift`.

| Visual element | SwiftUI source | Geometry source | Skia mapping | Status |
| --- | --- | --- | --- | --- |
| Feathered background | `9-23` | `backgroundLocalRect` `48-57` (padding × `element.scale`) | precomposed BGRA + `skb_draw_image` | ⚠️ |
| Background shadow (single) | `22`, `165-175` | element style | `skb_begin_shadow_layer` | ✅ |
| Overlay border | `26-31` | `layout.cornerRadius`, `layout.borderWidth`, expanded rect | `skb_stroke_round_rect` | ✅ |
| Content shadow (only when no background) | `43` | element style | shadow layer around border+segments | ✅ |
| Segment fill (per-lap rounded rect, opacity by state) | `77-95` | `layout.segments[].rect`, `segment.color`, `segment.opacity`, `layout.segmentCornerRadius` | `skb_fill_round_rect` | ✅ |
| Current progress overlay (white 0.30, width × progress) | `83-88` | `layout.currentProgress` | `skb_fill_round_rect` | ✅ |
| Current segment border (white 0.74) | `89-94` | `layout.currentSegmentBorderWidth` | `skb_stroke_round_rect` | ✅ |
| Current segment glow (shadow radius `10 * scale`, 0.45) | `95` | `element.scale` | `skb_begin_shadow_layer` around segment | ✅ |
| Segment label stack (rep line + label lines, spacing `1 * scale`, horizontal padding `4 * scale`) | `97-119` | `segment.labelLines`, `layout.repText`, `labelFontSize`, `durationFontSize`; line heights are intrinsic | text engine, centered vertical stack, shrink 0.64–0.70 | ⚠️ text + view-local layout |
| Overflow ellipsis `···` left/right | `59-75` | `layout.overflowEllipsisInset`, `layout.contentRect.midY` | centered text | ✅ |
| Marker triangle | `124-131`, `148-157` | `layout.markerX`, `markerTopY`, triangle w/h | B1 filled path | ❌ B1 |
| Marker label (`NOW`) | `132-142` | `layout.markerLabel`, font size/weight/name, label rect | centered text | ⚠️ text |

Module notes:

- The current segment's progress fill is **overall workout progress**
  (`activity.lapProgress` is not used for it in the layout; `currentProgress`
  comes from `lapProgress` of the current lap — confirm with the lead whether the
  doc statement "overall workout progress" is stale). The port consumes
  `layout.currentProgress` and does not re-derive.
- Centered vs full schedule, hidden WU/Rest/CD, overflow counts, current width,
  and equal/duration widths are all resolved in the layout. Do not recompute.
- The marker lane is reserved in `layout.rect` height; enabling/disabling the
  marker or label must not move segments. Consume `markerTopY`.
- Segment text must be centered with intrinsic line heights, not the CG
  renderer's `rect.height / (lineCount + 1)` approximation.

### 5.3 Interval Countdown

Layout: `OverlayRenderModel.intervalCountdownLayout` (`OverlayRenderModel.swift:601-686`).
View: `IntervalCountdownOverlayView.swift`.

| Visual element | SwiftUI source | Geometry source | Skia mapping | Status |
| --- | --- | --- | --- | --- |
| Background rounded rect (clamped radius) | `9-14`, `92-103` | `layout.backgroundPaddingX/Y`, `layout.backgroundRadius` | `skb_fill_round_rect` | ✅ |
| Background shadow (3 layers) | `14`, `157-177` | `layout.shadowRadius/Offset`, element style | `skb_begin_shadow_chain` | ⚠️ |
| Overlay border | `16-24` | `layout.borderWidth`, clamped radius | `skb_stroke_round_rect` | ✅ |
| Track ring (stroke, cap butt/round) | `36-40` | center = `rect.mid`, radius = `rect.width/2 - ringWidth` (ZStack padding `ringWidth`), `layout.ringWidth`, `trackColor × trackOpacity` | B2 arc, full 360° sweep | ❌ B2 |
| Progress ring (trim 0…progress, −90°, CCW mirror) | `42-50` | `layout.progress`, `layout.ringColor`, `resolvedRingDirection` | B2 arc with start/sweep/direction and cap | ❌ B2 |
| Ring glow (2 shadows on the arc) | `50`, `133-143` | `ringGlowIntensity` | shadow layers around arc only | ✅ |
| Global foreground glow (2 shadows) | `28`, `145-155` | element glow style | shadow layers around foreground group | ✅ |
| Foreground shadow (only when no background) | `29`, `157-177` | `layout.shadowRadius/Offset` | shadow layers around foreground group | ✅ |
| Inner text stack (helper, phase+rep row, countdown, caption; spacing `max(2*scale,1)`, phase/rep spacing `max(5*scale,2)`, countdown vertical padding `max(2*scale,1)`) | `58-90`, `113-123` | `layout.textItems`, `layout.innerDiameter` | text engine, centered vertical stack; countdown monospaced; uppercase helper/phase; shrink 0.62/0.64 | ⚠️ text + view-local layout |

Module notes:

- `layout.textItems` is already ordered helper → phase → rep → countdown →
  caption and only contains visible, non-empty items. Draw in that order.
- The countdown item always renders even if `isVisible` is false (layout forces
  it). Phase and rep share a baseline row; helper, countdown, and caption are
  separate rows.
- The ring's circular path is inset by `ringWidth`, and the stroke is centered
  on that path. Use radius `rect.width/2 - ringWidth`, not
  `innerDiameter/2`.
- Counterclockwise is a horizontal mirror of the trimmed arc, not a different
  progress value; `layout.progress` already encodes the remaining/elapsed
  direction.
- This module is the only one that needs B2. It is small enough to validate B2
  and the text stack early.

### 5.4 Interval Work Summary

Layout: `OverlayRenderModel.intervalWorkSummaryLayout` (`OverlayRenderModel.swift:688-758`).
View: `IntervalWorkSummaryOverlayView.swift`.

| Visual element | SwiftUI source | Geometry source | Skia mapping | Status |
| --- | --- | --- | --- | --- |
| Visibility window | `9`, `695-698` | `layout.isVisible` | early return | ✅ |
| Background **continuous** rounded rect | `10-14` | `layout.rect`, `layout.backgroundRadius` | B1 cubic squircle path + fill (or circular approximation with review) | ❌ B1 / ⚠️ |
| Background shadow (2 layers) | `14`, `171-185` | `layout.shadowRadius/Offset` | `skb_begin_shadow_chain` | ⚠️ |
| Overlay border (continuous) | `15-23` | `layout.borderWidth` | B5 stroked path (or `skb_stroke_round_rect` approximation) | ❌ B5 / ⚠️ |
| Global content glow (2 shadows) | `30`, `155-169` | element glow style | shadow layers around content | ✅ |
| Content shadow (only when no background) | `31`, `171-185` | layout shadow fields | shadow layers around content | ✅ |
| Content inset | `27-29` | `layout.backgroundPaddingX/Y` (insets **inside** `layout.rect`, unlike other modules) | content rect = `rect.insetBy` | ✅ |
| Component label (uppercase, alignment leading/center/trailing, bottom padding 8) | `39-48` | `layout.componentLabel`, `textItems[.componentLabel]`, `resolvedComponentLabelAlignment` | text engine with alignment | ⚠️ text |
| Primary metric (value + unit baseline row spacing 7, unit scale 0.34; label below spacing 5) | `63-91` | `layout.primary`, `textItems[.primaryValue/.primaryLabel]` | baseline-aligned runs + centered label | ⚠️ text |
| Secondary metrics row (equal cells, horizontal padding 8, value+unit baseline spacing 4, unit scale 0.38, label below spacing 4) | `93-135` | `layout.secondaryItems`, `textItems[.secondaryValue/.secondaryLabel]` | baseline runs per cell | ⚠️ text |
| Secondary dividers (width `max(dividerWidth, 0.5)`, height `rect.height * 0.26`) | `98-103` | style divider fields | `skb_fill_rect` | ✅ |
| Vertical spacer distribution (label → primary → secondary) | `38-61` | view-local SwiftUI `Spacer(minLength: 0/12)` + intrinsic heights | replicate VStack distribution | ⚠️ view-local layout |
| Element group opacity | container | `element.opacity` | B3 | ❌ B3 |

Module notes:

- This is the only interval module using `.continuous` corners, for both the
  background and border. A circular `SkRRect` will visibly differ at large
  radii. Prefer a cubic superellipse path through B1/B5; otherwise accept a
  reviewed threshold.
- The background is drawn at the full `layout.rect`; padding insets the content
  instead of expanding the background. Do not reuse the HUD/timeline background
  helper unchanged.
- `layout.secondaryItems` is already filtered to visible slots and capped at 3.
  `normalizedSecondarySlots` pads hidden slots for editing; do not render them.
- The card is invisible outside `displayDuration` after the last active lap.
  Golden fixtures must assert full transparency, not just "no visible marks".

### 5.5 Zone Edge Bar

Layout: `OverlayRenderModel.zoneEdgeBarLayout` (`OverlayRenderModel.swift:760-807`),
helpers `1386-1534`.
View: `ZoneEdgeBarOverlayView.swift`.

| Visual element | SwiftUI source | Geometry source | Skia mapping | Status |
| --- | --- | --- | --- | --- |
| Active-zone glow (blur) | `12-21` | `style.glowIntensity`, `crossAxisThickness * 1.6` | `skb_begin_blur_layer` + rounded fill | ✅ |
| Zone segments (horizontal and vertical, gaps, active height scale) | `23-31`, `73-118` | `intervalZoneSegmentFrames` + `zoneRects`; `layout.barRect`, `layout.orientation` | shared zone-bar helper + `skb_fill_round_rect` | ⚠️ shared helper |
| Overlay border | `33-38` | `localBarRect`, clamped corner radius, `style.borderWidth * scale` | `skb_stroke_round_rect` | ✅ |
| Current-zone marker: triangle (4 directions) | `40-50`, `148-177`, `272-305` | `markerPosition` `124-146`; arrow size `max(crossAxis*1.35,12) × max(crossAxis*0.9,8)` | B1 filled path | ❌ B1 |
| Current-zone marker: value text (optional) | `149-177`, `215-229` | `style.markerShowsValue`, `layout.markerText` | centered text | ⚠️ text |
| Threshold marker: capsule tick + text | `179-213` | `thresholdLineLength = max(crossAxis*1.35,10)`, offset by label/spacing | `skb_fill_round_rect` capsule + text | ✅ / ⚠️ text |
| Whole-bar shadow (single) | `54`, `313-324` | element style | `skb_begin_shadow_layer` | ✅ |
| Element group opacity | container | `element.opacity` | B3 | ❌ B3 |

Module notes:

- Placement `.edge` derives orientation from `style.edge` (left/right →
  vertical), while `.free` uses `style.orientation`. The layout already resolves
  `layout.orientation` and `layout.barRect`; do not re-derive.
- Vertical zone order is reversed in the view (`barRect.maxY - usableLength *
  (frame.start + frame.width)`); replicate exactly.
- The marker sits outside the bar; do not clip.
- This is the smallest module that exercises segmented bars, both orientations,
  glow, markers, and text. It is the recommended first port.

## 6. Shared drawing code across the five modules

| Shared concern | Where it appears | Recommendation |
| --- | --- | --- |
| Zone segment frames | `OverlayRenderModel.intervalZoneSegmentFrames` (shared, already) | consume directly |
| Zone segment rect math (gap clamp, active thickness, horizontal/vertical) | HUD view `409-430`; Zone Edge view `73-118`; CG `2320-2392` | one module-local `IntervalZoneBarGeometry` helper for Skia; recommend lead eventually lift into `OverlayRenderModel` |
| Zone marker geometry + drawing (triangle, pill, threshold tick) | HUD view `371-495`; Zone Edge view `124-261`; CG `2148-2252`, `2394-2531` | one module-local `IntervalZoneMarkerRenderer` with an orientation/role enum |
| Layered shadow chains | HUD `564-587`; Timeline `165-175`; Countdown `133-177`; Work Summary `155-185`; Zone Edge `313-324` | one group-shadow helper taking an explicit list of shadows/glows |
| Feathered background | HUD `11-25`; Timeline `9-23`; both via `OverlayFeatheredBackground` | one cached feathered-background helper |
| Rounded-rect background + border | all five | thin `drawRoundedBackground` / `drawRoundedBorder` wrappers |
| Text stack (vertical, centered, per-role fonts) | HUD cells; Timeline segments; Countdown inner text; Work Summary primary/secondary | one text-stack helper on top of the text engine |
| Baseline-aligned inline runs (value + unit) | HUD metric cells; Work Summary primary/secondary | one baseline-row helper |
| Marker triangle path | HUD up/down; Timeline up; Zone Edge up/down/left/right | one triangle/path helper over B1 |
| Element opacity | all five | B3 + one `withElementOpacity` wrapper |
| Canvas-coordinate conversion | views use local offsets; CG uses absolute | use absolute `layout.rect` everywhere; no shared conversion needed |

## 7. Layout completeness gap (coordination item)

`OverlayRenderModel` does **not** contain all geometry needed for pixel parity.
The following layout math currently lives in the SwiftUI views:

- HUD bar: vertical padding/spacing algorithm, main-content height, horizontal
  content inset, divider height/padding, HStack column distribution, zone-rect
  math, marker Y placement. (`IntervalHUDBarOverlayView.swift:66-170`, `371-430`)
- Timeline: overflow ellipsis positions, segment local offsets, marker stack
  placement, label line spacing. (`IntervalTimelineOverlayView.swift:59-145`)
- Countdown: text stack spacing/padding, ring inset, background radius clamp.
  (`IntervalCountdownOverlayView.swift:58-103`)
- Work Summary: content insets, spacer distribution, unit scale factors,
  divider height, label alignment mapping. (`IntervalWorkSummaryOverlayView.swift:37-151`)
- Zone Edge Bar: zone-rect math, marker position/size, corner-radius clamps.
  (`ZoneEdgeBarOverlayView.swift:61-261`)

Plan decision #2 says the Skia renderer must not duplicate layout. There are two
ways to honor it:

1. **Preferred:** the lead lifts the shared pieces (zone rects, marker metrics,
  text-stack metrics, HUD vertical layout, Work Summary content metrics) into
  `OverlayRenderModel` before ports. This is a shared-file change and must be
  lead-owned. It also removes the four-way zone-rect duplication.
2. **Fallback:** each Skia module replicates the view math in a module-local
  helper and golden frames prove parity. This is faster but temporarily
  duplicates layout and risks drift if the views change before cutover.

This inventory assumes option 2 until the lead decides, but flags it as the
largest coordination risk.

## 8. Parity risks

1. **Text shaping and shrink-to-fit.** SwiftUI's `minimumScaleFactor` shrink
   algorithm is not specified; CoreText fit-to-width will be close but not
   bit-identical. Mitigation: fixture text that fits at scale 1.0 for the main
   golden set; a small "tight text" set for reviewed shrink behavior; record
   per-element diff boxes.
2. **Monospaced digits.** Must use the CoreText number-spacing feature, not a
   monospaced family. Verify `SkMakeTypefaceFromCTFont` preserves the glyph IDs
   produced by the feature-adjusted CTFont.
3. **Shadow sigma mapping.** SwiftUI `shadow(radius:)` → Skia `sigma` is not
   documented. The spike already has `SKIA_SHADOW_SIGMA_FACTOR`
   (`SkiaEasyRunRenderer.swift:839`). Calibrate once per module and record the
   value in the golden harness, not in production code.
4. **Nested vs stacked shadows.** Validate the 3-layer HUD/Countdown and 2-layer
   Work Summary chains against the SwiftUI oracle before adding B4.
5. **Continuous corners.** Work Summary's `.continuous` background/border is the
   only squircle in the group. Circular approximation may fail the threshold.
6. **Feather background.** `OverlayFeatherMaskRenderer` uses a distance-field
   mask; reuse it rather than approximating. Background blur/material
   (`ultraThinMaterial`) is not reproducible on a transparent overlay canvas and
   is already ignored by the CG export path; match the CG behavior and flag the
   preview-only difference.
7. **Element opacity.** Missing B3 would make all non-text shapes ignore
   `element.opacity`.
8. **Preference determinism.** `intervalHUDBarLayout`, `zoneEdgeBarLayout`, and
   `lapKindColor` read `HeartRateZonePreferences.currentSnapshot()` and
   `IntervalKindColorPreferences.currentSnapshot()`, which read
   `UserDefaults.standard`. Golden tests on a developer machine with saved zones
   will not be reproducible. See §10.3.
9. **Font defaults.** Style defaults use `FontLibraryManager.currentDefaultFamily`
   (user-configurable). Fixtures must set explicit `fontName` values.
10. **Timeline doc drift.** The module doc says the current-segment progress fill
    is overall workout progress, while the layout uses
    `activity.lapProgress(at:byDistance:false)`. The port consumes the layout;
    the lead should reconcile the doc during the module documentation update.
11. **Work Summary visibility edge.** `age <= displayDuration` includes the exact
    boundary; fixtures should test just-inside and just-outside.

## 9. Port order

Risk-first order, assuming B1/B2/B3 and the shared text engine are frozen:

1. **Zone Edge Bar** — smallest; proves segmented bars (both orientations),
   gap/thickness math, marker triangles, glow, single shadow, group opacity.
2. **Interval Timeline** — proves rounded segment bars, current progress/border/
   glow, intrinsic-height text stacks, overflow hints, marker lane. No new
   primitives beyond B1.
3. **Interval Countdown** — proves B2 arcs, ring caps, ring/global glows, and the
   centered text stack. Small surface area.
4. **Interval HUD Bar** — integration module: reuses zone-bar and text-stack
   helpers, adds feathered background, layered shadows, multi-column grid,
   lap-progress bar, and both marker kinds.
5. **Interval Work Summary** — last because it depends on the B1/B5 continuous
   corner decision and the content-spacer layout; it is otherwise small.

If the lead wants the highest-value module earlier, HUD Bar can move to slot 2
after Zone Edge Bar; it then becomes the text-engine stress test. Timeline and
Countdown can run in either order. Do not start HUD Bar before Zone Edge Bar,
because it reuses the segmented-bar and marker helpers.

Per-module exit gate (from the migration plan):

- Skia draw implementation in a new module file.
- Golden frames against the SwiftUI oracle at 1280×720, 1920×1080, 3840×2160
  (4K may be a reduced time set for runtime).
- Focused unit tests for layout consumption and edge cases.
- Module documentation update under `docs/overlay-modules/`.
- Feature-flag fallback until parity review passes.
- No edits to shared bridge/renderer/model files.

## 10. Deterministic golden-frame fixtures

### 10.1 Synthetic workout

Use one authored activity, `interval-6-lap`, with no GPS, no network, and fixed
timestamps (`Date(timeIntervalSince1970: 1_735_689_600)`):

| Lap | Kind | Start–End (s) | Distance (m) |
| --- | --- | --- | --- |
| 0 | warmup | 0–60 | 180 |
| 1 | active | 60–240 | 720 |
| 2 | rest | 240–300 | 120 |
| 3 | active | 300–480 | 720 |
| 4 | rest | 480–540 | 120 |
| 5 | cooldown | 540–660 | 180 |

Records every 1 s, piecewise-linear distance matching lap totals; HR 120 → 178
in work, 150–145 in rest; pace 330 / 240 / 420 / 300 s/km by kind; power
220 / 280 / 140 / 200 W; cadence 168 / 182 / 150 / 170 spm; elevation
20 + 0.01·t m; temperature 18 °C; grade 0.5%. Set an explicit structured
`workoutStructure` for realism, though layout only reads `laps`.

Second fixture, `interval-1min-x25`, reuses the repeated-lap builder already in
`OverlayRenderModelTests.swift:2300-2327` (warmup + 25 work/rest pairs +
cooldown) to exercise Timeline centered overflow, full-schedule compression,
and rep counter.

### 10.2 Fixed styles

For each module, render three variants:

- **default** — module default style, explicit `fontName = "Menlo"` (system,
  deterministic), default colors.
- **effects** — background + border + shadow + glow enabled, non-zero
  fade/padding, marker label/value enabled.
- **plain** — background/shadow/glow/border disabled, so geometry-only diffs are
  readable.

Zone-specific fixtures set `bottomBarMode = .heartRateZones` and `.paceZones`
for HUD Bar, and `metric = .heartRate` / `.pace` for Zone Edge Bar, so both
marker/threshold paths render. Set `zoneMarkerShowsValue = true` and
`thresholdZoneMarkerEnabled = true`.

### 10.3 Deterministic preferences

The layout functions read global preferences. Before rendering, the fixture
harness must install a fixed snapshot and restore the previous state:

- HR/pace zones: 5 zones with fixed HR ranges (0–120, 121–140, 141–155,
  156–170, 171–200), fixed pace ranges, `thresholdHR = 165`,
  `thresholdPaceSecPerKm = 270`.
- Interval kind colors: `IntervalKindColorPalette.default`.

Two options, in order of preference:

1. **Lead adds an injection seam** (e.g., `OverlayRenderContext` carries an
   optional `HeartRateZoneSnapshot` / `IntervalKindColorPalette`, defaulting to
   `currentSnapshot()`). This is a shared-file change and keeps tests free of
   `UserDefaults`.
2. **Serialize and seed `UserDefaults.standard`** in the fixture suite
   (`@Suite(.serialized)`), snapshotting and restoring the zone/kind keys in
   `defer`. This is brittle because the keys are private, but workable if the
   lead declines the seam.

Do not rely on the current developer machine's defaults.

### 10.4 Times and resolutions

| Module | Times (s) | Notes |
| --- | --- | --- |
| HUD Bar | 120, 270, 400 | active mid, rest (HR drop), second active |
| Timeline | 150, 400, 900 | centered active, full schedule, high-count overflow |
| Countdown | 120, 270, 599 | active remaining, rest, cooldown |
| Work Summary | 241, 301, 420 | inside window after work lap, inside window after rest, outside window (transparent) |
| Zone Edge Bar | 120, 270 | HR zone horizontal, pace zone vertical |

Resolutions: 1280×720 and 1920×1080 for every module/time; 3840×2160 for one
representative time per module (runtime control). The renderer receives the
canvas size through `OverlayRenderContext`, so layout scaling is exercised at
each resolution.

### 10.5 Harness and metrics

- Render the SwiftUI oracle with
  `SwiftUIOverlayVideoExporter.renderFrameCGImage` (as `SkiaSpikeTests` does) and
  the Skia frame with the module renderer; rasterize both to premultiplied BGRA.
- Compare per pixel with a channel-delta threshold of 8 (matching
  `SkiaSpikeTests`) and report:
  - changed-pixel ratio,
  - mean channel delta,
  - diff bounding box,
  - per-element attribution (nearest element center, as the spike does).
- Proposed initial gates: changed-pixel ratio ≤ 0.5% and mean channel delta
  ≤ 1.0 for geometry/color; text-heavy modules may need a reviewed, slightly
  looser gate until the text engine is calibrated. The lead sets the final
  numbers.
- Write both PNGs plus a JSON metric report to a temporary directory for human
  review. Do not commit generated frames.
- No network, no MapKit, no current date, no user fonts, no `UserDefaults`
  leakage.

### 10.6 Fixture files

- Swift fixture builder: `Tests/RunningOverlayTests/SkiaIntervalFixtures.swift`
  (synthetic activity, fixed styles, fixed preferences, time/resolution matrix).
- Focused layout tests:
  `Tests/RunningOverlayTests/SkiaIntervalLayoutTests.swift` (consume the five
  layout functions; assert rect/segment/marker fields and visibility window).
- Golden parity tests:
  `Tests/RunningOverlayTests/SkiaIntervalGoldenTests.swift`.
- If a committed project snapshot is preferred over a Swift builder, add
  `Tests/RunningOverlayTests/Fixtures/Skia/interval-workout.json` and document
  provenance in `Tests/RunningOverlayTests/Fixtures/README.md` and
  `docs/testing.md`. A Swift builder is preferred because it is synthetic by
  construction and avoids a new binary fixture.

## 11. Proposed file layout (after foundation)

```text
Sources/RunningOverlay/Render/Skia/Modules/
  IntervalShared.swift          # zone rects, marker drawing, shadow groups,
                                # feathered background, text-stack helpers
  IntervalHUDBarRenderer.swift
  IntervalTimelineRenderer.swift
  IntervalCountdownRenderer.swift
  IntervalWorkSummaryRenderer.swift
  ZoneEdgeBarRenderer.swift

Tests/RunningOverlayTests/
  SkiaIntervalFixtures.swift
  SkiaIntervalLayoutTests.swift
  SkiaIntervalGoldenTests.swift
```

These files do not exist yet. The foundation branch creates
`Render/Skia/` and the per-module dispatch table. Until then, do not extend
`SkiaEasyRunRenderer.swift` (spike) or `OverlayFrameRenderer.swift` (legacy).

## 12. Decisions needed from the lead

1. **Freeze B1–B3.** Generic filled path (or triangle-only), stroked arc with
   cap, and group opacity layer. B4/B5 are optional/calibration-dependent.
2. **Layout completeness (§7).** Lift view-local geometry into
   `OverlayRenderModel`, or approve module-local replication for the port.
3. **Preference injection (§10.3).** Add a snapshot seam to
   `OverlayRenderContext`, or approve serialized `UserDefaults` seeding in tests.
4. **Continuous corners.** Commit to a cubic squircle path for Work Summary, or
   approve a reviewed circular approximation.
5. **Text engine ownership.** Confirm the foundation exposes a shared
   `SkiaTextLine`/text-stack helper, including shrink-to-fit and monospaced
   digits, before the first module port.
6. **Golden thresholds.** Approve initial changed-pixel/mean-delta gates and the
   shadow-sigma calibration workflow.
7. **Work Summary doc drift (§8.10).** Confirm the Timeline current-progress
   definition so the module doc update is correct.

## 13. Phase A acceptance

- [x] All five SwiftUI views inspected.
- [x] All five `OverlayRenderModel` layout functions and their helpers inspected.
- [x] Every visual element mapped to an existing `skb_*` primitive or a missing
      primitive.
- [x] Shared drawing code identified.
- [x] Port order proposed.
- [x] Deterministic golden-frame fixtures proposed.
- [x] Bridge API frozen by the lead (`d6d0125`, decisions `cdb4aba`).
- [x] Decisions in §12 resolved.
- [x] First module port started (Zone Edge Bar).

## 14. Phase B status (2026-11-02)

### Landed files

```text
Sources/RunningOverlay/Render/Skia/Modules/
  IntervalShared.swift               # color/shape/effect helpers, feathered
                                     # background mask cache, text seam
  ZoneEdgeBarSkiaRenderer.swift
  IntervalTimelineSkiaRenderer.swift
  SkiaIntervalModules.swift          # dispatch + SkiaIntervalFrameRenderer

Tests/RunningOverlayTests/
  SkiaIntervalTests.swift
```

Also added:

- `IntervalHUDBarModel.IntervalZoneBarRect`.
- `OverlayRenderModel.intervalZoneBarRects(...)` in a new
  `MARK: - Interval family geometry` section. It mirrors the SwiftUI
  zone-segment rect math, including the `18%` gap clamp, active-thickness
  scaling, and vertical ordering.

### Text seam

`SkiaIntervalText` owns shaping, shrink-to-fit, truncation, and vertical stacks
for now. Group T published `SkiaTextComposer.makeLine/measure/draw`,
`SkiaTextEffects.withElementLayers`, and `SkiaTextModule.draw` on the
integration branch, but those files are not on this branch yet. The seam is
deliberately narrow and marked:

```text
TODO(Group T): replace this with SkiaTextComposer when it is published.
```

No module renderer calls CoreText directly; all call sites go through the seam,
so the swap is mechanical.

### Marker geometry (module-local for now)

Zone Edge Bar marker placement still lives in `ZoneEdgeBarSkiaRenderer` because
the SwiftUI view owns it. It mirrors `markerPosition`, `currentMarkerHeight`,
`currentMarkerWidth`, `markerGap`, and `thresholdLabelAndSpacing` exactly.
Marked for a follow-up lift into `OverlayRenderModel` after lead review; it was
not lifted now to keep the first milestone small.

### Golden results

Harness: SwiftUI export oracle vs `SkiaIntervalFrameRenderer`, 6-lap synthetic
workout, frame at 150 s. Threshold counts a pixel changed when the summed RGBA
delta exceeds 8. PNGs are written to
`$TMPDIR/skia-interval-goldens/<label>/`.

| Fixture | Resolution | Changed | Mean delta |
| --- | --- | ---: | ---: |
| zone-edge-bar default | 720p | 0.168% | 0.0307 |
| zone-edge-bar effects | 720p | 0.518% | 0.0542 |
| zone-edge-bar plain | 720p | 0.020% | 0.0040 |
| zone-edge-bar default | 1080p | 0.098% | 0.0319 |
| zone-edge-bar effects | 1080p | 0.477% | 0.0566 |
| zone-edge-bar plain | 1080p | 0.011% | 0.0025 |
| zone-edge-bar default | 2160p | 0.046% | 0.0154 |
| timeline default | 720p | 1.484% | 0.2487 |
| timeline effects | 720p | 1.641% | 0.2727 |
| timeline plain | 720p | 1.347% | 0.2389 |
| timeline default | 1080p | 1.010% | 0.1870 |
| timeline effects | 1080p | 1.172% | 0.2159 |
| timeline plain | 1080p | 0.908% | 0.1803 |
| timeline default | 2160p | 0.554% | 0.1397 |

Reading:

- Zone Edge Bar shapes, glow, border, markers, and text are effectively at
  parity. The residual is glow/blur falloff.
- Timeline shapes (segments, progress overlay, current border, overflow hints,
  marker) are at parity. The residual is glyph antialiasing plus a roughly 2 px
  vertical text-stack offset in SwiftUI Text vs CoreText line boxes. Group T's
  composer should absorb that offset.
- Tests pin the font to `"SF Pro"` for goldens. The production fallback is
  `"PT Mono"`, which is not bundled on every machine and resolves to the system
  font through two different SwiftUI/AppKit paths.

### Determinism

`SkiaIntervalTests` is `@Suite(.serialized)` because
`OverlayPreferenceFixtures` saves, seeds, and restores process-wide
`UserDefaults` keys. Parallel golden tests produced different marker states.
A full parallel test run can still overlap this suite with other suites that read
the same keys; the fixture is only safe when every reader is serialized or when
preferences move to an explicit render-context snapshot.

### Remaining

1. Rebase and swap `SkiaIntervalText` for `SkiaTextComposer`, then re-baseline
   the timeline goldens.
2. Port Interval Countdown, Interval HUD Bar, Interval Work Summary in the agreed
   order.
3. Lift Zone Edge Bar marker metrics into `OverlayRenderModel` with lead review.
4. Implement `backgroundBlurRadius` material blur when a backdrop primitive
   exists; the timeline port currently draws the fade mask but not the material
   blur.
5. Wire `SkiaIntervalModules.draw` into the shared dispatch table once the lead
   opens that seam.

