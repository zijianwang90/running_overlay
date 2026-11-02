# Distance Timeline Elevation Profile

Last updated: 2026-11-01

## Purpose

The Distance Timeline normally fills its progress track with a straight bar.
The **Elevation Profile** checkbox replaces that fill with a curve shaped by the
activity's elevation samples, so terrain context can appear on any timeline
preset, not only on the Route preset.

## Input

- Label: `Elevation Profile`
- Suffix: `ElevationProfile`
- Default: `0` (off)

Input keys follow the existing slot convention:

| Slot | Key |
| --- | --- |
| Primary | `TimelineElevationProfile` |
| Widget 5 | `Widget5TimelineElevationProfile` |
| Widget 16 | `Widget16TimelineElevationProfile` |

The checkbox is independent of the **Preset** combo. It is shown with the other
timeline controls and has no effect on the label, axis, stats bar, marker,
background, border, tick or glow layers.

## Rendering

When the checkbox is on, `render_timeline` reuses the existing elevation
preparation (`prepare_elevation`) and the same curve geometry the Route preset
draws:

1. Valid `elevation_m` samples are collected and smoothed with the Mac
   full-profile Gaussian filter.
2. The smoothed profile is flattened into Catmull-Rom segments and clamped to
   the content width.
3. The area beneath the curve is filled with the timeline accent at 0.22 alpha.
4. The progress portion of the curve is stroked with the accent color.

While the curve is visible the straight progress fill is skipped, exactly as the
Route preset does today. Ticks, glow, background, border, marker, labels, custom
values and the stats bar still render normally.

## Fallback

If there are no usable elevation samples, or the profile has fewer than two
points, the toggle does not error and does not draw an empty curve. The
straight progress fill is used instead.

## Relationship To The Route Preset

- Preset **Route** (index 8) shows the elevation curve unconditionally; the
  checkbox is not required and turning it off does not remove the curve.
- Every other preset shows the curve only when **Elevation Profile** is on.
- When the checkbox is off, every preset keeps its previous output, including
  the Route preset's existing omission of the straight fill when no elevation
  samples exist.

## Tests

`test/numeric-renderer.test.js` executes the real Fuse through fengari and
asserts on recorded shape events:

- Custom preset with the checkbox off: straight fill, no curve.
- Custom preset with the checkbox on: curve present, straight fill skipped.
- Route preset with the checkbox off: curve still present.
- No elevation samples with the checkbox on: straight-track fallback.
