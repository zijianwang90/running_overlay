# Route Map Overlay UI Design Spec

Last updated: 2026-04-28 (Stats Bar major refactor — placement, layout modes, dividers, blur, corner radius)

## Purpose

Route Map Overlay is a composite overlay that combines a **map background**, a
**polyline of the GPS route**, **start / finish markers**, and a **fully
customizable Status Bar**. Unlike Numeric Overlays, it is not a single text field;
it is a small visual module dropped on top of the source video. This spec
captures the editing surface and visual rules so the implementation stays
consistent with the rest of the Inspector design system.

This spec extends and supersedes the Inspector portions of
[`docs/overlay-modules/route-map-overlay.md`](../../../overlay-modules/route-map-overlay.md),
which still owns rendering architecture, GPS data, map snapshot caching, and
phase planning.

## Design Reference

The original full-video container reference image is not currently present in
the repository. Use the existing [numeric overlay mockup](../numeric/numeric-overlay.png)
for the Inspector density target.

The four reference container variants:

1. **Square Hard Edge** — rounded rectangle, crisp border, drop shadow.
2. **Circle Hard Edge** — circular window with subtle 1 px border, drop shadow.
3. **Square Gradient Edge** — rounded rectangle whose map fades into the video.
4. **Circle Gradient Edge** — circular vignette that blends into the video.

## Applies To

- `OverlayElementType.routeMap` only.

Route Map does **not** share the Numeric Overlay detail view. It uses its own
`RouteMapOverlayDetailView`, but reuses the shared dense Inspector primitives
from `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
(`InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseSegmented`,
`InspectorDenseMenuLabel`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`)
and `NumericTokens` so density and spacing match the rest of the Inspector.

## Design Direction

- DaVinci-style dense parameter rows.
- Two-column label/control alignment.
- Compact section headers with icons and chevron collapse affordance.
- Small section dividers, no big card containers.
- Container presets at the top of the panel — the user should be able to pick
  one of the four reference variants in a single click and only fine-tune from
  there.
- Status Bar is a bottom / edge data strip composed from configurable metric slots, not a fixed 3-column distance / pace / time block.
- Route line is always more prominent than the map background. The map
  background defaults are intentionally dim, low saturation, and partially
  transparent.

## Header

Content:

- Back icon button.
- Map icon (filled `map.fill` style) in accent blue.
- Title: `Route Map`.
- Pill: `Overlay`.
- Subtitle: total distance (e.g. `12.86 km`) or `—` if route has no GPS.
- Trash icon button.

Rules:

- Header height matches `EditorTheme.panelHeaderHeight`.
- The subtitle uses the same distance formatter as the bottom HUD and Numeric
  Overlay distance preview.
- Trash remains the only destructive header action.

## Section Model

Sections, in order:

1. `Preset` — Route Style Preset (line appearance only) + Distance readout.
2. `Layout` — Position X/Y, Scale, Width, Height, Opacity.
3. `Container` — Shape, Width, Height (or Size for circle), Corner Radius
   (square only), Edge Mode, Edge Softness, Border.
4. `Background Map` — Show Map (header toggle), Map Style, Map Opacity,
   optional Contrast / Saturation / Brightness / Blur.
5. `Route Line` — Color Mode, Solid Color, Gradient Stops, Width, Opacity,
   Dash, Glow.
6. `Markers` — All Markers, Start Marker, Finish Marker (style / color / size /
   border / label).
7. `Status Bar` — Enabled (toggle accessory), Placement, Inside, Layout, Size, Width, Offset, Item Gap, Slots, Background, Dividers, Radius.
8. `Effects` — Shadow opacity / radius, Glow opacity / radius, Background
   opacity (container fill).

Each section renders as a compact collapsible group:

- Header height: 30 px.
- Small `Image(systemName:)` in `textSecondary`.
- Section title, optional accessory (e.g. enabled toggle).
- Body rows: `InspectorDenseRow` with two-column grid.
- Anchor rows use a taller min-height so the 3x3 anchor grid cannot overflow into the next row.

Do not use one-row card containers. Row gap is 6 px, section gap is 8 px.

## Preset Section

The Preset section is now a thin starting point that bundles a single
high-level decision: which route line aesthetic to use. Container shape,
edges, map background, and effects each live in their own section so the
inspector never has two controls fighting for the same field.

### Route Style Preset

