# ADR 0013: Declarative Overlay Components

Date: 2026-11-04

## Status

Accepted as a direction by the maintainer. The v0.1 specification linked below
is still a draft. A runtime kernel, a `component` project element kind (project
schema version 2), a Skia drawing path with embedded image assets, a generated
Inspector, bundled read-only definitions, package import and a headless
validate/render CLI now exist. Visual-parity approval for ported built-ins does
not. Implementation remains gated on the reviews listed under Consequences.

## Context

Every overlay type currently requires coordinated edits to five places:
`OverlayElementType`, the shared `OverlayStyle` union in `OverlayElement.swift`,
`OverlayRenderModel` layout, a Skia renderer under `Render/Skia/`, and an
Inspector detail view. Those files are already several thousand lines each, so
adding a community-requested overlay means contributing across 6,000+ lines of
Swift. That cost is the reason the Overlay Pool is fixed to the types the
maintainer ships.

At the same time, the product renderer exposes a deliberately small drawing
vocabulary. `Sources/CSkiaBridge/include/skia_bridge.h` offers text, rects,
rounded rects, circles, paths, polylines, images, clips, gradients, shadows,
blur and opacity layers. All current overlays are compositions of that
vocabulary plus host-computed data (activity samples, lap and interval
structure, heart-rate and pace zones, route projection, weather results).

Two alternatives were considered and rejected:

- **A native plugin ABI (Swift dylibs or XPC).** It couples third parties to
  unstable Swift ABI and internal model types, is hard to sandbox and notarize,
  is a much larger security surface, and risks App Store guideline 2.5.2
  (downloaded code that changes functionality).
- **An embedded scripting runtime (JavaScriptCore or similar).** It makes
  export performance and output non-deterministic, expands the security
  surface, and still requires every overlay to author pixel drawing by hand.

## Decision

1. **Components are declarative JSON documents.** A component conforms to
   `ros.component/0.1` and is distributed as a `.rocomponent` package
   (`component.json` plus PNG/JPEG assets). Components do not execute code.
2. **The host owns data and analysis.** Components receive a versioned,
   read-only data contract: current signal values, bounded series, lap and
   interval structure, zone state, route geometry and weather results.
   Interval detection, zone resolution, route projection and weather fetching
   stay in native Swift. Components never access the network, the file system,
   the process environment, or any clock other than the playhead-derived
   values the host publishes.
3. **A closed, pure expression language and a fixed node vocabulary.** Base
   nodes map one-to-one onto `skb_*` primitives. Capability nodes (for example
   `sparkline`, `progressBar`, `arc`) are implemented natively and added to the
   contract only through review. The language has no loops beyond a bounded
   `repeat` node, no recursion, and no user-defined functions.
4. **Inspector UI is generated from typed params, not designed by authors.**
   Params use a fixed control vocabulary (`number`, `bool`, `color`, `enum`,
   `string`, `font`, `metric`) rendered through the existing
   `InspectorDense*` primitives. Every edit routes through a new
   `ProjectDocument` API with defined undo semantics: one undo point for a
   discrete edit, one continuous transaction for a drag.
5. **Bundled overlays use the same format.** Native overlay types are ported
   to components incrementally. Each port must pass pixel-parity checks against
   the existing Skia renderer and visual snapshots before its native renderer
   and detail view are removed. Bundled definitions are read-only in the app;
   users may inspect them and duplicate one into an editable custom component,
   but cannot edit a bundled definition in place. Legacy element types remain
   readable for the foreseeable future; there is no flag-day migration.
6. **Projects store component instances, not just references.** An instance
   records component id, semantic version, definition digest and params, plus
   an embedded definition when the component is not bundled with the app. This
   preserves deterministic rendering when a project moves between machines or
   is shared.
7. **Community distribution is data-only and explicit.** Users import a
   `.rocomponent` file; nothing is downloaded or auto-installed. Every package
   carries an SPDX license identifier and asset provenance. Validation happens
   at import and at project load; a failing component renders an editor
   placeholder and fails export with a diagnostic rather than being skipped.
8. **Compilation happens once.** The host validates and compiles a component
   into a typed render graph at load time. Per frame it evaluates only dynamic
   values. Per-component draw cost is gated by the existing export benchmark
   suite.

## Consequences

Positive:

- A new overlay becomes one JSON document plus optional image assets, which
  the community and AI tooling can author without touching Swift.
- Built-in overlays share one implementation path, reducing the six-place
  edit burden and the divergence between preview and export.
- The data contract keeps timing domains and analysis in the host, preserving
  the invariants in `AGENTS.md`.

Negative and risks:

- The format is a long-lived public contract. Its mistakes are expensive to
  undo, which is why v0.1 is deliberately small.
- Growth pressure will come as requests for scripting, arbitrary layout,
  networking and custom fonts. Each must be answered by a reviewed capability
  node or declined, not by widening the language ad hoc.
- Component text is canvas-drawn and has no accessibility tree, matching
  existing overlay behavior. Editor-side accessibility for generated
  Inspector controls must be preserved.
- Route map, weather and chart rendering may remain partially host-defined;
  the format describes their appearance and inputs, not their internals.
- The SwiftUI comparison renderer retained by ADR 0012 cannot draw
  components, so ported built-ins can only be compared against Skia
  snapshots. This must be stated in snapshot policy when porting begins.

Required reviews before implementation lands:

- Project-file compatibility and migration plan (human review).
- App Store policy review of downloadable declarative content
  (guideline 2.5.2 and sandbox implications).
- Visual snapshot and pixel-parity approval.
- Export benchmark approval with no meaningful regression.
- Asset, font and license review for any bundled example.

## References

- Draft specification:
  [Overlay Component Format v0.1](../overlay-components/spec-v0.1.md)
- JSON Schema:
  [ros-component-0.1.schema.json](../overlay-components/schema/ros-component-0.1.schema.json)
- ADR 0011 (Skia product renderer) and ADR 0012 (staged renderer retirement).
