# Zone Edge Bar Overlay UI Design Spec

Last updated: 2026-06-16

## Purpose

Zone Edge Bar is a thin HR/pace zone strip intended for video edges or unobtrusive free placement. It gives viewers a quick read of the runner's current intensity without competing with the main frame.

## Visual Rules

- Use the shared HR-zone palette from Project Settings.
- Horizontal bars render Z1 through Z5/Z6 from left to right.
- Vertical bars render Z1 at the bottom and Z5/Z6 at the top.
- Current zone can be emphasized by width and height.
- Inactive zones use editable opacity.
- Current marker is a solid triangle colored by the active zone.
- Marker value is optional and uses a compact dark label.
- Threshold marker is a subtle tick with a `T` label, colored by the matched threshold zone.
- Pace current marker is hidden when pace is `0` or invalid; threshold pace can remain visible.

## Placement

Modes:

- `Edge`: Top, Bottom, Left, Right.
- `Free`: Horizontal or Vertical, positioned by shared Layout controls.

Edge mode ignores the overlay's normalized position for the pinned axis and centers the bar along the opposite axis. Edge inset controls distance from the video boundary.

Marker direction points inward to avoid canvas clipping:

- Top edge: marker below.
- Bottom edge: marker above.
- Left edge: marker right.
- Right edge: marker left.

## Inspector

Sections:

- `Layout`: shared overlay layout rows.
- `Zone Bar`: Metric, Placement, Edge, Orientation, Length, Thickness, Vertical/Horizontal Position, Active Zone Width, Active Zone Height, Zone Gap, Inactive Opacity, Corner Radius, Border, Border Color, Border Width, Border Opacity, Glow, Glow Intensity.
- `Markers`: Current Marker, Marker Value, Threshold Marker.
- `Effects`: shared shadow controls only. Shared Glow and Fade Out rows are hidden for this overlay.

No Background section is exposed for v1; the default overlay is transparent except for bar-local border/glow and shared shadow.

## Defaults

- Metric: Heart Rate.
- Placement: Edge.
- Edge: Bottom.
- Free orientation: Horizontal.
- Length: 780.
- Thickness: 10.
- Edge position: 0.
- Active zone width: Equal.
- Active zone height: 1x.
- Zone gap: 2.
- Corner radius: 5.
- Inactive opacity: 55%.
- Border: enabled, white at 12%, 1 px.
- Current marker: enabled.
- Marker value: enabled.
- Threshold marker: enabled.