Dropdown: `OverlayRouteMapPreset` — `minimal`, `gradient`, `glow`. The
preset describes the **line** appearance only (solid color vs. gradient
stops, glow / shadow defaults). It does **not** decide whether the map
background is rendered.

To show or hide the map background, use the `Show Map` toggle in the
Background Map section header — the toggle flips
`routeMapBackgroundStyle` between `.dark` (or the previously selected
style) and `.none`.

### Container Preset (legacy)

`OverlayRouteMapContainerPreset` is still exposed via
`ProjectDocument.setOverlayRouteMapContainerPreset` for one-click recipes
in templates and unit tests. It writes Shape / Edge Mode / Edge Softness /
Map Opacity / Shadow defaults onto the element as a single undo edit. The
Inspector no longer renders a dropdown for it because the per-field
controls below cover the same surface area without conflict.

| Preset id | Shape | Edge Mode | Edge Softness | Map Opacity | Shadow |
| --- | --- | --- | ---: | ---: | --- |
| `squareHardEdge` | rounded rectangle | hard | `0` | `0.72` | radius 14, opacity 0.35, offset (0, 6) |
| `circleHardEdge` | circle | hard | `0` | `0.72` | radius 16, opacity 0.38, offset (0, 6) |
| `squareGradientEdge` | rounded rectangle | gradient | `0.30` | `0.58` | off |
| `circleGradientEdge` | circle | gradient | `0.34` | `0.58` | off |

Defaults:

- New Route Map elements default to `squareHardEdge` shape, `solid` edge,
  `dark` map background, gradient route line.
- Picking a Container Preset writes one undo checkpoint.

## Layout Section

Implemented via the shared `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows` components. Controls:

- Position X / Y on one row, three-decimal precision.
- Scale slider, range `0.25...4`, quantized to `0.05`, formatted `1.00x`.
- Width slider, range `120...720` pt, quantized to 4 pt.
- Height slider, range `120...720` pt, quantized to 4 pt.
- Opacity slider, range `0...1`, formatted as percentage (Route Map–specific).

The Anchor grid has been removed. Position is set numerically only.

Model mapping:

- `OverlayElement.position.x`, `OverlayElement.position.y`.
- `OverlayElement.scale`.
- `OverlayStyle.backgroundOpacity` (re-used as overall container alpha).

## Container Section

Controls:

- Shape segmented: `Square` / `Circle` (`OverlayRouteMapShape`).
- Width slider (square only), range `120...720` pt, quantized to 4 pt.
- Height slider (square only), range `120...720` pt, quantized to 4 pt.
- Size slider (circle only), range `120...600` pt, quantized to 4 pt — drives
  both `routeMapWidth` and `routeMapHeight` symmetrically.
- Corner Radius slider (square only), range `0...80` pt, quantized to 2 pt.
  Display rule: show `Sharp` when `< 1`, otherwise `NN pt`. Default `12`.
  Maps to `OverlayStyle.routeMapCornerRadius`. The setter is
  `setOverlayRouteMapCornerRadius`.
- Edge Mode segmented: `Hard` / `Gradient` (`OverlayRouteMapEdgeFade`).
- Edge Softness slider, range `0...0.85`, quantized to `0.01`. Display rule:
  show `Solid` when `<= 0.001`, otherwise `NN%`. Disabled when Edge Mode is
  `Hard`. The setter is `setOverlayRouteMapEdgeSoftness`. When Corner Radius
  is set, the rounded corners are naturally included in the mask clip so the
  fade follows the rounded shape boundary.
- Border Enabled toggle (planned).
- Border Color swatches (planned).
- Border Width slider, range `0...4` (planned).

Rules:

- When Edge Mode is `gradient`, the alpha mask defined in `RouteMapMaskRenderer`
  draws a single radial vignette clipped to the container outline so the fade
  reaches the corners of a rectangle without a hard step. Three-stop gradient
  (`white → white → black` at locations `[0, 0.45, 1]`) keeps the inner
  region punchy while letting the outer ring fall off gradually.
- The mask renderer caps Edge Softness at `0.85` so the box never collapses
  to nothing.
- Switching Shape to `Circle` collapses Width and Height to the shorter edge
  so the editor handles stay in sync with the rendered diameter. Square
  preserves the previous Width / Height.
