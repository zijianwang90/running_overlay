# Distance Timeline Overlay

Last updated: 2026-04-28

## Purpose

Distance Timeline Overlay is a compact visual progress component for showing activity distance or progress over a video. It starts from the existing simple `5.94 / 18.44 km` progress bar and expands it into a styleable module with presets, optional media slots, route/elevation variants, axis labels, a stats bar, border controls, and fade behavior.

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
- Toggle the primary Value on/off, switch metric/imperial units, and append up to four metric-driven custom values inline after the main value with separate group gap, item gap, size, color, and opacity.
- Move progress percentage and other metrics into a dedicated Stats Bar that can be placed top/bottom/left/right.
- Configure axis labels below the timeline as start/finish text or distance endpoints, plus optional intermediate distance points.

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
   - label
   - progress track
   - axis labels and distance points
   - stats bar
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
- Value
- Label
- Layout
- Progress
- Axis Labels
- Stats Bar
- Media Slot
- Route / Elevation
- Background & Border
- Effects

Only show sections that apply to the current preset.

## Phasing

Phase 1:

- Presets: minimal, dense, sport, lowerThird.
- Static media slot.
- Background and border controls.

Phase 2:

- Presets: splits, glass, neon.
- Ticks, marker, solid dense/splits progress, glow, fade masks.

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
- Preview and export share `OverlayDistanceTimelineRenderLayout`, including value text, progress/stat text, content rect, track rect, optional media slot rect, progress, axis label strings, optional `markerDistanceText`, and elevation samples.
- Value has its own typography controls, enabled/disabled state, a Total Distance toggle for switching between `current / total unit` and `current unit`, metric/imperial unit system, adjustable Progress Gap to the track, and a Custom Values master toggle. Progress Gap moves the progress track away from the Value row without moving the Value row itself. When Custom Values is enabled, all four Custom 1-4 rows appear as metric pickers and render inline after the main value with independent group gap, item gap, size, color, and opacity. Group gap moves the entire custom group without compressing custom text or reducing item gap.
- Label has been split into its own Inspector section following the Numeric overlay pattern, with independent font, size, weight, color, and Label-to-Value gap controls.
- Percent is no longer an inline Content option. Progress percentage is available through the dedicated Stats Bar, which supports up to four metric slots, top/bottom/left/right placement, Inside mode, width override, X/Y offset, and item gap.
- Stats Bar Value and Label typography is now fully configurable per bar (font, size, weight, color), and rendered from Stats Bar-owned fields rather than outer accent color.
- Stats Bar inspector now uses the shared cross-overlay component pair: `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows`.
- The Enabled switch is placed in the Stats Bar section header (left of chevron); expanded rows do not include a separate Enabled row.
- Distance Timeline intentionally follows the same Stats Bar row set and icon as Route Map (the full shared set from the original Distance Timeline controls).
- Axis labels: **Start / Finish** and **More Points** are separate toggles; each has its own **Below / Above** placement and offset (`distancePointOffset` for start/finish, `midpointAxisLabelOffset` for midpoints). Mode switches start/finish copy vs distance numerals (origin `0 <unit>`); Density applies when More Points is on. **Axis** typography applies to axis text and to the optional **Marker Label** (current distance at the playhead). Preview and export align endpoint labels to the track leading and trailing edges and expand background/selection bounds for whichever bands are visible.
- Progress marker: **Marker Size** scales the marker shape; **Marker Label** shows current distance with its own placement and offset (`markerDistanceLabelPlacement`, `markerDistanceLabelOffset`).
- Distance Timeline background and border bounds expand to include Axis Labels. Stats Bars with Inside enabled are included in the same background/border bounds at their current side, size, and offset; attached outside bars keep a separate bar background.
- Stats Bars are positioned outside the complete Distance Timeline content bounds, including Axis and Marker labels. Inside controls background/border grouping only, so it never overlays progress or axis content.
- Custom Values and Stats Bar slot metric menus use the shared activity metric catalog plus the Stats Bar-only Progress item, so Distance Timeline receives new numeric activity metrics through the shared picker path.
- Tick density is configurable independently from preset, and left/right Stats Bar backgrounds expand enough to cover all vertical slots. Preview selection uses the same dynamic visual bounds as the background/border.
- Dense and Splits render progress as a solid fill; their technical appearance comes from tick marks and axis labels rather than dashed/segmented progress.
- The Glass preset keeps the named preset and border/fade defaults, but disables the fake glass background until a real blur/material implementation exists.
- Minimal, dense, sport, splits, glass, neon, lowerThird, and route presets render distinct visual treatments in both SwiftUI preview and PNG/MOV export.
- Sport and lowerThird support deterministic media slot modes: system icon, embedded static SVG, and embedded animated SVG.
- SVG import embeds the source text into the overlay style so templates persist the asset without relying on an external file path.
- Animated SVG is sampled deterministically from overlay elapsed time in both preview and export. The first renderer supports common SVG primitives (`rect`, `circle`, `line`, `polyline`, `polygon`, simple `path` commands) plus simple `animateTransform` rotate and opacity pulse timing.
- Background, border, corner radius, padding, track height, track opacity, ticks, current marker style/color, glow, fade amount, and route elevation profile controls are exposed through `DistanceTimelineOverlayDetailView`; shared Background padding expands the rendered background bounds in preview and export.
- The route preset renders a stylized route progress curve with optional elevation-profile underlay from FIT elevation samples.
- When FIT GPS samples are available, the route preset projects and renders the sampled route geometry with a current-position marker; when GPS is missing, it falls back to the stylized progress curve.
- The Inspector uses dense module-specific sections: Preset, Value, Label, Layout, Progress, Axis Labels, Stats Bar, Media Slot, Route / Elevation, Background & Border, and Effects. Irrelevant sections are hidden for presets that do not use them.

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
