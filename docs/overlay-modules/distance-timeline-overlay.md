# Distance Timeline Overlay

Last updated: 2026-04-28

## Purpose

Distance Timeline Overlay is a compact visual progress component for showing activity distance or progress over a video. It starts from the existing simple `5.94 / 18.44 km` progress bar and expands it into a styleable module with presets, optional media slots, route/elevation variants, border controls, and fade behavior.

Design spec:

- [Distance Timeline Overlay UI](../design/overlays/distance-timeline/distance-timeline-overlay-ui.md)
- [Structured spec](../design/overlays/distance-timeline/distance-timeline-overlay-ui.spec.json)
- [Style board](../design/overlays/distance-timeline/distance-timeline-overlay-styles.png)

## User Goals

- Show current distance vs total distance in a compact overlay.
- Choose a style that matches the video: minimal, technical, sport-watch, lower-third, glass, neon, split markers, or route/elevation.
- Add a custom left-side media slot for sport/lower-third variants.
- Use route/elevation visuals when terrain context matters.
- Control whether background, border, fade, and shadows are visible.

## Data Inputs

Required:

- Activity distance at current elapsed time.
- Total activity distance.
- Activity progress fraction.

Optional:

- FIT elevation samples.
- GPS route samples.
- Lap/split distances.
- User-provided static or animated media assets.

## Rendering Model

Recommended layout pipeline:

1. Resolve `DistanceTimelineStyle` from the selected preset and custom overrides.
2. Sample activity distance and progress fraction.
3. Compute component rect from overlay position, scale, width, and height.
4. Layout content regions:
   - media slot
   - value text
   - label/percent
   - progress track
   - route/elevation area when enabled
5. Draw background and optional border.
6. Draw progress track/path/profile.
7. Draw media slot.
8. Draw value text and labels.
9. Apply fade masks only to intended layers.
10. Apply shadow/glow effects.

## Custom Media Slot

`sport` and `lowerThird` variants support custom left-side media:

- system icon
- static SVG
- animated SVG
- image
- video loop later

Implementation note:

- Static SVG can be implemented first.
- Animated SVG must be verified for preview and export. Do not enable animated controls until deterministic export rendering exists.

## Route And Elevation Variant

The `route` variant can render:

- start/finish dots
- current marker
- route-style progress line
- optional elevation profile below or behind the line
- shaded/blurred area under the elevation line

Elevation profile shadow should be subtle and configurable.

## Inspector

Use dense Inspector sections:

- Preset
- Content
- Layout
- Progress
- Media Slot
- Route / Elevation
- Background & Border
- Typography
- Effects

Only show sections that apply to the current preset.

## Phasing

Phase 1:

- Presets: minimal, dense, sport, lowerThird.
- Static media slot.
- Background and border controls.

Phase 2:

- Presets: splits, glass, neon.
- Ticks, marker, glow, fade masks.

Phase 3:

- Route preset.
- Elevation profile with fill/shadow.
- GPS sampled path where available.

Phase 4:

- Animated SVG support and export verification.
- Asset packaging/persistence.

## Current Implementation

Implemented on 2026-04-28:

- `OverlayElementType.distanceTimeline` now uses a dedicated `DistanceTimelineStyle` block on `OverlayStyle`.
- Preset enum is in place for all eight design directions: minimal, dense, sport, splits, glass, neon, lowerThird, and route.
- Preview and export share `OverlayDistanceTimelineRenderLayout`, including value text, percent text, content rect, track rect, optional media slot rect, progress, and elevation samples.
- Minimal, dense, sport, splits, glass, neon, lowerThird, and route presets render distinct visual treatments in both SwiftUI preview and PNG/MOV export.
- Sport and lowerThird support deterministic media slot modes: system icon, embedded static SVG, and embedded animated SVG.
- SVG import embeds the source text into the overlay style so templates persist the asset without relying on an external file path.
- Animated SVG is sampled deterministically from overlay elapsed time in both preview and export. The first renderer supports common SVG primitives (`rect`, `circle`, `line`, `polyline`, `polygon`, simple `path` commands) plus simple `animateTransform` rotate and opacity pulse timing.
- Background, border, corner radius, padding, track height, track opacity, ticks, current marker, glow, fade amount, and route elevation profile controls are exposed through `DistanceTimelineOverlayDetailView`.
- The route preset renders a stylized route progress curve with optional elevation-profile underlay from FIT elevation samples.
- When FIT GPS samples are available, the route preset projects and renders the sampled route geometry with a current-position marker; when GPS is missing, it falls back to the stylized progress curve.
- The Inspector uses dense module-specific sections: Preset, Content, Layout, Progress, Media Slot, Route / Elevation, Background & Border, Typography, and Effects. Irrelevant sections are hidden for presets that do not use them.

Remaining:

- Full SVG path coverage, gradients, filters, masks, and CSS animation support.
- Raster image import and persistence.
- Video-loop support with deterministic export timing.
- Fine-grained fade masks that affect background/track layers without lowering primary text opacity.

## Open Questions

- Should Distance Timeline support elapsed-time progress as an alternate mode?
- Should split tick marks derive from laps, fixed kilometers, or both?
- Should custom SVG assets be embedded in project files or referenced externally?
- Should animated SVG timing follow project time or loop local overlay time?