- The new `routeMapWidth` / `routeMapHeight` fields default to `320` / `240`
  (4:3) and are the ground truth for the rendered container size. The
  legacy `OverlayElement.scale` continues to scale on top.
- Border defaults to off when Edge Mode is `gradient` (the soft edge already
  reads as a vignette; a 1 px stroke would clash).

## Background Map Section

The section header carries a `Show Map` toggle accessory. The toggle is the
single source of truth for "is the map background drawn?" and flips
`routeMapBackgroundStyle` between `.none` (off) and the previously selected
style — defaulting to `.dark` if the previous value was already `.none`.
When off, every row in the section dims to 50% and remains disabled.

Controls (v1):

- Map Style dropdown: `dark`, `light`, `terrain`, `satellite`
  (`OverlayRouteMapBackgroundStyle.visibleCases`). The dropdown excludes
  `.none` because show/hide is handled by the toggle.
- Map Opacity slider, range `0...1`, default `0.72`. The slider modulates the
  alpha applied to the map snapshot in both preview and export. It does **not**
  affect the route line, markers, or legend.

Controls (v2, planned):

- Contrast slider, range `0.5...1.5`.
- Saturation slider, range `0.0...1.5`.
- Brightness slider, range `-0.5...0.5`.
- Blur slider, range `0...20` px.

Rules:

- Map background defaults are intentionally dim and low saturation. The route
  line should always read as the primary element.
- The Route Style preset never changes map visibility; only the Show Map
  toggle (and direct edits to `routeMapBackgroundStyle`) do.
- The map provider is recomputed by `OverlayRenderModel.routeMapLayout`
  from `routeMapBackgroundStyle != .none`, so callers no longer need to
  keep `routeMapProvider` in sync with the preset.

## Route Line Section

Controls (v1, implemented today):

- Color Mode segmented: `Solid` / `Gradient` (`OverlayRouteMapColorMode`).
- Solid Color swatches (when `solid`) — uses `OverlayStyle.foregroundColor`.
- Gradient Start / Mid / End swatches (when `gradient`).

Controls (v2, planned per spec):

- Gradient Metric dropdown: `pace`, `heartRate`, `power`, `elevation`.
- Width slider, range `1...24`.
- Opacity slider, range `0...1`.
- Dash toggle + dash pattern editor.
- Glow toggle + color + opacity + radius.
- Shadow toggle + opacity + radius.

Rules:

- Color modes are mutually exclusive; switching between them is reversible
  without losing the underlying gradient stops or solid color.
- Width defaults to `5` design units, scaled by overlay scale and project DPR.

## Markers Section

Controls:

- All Markers segmented: `Hidden` / `Dot` / `Pin` / `Flag`. Setting this
  writes both `routeMapStartMarkerStyle` and `routeMapEndMarkerStyle` for
  quick symmetric edits.
- Start Marker dropdown: same enum, drives `routeMapStartMarkerStyle` only.
- Finish Marker dropdown: same enum, drives `routeMapEndMarkerStyle` only.

Controls (v2, planned per spec):

- Per-marker color, size, border (color / width), icon name, label toggle and
  label text.

Rules:

- `Hidden` removes the marker from preview and export.
- Start defaults to green, Finish defaults to red.

## Status Bar Section

The Status Bar is a configurable data strip that can be placed at any edge of
the map container or overlaid inside it. It displays up to four live activity
metrics and is the primary way to show data alongside the route map.

The section header carries an `Enabled` toggle accessory. When off, body
controls fade to 50% and remain disabled; preview and export skip the bar.

### Data Model

`OverlayRouteMapStatsBarConfig` fields:

| Field | Type | Default | Range |
| --- | --- | --- | --- |
| `visible` | `Bool` | `false` | — |
| `placement` | `RouteMapStatsBarPlacement` | `.bottomAttached` | see below |
| `inside` | `Bool` | `false` | — |
| `layoutMode` | `RouteMapStatsBarLayoutMode` | `.equalColumns` | see below |
| `height` | `Double` | `64` | `32...160` pt |
| `width` | `Double` | `0` | `0...640` pt (`0` = Auto) |
| `offsetX` | `Double` | `0` | design units |
| `offsetY` | `Double` | `0` | design units |
| `itemSpacing` | `Double` | `0` | `0...32` pt |
| `backgroundOpacity` | `Double` | `0.88` | `0...1` |
| `dividerOpacity` | `Double` | `0.12` | `0...1` |
| `cornerRadius` | `Double` | `0` | `0...32` pt |
| `valueFontName` | `String` | `SF Pro Display` | font preset |
| `valueFontSize` | `Double` | `30` | `8...96` pt |
| `valueFontWeight` | `OverlayFontWeight` | `.semibold` | enum |
| `valueColor` | `OverlayColor` | `white` | swatch |
| `labelFontName` | `String` | `SF Pro Display` | font preset |
| `labelFontSize` | `Double` | `10` | `8...96` pt |
| `labelFontWeight` | `OverlayFontWeight` | `.medium` | enum |
| `labelColor` | `OverlayColor` | `white@58%` | swatch |
| `slots` | `[RouteMapStatsBarSlot]` | 4 slots | — |

