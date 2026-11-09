# Authoring Overlay Components

A component is JSON, not Swift or executable code. The same format powers
bundled and imported overlays; `params` generates the Inspector. Start with
[Metric Card](examples/metric-card.rocomponent.json), then use the
[specification](spec-v0.1.md) and [schema](schema/ros-component-0.1.schema.json)
for the full vocabulary. No Swift source reading is needed to author one.

## Authoring with an AI client in the app

App users author components with the AI client they already have. Overlay Pool
› Components › **Create with AI…** shows the steps for Claude Code, Codex,
Claude Desktop, or any chat app. MCP clients connect once to the app
executable as a local stdio server:

```sh
claude mcp add running-overlay -- \
  "/Applications/Running Overlay Studio.app/Contents/MacOS/RunningOverlay" --mcp
```

The server (`RunningOverlay --mcp`) offers `get_authoring_guide` (this guide,
the specification, the schema and the short workflow), `list_examples`,
`get_example`, `list_metrics`, `validate_component`, `render_component` and
`save_draft` / `list_drafts` / `get_draft`. `render_component` returns a PNG
drawn by the app's renderer from a synthetic 12-minute interval workout
(warmup 0–60 s, work 60–300 s, rest 300–360 s, work 360–600 s, rest 600–660 s,
cooldown 660–720 s) with a fictional route and fixed sample weather. It never
reads the user's projects or activities and never reaches the network.

`save_draft` writes `<name>.json` into the drafts folder
(`Application Support/RunningOverlay/ComponentDrafts`, inside the app
container in sandboxed builds). Invalid documents and ids in the reserved
`studio.` namespace are rejected. Drafts appear under Overlay Pool ›
Components › **Drafts**. Adding one embeds its definition in the project. When
the same draft is saved again while the app runs, placed instances with that
component id switch to the new definition as one undo point and keep their
parameter values. Hand-written drafts (`.json` files or `.rocomponent`
folders) in the same folder are listed too; invalid ones show their
diagnostics. Without MCP, the sheet copies a self-contained prompt and saves
pasted JSON as a draft. See
[ADR 0016](../adr/0016-ai-component-authoring-mcp.md).

## First render

From the repository root, build with `swift build`. Validation works without
Skia. PNG rendering requires a Skia build: configure the SDK as described in
[Skia development](../development/skia-sdk.md), then build with those same
`SKIA_DIR` / `SKIA_GPU` settings. For an installed app, replace
`.build/debug/RunningOverlay` with its `Contents/MacOS/RunningOverlay` executable.

```sh
.build/debug/RunningOverlay --component-validate \
  docs/overlay-components/examples/metric-card.rocomponent.json
.build/debug/RunningOverlay --component-render \
  docs/overlay-components/examples/metric-card.rocomponent.json \
  --component-activity Tests/RunningOverlayTests/Fixtures/Activities/synthetic-component-run.fit \
  --component-at 30 \
  --component-params docs/overlay-components/examples/params/metric-card.json \
  --component-output /tmp/metric-card.png
```

When a ported built-in needs a native constant that does not scale with the
element, such as a fixed 8-point gap, divide it by `signal("host.scale")`
(`=8 / signal("host.scale")`) so it stays pixel-faithful at every element
scale. Signal paths are read with `signal(...)` or a declared binding; they are
not free identifiers.
`--component-at` is nonnegative **activity elapsed seconds**, never video or
project time. Samples beyond the activity end clamp to the activity duration.
Omit the activity argument to check missing-data placeholders. FIT and GPX use
the same parsers as the app. The command never fetches weather or maps.

`--component-weather` reads a JSON object describing the host weather snapshot
for host-drawn weather nodes: `condition` (the `weather.current` condition
name), `temperatureC`, and optional `humidity`, `highC`, `lowC`, `windKph`,
`feelsLikeC` and `location`. It never reaches the network, so an
`openMeteo`/`openWeather` data source renders exactly those authored values:

```sh
.build/debug/RunningOverlay --component-render \
  docs/overlay-components/examples/weather-card.rocomponent.json \
  --component-weather docs/overlay-components/examples/weather/osaka-afternoon.json \
  --component-output /tmp/weather-card.png
```

`--component-params` reads a JSON object mapping parameter IDs to JSON values.
Omitted IDs keep their declared defaults. Unknown IDs, wrong types, invalid
colors, out-of-range numbers, overlong strings and undeclared enum/metric
options fail the command. The normal app persistence path remains tolerant of
stale values. `--component-scale 2` requests two pixels per design unit; the
renderer caps scale when necessary to fit its reference canvas. The output is
a transparent PNG cropped to the measured component bounds. In the app,
content-sized components allow a 16-design-unit ink outset around those bounds;
the CLI crop intentionally excludes that outset, so overhanging glyph ink can
be cropped in the PNG. Use explicit padding when exporting a standalone image. Evaluation diagnostics print to stderr; validation
or rendering errors return a nonzero exit status.

## Build a component

1. Copy an example to a new JSON file. Replace the copied example's ID and author metadata. Choose an ID outside the
   reserved `studio.` namespace, a semantic version, a name and an SPDX license.
2. Use a fixed `size: [width, height]`, or `size: "content"` with optional
   `padding: [x, y]` and `minSize: [width, height]`. Units are design units on
   the host's 1280×720 reference canvas. Fixed sizes clip; content sizing needs
   measurable top-level nodes. Avoid `width`/`height` builtins in content sizing
   because they would make measurement circular.
