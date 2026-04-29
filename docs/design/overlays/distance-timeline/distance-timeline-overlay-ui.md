# Distance Timeline Overlay UI Design Spec

Last updated: 2026-04-29 (fine-grained value, label, axis, and marker controls)

## Purpose

Distance Timeline Overlay is a compact progress overlay that communicates current distance or activity progress on top of video. It is not the bottom editor timeline and it is not a single numeric text overlay. It is a visual component that combines value text, progress geometry, optional media/illustration slots, route or elevation context, borders, fade, and background styling.

This spec guides `OverlayElementType.distanceTimeline` design and implementation.

## Design Reference

![Distance Timeline Overlay style board](./distance-timeline-overlay-styles.png)

The style board shows eight directions using the same sample value: `5.94 / 18.44 km`.

## Applies To

- `OverlayElementType.distanceTimeline`

Related but separate overlays:

- `elevationChart`: dedicated elevation chart overlay.
- `routeMap`: GPS map/route overlay.
- Numeric `distance`: single-value text overlay.

## Style Variants

The first implementation should support these presets as a stable enum. Implementations can ship a subset first, but the data model should avoid blocking the rest.

| Preset | Description | Best use |
| --- | --- | --- |
| `minimal` | Tight translucent dark widget, value text, slim progress bar. | Default, readable on most footage. |
| `dense` | DaVinci-like compact technical panel with ticks and a solid progress fill. | Data-heavy videos and editor-style overlays. |
| `sport` | Sport-watch style, bold value, accent bar, optional media icon/animation on the left. | Fitness-forward content. |
| `splits` | Kilometer tick marks, current-position marker, and configurable axis labels below the line. | Race recap and pacing videos. |
| `glass` | Glass preset is retained as a named direction, but the fake glass background is disabled until a real blur/material implementation is available. | Scenic footage where overlay should feel embedded. |
| `neon` | Cyan/glow progress line and pulse marker. | Night/tech/futuristic edits. |
| `lowerThird` | Broadcast lower-third with left media slot, label, value, stats bar, and line under text. | More editorial videos. |
| `route` | Route/path-like progress line with start/finish dots and optional elevation underlay. | Route recap or terrain storytelling. |

## Core Content

Every preset must support:

- Current distance.
- Total distance.
- Progress fraction.
- Formatted value text, e.g. `5.94 / 18.44 km`.

Optional content:

- Label, e.g. `Distance`.
- Up to four custom metric values appended to the Value area. Each slot chooses a metric such as pace, heart rate, or power; custom value typography is controlled separately from the primary value.
- Axis labels below the timeline: start/finish text or start/end distance values.
- Additional distance point labels below the axis with configurable density.
- Stats Bar values, including progress percentage, placed top/bottom/left/right with a separate Inside toggle.
- Current-position marker.
- Left media slot.
- Elevation/route underlay.

## Custom Media Slot

`sport` and `lowerThird` should support a customizable left media slot.

Supported slot modes:

- `none`
- `systemIcon`
- `staticSVG`
- `animatedSVG`
- `image`
- `videoLoop` (future)

Use cases:

- Runner icon.
- Shoe icon.
- Race logo.
- Animated SVG pulse/runner.
- Sponsor or event mark.

Rules:

- The slot must be optional.
- Slot size should be fixed per preset so text alignment does not jump.
- Animated SVG must be previewable in app and exportable deterministically.
- If animated SVG export is not implemented, allow static SVG first and render animated assets as disabled/future in Inspector.
- Slot media should be project-local or embedded in the project package when project packaging exists.

Recommended controls:

- `Media Slot` toggle.
- `Source Type` menu.
- `Asset` picker/import.
- `Size` slider.
- `Tint` mode: original / text color / accent color.
- `Animation Speed` for animated SVG only.
- `Loop` toggle for animated assets.

## Route And Elevation Customization

The `route` preset can display a route-like progress line and/or a compact elevation profile under the line.

Route options:

- Path mode: straight / stepped / curved / sampled route.
- Start dot.
- Finish dot.
- Current marker.
- Marker size.
- Line width.
- Line cap: round / square.
- Progress color mode: solid / gradient.

Elevation options:

- Show elevation profile.
- Profile source: FIT elevation samples.
- Profile line color.
- Profile fill/shadow under the line.
- Fill opacity.
- Shadow blur.
- Shadow offset.
- Clip profile to progress or show full route profile.

Elevation under-line shadow:

- Enabled by default for `route` only when elevation profile is visible.
- Keep it subtle so it reads as depth/terrain, not a heavy chart area.
- Suggested default: fill opacity `0.18`, shadow opacity `0.25`, blur `6`.

## Border, Edge, And Fade

All presets should support edge treatment, with sensible defaults per preset.

Controls:

- `Border` toggle.
- Border color.
- Border opacity.
- Border width.
- Corner radius.
- `Fade Out` toggle.
- Fade edge: left / right / both / vertical / all.
- Fade amount.

Fade Out behavior:

- Fades the overlay container or selected visual layer into the underlying video.
- Useful for `glass`, `route`, and lower-third designs.
- Should not make text unreadable. Text fade should be separate from background/track fade where possible.

Suggested fade implementation:

- Apply alpha mask to background/track layer.
- Keep primary value text at full opacity by default.
- Allow `Fade Text` only as an advanced option.

## Background

Controls:

- Background enabled.
- Background color.
- Background opacity.
- Blur/material style, if supported.
- Corner radius.

Preset defaults:

- `minimal`: enabled, black 70%.
- `dense`: enabled, panel background 80%.
- `sport`: enabled, black 76%.
- `splits`: enabled, black 65%.
- `glass`: background disabled until real blur/material support exists; keep subtle border/fade treatment only.
- `neon`: enabled, black 60%, glow on progress.
- `lowerThird`: optional, flatter and wider.
- `route`: optional, depends on line/profile contrast.

Background bounds:

- The background and border are dynamic visual bounds, not only the base track/value rect.
- They must include Axis Labels and intermediate distance points at the current Point Gap.
- When the Stats Bar Inside toggle is on, they must include the Stats Bar at its current side, width, height, and offset, so moving the bar also moves/expands the background.
- Attached outside Stats Bars keep their own bar background and do not expand the main component background.

## Progress Track

Controls:

- Track style: solid / ticks / line / route path / elevation.
- Track height.
- Track color.
- Track opacity.
- Fill color.
- Fill opacity.
- Fill gradient.
- Current marker toggle.
- Current marker shape: dot / pill / triangle / pulse.
- Tick marks toggle.
- Tick density.
- Tick interval: auto / 1 km / 5 km / lap.

Dense and Splits progress must render as a continuous solid fill. Their technical/tick look comes from tick marks and labels, not from dashed or segmented progress blocks.

## Value

Controls:

- Value toggle.
- Unit system: Metric / Imperial.
- Font family, primary value size, weight, and text color.
- Progress Gap controls the vertical distance between the Value block and the progress track.
- Custom Values master toggle.
- When Custom Values is enabled, show all four Custom 1-4 rows using the same slot-row pattern as Stats Bar slots: row title on the left, metric picker and visible toggle on the right.
- Custom Values render inline after the primary Value text on the same baseline.
- Group Gap controls the distance between the primary Value and the whole Custom Values group.
- Item Gap controls spacing between individual Custom 1-4 values.
- Group Gap must move the whole Custom Values group to the right without compressing Custom text or reducing Item Gap.
- Custom value font size, color, and opacity, independent from the primary Value settings.

When Value is disabled, the overlay can be used as a pure distance timeline with only axis/progress/labels/stats.

## Label

Label is its own section, matching the Numeric overlay pattern.

Controls:

- Show label toggle.
- Label text.
- Font family, size, weight, and color.
- Value Gap controls the vertical distance between the Label and the Value row.

## Axis Labels

Controls:

