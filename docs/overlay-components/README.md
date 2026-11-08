# Overlay Components

Status: **Draft, with an authoring loop implemented.** The loader, validator,
expression evaluator and resolved draw-tree builder live in
`Sources/RunningOverlay/Components/`. The project schema stores a `component`
element kind (schema version 2), and the shared Skia preview/export renderer
draws instances from embedded or bundled definitions, including image assets.
The Overlay Pool lists bundled components and imports `.rocomponent` packages
(folders or ZIP archives) or component JSON files, manages project definitions
under **My Components** (add, export, remove), the Inspector generates controls
from `params`, and `--component-validate` / `--component-render` cover headless
authoring. See
[ADR 0013](../adr/0013-declarative-overlay-components.md) for the decision and
gates.

This directory defines how an overlay can be described as data instead of
Swift code, so the community, the maintainer and AI tooling can all author
overlays against the same contract.

## Documents

| Document | Purpose |
|---|---|
| [Spec v0.1](spec-v0.1.md) | Normative format: package, data contract, expressions, nodes, params, persistence, limits, security. |
| [JSON Schema](schema/ros-component-0.1.schema.json) | Machine-readable validation for editors and future import tooling. |
| [Heart Rate Pill](examples/hr-pill.rocomponent.json) | Minimal scalar + series example with params and Inspector controls. |
| [Lap Splits](examples/lap-splits.rocomponent.json) | List + `repeat` example using lap structure. |

## The Idea In One Example

```json
{
  "spec": "ros.component/0.1",
  "id": "community.alice.pace-pill",
  "version": "1.0.0",
  "name": "Pace Pill",
  "license": "MIT",
  "size": [200, 64],
  "params": [
    {
      "id": "accent", "type": "color", "label": "Accent",
      "default": "#4DA3FF"
    }
  ],
  "bindings": { "pace": { "signal": "activity.pace" } },
  "nodes": [
    { "type": "rect", "frame": [0, 0, 200, 64], "radius": 32, "fill": "#0B1220CC" },
    {
      "type": "text", "frame": [24, 10, 152, 44],
      "text": "=format(pace, \"pace\")",
      "font": { "family": "system-rounded", "size": 30, "weight": "bold" },
      "color": "=accent", "verticalAlign": "center"
    }
  ]
}
```

The host supplies `activity.pace`, converts design units with the existing
1280×720 reference-canvas scale, generates a color well for `accent` in the
Inspector, and draws through the same Skia renderer used by preview and
export.

## What Components Can Do

- Draw text, shapes, paths, images and gradients with the primitives already
  exposed by `skb_*`, including per-node letter tracking.
- Stack text and other boxed nodes horizontally or vertically with auto-sized
  text, so a unit can follow a value whose width changes, and override the
  cross-axis alignment of a single child with `alignSelf`.
- Size the whole component from its measured content (`"size": "content"`)
  with padding, a minimum size and a background that follows the content.
- Draw system SF Symbols with the `symbol` node.
- Read a versioned, read-only view of activity signals, series, laps,
  intervals, zones, route position and weather results, including lap pace
  and running dynamics.
- Show any native numeric reading with host formatting through
  `metric(id, unit)`, which returns the same value, unit and label text as the
  native overlay.
- Use three native capability nodes in v0.1: `sparkline`, `progressBar`, `arc`.
- Expose typed params that become HIG-consistent Inspector rows.
- Bundle PNG/JPEG assets with declared licensing.

## What Components Cannot Do

- Execute code, script, load dylibs, or use JavaScriptCore.
- Access the network, files, processes, keychain, or arbitrary clocks.
- Compute intervals, zones, route projection or weather. Those stay in the
  host and are exposed as data.
- Use general auto layout (wrapping, distribution, flexible sizing), SVG,
  bundled fonts or nested `repeat`. Only one-dimensional stacks and
  content-sized components are available.
- Design arbitrary Inspector UI.

## Authoring Loop (Planned)

The intended feedback loop for humans and AI is:

1. Write `component.json` against the spec and schema.
2. `RunningOverlay component validate <package>` — schema plus semantic
   validation with JSON-pointer errors.