3. Declare editable values in `params`: number, bool, color, enum, string,
   font or metric. Provide defaults and labels; use sections, descriptions,
   `advanced` and `when` for larger Inspectors. Node fields reference parameter
   IDs directly, for example `"color": "=accent"`.
4. Read data through bindings: `signal` for a scalar/record, `series` for a
   sampled window, `list` for laps/intervals. Use `metric("pace").value` and
   `.unit` for host formatting; use raw `activity.pace` when doing arithmetic.
   Raw pace is seconds/km. Lap lists contain the whole activity in source lap
   order, including laps after the playhead; FIT indices start at zero. Use the
   repeat index plus one for display row numbers. Missing data is null: use `coalesce` or `if` rather
   than assuming a sensor is present. The spec lists exact paths and units.
5. Compose nodes. Auto-sized `text` and horizontal/vertical `stack` handle
   variable text widths; `alignSelf` overrides a child's cross alignment.
   `spacer` shares remaining space in a constrained stack; give it `min` when
   a narrow window must keep a minimum gutter. Auto-sized `textRows` take
   `maxWidth` instead of a frame. `columns` lays children out in equal widths
   with an optional divider. Use `group` and
   explicit frames for graphics. Group/repeat frames bound effects and clipping;
   their children still use component coordinates, so include the row origin
   in each child frame (as Lap Splits does); `symbol` needs a frame and an SF Symbol name.
   `repeat` expands bounded list rows; nested repeats are unsupported.
6. Validate, render with default and overridden parameters, inspect the PNG,
   and revise. Check start/middle/end, empty activity, long text and layout
   toggles. Rendering is not a substitute for inspecting the result.

Validation reports JSON-pointer paths, such as `$.nodes[0].font.size`.
Fix the first structural error, validate again, then address evaluation
warnings. A name error often means a parameter or binding was misspelled.
An empty graph can mean the signal is null, a condition is false, or the
series window contains no samples. Use the reference examples to isolate the
failing feature. Do not invent nodes, signal paths or expression functions.

## Reproducible gallery

Run the repository command after building with Skia:

```sh
./scripts/component-gallery.sh
```

It validates all four examples and renders sixteen PNGs (empty activity and
0/30/60 seconds with parameter overrides) into a temporary directory. Optional
arguments select a binary and output directory. Inputs are authored JSON plus
a generated FIT file with three records and three laps; there are no real GPS
traces, credentials, downloads or API calls.

| Example | What to learn | Parameter experiment |
|---|---|---|
| [Metric Card](examples/metric-card.rocomponent.json) | Host formatting, content sizing, stacked text | Pace and a longer title |
| [Heart Rate Pill](examples/hr-pill.rocomponent.json) | Scalar, zone fallback, a recent series | Accent, radius, trend visibility |
| [Lap Splits](examples/lap-splits.rocomponent.json) | List binding, bounded repeat, row offsets | Title and visible row count |
| [Weather Card](examples/weather-card.rocomponent.json) | Host-drawn `weatherWidget` capability node with a data-source selector | Preset, unit, palette and metric slots |

The larger bundled [Numeric component](../../Sources/RunningOverlay/Resources/Components/numeric.json)
shows production parameter sections, unit families, conditional controls and
expression-driven layout. Bundled files are read-only in the app.

## Import and edit

In Overlay Pool → Components, import the JSON or a `.rocomponent` folder/ZIP
containing `component.json` and declared image assets. Use My Components to
add instances, export the package or remove an unused definition. To customize
a bundled definition, duplicate it into an editable project component first.
Parameters edit instances; changing the component definition is an external
JSON edit followed by import. Give a changed definition an appropriate version.

After import, change parameters, undo/redo, duplicate the instance, save the
project, close and reopen it. Confirm the values and appearance survive. A
project embeds imported definitions and assets; it must not depend on the
original author's filesystem. Preview and export use the same Skia component
renderer. Component CLI rendering writes a PNG, not a video export.

## Display text and effect chains

`text` is single-line CoreText text with optional measurement; `richText` is a
wrapped paragraph. `textRows` lays out a vertically centered stack of
single-line runs and shrinks each run or row to fit, which is what the interval
countdown uses for helper, phase/rep, center value and caption. Rows and runs
support `if`, so parameter-driven visibility removes them from layout instead
of leaving a gap.

A `group` accepts one `shadow` or a `shadows` array. Each shadow has `sigma`,
`dx`, `dy`, `color` and optional `opacity`; zero-alpha entries are skipped.
`shadowBounds` controls the layer extent when a blur must paint outside the
group frame. Group shadows are for effects inside the design, such as a ring
glow.

The Inspector's element shadow, glow and opacity are host state: the host
applies them around the whole component before drawing its nodes. Do not
re-create the element drop shadow or glow inside a definition, or a ported
built-in draws two of them. The bundled interval components rely on the host
for those effects.

## Package boundaries

Only PNG/JPEG assets are supported; declare licenses and provenance. Fonts
use installed families; font files cannot be bundled. Components cannot
execute scripts, read files, access the network or compute their own weather,
zones or route projection. See the spec for limits and currently available
capabilities. If a design needs an unsupported feature, state the gap before
adding a native dependency or changing the protocol.

For an AI-assisted workflow, use the portable
[component authoring skill](skills/overlay-component-authoring/SKILL.md).
