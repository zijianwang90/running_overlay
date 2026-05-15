# Interval Timeline Overlay

Last updated: 2026-05-14

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

Default mode. The current lap stays centered while nearby laps are shown on both sides. Hidden previous/next laps are summarized with clipped-count pills and edge fades.

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
    var maxFullSegments: Int
    var segmentHeight: Double
    var currentSegmentHeightScale: Double
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
    var primaryLabelMode: IntervalTimelineLabelMode
    var durationLabelsEnabled: Bool
    var repCounterEnabled: Bool
    var overflowPillsEnabled: Bool
    var railEnabled: Bool
    var railSpacing: Double
    var railDotSize: Double
    var railColor: OverlayColor
    var railOpacity: Double
    var railLineColor: OverlayColor
    var railLineWidth: Double
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
- The `NOW` marker lives in a reserved marker lane below the rail. Enabling or disabling it must not change `contentRect`, segment rects, the marker lane, or the rail position.
- The marker is visually attached to the rail: it renders just below the rail, remains inside the background and border, and supports marker color, font size, and font weight controls.
- The rail is decorative and configurable through `railEnabled`, `railSpacing`, `railDotSize`, `railColor`, `railOpacity`, `railLineColor`, and `railLineWidth`. `railSpacing` is the vertical gap from segment blocks to the rail, not the distance between dots.
- Rail spacing contributes to the rendered background height so the rail remains inside the background.
- Endpoint context (`WU` / `CD`) reserves edge space whenever hidden laps exist, even if `overflowPillsEnabled` is false. When pills are visible, each compact edge cluster reserves enough width for endpoint label, ellipsis, and square `xN` pill before the visible segment area starts. `overflowPillsEnabled` only controls the hidden-count boxes and ellipses, not endpoint protection.
- Label fitting should be layout-driven: hide duration labels first, then reduce to short kind labels, then hide non-current labels.

## Inspector

Use the design in `docs/design/overlays/interval-timeline/interval-timeline-overlay-ui.md`.

Primary sections:

- Layout
- Timeline
- Current
- Rail
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
- Add tests that marker visibility does not move the rail or segment geometry.

### Phase 2

- Add Compressed Sets repeated-pair detection.
- Add richer rep-counter labeling such as `RUN 9 / 25`.
- Add per-kind custom label overrides.
- Add optional tick rail for hidden repeated sets.

## Acceptance Criteria

- `WU + 6 x 400m/R + CD` is readable as a full horizontal schedule.
- `1min x25` is readable without showing 25 tiny labeled blocks.
- Current lap is enlarged and centered in Centered Window mode.
- Hidden laps are summarized clearly at both edges.
- Preview and export match.