- Enabled toggle.
- Mode: `Start / Finish` or `Distance`.
- More distance points toggle.
- Distance point density.
- Point Gap controls the vertical distance from the progress axis for start/finish endpoint labels and intermediate distance points.
- Point Gap remains editable even when More Points is off because endpoint labels use it too.
- Font family, size, weight, and color apply to endpoint labels and intermediate distance point labels.

Start/finish text and distance labels should sit below the axis, not on top of or centered over the track.

## Progress Marker

Controls:

- Marker toggle.
- Marker style: dot, pill, or triangle. These are rendered as vector-native shapes in preview and export; SVG marker assets are not part of this control yet.
- Marker color, independent from progress fill color.

## Stats Bar

Stats Bar replaces the previous inline Percent option.

Controls:

- Enabled toggle.
- Placement: bottom, top, left, right.
- Inside toggle: places the selected side inside the component; supports top, bottom, left, and right.
- Layout: equal columns, emphasis, 2x2 grid, stack, compact.
- Width, height, item gap, offset X/Y, background opacity, divider opacity, corner radius.
- Up to four metric slots. Supported metrics mirror Route Map stats metrics and add progress percentage.

Stats Bar should behave like Route Map's status/stat bar: it is a separate block at the component edge. When Inside is off, Offset is distance from the whole component. When Inside is on, Offset is internal X/Y adjustment and must avoid covering the progress axis.
For left/right placements, the bar background must expand enough to cover all vertical slots and their labels.

## Inspector Sections

Use dense Inspector primitives from
`Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`:

1. `Preset`
2. `Layout` — shared `OverlayLayoutInspectorRows`: Position X/Y, Scale, Width, Height. No Anchor, no Padding.
3. `Value`
4. `Label`
5. `Progress`
6. `Axis Labels`
7. `Stats Bar`
8. `Media Slot`
9. `Route / Elevation`
10. `Background & Border`
11. `Effects`

Section rules:

- Keep standard rows around 30-34 px high.
- Hide irrelevant sections for presets where they do not apply.
- Do not show animated SVG controls unless media slot mode is animated.
- Do not show elevation controls unless `route` or an elevation-capable preset is selected.

## Current Model Gaps

Current `distanceTimelineLayout` is mostly hard-coded:

- Width and height are fixed from scale.
- One progress bar style.
- One label format.
- No preset enum.
- No media slot.
- No elevation profile.
- No route path mode.
- No border toggle.
- No fade options.
- No background color/radius/padding fields specific to distance timeline.

Required model additions:

- `DistanceTimelinePreset`
- `DistanceTimelineStyle`
- `DistanceTimelineMediaSlot`
- `DistanceTimelineTrackStyle`
- `DistanceTimelineRouteStyle`
- `DistanceTimelineElevationStyle`
- `OverlayEdgeFadeStyle`
- Background/border/fade fields for this overlay.

## Implementation Phasing

Phase 1:

- Add preset enum and style config.
- Implement `minimal`, `dense`, `sport`, and `lowerThird`.
- Add border toggle and background controls.
- Add static media slot for `sport` and `lowerThird`.

Phase 2:

- Add `splits`, `glass`, and `neon`.
- Add tick marks, current marker, solid dense/splits progress, glow.
- Add fade out masks.

Phase 3:

- Add `route` preset.
- Add elevation profile underlay.
- Add elevation fill/shadow controls.
- Add sampled route/progress path if GPS is available.

Phase 4:

- Add animated SVG slot rendering.
- Verify animation timing in preview and export.
- Add asset packaging/persistence strategy.

## Acceptance Criteria

- The overlay can reproduce the existing compact dark progress bar as `minimal`.
- `sport` and `lowerThird` expose a customizable left media slot.
- `route` exposes route/elevation customization.
- Elevation profile can render a line plus optional shaded/blurred underlay.
- Border can be toggled independently from background.
- Fade Out can be enabled without fading primary text by default.
- Unsupported controls are hidden or disabled clearly until model/export support exists.
