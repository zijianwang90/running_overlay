# Interval Timeline Overlay

Last updated: 2026-06-15 (custom label fields; explicit full mode; WU/Rest/CD visibility controls; simplified ellipsis overflow)

## Module Goal

Interval Timeline is a horizontal schedule overlay for interval workouts. It is designed to pair with the existing `Interval HUD Bar`:

- `Interval HUD Bar` focuses on the current rep, phase, remaining work, and live metrics.
- `Interval Timeline` shows the workout structure around the current lap.

The module should make interval sessions readable in video exports, especially high-repetition workouts such as `1min x25`, where drawing the full schedule with labels would become too dense.

## Data Model

The overlay uses existing lap data:

- `ActivityTimeline.laps`
- `LapRecord.startElapsedTime`
- `LapRecord.endElapsedTime`
- `LapRecord.totalElapsedTime`
- `LapRecord.totalDistanceMeters`
- `LapRecord.kind`
- `ActivityTimeline.currentLap(at:)`
- `ActivityTimeline.lapProgress(at:byDistance:)`

No new FIT parser fields are required for the first version.

The runtime overlay intentionally omits the design-board title badge and title text from the visual mockup. The exported element is the compact timeline rail itself, with no legend or mode controls.

## Display Strategy

### Centered Window

Default mode. The current lap stays centered while nearby laps are shown on both sides. Hidden previous/next laps are summarized with compact `···` overflow hints and edge fades.

This is the first-choice behavior for big sets:

```text
... x8 | R | RUN | [CURRENT R] | RUN | R | x12 ...
```

### Full Schedule

The whole workout is drawn from warmup to cooldown. Segment widths can be proportional to lap duration, with minimum width clamps. Labels reduce or disappear when space is limited.

This works best for small or moderate workouts:

```text
WU | 400m | R | 400m | R | 400m | R | CD
```

Full Schedule is explicit: selecting Full always draws all enabled segments instead of automatically falling back to Centered Window for high lap counts. Full mode supports two segment layout strategies:

- `Equal`: enabled segments share the available width evenly.
- `Duration`: enabled segments use duration-proportional widths, preserving the previous Full Schedule geometry.

### Compressed Sets

Future mode. Repeated work/rest pairs are summarized into a set rail, with the current pair expanded in place and a visible `Rep n / total` counter.

## Style Model Proposal

Dedicated style namespace:

```swift
struct IntervalTimelineStyle: Equatable, Codable {
    var width: Double
    var height: Double
    var mode: IntervalTimelineMode
    var visibleNeighbors: Int
    var fullSegmentLayoutMode: IntervalTimelineFullSegmentLayoutMode
    var showsWarmupSegments: Bool
    var showsRestSegments: Bool
    var showsCooldownSegments: Bool
    var segmentHeight: Double
    var currentSegmentHeightScale: Double
    var currentSegmentWidthFraction: Double
    var fullEqualCurrentSegmentWidthFraction: Double
    // (Rail dot/line fields removed — the overlay no longer renders a rail.)
    var minSegmentWidth: Double
    var segmentGap: Double
    var edgeFadeEnabled: Bool
    var currentProgressEnabled: Bool
    var markerEnabled: Bool
    var markerLabel: String
    var markerPosition: IntervalTimelineMarkerPosition
    var markerColor: OverlayColor
    var markerFontSize: Double
    var markerFontWeight: OverlayFontWeight
    var currentDistanceLabelMode: IntervalTimelineCurrentLabelMetricMode
    var currentTimeLabelMode: IntervalTimelineCurrentLabelMetricMode
    var neighborLabelMode: IntervalTimelineNeighborLabelMode
    var repCounterEnabled: Bool
    var overflowHintEnabled: Bool
    var warmupColor: OverlayColor
    var activeColor: OverlayColor
    var restColor: OverlayColor
    var cooldownColor: OverlayColor
    var unknownColor: OverlayColor
    var completedOpacity: Double
    var futureOpacity: Double
}
```

