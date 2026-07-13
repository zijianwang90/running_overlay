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

## Rendering

- Preview and SwiftUI export use `OverlaySharedIntervalCountdownView`.
- Legacy frame rendering uses `OverlayFrameRenderer.renderIntervalCountdown`.
- Layout is computed in `OverlayRenderModel.intervalCountdownLayout(for:in:)`
  so preview, export, hit testing, and tests share the same geometry.

## Behavior

- The center countdown text is always visible.
- Helper, phase, rep, and caption text can be hidden independently.
- Every text role has independent font family, size, weight, and color mode.
- Text and ring fill color modes are `Follow Group` or `Custom`.
- Progress is the current segment's remaining fraction.
- Ring-local glow applies only to the progress fill.
- Shared/global Glow applies to the foreground content group.
- When Background is enabled, Shadow targets the background surface only.
- When Background is disabled, Shadow targets all visible internal parts.

## Inspector

Inspector sections:

1. `Layout`
2. `Countdown`
3. `Progress Ring`
4. `Text`
5. `Background`
6. `Border`
7. `Effects`

The final three sections reuse shared inspector modules.
