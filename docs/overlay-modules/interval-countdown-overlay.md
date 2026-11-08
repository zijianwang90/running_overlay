# Interval Countdown Overlay

Last updated: 2026-07-08

Interval Countdown is a compact circular overlay for structured workouts. It
shows the current lap or interval segment's remaining time in the center and
renders a single progress ring around it.

Design references:

- `docs/design/overlays/interval-countdown/interval-countdown-overlay-ui.md`
- `docs/design/overlays/interval-countdown/interval-countdown-overlay-ui.spec.json`

## Data Model

- Element type: `OverlayElementType.intervalCountdown`.
- Style container: `OverlayStyle.intervalCountdown`.
- Source data: `ActivityTimeline.currentLap(at:)`, `ActivityTimeline.lapProgress(at:byDistance:)`,
  and `LapRecord.kind`.
- Color source: `IntervalKindColorPreferences.currentSnapshot()`, shared with
  interval workout coloring.

## Declarative Component Port

`studio.interval-countdown` composes the same layout from `structure.segment`
data and general component nodes (`arc`, `group` shadow chains, `textRows`).
It covers both ring directions, time/distance and remaining/elapsed values,
per-role text visibility and typography, background, border, shadow and glow.
The element-level drop shadow and glow are applied by the host around the
component, outside its clip, and the ring glow is drawn by the definition.
Parameter values that the native renderer treats as pixels are divided by
`signal("host.scale")` to stay pixel-faithful at every element scale.

The native renderer remains the parity oracle and is not removed; the port's
remaining visible difference is an antialias fringe below 0.25% of pixels at
ring edges. With both a background and the element glow enabled, the host glow
follows the component's outer silhouette rather than only the ring, which is a
small, deliberate difference; the host shadow also includes the border in its
mask, costing at most two alpha levels at the edge. SVG/user-image selection
does not apply to this module.

## Rendering

- Preview and SwiftUI export use `OverlaySharedIntervalCountdownView`.
- Layout is computed in `OverlayRenderModel.intervalCountdownLayout(for:in:)`
  so preview, export, hit testing, and tests share the same geometry.

## Behavior

- The center value is always visible and supports current-segment time or
  distance in either `End to 0` or `0 to End` direction.
- Helper, phase, rep, and caption text can be hidden independently.
- Every text role has independent font family, size, weight, and color mode.
- Text inspector roles are grouped; each hideable role exposes its visibility
  checkbox in the trailing group header.
- Text and ring fill color modes are `Follow Group` or `Custom`.
- The `Direction` control selects clockwise `Full to Empty` (the default) or
  counterclockwise `Empty to Full`. Both modes use the current segment only.
- Ring-local glow applies only to the progress fill.
- Shared/global Glow applies to the foreground content group.
- When Background is enabled, Shadow targets the background surface only.
- When Background is disabled, Shadow targets all visible internal parts.

## Inspector

Inspector sections:

1. `Layout`
2. `Center Value`
3. `Progress Ring`
4. `Text`
5. `Background`
6. `Border`
7. `Effects`

The final three sections reuse shared inspector modules.
