# Overlay Components

Status: **v0.1 implemented; built-in ports in progress.** The loader, validator,
expression evaluator and resolved draw-tree builder live in
`Sources/RunningOverlay/Components/`. The project schema stores a `component`
element kind (schema version 2), and the shared Skia preview/export renderer
draws instances from embedded or bundled definitions, including image assets.
The Overlay Pool lists bundled components and imports `.rocomponent` packages
(folders or ZIP archives) or component JSON files, manages project definitions
under **My Components** (add, export, remove), the Inspector generates controls
from `params`, and `--component-validate` / `--component-render` cover headless
authoring. **Create with AI…** connects Claude Code, Codex or Claude Desktop
to `RunningOverlay --mcp`, whose drafts appear live under **Drafts** in the
Overlay Pool ([ADR 0016](../adr/0016-ai-component-authoring-mcp.md)). See
[ADR 0013](../adr/0013-declarative-overlay-components.md) for the decision and
gates.

This directory defines how an overlay can be described as data instead of
Swift code, so the community, the maintainer and AI tooling can all author
overlays against the same contract.

## Documents

| Document | Purpose |
|---|---|
| [Authoring Guide](authoring.md) | Create, validate, render and import a component without reading Swift. |
| [AI Authoring Skill](skills/overlay-component-authoring/SKILL.md) | Portable protocol-driven authoring workflow and evaluation prompts. |
| [Spec v0.1](spec-v0.1.md) | Normative format: package, data contract, expressions, nodes, params, persistence, limits, security. |
| [JSON Schema](schema/ros-component-0.1.schema.json) | Machine-readable validation for editors and future import tooling. |
| [Heart Rate Pill](examples/hr-pill.rocomponent.json) | Minimal scalar + series example with params and Inspector controls. |
| [Lap Splits](examples/lap-splits.rocomponent.json) | List + `repeat` example using lap structure. |
| [Weather Card](examples/weather-card.rocomponent.json) | Host-drawn `weatherWidget` node with a data-source selector and `--component-weather`. |

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
  text, so a unit can follow a value whose width changes, override the
  cross-axis alignment of a single child with `alignSelf`, stretch a child
  stack across its parent and push items apart with flexible `spacer` nodes,
  optionally pinning them to a minimum length.
- Lay out equal-width `columns` with an optional vertical divider between
  them, and auto-size `textRows` blocks against a `maxWidth` instead of a
  frame.
- Drive fonts, stack direction and alignment from params through
  expressions.
- Size the whole component from its measured content (`"size": "content"`)
  with padding, a minimum size and a background that follows the content.
- Draw system SF Symbols with the `symbol` node.
- Read a versioned, read-only view of activity signals, series, laps,
  intervals, zones, route position and weather results, including lap pace
  and running dynamics.
- Show any supported numeric reading with host formatting through
  `metric(id, unit)`, which returns the same value, unit and label text as the
  host formatter.
- Reuse computed `value` bindings to evaluate one expression once and share
  the result across several nodes.
- Use generic capability nodes in v0.1, including `sparkline`,
  `progressBar`, `arc` and `segmentedBar`, the last for zone bars and other
  segmented runs with active-segment, orientation and marker support.
- Expose typed params that become HIG-consistent Inspector rows.
- Bundle PNG/JPEG assets with declared licensing.

## What Components Cannot Do

- Execute code, script, load dylibs, or use JavaScriptCore.
- Access the network, files, processes, keychain, or arbitrary clocks.
- Compute intervals, zones, route projection or weather. Those stay in the
  host and are exposed as data.
- Use general auto layout (wrapping, grid, proportional flex), SVG, bundled
  fonts or nested `repeat`. Only one-dimensional stacks with spacers and
  stretch, and content-sized components, are available.
- Design arbitrary Inspector UI.

## Authoring Loop

Follow the [authoring guide](authoring.md): write component JSON, run
`--component-validate`, render through Skia with `--component-render`, inspect
the PNG, then import and check Inspector editing, undo and save/reopen.
Rendering accepts `--component-activity` (FIT/GPX), `--component-at` (activity
elapsed seconds), `--component-params` (a JSON object file),
`--component-weather` (an authored host weather snapshot) and
`--component-output`. The public fixture supplies metrics, series and laps.
Run `./scripts/component-gallery.sh` for the four reproducible examples.

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
- Deferred capability nodes: `areaChart`, `intervalTimeline`, `weatherIcon`,
  `textEffect`.

