# Overlay Components

Status: **Draft.** The format is specified and reviewed-pending; no runtime,
renderer, Inspector generation, CLI or project-schema support exists in the
app yet. See [ADR 0013](../adr/0013-declarative-overlay-components.md) for the
decision and gates.

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
  exposed by `skb_*`.
- Read a versioned, read-only view of activity signals, series, laps,
  intervals, zones, route position and weather results.
- Use three native capability nodes in v0.1: `sparkline`, `progressBar`, `arc`.
- Expose typed params that become HIG-consistent Inspector rows.
- Bundle PNG/JPEG assets with declared licensing.

## What Components Cannot Do

- Execute code, script, load dylibs, or use JavaScriptCore.
- Access the network, files, processes, keychain, or arbitrary clocks.
- Compute intervals, zones, route projection or weather. Those stay in the
  host and are exposed as data.
- Use auto layout, SVG, bundled fonts or nested `repeat`.
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
| M1 | Parser, validator, expression evaluator, compiled render graph, tests | Schema-valid examples load; evaluator unit tests pass |
| M2 | Base + capability nodes through `SkiaEasyRunRenderer`; `.component` element kind | One numeric overlay renders pixel-equivalent to native at fixture times |
| M3 | Params to Inspector generation and `ProjectDocument` undo | Inspector parity with native detail view; undo tests |
| M4 | `.rocomponent` import, embedded definitions, validation errors, CLI | Import/render loop works on synthetic fixtures |
| M5 | Port built-ins one by one with snapshot evidence | Parity approved, then native removal in a separate change |
| M6 | Authoring guide + AI skill + example gallery | Community can author without reading Swift |

M2 changes the project schema and is subject to the human review rules in
`AGENTS.md` (project-file compatibility) and to visual snapshot approval.

## License And Assets

Examples in this directory are synthetic and attributable to the project under
the repository license. Community components must declare an SPDX license and
document the provenance of bundled images, matching
[`docs/assets-and-licenses.md`](../assets-and-licenses.md). Bundled font files
are out of scope pending a license review.
