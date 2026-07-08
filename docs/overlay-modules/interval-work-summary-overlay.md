# Interval Work Summary Overlay

The Interval Work Summary overlay is an interval-series component that appears
briefly when a work lap completes. It is intended for fast comprehension during
workout videos: one primary metric plus up to three secondary metrics.

## Data

- Source: `ActivityTimeline.laps`.
- Trigger lap: the most recent completed lap with `kind == .active`.
- Visibility window: `IntervalWorkSummaryStyle.displayDuration` seconds after
  the active lap end time.
- Default primary metric: lap time.
- Default secondary metrics: lap pace, lap distance, average heart rate.

## Rendering

- Preview, SwiftUI export, and legacy frame rendering consume
  `OverlayRenderModel.intervalWorkSummaryLayout(for:in:)`.
- The layout returns `isVisible == false` outside the event window so renderers
  can skip visible drawing without changing element placement.
- Accent color follows the completed work group color by default, with a custom
  color option.

## Inspector

- Uses shared dense inspector rows.
- Sections: Layout, Timing, Content, Text, Background, Border, Effects.
- Background, Border, and Effects reuse the shared overlay modules.
- Component label, primary label, and secondary labels are hideable.
- Primary value and secondary values remain visible when their metric slot is
  visible.

## Export Notes

- SwiftUI export is the visual authority.
- The legacy AppKit renderer provides parity for smoke tests and non-SwiftUI
  frame-render paths.
