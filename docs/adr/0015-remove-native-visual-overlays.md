# ADR 0015: Remove Native Visual Overlays Without Migration

Date: 2026-11-08

## Status

Accepted by the maintainer.

## Context

ADR 0013 ports the built-in visual overlays (distance timeline, elevation
chart, running gauge, interval modules, zone edge bar, route map, weather,
decor) to declarative components and keeps the legacy element types readable.
ADR 0014 then accepted that early-project compatibility is worth less than
maintaining two implementations, and removed the 21 native numeric types
without migration: saved elements of those types are dropped when a project or
template is decoded.

The same trade-off applies to the ported visual types. The bundled components
delegate drawing to the existing native Skia modules, so each removed element
type retires only its element surface: type-specific style fields, Inspector
detail view, `ProjectDocument` setters, SwiftUI comparison view, parity tests
and pool entry. The drawing engine itself stays as the component's capability.

## Decision

1. Native visual element types are removed without migration, following the
   ADR 0014 policy. Saved projects and templates that contain them decode with
   those elements dropped; the rest loads unchanged and the app reports how
   many overlays were removed.
2. Removal is staged per type. A type is removed only after its bundled
   component reaches parity and every bundled template that used it has been
   converted to component instances, so no first-party template loses content.
3. `runningGauge`, `intervalCountdown` and `intervalWorkSummary` are the first
   removals. Their bundled `studio.*` components have parity coverage and no
   bundled template used the native types. The running gauge keeps its Skia
   drawing module as the component renderer; the interval types are fully
   declarative compositions.
4. `decorSolidColor`, `decorIcon` and `decorText` are removed next. Their
   bundled `studio.decor-shape`, `studio.decor-icon` and `studio.decor-text`
   components carry the same capabilities and no bundled template used the
   native types. The paragraph text rasterizer they shared with component
   richText moves to `SkiaParagraphText` in the shared Skia layer; the native
   decor drawing code is deleted.
5. The SwiftUI comparison renderer (ADR 0012) cannot draw components, so a
   removed type disappears from its frames. Native/component parity tests for
   that type are retired with the native side; component behavior is covered by
   component tests.
6. Re-adding a dropped capability means extending the component format or its
   host-data contract, not restoring a native element type.

## Consequences

- The Overlay Pool keeps one creation path: every add tile creates a component.
- Removed types stay listed in `OverlayElementType.removedRawValues` so
  decoding can drop them by raw value without keeping the enum case alive.
- `OverlayStyle` no longer stores parameters for removed types. Older files
  keep their unknown keys, which decoding ignores; saving rewrites the style
  without them.
- Early projects lose visual overlays of removed types and must re-add the
  component. Older app versions cannot open projects saved after components
  were added, which project schema version 2 already required.
- Where a template still contains a forward type (for example the route map),
  that type remains readable until its component capability gap is closed and
  the template is converted.

## References

- [ADR 0013](0013-declarative-overlay-components.md)
- [ADR 0014](0014-remove-native-numeric-overlays.md)
- [Overlay Components](../overlay-components/README.md)