3. `RunningOverlay component render <package> --activity <fixture.fit>
   --at <elapsed> --out frame.png` — headless render through the product Skia
   renderer with synthetic fixtures.
4. Inspect the PNG, adjust, repeat.
5. Add the package to a project and verify Inspector behavior and undo.

None of the CLI commands exist yet. They are part of the v0.1 implementation
milestone, not the current app.

## Governance

- The spec is versioned independently from component versions; see section 14
  of the spec.
- New base nodes, capability nodes, builtins, signals or param types are spec
  MINOR changes. They require documentation, tests and, for capability nodes,
  a native host implementation.
- Removals and semantic changes are spec MAJOR changes.
- The `studio.` id namespace is reserved for components bundled with the app.
  Bundled components use the same format and the same vocabulary as community
  components. They are read-only in the app; users inspect them and duplicate
  one into a new editable component, but cannot edit a bundled definition in
  place.
- Deferred capability nodes: `areaChart`, `intervalTimeline`, `routeMap`,
  `weatherIcon`, `textEffect`, `richText`.

## Implementation Milestones

| Milestone | Content | Exit gate |
|---|---|---|
| M0 (this draft) | ADR, spec v0.1, schema, examples | Maintainer review of format |
| M1 | Parser, validator, expression evaluator, compiled render graph, tests | **Kernel implemented:** `Sources/RunningOverlay/Components/`; focused tests pass |
| M2 | Base + capability nodes through `SkiaEasyRunRenderer`; `.component` element kind | **Implemented for embedded definitions:** schema v2, canonical digest, Skia path; pixel parity with native still pending |
| M3 | Params to Inspector generation and `ProjectDocument` undo | **Implemented:** generated Inspector rows, add/duplicate from the Overlay Pool, clamped/quantized parameter edits with discrete and continuous undo |
| M4 | `.rocomponent` import, embedded definitions, validation errors, CLI | **Implemented:** folder/ZIP/JSON import with asset embedding and defensive archive checks, My Components management and export, Skia image nodes, `--component-validate` and `--component-render` |
| M5 | Port built-ins one by one with snapshot evidence | **In progress**, split below. Done before M5a: exact native/component parity harness, Decor Solid Color pilots, heart-rate value plus trailing unit in an auto-sized stack |
| M5a | Layout primitives: `symbol`, `alignSelf`, content-sized components with padding, minimum size and background | **Implemented:** heart rate with icon and background matches native exactly at element scale 1, 1.5 and 2 (icon leading) and 1 and 2 (icon top, unit centered below, minimum width); measured bounds drive hit testing |
| M5b | Metric data contract | **Implemented:** `metric(id, unit)` returns host-formatted value/unit/label/short label/icon for every numeric type except Custom Numeric, with every native display unit (including 12-hour clock and date formats); lap pace and running-dynamics signals. String parity with `OverlayValueFormatter` for all 21 metrics × units × sampled times. Deferred: localized labels (native labels are English), Custom Numeric, manual temperature fallback, a speed signal |
| M5c | One generic `studio.numeric` definition with per-metric Overlay Pool presets | Pairwise pixel parity over icon/unit/label/background combinations and scales. Failure is a decision point for a native `textCluster` capability node |
| M5d | Legacy mapping: documented `OverlayStyle` → params conversion, used first by Pool add and bundled templates | Human review of project compatibility; automatic migration of saved projects is a separate decision |
| M5e | Remove native numeric renderers | Depends on the M5d migration decision; separate PR with visual snapshot review |
| M6 | Authoring guide + AI skill + example gallery, CLI fixtures | Community can author without reading Swift; can run in parallel with M5 |

M2 changes the project schema and is subject to the human review rules in
`AGENTS.md` (project-file compatibility) and to visual snapshot approval.

## License And Assets

Examples in this directory are synthetic and attributable to the project under
the repository license. Community components must declare an SPDX license and
document the provenance of bundled images, matching
[`docs/assets-and-licenses.md`](../assets-and-licenses.md). Bundled font files
are out of scope pending a license review.
