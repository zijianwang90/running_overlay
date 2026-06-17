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
- `Markers`: current marker, marker value, and threshold marker.
- `Effects`: shared shadow controls for the full overlay group. Shared glow and fade-out rows are hidden because this overlay has no outer container surface for those effects.

The overlay does not expose custom zone colors in v1. Colors remain shared with Project Settings, HR Zone numeric text, and Interval HUD Bar zone bars.

## Rendering

Preview and export use `OverlayRenderModel.zoneEdgeBarLayout(for:in:)` and `OverlaySharedZoneEdgeBarView`. The legacy PNG renderer also draws the module directly for calibration/export smoke coverage.

The render rect includes marker space so edge and free placements do not clip the current or threshold markers.

## Out Of Scope For V1

- Custom per-overlay zone palettes.
- Multiple threshold markers.
- Target workout zones from structured workouts.
- Animated marker transitions.
