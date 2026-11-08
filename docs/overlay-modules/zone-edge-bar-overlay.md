# Zone Edge Bar Overlay

Last updated: 2026-06-16

## Module Goal

Zone Edge Bar is a thin, independent physiology-zone overlay for showing the current heart-rate or pace zone without occupying the main video composition.

It reuses the visual language of the Interval HUD Bar zone bottom bar: segmented HR-zone palette, active-zone emphasis, current-value marker, and optional threshold `T` marker.

## Data Source

Zone Edge Bar reads the same global Project Settings physiology data as Interval HUD Bar:

- `HeartRateZonePreferences.currentSnapshot()`
- visible HR/pace zone ranges
- `Threshold HR`
- `Threshold Pace`
- current `ActivityTimeline.heartRate(at:)`
- current `ActivityTimeline.pace(at:)`

Pace values of `0` or invalid values do not render a current-value marker. Threshold pace remains visible when configured and inside a pace zone.

## Placement

The overlay supports two placement modes:

- `Edge`: automatically pins to one video edge and centers along the opposite axis.
- `Free`: uses the shared overlay position controls with editable length, thickness, and orientation.

Edge marker direction points inward:

- Top: marker below the bar.
- Bottom: marker above the bar.
- Left: marker to the right.
- Right: marker to the left.

Horizontal bars render Z1 → ZN from left to right. Vertical bars render Z1 at the bottom and ZN at the top.

## Inspector Surface

Inspector sections:

- `Layout`: shared position, scale, opacity, visibility, and lock controls.
- `Zone Bar`: metric, placement, edge/orientation, length, thickness, edge position, active-zone width/height, zone gap, inactive opacity, corner radius, bar-local border, and bar-local glow.
- `Markers`: current marker, marker value, arrow size, threshold marker, and threshold size.
- `Effects`: shared shadow controls for the full overlay group. Shared glow and fade-out rows are hidden because this overlay has no outer container surface for those effects.

The overlay does not expose custom zone colors in v1. Colors remain shared with Project Settings, HR Zone numeric text, and Interval HUD Bar zone bars.

## Rendering

Preview and export use `OverlayRenderModel.zoneEdgeBarLayout(for:in:)` and `OverlaySharedZoneEdgeBarView`. The legacy PNG renderer also draws the module directly for calibration/export smoke coverage.

The render rect includes marker space so edge and free placements do not clip the current or threshold markers. Arrow and threshold sizes scale from the bar thickness by default; `markerSizeScale` and `thresholdMarkerSizeScale` multiply those sizes and the reserved marker padding together, and the SwiftUI, Skia, and legacy renderers consume the same fields.

## Declarative Component Port

`studio.zone-edge-bar` composes the same bar from `zone.heartRate*` and
`zone.pace*` signals and the generic `segmentedBar` node. It ships 24 generated
Inspector parameters covering metric, orientation, marker side, geometry,
active-zone emphasis, border, glow, markers and marker typography.

The port extended `segmentedBar` with the primitives this module needs:

- `orientation`: vertical bars run Z1 from the bottom edge upward.
- Marker `layout`: `inline` keeps the interval HUD treatment; `outside` draws
  the zone edge callout and threshold tick wholly outside the bar.
- Marker `position`: four-way `above`/`below`/`leading`/`trailing`.
- Marker `scale`: the native `markerSizeScale` and
  `thresholdMarkerSizeScale` multipliers, clamped to 0.1...4.

Native parity is exact for HR and pace metrics, horizontal `above` and free
placements, top and bottom edge appearance, vertical free and left/right edge
appearance, widened/thickened active zones, border on/off, glow, marker without
its value pill, marker and threshold size scales, inactive opacity, zero corner
radius and element scale 1.5.

Rules that make the port pixel-faithful:

- Marker padding and the minimum arrow/text sizes are raw pixels in the native
  renderer, so they are divided by `signal("host.scale")` in the definition.
- The current-marker anchor uses the native asymmetry: horizontal callouts are
  offset by their height plus the value text, vertical callouts by a fixed
  84px pill allowance.
- Edge placement cannot be reproduced by a component today: the host pins
  `Edge` bars to the canvas edge and centers them, while a component is
  positioned by the author. The port reproduces the pixels for a given rect and
  leaves auto-pinning as future host work; the Inspector exposes orientation
  and marker side instead of placement.
- The component's content bounds reserve 64 design units of ink margin so the
  outside callouts are not clipped; the authored position is that margin
  outside the bar rect.

The native renderer remains the parity oracle and is not removed.

## Out Of Scope For V1

- Custom per-overlay zone palettes.
- Multiple threshold markers.
- Target workout zones from structured workouts.
- Animated marker transitions.