The first implementation should add `OverlayElementType.intervalTimeline` and `OverlayStyle.intervalTimeline`.

## Rendering Architecture

Recommended flow:

1. `OverlayRenderModel.intervalTimelineLayout(for:in:)` determines visible laps, current index, segment rects, labels, hidden counts, and progress.
2. SwiftUI Preview renders from that layout.
3. CoreGraphics export renders from the same layout to keep preview and MOV output aligned.

Important rules:

- The render path must be deterministic from `elapsedTime`, style, and activity data.
- Do not store transient scroll offset in UI state for export-visible behavior.
- Overlay bounds must not jump when the current lap changes.
- The `NOW` marker lives in a reserved marker lane directly below the current segment. Enabling or disabling it must not change `contentRect`, segment rects, or the marker lane position.
- The marker renders just below the segment row, remains inside the background and border, and supports marker color, font size, and font weight controls.
- Overflow context is intentionally minimal: hidden laps render only as a low-contrast `···` hint at the left and/or right edge. WU/CD endpoint ghost labels and `xN` hidden-count pills are not rendered because the count represents hidden segments, not repeated sets.
- Overflow hint geometry is computed in the layout (`overflowEllipsisInset`) so SwiftUI preview and CoreGraphics export consume identical positions. The hint reserves a compact edge width before the first/last visible segment; disabling the hint removes that reserved space.
- The overlay background height is derived from the actual stacked content (segments → marker → bottom padding). This keeps the bottom flush with the marker label.
- In `centeredWindow`, the current segment's width is a fixed fraction of the segment area (`currentSegmentWidthFraction`, default `0.28`). Remaining laps share the leftover width evenly. The current segment communicates *position in the overall workout*, not the lap's individual duration. The progress fill inside the current segment is overall workout progress (`elapsedTime / activity.duration`), not lap progress.
- Timeline visibility controls filter WU, Rest, and CD independently before layout. If the current playback lap is filtered out, no segment is marked current; the marker falls back to the nearest visible segment or the segment area midpoint when none are visible.
- In `fullSchedule`, `fullSegmentLayoutMode` controls segment widths. `Equal` distributes enabled segments evenly by default; `fullEqualCurrentSegmentWidthFraction` lets the Current Width slider give the active segment a larger target share, with `0` meaning equal-width. `Duration` uses duration-proportional widths. Current segment emphasis still affects the current segment's height in both layouts.
- Segment labels are user-configurable instead of kind-mode driven. Current labels expose independent distance and time rows, each set to `Off`, `Live`, or `Remain`; enabled rows can be shown together. Neighbor labels use one selected metric for non-current segments: `Distance` or `Time`.

## Inspector

Use the design in `docs/design/overlays/interval-timeline/interval-timeline-overlay-ui.md`.

Primary sections:

- Layout
- Timeline: mode, Full layout, visible neighbors, WU/Rest/CD visibility, overflow hint, segment gap, segment radius
- Current
- Labels
- Colors
- Background
- Border & Effects

Shared modules should be reused for Layout, Background, Border, and Effects.

## Implementation Phases

### Phase 1

- Add style model and overlay type.
- Implement Centered Window mode.
- Implement Full Schedule mode.
- Add Preview and export renderers.
- Add Inspector controls for the first-version fields.
- Add tests for visible-window selection and current-lap centering.
- Add tests that marker visibility does not move the segment geometry or content rect.

### Phase 2

- Add Compressed Sets repeated-pair detection.
- Add richer rep-counter labeling such as `RUN 9 / 25`.
- Add per-kind custom label overrides.

## Acceptance Criteria

- `WU + 6 x 400m/R + CD` is readable as a full horizontal schedule.
- `1min x25` is readable without showing 25 tiny labeled blocks.
- Current lap is enlarged and centered in Centered Window mode.
- Hidden laps are summarized clearly at both edges.
- Preview and export match.
