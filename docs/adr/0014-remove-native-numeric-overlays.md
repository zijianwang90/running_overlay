# ADR 0014: Remove Native Numeric Overlays Without Migration

Date: 2026-11-07

## Status

Accepted by the maintainer.

## Context

ADR 0013 ports built-in overlays to declarative components and keeps legacy
element types readable, so native renderers could only be removed after a
reviewed migration of saved projects. M5c delivered the bundled
`studio.numeric` component, which matches the native numeric overlays pixel for
pixel across pairwise layout, color, font, background and scale cases, and the
three bundled templates converted to it with zero changed pixels.

The product is early and many features are exploratory. Keeping two numeric
implementations (native renderer, SwiftUI comparison view, Inspector detail
view, 30 style fields, 45 mutation APIs and their tests) alongside the
component costs more than compatibility with early projects is worth.

## Decision

1. The 21 native numeric element types (`heartRate`, `heartRateZone`, `pace`,
   `avgPace`, `lapPace`, `calories`, `elapsedTime`, `realTime`, `date`,
   `distance`, `elevation`, `cadence`, `power`, the five running-dynamics
   types, `temperature`, `grade` and `customNumeric`) are removed, together
   with their Skia and SwiftUI renderers, Inspector detail view, numeric-only
   `OverlayStyle` fields, `ProjectDocument` setters and text presets.
2. Saved projects and templates are not migrated. When they are decoded,
   elements of removed types are dropped. The other elements load unchanged,
   and opening a project reports how many numeric overlays were removed.
3. Numeric readings are the bundled `studio.numeric` component. The Overlay
   Pool Metrics tab lists one preset per metric, and the bundled templates
   ship component instances converted with exact pixel parity.
4. Metric formatting is keyed by `OverlayMetric`, independent of element
   types. Components (`metric(id, unit...)`), interval HUD, running gauge and
   route-map stats slots share it.
5. Features without a component equivalent are dropped rather than ported in
   this change: Custom Numeric (arbitrary FIT fields, coordinates), the manual
   temperature fallback, numeric background fade-out and material blur, the
   numeric border, separate value/label/unit opacity sliders (color alpha
   remains), and numeric batching in the SwiftUI comparison exporter.

## Consequences

- One numeric implementation remains, defined in a component file that the
  community format already describes.
- Opening an older project removes its numeric overlays; users re-add them
  from the Overlay Pool. Older app versions cannot open projects saved after
  numeric overlays are added, because they contain component elements
  (project schema version 2 already required that).
- The native/component parity tests for numeric overlays are removed with the
  native side. Their results are recorded in the November 2026 project log;
  component behavior is covered by component tests and a pinned formatting
  table.
- The SwiftUI comparison renderer (ADR 0012) cannot draw components, so
  numeric overlays no longer appear in its frames.
- Re-adding a dropped feature means extending the component format or the
  data contract, not restoring a native type.

## References

- [ADR 0013](0013-declarative-overlay-components.md)
- [Overlay Components](../overlay-components/README.md)
