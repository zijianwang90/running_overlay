# Elevation Chart Overlay

Last updated: 2026-11-09

> **Status: bundled component.** The native `.elevationChart` element and
> `ElevationChartOverlayDetailView` were removed without migration (ADR 0015).
> The module is now the bundled `studio.elevation-chart` component, whose
> `elevationChart` host node exposes the same renderer settings through the
> generated component Inspector; older elements of the native type are dropped
> on load. This document remains the rendering and design reference for that
> node.
>
> **Stats Bar is no longer attached (2026-11-09).** The chart draws only its
> own profile, marker and labels. A metric strip is now the standalone
> `studio.stats-bar` component, placed freely by the user; the `statsBar`
> field was removed from the component node format and attached bars are
> always hidden by the resolver.

The Elevation Chart overlay renders an activity elevation profile. It is separate from Distance Timeline and Route Map, but intentionally reuses their shared inspector and stats bar infrastructure where it makes sense.

## Current Implementation

- Overlay type: `OverlayElementType.elevationChart` (render seed; not creatable)
- Style model: `ElevationChartStyle` on `OverlayStyle.elevationChart`
- Inspector: generated `OverlayComponentDetailView` over the component's `elevationChart` node parameters
- Layout controls: shared `CollapsibleLayoutInspectorSection` and `OverlayLayoutInspectorRows`
- Stats bar controls: shared `CollapsibleStatsBarInspectorSection` and `OverlayStatsBarInspectorRows`
- Preview path: `PreviewCanvasView.ElevationChartOverlayView`
- Export path: `SwiftUIOverlayVideoExporter` via the shared `OverlaySharedElevationChartView` (same SwiftUI component as preview). The legacy `OverlayFrameRenderer.renderElevationChart` CoreGraphics path is retained only for `OverlayFrameRenderer` PNG/test rendering and is not used by production MOV export.
- Export static-fill cache: in the per-overlay export path, full-profile charts bake their static geometry once and re-render only the current-position marker per frame via `ElevationChartLayerVisibility` (base / line / dual-area lower-fill / marker layers). See `docs/development/export.md` for eligibility, the dual-area crop, and parity verification. The shared `OverlaySharedElevationChartView` accepts an optional `visibility` that defaults to the full preview appearance, so preview and normal export are unchanged.
- Render layout: `OverlayRenderModel.elevationChartLayout`
- Fill gradient inspector: `From` and `To` swatch strips are stacked vertically so the color editor stays within the inspector width.
- Inspector chrome: collapsed custom section headers use the single-line separator pattern, and Reset Style lives in the shared detail header's action menu (no footer).
- Smoothing: the chart renderer filters quantized elevation samples and uses curved line/area paths in both Full and Progress modes. The `Smoothness` slider controls filter strength from 0 to 100 percent. At 100 percent, the overlay uses a wide display-only Gaussian filter to prioritize a visually continuous curve over passing through every integer-meter sample. Preview and export share the same smoothed sample set before their native path drawing.
- Bottom-strip sizing: layout width supports `220...1200` design points and height supports `72...320`. Compact heights reduce vertical chart padding proportionally instead of forcing the earlier 52-point chart minimum, allowing a wide, low elevation profile to sit along the bottom of a 1280-point reference canvas without covering as much footage.
- Dimension decoding clamps imported or legacy values to the supported range so malformed templates cannot create an unusable chart frame.
- Component content bounds are exactly `chartWidth × chartHeight`; the retired attached Stats Bar no longer reserves extra height below the chart, so the visible card is the element's selectable and draggable bounds. Editing either dimension resizes those bounds.
- Axis & Labels: `Grid`, `Axis Line`, and `Labels` toggles control the horizontal grid, left Y-axis stroke, and min/max/unit labels. Preview and export share the same axis-line rendering. The current-marker playhead guide is suppressed on the chart's left edge so it does not duplicate the optional Y-axis line.
- Markers: `Current`, `Playhead Line`, `Marker Color`, `Size`, and `Value Label` control the current-position marker. `Size` scales the marker from the shared render model so preview and SwiftUI export stay proportional at different canvas resolutions. `Playhead Line` toggles the vertical dashed guide that tracks playback progress.

## Presets

The module exposes a compact set of premium visual presets while keeping the chart model simple:

- `Premium Gradient` - default smooth area chart with a white line, soft green-to-blue fill, compact marker tooltip, axis labels, and stats bar.
- `Dark Terrain` - enables `dualAreaEnabled` and uses a two-tone terrain fill split around current progress.
- `Tech Glow` - adds a cyan line/fill treatment, subtle grid, and line glow for HUD-style videos.
- `Minimal White` - line-only treatment with labels and stats hidden for low-clutter footage.
- `Big Elevation` - emphasizes a large current-elevation metric while keeping the chart visible.

The presets initialize values only; all line, fill, marker, axis, background, and effects fields remain editable. The overlay still avoids separate bar, dot, step, and segmented chart modes.

Big Elevation uses dedicated `bigNumberFontName`, `bigNumberFontWeight`, and `bigNumberFontSize` fields so its primary metric typography can differ from the chart's general overlay font.

Elevation Chart does not define an independent card-background system. It uses the shared overlay Background, Border, and Effects modules so it stays consistent with Distance Timeline, Route Map, and the rest of the overlay editor.

## Stats Bar

Stats Bar is not part of Elevation Chart. It is the standalone
`studio.stats-bar` component: up to four host-formatted metric slots, its own
background, dividers, corner radius and typography. Users place and scale it
independently of any chart, so the two no longer share a container, spacing or
geometry contract.

## First-Version Limits

- No bar, dot, step, or segmented chart modes.
- Dual Area is visually two-tone; climb/descent segment coloring is deferred.
- Remaining climb is not yet exposed as a stats metric.
