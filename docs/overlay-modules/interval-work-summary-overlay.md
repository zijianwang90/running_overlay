# Interval Work Summary Overlay

The Interval Work Summary overlay is an interval-series component that appears
briefly when a work lap completes. It is intended for fast comprehension during
workout videos: one primary metric plus up to three secondary metrics.

## Data

- Source: `ActivityTimeline.laps`.
- Trigger lap: the most recent completed lap with `kind == .active`.
- Visibility window: the component's `displayDuration` parameter (seconds
  after the active lap end time).
- Default primary metric: lap time.
- Default secondary metrics: lap pace, lap distance, average heart rate.

## Rendering

- The bundled `studio.interval-work-summary` component reads
  `structure.lastWork` and resolves its layout from component nodes.
- Host data reports the completed lap and completion age; the component stays
  hidden outside the configured display window.
- Accent color follows the completed work group color by default, with a custom
  color option.

## Declarative Component Port

`studio.interval-work-summary` composes the same layout from
`structure.lastWork` data and general component nodes: an auto-sized label and
`textRows` block, pinned flexible spacers, and equal-width `columns` with a
divider. It ships 64 generated Inspector parameters covering metrics, units,
labels, columns, typography, colors, background and border.

Native parity is exact across the default, imperial, one-column, no-columns,
hidden-labels, pace-primary, background-with-shadow and element-scale-1.5
cases. Two rules make that possible:

- Layout constants that are pixels in the native renderer (gaps, the minimum
  gutter, column insets) are divided by `signal("host.scale")` so they stay
  pixel-faithful when the element is scaled.
- Element shadow, glow and opacity are host state, so the definition draws
  none of them; the host applies them around the component outside its clip.

The native `intervalWorkSummary` element type and its renderer were removed
without migration (ADR 0015); saved elements are dropped on load. Parity
results are recorded in the November 2026 project log.

## Inspector

- Uses shared dense inspector rows.
- Sections: Layout, Timing, Content, Text, Background, Border, Effects.
- Background, Border, and Effects reuse the shared overlay modules.
- Component label, primary label, and secondary labels are hideable.
- Primary value and secondary values remain visible when their metric slot is
  visible.
- Text controls are grouped by text role, with short row labels inside each
  group to avoid wrapping in the narrow inspector.

## Export Notes

- SwiftUI export is the visual authority.
- The legacy AppKit renderer provides parity for smoke tests and non-SwiftUI
  frame-render paths.