Default slots:

| Slot | Metric | Enabled |
| --- | --- | --- |
| 1 | `distance` | on |
| 2 | `pace` | on |
| 3 | `elapsedTime` | on |
| 4 | `heartRate` | off |

### Placement (`RouteMapStatsBarPlacement`)

| Case | Behaviour |
| --- | --- |
| `bottomAttached` | Bar below map; total element height = map + bar |
| `topAttached` | Bar above map; total element height = map + bar |
| `leftAttached` | Bar left of map; total element width = bar + map |
| `rightAttached` | Bar right of map; total element width = map + bar |
| `insideBottom` | Bar overlaid at bottom inside map bounds; total size = map |
| `insideTop` | Bar overlaid at top inside map bounds; total size = map |

For `leftAttached` / `rightAttached`, the bar is rendered in vertical stack flow
(top-to-bottom) regardless of selected layout mode so metrics remain legible.
`itemSpacing` is applied as vertical row gap in this mode.

When `inside == true`, bar geometry is treated as an inset lane inside the map
container and route content reserves this lane as padding (the route line does
not draw underneath the bar).

### Layout Modes (`RouteMapStatsBarLayoutMode`)

| Case | Description |
| --- | --- |
| `equalColumns` | N equal-width columns. Value (top, large), unit (below), label (bottom, small uppercase) |
| `emphasis` | First slot 38% width at larger font; remaining slots share the rest |
| `grid2x2` | 2 × 2 grid (up to 4 slots). Falls back to `equalColumns` if < 3 slots |
| `stack` | Vertical list: label left, value+unit right per row. Ideal for left/right placements |
| `compact` | Dense horizontal row: value + inline unit, tiny label below |

Font-size ratios (relative to bar height H):

| Mode / slot | value | unit | label |
| --- | ---: | ---: | ---: |
| `equalColumns` | 0.38 H | 0.22 H | 0.20 H |
| `emphasis` first | 0.46 H | 0.26 H | 0.20 H |
| `emphasis` rest | 0.33 H | 0.19 H | 0.17 H |
| `grid2x2` (row H = H/2) | 0.40 rowH | 0.22 rowH | 0.18 rowH |
| `stack` | min(0.42 rowH, 0.28 H) | inline | min(0.28 rowH, 0.18 H) |
| `compact` | 0.34 H | 0.20 H (inline) | 0.16 H |

### Inspector Controls

Displayed in the Stats Bar section (in order):

1. **Placement** — dropdown (`RouteMapStatsBarPlacement`). Setter: `setOverlayRouteMapStatsBarPlacement`.
2. **Inside** — toggle. Setter: `setOverlayRouteMapStatsBarInside`.
3. **Layout** — dropdown (`RouteMapStatsBarLayoutMode`). Setter: `setOverlayRouteMapStatsBarLayoutMode`.
4. **Size** — slider `32...120` pt. Setter: `setOverlayRouteMapStatsBarHeight`.
5. **Width** — slider `0...640` (`Auto` when 0). Setter: `setOverlayRouteMapStatsBarWidth`.
6. **Offset** — X/Y fields. Setters: `setOverlayRouteMapStatsBarOffsetX` / `setOverlayRouteMapStatsBarOffsetY`.
7. **Item Gap** — slider `0...32`. Setter: `setOverlayRouteMapStatsBarItemSpacing`.
8. **Background** — opacity slider `0...1`. Setter: `setOverlayRouteMapStatsBarBackgroundOpacity`.
9. **Dividers** — opacity slider `0...1`; display `Off` below 0.005. Setter: `setOverlayRouteMapStatsBarDividerOpacity`.
10. **Radius** — corner radius `0...32` pt. Setter: `setOverlayRouteMapStatsBarCornerRadius`.
11. **Value Typography** — Font, Size, Weight, Color.
12. **Label Typography** — Font, Size, Weight, Color.
13. **Slot 1–4** — metric dropdown + visibility toggle per slot.