## Implementation Milestones

| Milestone | Content | Exit gate |
|---|---|---|
| M0 (this draft) | ADR, spec v0.1, schema, examples | Maintainer review of format |
| M1 | Parser, validator, expression evaluator, compiled render graph, tests | **Kernel implemented:** `Sources/RunningOverlay/Components/`; focused tests pass |
| M2 | Base + capability nodes through `SkiaEasyRunRenderer`; `.component` element kind | **Implemented for embedded definitions:** schema v2, canonical digest, Skia path; numeric and solid-color parity established during M5 |
| M3 | Params to Inspector generation and `ProjectDocument` undo | **Implemented:** generated Inspector rows, add/duplicate from the Overlay Pool, clamped/quantized parameter edits with discrete and continuous undo |
| M4 | `.rocomponent` import, embedded definitions, validation errors, CLI | **Implemented:** folder/ZIP/JSON import with asset embedding and defensive archive checks, My Components management and export, Skia image nodes, `--component-validate` and `--component-render` |
| M5 | Port built-ins one by one with snapshot evidence | **In progress**, split below. Done before M5a: exact native/component parity harness, Decor Solid Color pilots, heart-rate value plus trailing unit in an auto-sized stack |
| M5a | Layout primitives: `symbol`, `alignSelf`, content-sized components with padding, minimum size and background | **Implemented:** heart rate with icon and background matches native exactly at element scale 1, 1.5 and 2 (icon leading) and 1 and 2 (icon top, unit centered below, minimum width); measured bounds drive hit testing |
| M5b | Metric data contract | **Implemented:** `metric(id, unit)` returns host-formatted value/unit/label/short label/icon for every numeric type except Custom Numeric, with every native display unit (including 12-hour clock and date formats); lap pace and running-dynamics signals. String parity with `OverlayValueFormatter` for all 21 metrics × units × sampled times. Deferred: localized labels (native labels are English), Custom Numeric, manual temperature fallback, a speed signal |
| M5c | One generic `studio.numeric` definition with per-metric Overlay Pool presets | **Implemented:** bundled `studio.numeric` (46 params) with 21 Pool presets under Metrics; 13 pairwise cases over metric, icon/unit/label positions, alignments, colors, fonts, background, minimum size and element scale 1/1.5/2 match native exactly, so `textCluster` is not needed. Added `spacer`, `stretch`, and expression-driven enum and font fields. Native numeric tiles were replaced in M5d |
| M5d | Replace native numeric overlays | **Implemented without migration (ADR 0014):** bundled templates converted to `studio.numeric` with exact pixel parity; Overlay Pool Metrics lists the numeric presets; saved projects drop native numeric elements on load with a status message |
| M5e | Remove native numeric renderers | **Implemented with M5d:** native types, Skia/SwiftUI renderers, Inspector, numeric-only style fields and setters removed; metric formatting keyed by `OverlayMetric` |
| M5f | Decor shapes, text and icons | **Component ports implemented:** `studio.decor-shape` (24 exact native combinations), `studio.decor-text` (18 exact richText cases) and `studio.decor-icon` (27 exact fitted-symbol cases). Added generic `richText`, `textRows`, multi-shadow group effects and expression-driven symbol weight/scale. Native decor element types were removed without migration (ADR 0015); the shared paragraph rasterizer moved to `SkiaParagraphText`. SVG/user-image selection remains on its compatibility/review gate |
| M5g | Distance Timeline, Elevation Chart, Running Gauge | **Implemented:** `studio.running-gauge` reuses the shared `RunningGaugeLayoutEngine`/`SkiaRunningGaugeRenderer`; 17 native parity cases cover all seven layout presets, ring/tick/divider/glass/cap toggles, hidden labels, monospaced off, zero progress and element scale 1.5. `studio.distance-timeline` reuses the distance layout and Skia renderer; 16 parity cases cover all presets, axis and distance-point labels, markers and marker labels, ticks, label/value visibility, imperial units, fade and element scale 1.5. `studio.elevation-chart` reuses the elevation layout and Skia renderer; 17 parity cases cover all presets, area/line, progress mode, grid, marker toggles and scale, fill off, smoothing off, background off, axis off, glow and element scale 1.5. All chart renderers now receive an effect-free element so the host applies opacity/shadow/glow exactly once. |
| M5h | Interval Countdown, Work Summary, HUD Bar, Timeline, Zone Edge Bar | **In progress:** `studio.interval-countdown` (native element type removed, ADR 0015) consumes `structure.segment` for phase, rep, remaining/elapsed time and distance, ring progress in both directions, per-role text visibility and typography, background/border and effect chains. Native comparison covers warmup/active/rest, both directions, distance/elapsed values, hidden roles, background and element scale 1–2; remaining difference is a sub-0.25% antialias fringe at ring edges (mean channel delta under 0.13). `studio.interval-work-summary` (native element type removed, ADR 0015) matched native exactly across metric/unit combinations, column visibility, label visibility, background with element shadow, and element scale 1.5, using auto-sized `textRows`, `columns` with dividers and `field()`; it relies on the host's element-level shadow/glow instead of re-creating them. `studio.interval-hud-bar` matches native across lap progress, HR and pace zone bars, marker and threshold marker states, HR-drop-at-rest and element scales, using the new generic `segmentedBar` node and lazy `value` bindings. `studio.zone-edge-bar` matches native across HR and pace metrics, horizontal and vertical bars, free and edge placements, marker above/below/leading/trailing, marker and threshold size scales, active-zone widening, glow, border and element scale 1.5, reusing `segmentedBar` with vertical orientation and outside-layout markers; it cannot yet reproduce the host's edge auto-pinning, so its position stays author-controlled. `studio.interval-timeline` matches native across centered and full-schedule modes, equal and duration layouts, warmup/work/rest states, neighbor and current label modes, live-progress and centered markers, overflow hints, rep counters, kind filters, element scale 1.5 and background/border, using the new `timelineStrip` capability node |
| M5i | Route Map and Weather Widget | **Implemented for route and weather nodes:** `studio.route-map` reuses `SkiaRouteMapModule` with the host render-asset store; 8 native parity cases cover square and circle containers, hidden markers, border/background toggles, custom corner radius, element scale 1.5 and a late playhead. `studio.weather-widget` reuses `SkiaWeatherWidgetModule` and adds the host weather snapshot: `weather.current` reports the payload (`temperatureC`, `condition`, `icon`, `windSpeedMPS`, `humidity`), the node's `dataSource` param selects manual or an API source, and host snapshots live in a project-level cache shared by every weather component (one fetch per project, persisted with the project), with manual values as the fallback. native parity cases cover the single card template, condition and icon toggles, location/weekday visibility, Fahrenheit, palettes, metric slots, a flat card, FIT temperature, a host snapshot, element scale 1.5 and a late playhead; the only difference is an alpha-only fringe where the component clip trims the module's card shadow. Both native element types and their Inspectors were removed without migration (ADR 0015); the bundled templates are fully component-authored, and the route-map node now exposes the native border, edge-fade, gradient, zoom, POI and typography controls. Charts and maps no longer draw attached stats bars: `studio.stats-bar` is a standalone component with up to four host-formatted metric slots that users place freely. |
| M6 | Authoring guide + AI skill + example gallery, CLI fixtures | **Implemented:** authoring guide and portable skill; strict CLI parameter overrides, FIT/GPX activity and elapsed-time inputs, and `--component-weather` authored snapshots; reproducible scalar/series/list/weather gallery with synthetic fixtures |

M2 changes the project schema and is subject to the human review rules in
`AGENTS.md` (project-file compatibility) and to visual snapshot approval.

## License And Assets

Examples in this directory are synthetic and attributable to the project under
the repository license. Community components must declare an SPDX license and
document the provenance of bundled images, matching
[`docs/assets-and-licenses.md`](../assets-and-licenses.md). Bundled font files
are out of scope pending a license review.
