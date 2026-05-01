# Elevation Chart Overlay

Last updated: 2026-05-01

The Elevation Chart overlay is a dedicated `.elevationChart` module for rendering an activity elevation profile. It is separate from Distance Timeline and Route Map, but intentionally reuses their shared inspector and stats bar infrastructure where it makes sense.

## Current Implementation

- Overlay type: `OverlayElementType.elevationChart`
- Style model: `ElevationChartStyle` on `OverlayStyle.elevationChart`
- Inspector: `Sources/RunningOverlay/UI/ElevationChartOverlayDetailView.swift`
- Layout controls: shared `CollapsibleLayoutInspectorSection` and `OverlayLayoutInspectorRows`
- Stats bar controls: shared `CollapsibleStatsBarInspectorSection` and `OverlayStatsBarInspectorRows`
- Preview path: `PreviewCanvasView.ElevationChartOverlayView`
- Export path: `OverlayFrameRenderer.renderElevationChart`
- Render layout: `OverlayRenderModel.elevationChartLayout`
- Fill gradient inspector: `From` and `To` swatch strips are stacked vertically so the color editor stays within the inspector width.

## Presets

The module exposes only structural presets:

- `Gradient Area` - default area chart with editable line, fill, marker, axis, background, and stats bar settings.
- `Dual Area` - enables `dualAreaEnabled` and uses a two-tone area treatment.
- `Big Numbers` - emphasizes a large elevation metric while keeping the chart visible.

Color-only variants should be created by editing line/fill/background colors rather than adding more presets.

## Stats Bar

Elevation Chart uses the shared stats bar inspector/configuration surface already used by Route Map and Distance Timeline. Slots support shared metrics such as distance, pace, elapsed time, heart rate, elevation, grade, cadence, power, calories, and progress.

## First-Version Limits

- No bar, dot, step, or segmented chart modes.
- Dual Area is visually two-tone; climb/descent segment coloring is deferred.
- Remaining climb is not yet exposed as a stats metric.
- Smoothing is stored in the model, but the first renderer still uses the sampled elevation polyline directly.