All controls disable and dim to 50% when the section is toggled off.

### Rendering

**Export (`SwiftUIOverlayVideoExporter`)**:
- MapKit backgrounds are preloaded before MOV/PNG rasterization from the same
  `MapSnapshotRequest` inputs used by preview, then injected into
  `OverlaySharedRouteMapView` as static `NSImage` render assets. Failed or
  unavailable snapshots fall back to the local grid background.
- Route Map and Distance Timeline now call the same shared Stats Bar drawing path (`drawSharedStatsBar`) based on the Distance Timeline visual logic.
- Background, divider, spacing, stacked-vs-horizontal flow, value text, and label text are rendered by the same function for both overlays.

Inside-mode additions:
- Route content rect reserves bar lane as padding (bar does not cover route polyline).
- Bar background is clipped by container shape; inside bars should visually merge
  with the container bottom/top radius (bar radius treated as off in inside mode).

**Preview (`PreviewCanvasView`)**:
- `placementContainer` is a `@ViewBuilder` that emits the correct outer
  `VStack`/`HStack`/`ZStack.overlay` depending on `statsBar.placement`.
- Route Map and Distance Timeline both render through `SharedStatsBarContentView`
  (single SwiftUI Stats Bar renderer).
- Shared renderer uses Stats Bar-owned Value/Label typography and colors directly (no fallback to outer accent/foreground color).

- Values use the same formatters as Numeric Overlay. Pace uses `M'SS" /km`
  or selected unit system; elapsed time in `hh:mm:ss` mode is always rendered
  as zero-padded `HH:MM:SS`.
- Missing data renders `—`, not `0`, unless the metric naturally starts at zero
  such as elapsed time.
- Slot order is user-controlled and should be drag-reorderable in Phase F.

### Legacy Legend Compatibility

Existing `routeMapLegendVisible` / `routeMapLegendMode` fields are treated as
legacy migration inputs only. On decode, map old `routeMapLegendVisible` to
`routeMapStatusBarVisible`. Do not expose the old fixed pace color bar in the
Inspector. If an older document used `gradientBand`, migrate to a Status Bar
with route metrics and keep route gradient controls in the Route Line section.

## Effects Section

Controls (v1, implemented today):

- Shadow Opacity slider, range `0...1`, formatted as percentage.
- Shadow Radius slider, range `0...24`.
- Background slider — drives container fill alpha
  (`OverlayStyle.backgroundOpacity`), used by gradient edges to keep a soft
  fill.

Controls (v2, planned per spec):

- Shadow Color, Shadow Offset X / Y.
- Glow toggle, color, opacity, radius.
- Blend Mode dropdown.

## Footer

Sticky footer:

- Secondary `Reset` button — calls `project.resetOverlayStyle(elementID)`.
- Primary `Done` button — clears overlay selection.

## Density And Layout Tokens

Re-uses the shared `NumericTokens` from
`Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift` so the
editing surface visually matches the other dense overlay inspectors:

| Token | Value |
| --- | ---: |
| `numeric.sectionHeaderHeight` | 30 |
| `numeric.rowHeight` | 34 |
| `numeric.anchorGridRowHeight` | 64 (min-height for anchor grid rows) |
| `numeric.rowGap` | 6 |
| `numeric.sectionGap` | 8 |
| `numeric.labelColumnWidth` | 88 |
| `numeric.controlHeight` | 26 |
| `numeric.iconButtonSize` | 28 |
| `numeric.swatchSize` | 20 |
| `numeric.panelPaddingX` | 12 |
| `numeric.panelPaddingY` | 8 |
| `numeric.controlRadius` | 5 |

Inspector width:

- Default: 460 px. Minimum: 460 px.
- Route Map detail must remain usable at 460 px without horizontal clipping.

## Model Gaps And Phases

Currently model-backed (post 2026-04-27 Phase E.1):

