# Interval HUD Bar Overlay

Last updated: 2026-05-13

## Module Goal

Interval HUD Bar is a horizontal interval-training overlay for showing the current workout rep, phase, remaining work, and key live metrics in one compact broadcast-style strip.

It replaces the retired lap overlay prototypes:

- `Lap List` was a vertical lap teleprompter.
- `Lap Card` was a completed-lap recap card.
- `Lap Live` was a compact vertical current-lap panel.
- `Interval HUD Bar` is the new wide horizontal HUD optimized for interval videos and lower-third placement.

## Data Source

First implementation uses existing lap-derived interval data:

- `ActivityTimeline.laps`
- `LapRecord.kind`
- `ActivityTimeline.currentLap(at:)`
- `ActivityTimeline.lapProgress(at:byDistance:)`
- live FIT samples for HR, pace, power, cadence, and distance

No FIT workout-step parser is required for v1.

## Rep Rules

- Rep count is based on `.active` laps only.
- `WORK` maps from `.active`.
- `REST` maps from `.rest`.
- `WU` and `CD` do not count as reps.
- During `REST`, show the most recent `WORK` rep number.
- If no active rep exists yet, show `-- / total`.

## Default Content

The default bar shows:

- `REP`: current active rep / total active reps.
- Phase: `WORK`, `REST`, `WU`, `CD`, or `LAP`.
- Phase distance: current lap distance.
- `TIME LEFT`: current lap remaining time.
- `DIST LEFT`: current lap remaining distance.
- `HR ZONE`: current heart-rate zone and current HR.
- Live metrics: pace and power by default.

Do not include Target Pace in v1.

## REST HR Drop

REST state can show HR recovery drop:

- `bpm` mode: peak HR since the current rest lap started minus current HR, e.g. `-18 bpm`.
- `%` mode: drop divided by peak HR, e.g. `10%`.

Use existing recovery helpers where possible:

- `ActivityTimeline.recoveryPeakHR(at:)`
- `ActivityTimeline.recoveryDrop(at:)`
- `ActivityTimeline.recoveryDropPercent(at:)`

## Bottom Bar Modes

The bottom bar is optional.

Modes:

- `none`: no bottom bar.
- `lapProgress`: progress through the current lap, colored by current phase.
- `heartRateZone`: segmented zone strip using the shared HR zone palette and current HR marker.
- `paceZone`: segmented zone strip using configured pace zones and current pace marker.

Heart-rate and pace zone modes read global `HeartRateZonePreferences`.

## Shared Zone Colors

The HR zone color palette should be extracted into a shared code path so Project Settings, Interval HUD Bar, and future physiology-aware overlays use the same colors.

| Zone | Color intent |
| --- | --- |
| Z1 | Blue |
| Z2 | Cyan |
| Z3 | Green |
| Z4 | Yellow |
| Z5 | Orange |
| Z6 | Red |

## Out Of Scope For V1

- Target Pace display.
- Workout-step parsing.
- Manual workout plan editing.
- Multi-profile zone management.
- Animation between reps.
