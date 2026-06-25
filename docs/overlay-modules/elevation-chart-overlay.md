# Elevation Chart Overlay

Last updated: 2026-06-25

The Elevation Chart overlay is a dedicated `.elevationChart` module for rendering an activity elevation profile. It is separate from Distance Timeline and Route Map, but intentionally reuses their shared inspector and stats bar infrastructure where it makes sense.

## Current Implementation

- Overlay type: `OverlayElementType.elevationChart`
- Style model: `ElevationChartStyle` on `OverlayStyle.elevationChart`
- Inspector: `Sources/RunningOverlay/UI/ElevationChartOverlayDetailView.swift`
- Layout controls: shared `CollapsibleLayoutInspectorSection` and `OverlayLayoutInspectorRows`
- Stats bar controls: shared `CollapsibleStatsBarInspectorSection` and `OverlayStatsBarInspectorRows`
- Preview path: `PreviewCanvasView.ElevationChartOverlayView`
- Export path: `SwiftUIOverlayVideoExporter` via the shared `OverlaySharedElevationChartView` (same SwiftUI component as preview). The legacy `OverlayFrameRenderer.renderElevationChart` CoreGraphics path is retained only for `OverlayFrameRenderer` PNG/test rendering and is not used by production MOV export.
- Render layout: `OverlayRenderModel.elevationChartLayout`
- Fill gradient inspector: `From` and `To` swatch strips are stacked vertically so the color editor stays within the inspector width.
- Inspector chrome: collapsed custom section headers use the single-line separator pattern, and the Reset / Done footer reuses the shared detail footer height and button layout.
- Smoothing: the chart renderer filters quantized elevation samples and uses curved line/area paths in both Full and Progress modes. The `Smoothness` slider controls filter strength from 0 to 100 percent. At 100 percent, the overlay uses a wide display-only Gaussian filter to prioritize a visually continuous curve over passing through every integer-meter sample. Preview and export share the same smoothed sample set before their native path drawing.
- Bottom-strip sizing: layout width supports `220...1200` design points and height supports `72...320`. Compact heights reduce vertical chart padding proportionally instead of forcing the earlier 52-point chart minimum, allowing a wide, low elevation profile to sit along the bottom of a 1280-point reference canvas without covering as much footage.
- Dimension decoding clamps imported or legacy values to the supported range so malformed templates cannot create an unusable chart frame.
- Axis & Labels: `Grid`, `Axis Line`, and `Labels` toggles control the horizontal grid, left Y-axis stroke, and min/max/unit labels. Preview and export share the same axis-line rendering. The current-marker playhead guide is suppressed on the chart's left edge so it does not duplicate the optional Y-axis line.
- Markers: `Current`, `Playhead Line`, `Marker Color`, and `Value Label` control the current-position marker. `Playhead Line` toggles the vertical dashed guide that tracks playback progress.

## Presets

The module exposes a compact set of premium visual presets while keeping the chart model simple:

- `Premium Gradient` - default smooth area chart with a white line, soft green-to-blue fill, compact marker tooltip, axis labels, and stats bar.
- `Dark Terrain` - enables `dualAreaEnabled` and uses a two-tone terrain fill split around current progress.
- `Tech Glow` - adds a cyan line/fill treatment, subtle grid, and line glow for HUD-style videos.
- `Minimal White` - line-only treatment with labels and stats hidden for low-clutter footage.
- `Big Elevation` - emphasizes a large current-elevation metric while keeping the chart visible.

The presets initialize values only; all line, fill, marker, axis, stats bar, background, and effects fields remain editable. The overlay still avoids separate bar, dot, step, and segmented chart modes.

Big Elevation uses dedicated `bigNumberFontName`, `bigNumberFontWeight`, and `bigNumberFontSize` fields so its primary metric typography can differ from the chart's general overlay font and stats bar typography.

Elevation Chart does not define an independent card-background system. It uses the shared overlay Background, Border, and Effects modules so it stays consistent with Distance Timeline, Route Map, and the rest of the overlay editor.

## Stats Bar

Elevation Chart uses the shared stats bar inspector/configuration surface already used by Route Map and Distance Timeline. Slots support shared metrics such as distance, pace, elapsed time, heart rate, elevation, grade, cadence, power, calories, and progress.

The shared Inside toggle is exposed for Elevation Chart. Outside mode renders the bar below the chart card so it is not covered by the card background. Inside mode renders the bar along the chart card's inner bottom edge and reserves chart clearance above it, so the bar does not cover the elevation line or filled area.

Stats bar geometry and typography are resolved once in `OverlayRenderModel.elevationChartLayout` as `OverlayElevationChartStatsBarLayout`, scaled from the shared 1280x720 reference like the rest of the chart. Preview (fitted canvas) and SwiftUI export (project resolution) consume the same scaled bar rect, font sizes, and item spacing, so the bar stays proportional to the chart card at every resolution. The inside-bar chart clearance reserve is computed in design-point space before the chart height is scaled, so it is not double-scaled.

## First-Version Limits

- No bar, dot, step, or segmented chart modes.
- Dual Area is visually two-tone; climb/descent segment coloring is deferred.
- Remaining climb is not yet exposed as a stats metric.