- `routeMapPreset` (route line aesthetic only — no longer encodes "show map").
- `routeMapShape`, `routeMapEdgeFade`, `routeMapFadeAmount`.
- `routeMapWidth`, `routeMapHeight` — independent container dimensions, used
  by both shapes (circle takes the shorter edge as the diameter).
- `routeMapColorMode`, `routeMapGradientStart/Middle/End`,
  `OverlayStyle.foregroundColor` (solid route color).
- `routeMapStartMarkerStyle`, `routeMapEndMarkerStyle`,
  `routeMapMarkerStyle` (legacy / quick set).
- `routeMapBackgroundStyle` — single source of truth for map visibility.
  `routeMapProvider` is now derived in the layout step.
- `routeMapStatsBar.visible`, `routeMapStatsBar.placement`, `routeMapStatsBar.inside`,
  `routeMapStatsBar.layoutMode`, `routeMapStatsBar.height`, `routeMapStatsBar.width`,
  `routeMapStatsBar.offsetX`, `routeMapStatsBar.offsetY`, `routeMapStatsBar.itemSpacing`,
  `routeMapStatsBar.backgroundOpacity`, `routeMapStatsBar.dividerOpacity`,
  `routeMapStatsBar.cornerRadius`, `routeMapStatsBar.valueFontName`, `routeMapStatsBar.valueFontSize`,
  `routeMapStatsBar.valueFontWeight`, `routeMapStatsBar.valueColor`,
  `routeMapStatsBar.labelFontName`, `routeMapStatsBar.labelFontSize`,
  `routeMapStatsBar.labelFontWeight`, `routeMapStatsBar.labelColor`,
  `routeMapStatsBar.slots`.
- `routeMapLegendVisible`, `routeMapLegendMode` are legacy migration fields only.
- `OverlayElement.position`, `OverlayElement.scale`,
  `OverlayStyle.rotationDegrees`.
- `OverlayStyle.backgroundOpacity` (container fill alpha).
- `OverlayStyle.shadowOpacity`, `OverlayStyle.shadowRadius`.
- `routeMapContainerPreset` — used by templates / setters as a one-click
  bundle. The Inspector no longer renders a dropdown for it.
- `routeMapMapOpacity` — explicit map snapshot alpha.

Planned (Phase F, not yet implemented):

- Border (`enabled` / `color` / `opacity` / `width`).
- Glow (`enabled` / `color` / `opacity` / `radius`).
- Map adjustments (`contrast` / `saturation` / `brightness` / `blur`).
- Route line (`width` / `opacity` / `dash` / `glow` / `gradientMetric`).
- Per-marker color / size / border / label.
- Status Bar style preset enum.
- Status Bar slot label override editing in inspector.
- Glow / blend mode container effects.

When a Phase F field lands, this doc and `route-map-overlay-ui.spec.json`
move the corresponding entry from `modelGaps` into `modelBackedToday`.

## Acceptance Criteria

- All four container variants (Square Hard / Circle Hard / Square Gradient /
  Circle Gradient) remain reproducible via
  `setOverlayRouteMapContainerPreset` (used by templates and tests), and via
  the per-field controls in the Inspector.
- Map Opacity is a model-backed slider; the value is honored by both preview
  and exporter.
- Show Map is a header toggle in the Background Map section. Toggling it off
  sets `routeMapBackgroundStyle = .none`; toggling it back on restores
  `.dark` (or the previously selected style).
- Switching Route Style preset never toggles the map background visibility.
- Container Width and Height are independent for square containers. Circle
  containers expose a single Size slider that drives both axes.
- The whole projected route is visible inside the map container — no
  polyline segment clips outside `contentRect`. Verified by
  `routeMapLayoutProjectsGpsRouteAndCurrentPoint`.
- Edge Softness has visual effect from `0%` to `85%`, transitions from a
  hard edge through a vignette to a soft fade-out.
- Route Line, Markers, Status Bar, and Effects controls live in their own
  collapsible sections.
- Inspector width 460 px renders without text clipping.
- Disabling Status Bar hides every Status Bar control row beneath it and removes the data strip from preview/export.
- Status Bar supports at least 1–4 configurable metric slots, with default Distance / Pace / Time enabled and Heart Rate disabled.
- Status Bar does not render any pace color bar; route gradient remains controlled only by Route Line.
- The detail view shares `NumericTokens` from
  `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`;
  row height, row gap, control height, control radius, and label column width
  are visually identical to a Numeric Overlay panel side-by-side.
