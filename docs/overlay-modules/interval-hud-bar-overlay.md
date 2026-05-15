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

## Implementation Status

Implemented in `codex/interval-hud-bar`:

- `OverlayElementType.intervalHUDBar` and `IntervalHUDBarStyle`.
- Preview/export shared SwiftUI view: `OverlaySharedIntervalHUDBarView`.
- Render layout: `OverlayRenderModel.intervalHUDBarLayout(for:in:)`.
- Overlay Pool tile in Charts.
- Dedicated Inspector for size, main HUD cell visibility, current-training detail modes, HR Zone mode, HR Drop mode, remaining primary, ordered metrics, Bottom Bar, typography, divider, background, border, and effects.
- SwiftUI exporter and legacy PNG renderer support.
- Built-in `Interval Workout` template now includes Interval HUD Bar.

Companion module:

- `Interval Timeline` is implemented as a separate schedule overlay for the same interval-training workflow. Use Interval HUD Bar for current rep/phase/metrics, and Interval Timeline for the horizontal workout plan with current-lap centering and large-set overflow summaries.

## Rep Rules

- Rep count is based on `.active` laps only.
- `WORK` maps from `.active`.
- `REST` maps from `.rest`.
- `WU` and `CD` do not count as reps.
- During `REST`, show the next active rep number after the completed work lap.
- If no active rep exists yet, show `-- / total`.

## Default Content

The default bar shows:

- `REP`: current active rep / total active reps.
- Current Training: `WORK`, `REST`, `WU`, `CD`, or `LAP`, plus configurable detail. Training and REST can independently show remaining time or remaining distance.
- Remaining block: either `TIME LEFT` as the primary value with distance as secondary, or `DIST LEFT` as the primary value with time as secondary.
- HR Zone block: either always show current HR zone, or show HR Zone during training and switch to HR Drop during REST.
- Ordered metrics: default slots are `HR` and `PACE`.

Metrics are stored as an ordered add/delete list, not a fixed five-toggle surface. Users can append as many metric slots as needed, remove any row, and repeat the same metric when a layout calls for it. The options include every Numeric Overlay metric only. `HR Zone` and `HR Drop` are controlled by the dedicated HR Zone HUD cell.

The preview and export render the main row as equal-width cells: enabled `REP`, Current Training, Remaining, HR Zone, and each metric all get one cell. When the metric list is empty, no blank metric area is reserved.

Do not include Target Pace in v1.

## Inspector Surface

Inspector sections:

- `Layout`: shared placement, size, scale, and transform controls.
- `HUD Bar`: width, height, Rep toggle, Current Training toggle and detail modes, Remaining toggle and primary mode, HR Zone toggle, Zone mode, and HR Drop mode.
- `Metrics`: ordered add/delete list using `IntervalHUDBarMetricSlot`, with all Numeric Overlay metric types available. Each slot can store a per-metric unit option for numeric metrics that support multiple units.
- `Bottom Bar`: section-header enable switch, type menu (`Lap Progress`, `HR Zones`, `Pace Zones`), progress mode, spacing, corner radius, independent bottom-bar border controls, Glow toggle, and Glow Intensity.
- `Typography`: separate font family, size, and weight controls for labels, primary values, phase, phase detail, metric values, and metric units.
- `Divider`: shared overlay divider fields for all internal vertical separators.
- `Background`: shared `OverlayBackgroundInspectorModule`.
- `Border`: shared `OverlayBorderInspectorModule`.
- `Effects`: shared `OverlayEffectsInspectorModule`; Shadow applies to the outer HUD container in preview and export.

The final four sections stay in the canonical order `Divider`, `Background`, `Border`, `Effects`; `Background`, `Border`, and `Effects` are the shared components used by other overlays.

Background padding is container interior padding for the fixed HUD surface. Shadow follows the shared Effects fields (`shadowColor`, opacity, radius, offset, thickness): it is container-level when Background is enabled, and content-level when both Background and Border are disabled.

Bottom Bar Spacing is a real gap between the data row and bottom bar: `0` keeps them adjacent, and larger values separate them farther. The layout preserves requested spacing before compressing top/bottom padding on short HUDs; only when the data row and bar still cannot fit is spacing capped. Zone Marker is drawn as a floating overlay and never reserves layout height, so enabling it does not move the data row, bar, or background.

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

- `lapProgress`: progress through the current lap, colored by current phase.
- `heartRateZones`: segmented zone strip using the shared HR zone palette and current HR zone.
- `paceZones`: segmented zone strip using configured pace zones and current pace zone.

Heart-rate and pace zone modes read global `HeartRateZonePreferences`.

Bottom Bar Spacing controls the vertical gap between the HUD content cells and the bottom bar in both preview and export.

Shared Background Padding is honored as Interval HUD Bar content padding: X padding moves HUD cells and the bottom bar inward; Y padding increases top and bottom interior breathing room in both preview and export.

Zone modes support an Active Zone Width setting. Equal width keeps Z1-Z5/Z6 evenly divided; expanded width lets the active zone occupy up to 50% of the bar, with inactive zones sharing the remaining space evenly.

Zone modes support Active Zone Height, Zone Gap, and Corner Radius. Active Zone Height raises the active segment up to 2x around the bar centerline without changing layout height; Zone Gap adds visual separation between adjacent segments; Corner Radius can create square, softly rounded, or pill-like progress bars.

Bottom Bar Border is independent from the shared overlay Border section. It applies only to the bottom strip, supports enable, color, width, and opacity settings, and renders consistently in preview and export for lap-progress and zone modes.

Zone modes also expose Inactive Opacity for non-active segments.

Zone modes also support a single solid Zone Marker triangle. The marker can be hidden, placed above or below the bar, and can optionally show the current HR or pace value. Marker color follows the active zone color. It floats above the HUD layout and may overlap other HUD text or extend beyond the background.

Glow is controlled inside the Bottom Bar section. In lap progress mode, it highlights the completed portion. In zone modes, it highlights the active zone segment. Glow intensity is editable; glow color follows the phase or active zone color.

## Shared Zone Colors

The HR zone color palette is shared through `HRZonePalette` so Project Settings, Interval HUD Bar, and future physiology-aware overlays use the same color values.

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
