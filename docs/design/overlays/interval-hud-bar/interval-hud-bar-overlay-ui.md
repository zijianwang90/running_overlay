# Interval HUD Bar Overlay UI Design Spec

Last updated: 2026-05-13

## Purpose

Interval HUD Bar is a wide, horizontal overlay for interval-training videos. It shows current rep, phase, remaining time or distance, live metrics, and an optional bottom progress or intensity bar.

Design reference:

![Interval HUD Bar mockup](./interval-hud-bar.png)

## Applies To

- `OverlayElementType.intervalHUDBar`

Replaces retired lap overlay prototypes:

- `Lap Live`: compact vertical lap HUD.
- `Lap Card`: recovery recap card.
- `Lap List`: full lap list teleprompter.

## Functional Scope

The first implementation should support:

- Rep count.
- Current phase.
- Current phase distance.
- Time left.
- Distance left.
- HR zone.
- Current HR.
- Current pace.
- Current power.
- REST HR drop.
- Optional bottom bar: lap progress, HR zones, pace zones, or none.

Do not include Target Pace in v1.

## Layout

The default layout is a single rounded horizontal HUD:

- Dark translucent panel with a subtle border.
- Main row split into compact vertical blocks.
- Thin separators between blocks.
- Bottom bar embedded inside the same container.
- No nested cards.

Default block order:

1. `REP`
2. Phase (`WORK`, `REST`, `WU`, `CD`, `LAP`) plus lap distance.
3. `TIME LEFT`
4. `DIST LEFT`
5. `HR ZONE`
6. Live metrics (`HR`, `PACE`, `PWR`)

REST state replaces one right-side metric slot with `HR DROP` when enabled.

## Visual Style

- Use the app's dark professional video-editor visual language.
- Keep typography compact, uppercase, and legible over video.
- Use monospaced digits for changing numeric values.
- Internal separators should be thin and low contrast.
- Corner radius should stay restrained.
- The bottom bar should not add a second container; it lives inside the HUD.

Phase colors:

| Phase | Color |
| --- | --- |
| `WORK` | Orange |
| `REST` | Blue |
| `WU` | Teal |
| `CD` | Purple |
| `LAP` | FIT green / neutral |

## Bottom Bar

`lapProgress` mode:

- Track is a dark neutral strip.
- Fill is current phase color.
- Label may read `LAP PROGRESS`.
- Optional percentage may sit below or inside the fill, as long as it does not collide with the bar.

`heartRateZone` mode:

- Bar becomes a segmented Z1-Z6 strip.
- Segment colors use the shared HR zone palette from Project Settings.
- Current HR marker appears as a small white marker aligned to the active segment.
- Current zone label, such as `Z4`, uses the same zone color.

`paceZone` mode:

- Same visual pattern as HR zone mode, driven by pace ranges.
- Current pace marker uses the matched zone segment.

## REST HR Drop

REST mode should support HR drop display:

- `bpm` display: `HR DROP -18 bpm`.
- percentage display: `HR DROP 10%`.

The display mode should be a style option, not inferred from the selected bottom bar.

## Inspector Guidance

Inspector sections:

- Layout: width, height, corner radius, background opacity, position, scale.
- Content: toggles for Rep, Phase, Time Left, Distance Left, HR Zone, HR Drop.
- Metrics: configurable metric slots for HR, Pace, Power, Cadence.
- Bottom Bar: mode (`None`, `Lap Progress`, `HR Zones`, `Pace Zones`) and opacity.
- Recovery: HR Drop mode (`bpm`, `%`) and visibility.
- Appearance: shared background, border, and effects modules.

Do not expose Target Pace controls until target workout data exists.

## Implementation Notes

- Derive interval state from `ActivityTimeline.laps` and `LapRecord.kind`.
- Rep count uses `.active` laps only.
- REST uses the most recent active rep number.
- HR zone and pace zone color resolution should use one shared palette/helper also used by `HeartRateZonesView`.
- Preview and export must share one render layout so values and geometry match.
