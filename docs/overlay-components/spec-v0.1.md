# Overlay Component Format v0.1 (Draft)

Status: **Draft for review.** The runtime kernel implements parsing,
validation, expression evaluation and resolved draw-tree construction under
`Sources/RunningOverlay/Components/`. A `component` overlay element kind now
persists instances in projects (project schema version 2) and renders through
the shared Skia preview/export renderer, including image assets. The Inspector
is generated from `params`, the Overlay Pool imports `.rocomponent` folders,
ZIP archives and component JSON files and manages project definitions, and
`--component-validate` / `--component-render` provide a headless authoring
loop. Bundled components are read-only and
resolved by id, version and digest. This document defines the format; ADR 0013
records the decision and gates.

- Specification identifier: `ros.component/0.1`
- Package extension: `.rocomponent`
- JSON Schema: [schema/ros-component-0.1.schema.json](schema/ros-component-0.1.schema.json)
- Authoring: [guide](authoring.md), including CLI activity/time/parameter inputs.
- Examples: [Metric Card](examples/metric-card.rocomponent.json),
  [examples/hr-pill.rocomponent.json](examples/hr-pill.rocomponent.json),
  [examples/lap-splits.rocomponent.json](examples/lap-splits.rocomponent.json)

Keywords MUST, MUST NOT, SHOULD and MAY are used as in RFC 2119.

## 1. Scope

This specification defines how an overlay is described as data, which host
data a component may read, how it is drawn, how its Inspector controls are
derived, and how it is validated and stored in a project.

A v0.1 component is a pure function of:

- its params (edited by the user in the Inspector),
- the host data available at the playhead, and
- its bundled image assets.

The same component definition MUST render identically in preview and export.

### Non-goals for v0.1

- Executable code, scripts, plugins, dylibs, or network access.
- General auto layout (wrapping, grids, constraint solving). One-dimensional
  stacks, spacers, stretch and content sizing are supported.
- SVG, video, or bundled font files. Images are PNG or JPEG; fonts come from
  the host font library.
- User-defined functions, loops other than `repeat`, or mutable state.
- Author-designed Inspector layout beyond sections and control types.
- Animation authored inside a component. The host's element-level opacity and
  future element animation remain host concerns.
- Map tiles, weather fetching, interval detection, or zone computation inside
  a component. These are host data or host capability nodes.
- A marketplace, signing authority, or automatic updates.

## 2. Package Format

A `.rocomponent` package is a ZIP archive or a directory with exactly this
shape:

```
heart-pill.rocomponent/
  component.json        # required, UTF-8 JSON
  assets/
    heart.png           # optional
    ...
```

Rules:

1. `component.json` MUST be at the package root and MUST NOT exceed 1 MiB.
2. Asset paths MUST match `assets/[A-Za-z0-9._-]+\.(png|jpg|jpeg)` and MUST NOT
   escape the package via `..`, absolute paths, or symlinks.
3. Uncompressed package size MUST NOT exceed 32 MiB; assets MUST NOT exceed
   32 files or 8 MiB each.
4. Importing a package is an explicit user action. The host MUST NOT download
   packages automatically.
5. The host computes a SHA-256 digest over the canonical `component.json`
   bytes. Digests are recorded in project instances.

## 3. Component Document

```json
{
  "spec": "ros.component/0.1",
  "id": "studio.builtin.heart-rate-pill",
  "version": "1.0.0",
  "name": "Heart Rate Pill",
  "description": "Current heart rate with a 60-second trend.",
  "author": "Running Overlay Studio",
  "license": "MIT",
  "size": [240, 72],
  "background": { "color": "transparent" },
  "params": [],
  "bindings": {},
  "nodes": []
}
```

| Field | Required | Meaning |
|---|---|---|
| `spec` | yes | Exactly `ros.component/0.1`. |
| `id` | yes | Dot-separated namespace, `[a-z0-9]+(\.[a-z0-9-]+)+`. `studio.` is reserved for components bundled with the app. |
| `version` | yes | Semantic version `MAJOR.MINOR.PATCH`. |
| `name` | yes | String or localized map (section 4). |
| `description` | no | String or localized map. |
| `author` | no | Display name of the author or organization. |
| `license` | yes | SPDX identifier, for example `MIT`, `Apache-2.0`, `CC-BY-4.0`. |
| `homepage` | no | `https` URL. |
| `size` | yes | `[width, height]` design units, each 8..8192, or `"content"` to size the instance from its measured nodes (section 4.1). |
| `padding` | no | `"content"` only. `[x, y]` design units added on each side of the measured content. Numbers or expressions; default `[0, 0]`. |
| `minSize` | no | `"content"` only. `[width, height]` minimum inner (unpadded) size. Numbers or expressions; default `[0, 0]`. |
| `background` | no | Optional card behind all nodes: `{ "color": "#RRGGBBAA", "radius": 0 }`. For `"content"` it fills the padded bounds. |
| `params` | no | Inspector controls (section 9). |
| `bindings` | no | Named data reads (section 6). |
| `nodes` | yes | Draw list, rendered in array order (section 7). At most 512 nodes. |

Unknown top-level fields MUST be rejected when authoring or importing.
Unknown fields inside a project instance's saved params MUST be preserved but
ignored by an older host.

### Localized text

Anywhere a label or name is allowed, the value is either a string or an object
keyed by BCP-47 language tag:

```json
"name": { "en": "Heart Rate Pill", "zh-Hans": "心率胶囊" }
```

An object MUST contain `en`. Resolution order: exact tag, language-only tag,
`en`, first entry.

## 4. Coordinates And Placement

- All component coordinates and sizes are **design units** in the component's
  own space, with origin at the top-left of `size`.
- The host scales the component by
  `element.scale × min(canvasWidth / 1280, canvasHeight / 720)`, matching the
  existing `OverlayRenderContext.canvasScale` reference canvas of 1280×720.
- The instance is positioned by the existing normalized `positionX` /
  `positionY` top-left anchor and clipped to its own bounds. A node or asset
  MUST NOT paint outside the component rectangle.
- Frames are `[x, y, width, height]`. Negative coordinates are allowed but
  clipped. Coordinates MUST be finite and within ±32768.
- Drawing order is array order. There is no z-index.

### 4.1 Content-sized components

`"size": "content"` lets an instance grow and shrink with its values, for
example a numeric readout whose width changes from `99` to `130`.

- The content box spans from the design origin to the farthest right and
  bottom edge of the top-level nodes' boxes. Every top-level node MUST have a
  box: a `frame`, or be `text`/`stack` (measured). `circle`, `line`,
  `polyline` and `path` MUST be wrapped in a framed group.
- The inner size is `max(content, minSize)`; the instance bounds are the inner
  size plus `padding` on each side. Content keeps its top-leading origin inside
  the padding when `minSize` is larger.
- Measurement runs at render pixel size, like `stack`, so the bounds follow
  the playhead. The host uses these bounds for the background, element-level
  effects, hit testing and selection.
- Rendering is clipped to the bounds outset by 16 design units on each side,
  so glyph ink that overhangs the typographic box (negative tracking, italic
  shapes) is not cut. Hit testing uses the bounds without the margin.
- `width` and `height` are undefined for a content-sized component; an
  expression that reads them is a validation error.
- Padding, minimum size and background radius scale with the element like
  every other design unit.

## 5. Data Contract

Components read host data through bindings (section 6) or the `signal` /
`series` builtins (section 8). The contract is versioned with this
specification. Every value is read-only and derived from the project timeline
at **activity elapsed time**, the same time domain used by
`ActivityTimeline` accessors. Components MUST NOT expect media source time,
project timeline time, or render-frame time.

Missing data resolves to `null`; it is never an error.

### 5.1 Signals (value at the playhead)

| Path | Type | Unit / meaning |
|---|---|---|
| `activity.duration` | number | total activity elapsed seconds |
| `activity.totalDistance` | number | total activity distance in meters |
| `activity.elapsed` | number | seconds of activity elapsed time |
| `activity.remaining` | number | seconds remaining |
| `activity.distance` | number | meters |
| `activity.heartRate` | number? | bpm |
| `activity.pace` | number? | seconds per kilometer |
| `activity.avgPace` | number? | seconds per kilometer |
| `activity.elevation` | number? | meters |
| `activity.elevationGain` | number? | meters |
| `activity.cadence` | number? | steps per minute |
| `activity.power` | number? | watts |
| `activity.grade` | number? | percent |
| `activity.temperature` | number? | degrees Celsius |
| `activity.calories` | number? | kilocalories |
| `activity.lapPace` | number? | seconds per kilometer in the current lap |
| `activity.verticalOscillation` | number? | millimeters |
| `activity.groundContactTime` | number? | milliseconds |
| `activity.strideLength` | number? | meters |
| `activity.verticalRatio` | number? | percent (oscillation ÷ stride) |
| `activity.groundContactBalance` | number? | percent on the left foot |
| `clock.realTime` | number? | seconds since local midnight at the playhead |
| `clock.date` | string? | ISO-8601 date at the playhead |
| `host.canvasWidth` | number | project canvas width in pixels |
| `host.canvasHeight` | number | project canvas height in pixels |
| `host.scale` | number | `element.scale × canvasScale`; read it with `signal("host.scale")` and divide a pixel-faithful constant by it to express that constant in design units |

### 5.2 Records

| Path | Fields |
|---|---|
| `zone.heartRate` | `index` (1-based), `count`, `label` (`Z2`), `color` (`#RRGGBBAA`), `lower`, `upper` bpm; `null` when zones are not configured |
| `zone.pace` | same shape for pace zones, values in seconds per kilometer; `null` when unavailable |
| `structure.currentLap` | `index`, `elapsed`, `distance`, `avgPace`, `avgHeartRate`, `maxHeartRate`, `avgCadence`, `avgPower`, `kind`; `null` before the first lap |
| `structure.current` | `index`, `phase` (`warmup`, `active`, `rest`, `cooldown`), `elapsed`, `duration`, `remaining`, `progress` (0..1); `null` for unstructured activities |
| `route.current` | `lat`, `lon`, `distanceFraction` (0..1), `elevation`; `null` when the activity has no GPS |
| `weather.current` | `temperatureC`, `condition`, `icon`, `windSpeedMPS`, `humidity`; `null` when weather is unavailable |
| `host` | `canvasWidth`, `canvasHeight`, `scale` |

Record fields resolve to `null` when the record is absent. `kind` and `phase`
are strings.

### 5.3 Series and lists

- A **series** is a bounded, evenly spaced sample array of numbers or nulls.
  The host samples by activity elapsed time; a component cannot request raw
  timestamps or arbitrary interpolation.
- `activity.*` numeric signals listed in 5.1 MAY be requested as series.
- `structure.laps` and `structure.intervals` are lists of records with the
  fields in 5.2 plus `index`; they are usable with `repeat`.

### Workout and zone records

All times below are **activity elapsed seconds**. Lap lists contain the whole
activity in source order, including future laps at the playhead. `index` is
the raw source lap index (zero-based for imported FIT). Use repeat indices for
presentation row numbers. Lap records also provide `startElapsed`, `endElapsed`,
`startDistance` (meters) and `totalAscent` (meters or null).

`structure.current` retains its structured-workout-only semantics.
`structure.segment` is available for normal and structured activities, using
the native current lap or an activity-level fallback:

- `index` (number or null), `startElapsed`, `endElapsed`, `startDistance`;
- `phase`, `phaseText` (`WU`, `WORK`, `REST`, `CD`, `LAP`), `groupColor`,
  `phaseColor` (active laps follow the resolved zone; others the group);
- `elapsed`, `duration`, `remaining`, `timeProgress`, `distanceProgress`;
- `distance`, `elapsedDistance`, `remainingDistance` (meters);
- `elapsedText`, `remainingText`, `elapsedDistanceText`, `remainingDistanceText`;
- `repIndex` (one-based or null), `repCount`, `repText`.

Without a source lap, time/distance values use the activity fallback and
`endElapsed` is `max(activity.duration, 1)`. Both progress fields stay zero,
matching native `lapProgress`; do not infer them from elapsed/duration.

`structure.lastWork` is null until an active lap has ended. At its exact end
boundary it becomes that lap's record, plus `completionAge` and `groupColor`.
Its `metrics.metric` and `metrics.imperial` records contain `lapTime`,
`lapPace`, `lapDistance`, `avgHeartRate`, `maxHeartRate`, `avgPower` and
`avgCadence`, each a host-formatted `{ value, unit, label }` record.
Summary visibility uses `completionAge >= 0 && completionAge <= displayDuration`.
`structure.recovery` exposes `peakHeartRate`, `drop` and `dropPercent`, each
nullable, using the native current-lap recovery queries. Seeking is stateless.

`zone.heartRateZones` and `zone.paceZones` are lists of all configured visible
zone slots, including empty slots, or null without a snapshot. Each record has
`index` (one-based), `count`, `label`, `color`, `lower` and `upper` (nullable).
Active `zone.heartRate` and `zone.pace` additionally provide `fraction` (0..1),
`value` and `valueText`. Matching uses inclusive boundaries and the first
matching visible slot; fractions default to 0.5 for open/degenerate bounds.
`zone.current` prefers HR, then positive pace. `zone.heartRateThreshold` and
`zone.paceThreshold` have the same active-value shape, with `valueText: "T"`,
or null when the threshold cannot be resolved. Zone values use bpm or seconds/km.
These totals are scalar signals, not resampled time series.

### 5.4 Formatted metrics

`metric(id, unit...)` returns the host-formatted reading that a native numeric
overlay shows, as a record of strings: `value`, `unit`, `label`, `shortLabel`
and `icon` (the default SF Symbol name). Formatting, rounding, placeholders
(`--`, `--'--"`) and unit conversion are the host's, so a component and a
native overlay always show the same text. Use `signal` for raw numbers and
`metric` for display text.

| `id` | `unit` values (first is the default) |
|---|---|
| `heartRate` | `bpm` |
| `heartRateZone` | none |
| `pace`, `avgPace`, `lapPace` | `paceMetric`, `paceImperial`, `paceRowing` |
| `distance` | `distanceKilometers`, `distanceMiles`, `distanceMeters` |
| `elevation`, `elevationGain` | `elevationMeters`, `elevationFeet` |
| `cadence` | `spm` |
| `power` | `watts` |
| `calories` | `kcal` |
| `elapsedTime` | `durationHMS`, `durationMS`, `durationSeconds` |
| `realTime` | `clock24Hour`, `clock12Hour` |
| `date` | `dateYMDHyphen`, `dateYMDSlash`, `dateMDYSlash`, `dateMDHyphen`, `dateMDSlash`, `dateMonthDay` |
| `verticalOscillation` | `oscillationCentimeters`, `oscillationMillimeters` |
| `groundContactTime` | `contactTimeMilliseconds` |
| `strideLength` | `strideLengthMeters` |
| `verticalRatio` | `verticalRatioPercent` |
| `groundContactBalance` | `balancePercent` |
| `temperature` | `temperatureCelsius`, `temperatureFahrenheit` |
| `grade` | `gradePercent` |

- Each `unit` argument is a candidate; the first one the metric supports is
  used, otherwise the metric's default. Unit names are disjoint across metric
  families, so a generic component can pass one unit param per family:
  `metric(id, paceUnit, distanceUnit, ...)`. Literal ids and units are
  validated; an unknown id at runtime returns `null`.
- `realTime` and `date` use the playhead's wall-clock time in the host's time
  zone. `temperature` reads FIT temperature only; the native manual fallback
  is not part of the contract.
- Labels are the host's English labels, matching native overlays. Localized
  labels are a later addition.
- Custom Numeric is not a metric; its field, format and precision choices are
  not part of v0.1.

## 6. Bindings

Bindings give data reads stable names and tell the host which data the
component depends on.

```json
"bindings": {
  "hr":     { "signal": "activity.heartRate" },
  "zone":   { "signal": "zone.heartRate" },
  "recent": { "series": "activity.heartRate", "window": [-60, 0], "samples": 60 },
  "laps":   { "list": "structure.laps" }
}
```

- `signal` takes a path from 5.1 or 5.2.
- `series` takes an `activity.*` path, `window` in activity seconds relative
  to the playhead (`"full"` for the whole activity), and `samples` 2..1024.
  Windows are clamped to the activity.
- `list` takes `structure.laps` or `structure.intervals`.
- `value` is a computed binding: `{ "value": "=expression" }` evaluates the
  expression once per resolve and stores the result under that name. Computed
  bindings may reference params, signal/series/list bindings and other computed
  bindings, which are evaluated first; reference cycles resolve to null.
- A binding name MUST be unique, match `[A-Za-z_][A-Za-z0-9_]*`, and MUST NOT
  shadow a builtin name.
- The host MAY use bindings to preload or cache data. A component MUST NOT
  assume a binding was read when computing anything.

## 7. Nodes

Every node has:

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | One of the node types below. |
| `id` | no | Unique within the component; for diagnostics. |
| `frame` | depends | `[x, y, width, height]`. Numbers or expressions. Required for `rect`, `image`, `symbol`, `gradientRect`, `richText`, `sparkline`, `progressBar`, `arc`, `segmentedBar` and `repeat`; optional for `text` (measured when absent), `textRows` (measured when absent; then `maxWidth` is required) and `stack`; optional for `group`, `line`, `circle`, `polyline` and `path`, whose geometry is explicit. |
| `if` | no | Expression. The node is skipped when the result is falsey. A skipped stack child takes no space. |
| `opacity` | no | Number 0..1 or expression, multiplied into the node. |
| `clip` | no | `group` only, default `false`. Clips children to the group frame. |
| `alignSelf` | no | Direct `stack` children only: `start`, `center`, `end` or `stretch`, overriding the stack's `crossAlign` for this child. |

Any numeric field accepts a JSON number or an expression string beginning with
`=`. Color fields accept `#RRGGBB`, `#RRGGBBAA`, `transparent`, or an
expression string. `stack.direction`, `stack.crossAlign`, `alignSelf`,
`font.family` and `font.weight` accept their literal value or an expression
returning it, so params can drive them; a literal outside the allowed values
is a validation error, and an expression result outside them falls back to
the field's default with a diagnostic.

### 7.1 Base nodes

These map directly to primitives in `Sources/CSkiaBridge/include/skia_bridge.h`.

| Type | Fields |
|---|---|
| `rect` | `fill` (color), `radius` (default 0), `stroke?`, `strokeWidth?` |
| `circle` | `center` `[x, y]`, `radius`, `fill?`, `stroke?`, `strokeWidth?` |
| `line` | `from` `[x, y]`, `to` `[x, y]`, `width`, `color`, `cap` (`butt`, `round`, `square`) |
| `polyline` | `points` (array of `[x, y]` or expression), `width`, `color`, `cap`, `join`, `dash` `[length, gap]?` |
| `path` | `commands` (array; see below), `fill?`, `stroke?`, `strokeWidth?`, `cap`, `join`, `dash?` |
| `text` | `text` (string or expression), `font` (section 7.3), `color`, `align` (`left`, `center`, `right`, default `left`), `verticalAlign` (`top`, `center`, `bottom`, default `top`), `maxWidth?`, `lineHeight?` (multiplier, default 1.2), `tracking?` (extra advance per glyph in design units, default 0; negative tightens). `frame` is optional; without it the node is auto-sized from its measured lines. |
| `image` | `asset` (`assets/...`), `fit` (`fill` or `contain`, default `contain`), `opacity?` |
| `symbol` | `name` (SF Symbol name or expression), `color`, `weight` (font weight or expression, default `medium`), `scale` (`small`/`medium`/`large` or expression, default `medium`), `rendering` (`glyph`/`fit`, default `glyph`) |
| `gradientRect` | `radius?`, `stops` (2..8 `{ "offset": 0..1, "color": "#..." }`), `from` `[x, y]`, `to` `[x, y]` |
| `group` | `children` (array of nodes), `frame?`, `clip`, `shadow?`, `shadows?` (2..8 shadows), `shadowBounds?` (frame for the shadow layer), `opacity?` |
| `stack` | `children` (array of nodes), `direction` (`horizontal`, default, or `vertical`), `spacing?` (default 0), `crossAlign` (`start`, default, `center`, `end`, `stretch`), `frame?`, `opacity?` |
| `spacer` | `length?`, `min?`. Stack children only; no `frame`. With `length` a fixed gap, without it flexible. `min` pinning keeps a flexible spacer at least that long before the rest of the leftover is shared. |
| `columns` | `width`, `divider?` (`{ "width": number, "color": color, "opacity?": number, "height": number }`), `children` (array of nodes). Children are laid out in equal-width columns along the row; a divider of the given width and height is drawn between them while more than one child is present. |

`path.commands` entries:

```json
["M", 0, 0], ["L", 100, 0], ["Q", 50, 40, 100, 80],
["C", 10, 20, 30, 40, 50, 60], ["A", 50, 50, 30, 0, 180], ["Z"]
```

`A` is `[cx, cy, radius, startDegrees, sweepDegrees]`. Coordinates may be
expressions.

`group.shadow` is `{ "sigma": number, "dx": number, "dy": number, "color": color,
"opacity?": number }` and applies to the composited group, using a shadow
layer. `group.shadows` adds a multi-shadow chain for effects that need layered
glows; when both are present the single `shadow` is first. `opacity`
multiplies the color alpha. `shadowBounds` sets the pixel-space layer extent
when blur must paint outside the group frame; it defaults to the group frame.
Zero-alpha shadows are skipped, matching native effect-chain filtering.

Text is a single draw per line. `text` MAY contain at most 8 `\n`-separated
lines. Text is laid out with the host's CoreText metrics and the same font
resolution rules as existing overlays; `maxWidth` enables host-side fitting
without changing font size. `tracking` adds a fixed advance per glyph in design
units and is applied as CoreText kerning; negative values tighten. When `frame`
is omitted, the text node measures its lines and reports that as its intrinsic
size. The renderer clips to the component rectangle, so leave padding around
glyphs whose ink can overhang the typographic line box.

`symbol` draws a system SF Symbol tinted with `color`. The glyph's point
size equals the shorter frame edge, and the glyph is centered in a square of
that edge inside the frame, matching native numeric overlay icons. `name` is a
lowercase dot-separated token (`heart.fill`, `figure.run`) of at most 128
characters; a literal that does not match is a validation error, and an
expression result that does not match skips the node with a diagnostic. An
unknown but well-formed name draws nothing. Symbols are rendered by the host
and are not bundled assets. The default `rendering: "glyph"` retains the
numeric-icon behavior above and ignores `scale`. `rendering: "fit"` uses the
host decor-symbol rasterizer: point size is 92% of the shorter edge, the chosen
symbol scale is applied, and the result is aspect-fitted into the full frame.
`weight` accepts all nine system weights, including `thin`. Invalid enum
expression results emit diagnostics and use their defaults. The bundled
`studio.decor-icon` definition exposes this fitted-symbol mode; user SVG and
image selection remain on the native Decor Icon until package asset inputs
have a reusable authoring contract.

Element-level Inspector effects (element opacity, the inspector drop shadow and
glow) are host state and are applied by the host around the whole component
before its nodes are drawn. A definition MUST NOT recreate them with group
shadows; group shadows are for design-internal effects such as a ring glow, and
the host shadow is what makes a ported built-in match its native module.

`stack` lays children out in order along one axis using each child's box size.
A child's box is its `frame` size unless the child is a `text` node without a
frame (measured lines) or a `stack` without a frame (its own content). Child
`frame` origins are ignored for placement; the stack assigns positions. Every
other child MUST declare a `frame`, and `circle`, `line`, `polyline` and `path`
MUST be wrapped in a group even when they declare one, because their geometry,
not a frame, defines what they draw. A child's `alignSelf` overrides
`crossAlign` for that child, so a centered unit can sit under a leading value.

`stretch` aligns a child to the start of the cross axis and, when the child is
itself a stack, sizes that stack to the container's cross extent. Flexible
`spacer` children (no `length`) share the leftover main-axis length of their
stack equally, so in a stretched row a trailing child sits at the far edge.
A stack never shrinks below its content; without stretch or a fixed frame
there is no leftover and flexible spacers are zero. A fixed `spacer` is a gap
of `length` design units, useful where neighbouring gaps differ. A flexible
spacer's `min` pins it to at least that length before the remaining space is
shared, which matches native layouts that switch from even distribution to a
minimum gutter. `columns` gives each child an equal share of `width` minus the
dividers; a divider's `height` is independent of the row height, and a
single-child row draws no divider. The stack reports its content size when `frame` is omitted;
a declared frame fixes the container size and `crossAlign` aligns children
inside it. Layout runs at render pixel size, not in design units, because
CoreText advances are not linear in point size.

### 7.2 Capability nodes

Capability nodes are implemented natively because their layout or data
reduction is not expressible as base nodes. v0.1 defines six:

| Type | Fields |
|---|---|
| `sparkline` | `series` (series expression), `stroke`, `lineWidth`, `fill?` (color or `null`), `smoothing` (`none` or `monotone`, default `none`) |
| `progressBar` | `value` (0..1 expression), `trackColor`, `fillColor`, `radius` (default 0) |
| `arc` | `value` (0..1), `startDegrees`, `sweepDegrees`, `radius`, `width`, `trackColor?`, `fillColor`, `cap` |
| `segmentedBar` | `segments` (list expression of records with `index` and `color`), `orientation?` (`horizontal`, default, or `vertical`), `activeIndex?`, `activeWidthShare?` (0..0.5, default 0), `activeThicknessScale?` (default 1), `gap?`, `radius?`, `inactiveOpacity?` (default 1), `glow?` (`{ "opacity", "sigma" }`), `border?` (`{ "color", "opacity", "width" }`), `markers?` (max 8; `role`, optional `layout` `inline`/`outside`, `position` `above`/`below`/`leading`/`trailing`, `scale`) |
| `distanceTimeline` | `preset` (`minimal`, `dense`, `sport`, `splits`, `glass`, `neon`, `lowerThird`, `route`), `valueFontSize`, `valueUnitSystem`, `showValue`, `showTotalDistance`, label fields (`showLabel`, `label`, font family/size/weight/color, spacing), axis fields (`showAxisLabels`, `axisLabelMode`, `axisLabelOffset`, font family/size/weight/color, `showDistancePoints`, `distancePointCount`, `distancePointOffset`, `midpointAxisLabelOffset`, endpoint/midpoint placement), marker fields (`markerDistanceLabel*`, `currentMarkerSizeMultiplier`, `currentMarkerEnabled`, `currentMarkerStyle`, `currentMarkerColor`), container (`backgroundEnabled`, `backgroundColor`, `backgroundOpacity`, `borderEnabled`, `borderColor`, `borderOpacity`, `borderWidth`, `cornerRadius`, `paddingX`, `paddingY`), track (`trackHeight`, `trackOpacity`, `fillColor`, `tickMarksEnabled`, `tickDensity`), effects (`glowEnabled`, `fadeEnabled`, `fadeEdge`, `fadeAmount`), media slot fields, `elevationProfileVisible` |
| `elevationChart` | `preset` (`gradientArea`, `dualArea`, `techGlow`, `minimalWhite`, `bigNumbers`), `chartStyle` (`area`, `lineOnly`), smoothing, `progressMode`, padding, line/fill colors and opacities, dual-area colors, marker and playhead fields, grid/axis toggles, big-number fields, container background/border/corner/effect fields, text `fontFamily`/`foregroundColor`/`valueFontSize` |
| `routeMap` | `shape` (`square`, `circle`), `backgroundStyle` (`none`, `dark`, `light`, `terrain`, `satellite`), `cornerRadius`, `backgroundOpacity`, start/end/runner marker style and color, `glowEnabled`, `mapOpacity`, `borderEnabled`, `borderOpacity`, `foregroundColor`, `fontFamily` |
| `weatherWidget` | `preset` (`simpleCard`, `compactStrip`, `forecastTile`, `minimalText`, `dashboardBar`), manual data (`condition`, `temperatureC`, `humidity`, `highC`, `lowC`, `windKph`, `feelsLikeC`, `temperatureUnit`, `useActivityTemperature`, `locationText`), visibility toggles (`showLocation`, `showWeekday`, `showHumidity`, `showHighLow`, `showWind`, `showFeelsLike`, `showIcon`, `showConditionLabel`), labels (`conditionLabelOverride`, `humiditySuffix`, `humidityMetricLabel`, `windMetricLabel`, `feelsLikeMetricLabel`), card (`cardBackgroundColor`, `cardBackgroundOpacity`, `cardCornerRadius`, `dividerEnabled`, `dividerColor`, `dividerThickness`, `dividerOpacity`, `palette`, `iconSize`), slots (`slotBackgroundColor`, `slotBackgroundOpacity`, `slotSpacing`), and five text roles with `fontFamily` plus per-role `location`/`condition`/`temperature`/`slotTitle`/`slotLabel` size, weight and color |
| `runningGauge` | `layoutPreset` (`topBottom`, `topMiddleBottom`, `threeZones`, `topTwoMiddleBottom`, `topThreeMiddleBottom`, `fourZones`, `fiveZones`), `progress` (0..1), dial (`dialBackgroundColor`, `dialBackgroundOpacity`, `glassEffectEnabled`), outer ring (`outerRingEnabled`, `outerRingColor`, `outerRingOpacity`, `outerRingWidthScale`), ticks (`tickMarksEnabled`, `tickColor`, `tickOpacity`, `majorTickOpacity`, `tickCount`, `majorTickEvery`), progress ring (`progressRingEnabled`, `progressColor`, `progressTrackColor`, `progressTrackOpacity`, `progressRingWidthScale`, `progressRoundedCaps`), dividers (`dividerEnabled`, `dividerColor`, `dividerOpacity`, `dividerWidth`), typography (`font`, `monospacedDigits`, `primaryFontWeight`, `secondaryFontWeight`, `primaryTextColor`, `secondaryTextColor`, `accentColor`), `regions?` (max 12; `region?`, `metric`, `customLabel?`, `showLabel?`, `showUnit?`, `valueFontScale?`, `labelFontScale?`, `unitFontScale?`, `valueWeight?`, `labelWeight?`, `valueColor?`, `labelColor?`) |
| `timelineStrip` | `segments` (list expression of lap records), `currentIndex?`, `elapsed?`, `mode` (`emphasized`, `equal`, `weighted`), `emphasisFraction?` (0..0.65), `window?`, `showsWarmup?`/`showsRest?`/`showsCooldown?`, `segmentAreaHeight?`, `segmentHeight?`, `currentHeightScale?`, `minSegmentWidth?`, `gap?`, `radius?`, `currentBorderWidth?`, `completedOpacity?`, `futureOpacity?`, `colors` (`warmup`/`active`/`rest`/`cooldown`/`unknown`), `labels?` (`font`, current work/rest metrics, `neighbor`), `progress?` (`value`, `color`, `opacity`), `marker?` (`enabled`, `position`, `color`, `label`, `showsLabel`, `font`), `overflow?` (`enabled`, `text`, `color`, `inset`), `repText?`, `distanceProgress?` |

| `textRows` | `frame` or `maxWidth`; non-empty `rows`; optional `spacing` between rows. Without `frame` the node is auto-sized and `maxWidth` bounds it; the node's measured width equals `maxWidth`. Each row has `runs` (non-empty), optional `spacing`, `alignment` (`center`, default, or `firstTextBaseline`), and `if`. Each run has `text`, `font`, `color`, optional `minimumScaleFactor` (0.1..1, default 1), `verticalPadding` (design units, default 0), `monospacedDigits` (default false), `opacity` (0..1, default 1) and `if`. |
| `richText` | Required `frame`, `text`, `font`, `color`; optional `align` (`left`, `center`, `right`, default `center`; literal or expression), `lineHeight` (multiplier, default 1.2, minimum 0.5), `tracking` (extra glyph advance in design units, default 0), `stroke` (color, default white), `strokeWidth` (design units, default 0), `autoFit` (boolean or expression, default false), `gradient` (below). |

`distanceTimeline`, `elevationChart`, `routeMap` and `weatherWidget` are
host-drawn chart capability nodes: the host supplies the activity, the
formatted distance and axis text, the elevation samples, the projected route
and the weather snapshot. The node carries only
appearance and layout fields, and reuses the same layout engine and Skia
renderer as the native element, so preview and export stay identical. Give each
node an explicit `[width, height]` size that leaves room for content drawn
outside the track or card (axis labels, attached stats bars, marker labels).

`weatherWidget` renders the native weather card through the host module and
never fetches weather. The host passes a snapshot through the
`weather.current` record (`temperatureC`, `condition`, `icon`, `windSpeedMPS`,
`humidity`); when a host snapshot for the playhead also carries high/low,
feels-like and a resolved location, the host may supply the full payload, and
the node falls back to its own manual values otherwise. The component clip ends
at the card bounds, so the module's soft card shadow is trimmed to an
alpha-only fringe on the widest preset; leave a margin in the frame when that
shadow must be visible.

`runningGauge` draws the native activity dial. The host owns metric
formatting and chart drawing; this node supplies the appearance fields and the
region-to-metric mapping. `layoutPreset` selects where regions sit on the dial,
and each `regions` entry maps one region to a host metric with optional label,
unit, typography and color overrides. `progress` is the host-computed ring
fraction (distance target, elapsed target or zone-derived). The node is
fixed-size, so give it an explicit `[width, height]` size in the definition.

`timelineStrip` draws the interval timeline rail: one segment per lap in the
supplied record list, centered on `currentIndex` with `window` neighbors per
side, or the whole schedule when `window` is large. Segment widths follow the
native timeline rules (`emphasized` gives the current lap `emphasisFraction` of
the width, `equal` splits evenly and `weighted` scales by lap distance/time).
The host supplies lap records; the node owns the layout, per-kind colors,
current/neighbor labels, progress overlay, overflow ellipses and the live
marker with its label. `labels` selects which metrics each segment shows;
`marker.position` is `progress` (live fraction) or `center` (segment middle).
The node measures its own height from `segmentAreaHeight`, so place it inside a
content-sized component rather than a fixed frame.

`segmentedBar` draws an equal-width run of segments inside its frame, matching
the native zone bars. `segments` records supply the paint order and each
segment's color; a record's `index` identifies it for `activeIndex`. The active
segment widens to at least `activeWidthShare` of the bar (capped at half) and
scales its thickness by `activeThicknessScale`; inactive segments fade by
`inactiveOpacity`. `gap` is clamped so the run always fits: at most
`length / (count - 1) * 0.18` per gap. `radius` is clamped to half the
cross-axis extent. An optional `glow` blurs the whole run and an optional
`border` strokes its outline. `orientation` defaults to `horizontal`;
`vertical` runs the first segment from the bottom edge upward.

Markers are drawn after the segments. Each marker names a segment `index` and
a `fraction` within it, and `text` must be supplied. `position` selects the
side: `above`/`below` for horizontal bars, `leading`/`trailing` for vertical
bars. `layout` defaults to `inline`, the interval HUD treatment (an arrow plus
an optional value pill stacked against the bar); `outside` matches the zone
edge treatment, where the callout or threshold tick sits wholly outside the
bar on the named side. `scale` multiplies the inline arrow or the whole outside
callout. `showsValue` (default true) hides the current marker's value pill
without hiding its arrow. A `threshold` marker draws a capsule with a label.
Marker metrics follow the corresponding native module, including the minimum
arrow and text sizes used at small element scales.

`textRows` lays out a short, vertically centered stack of single-line runs. It
uses the same CoreText line shaping and shrink-to-fit behavior as the native
interval modules: a run shrinks down to `minimumScaleFactor` when its row is
wider than the frame, and rows shrink their combined width toward 0.5. Row
conditions and run conditions are evaluated before layout, so hidden helper,
phase, rep or caption rows take no space. Use `richText` for wrapped
paragraphs and `textRows` for display typography such as countdown values.

`richText` is the reviewed paragraph-text capability for Decor Text and other
multiline cards. It uses the shared AppKit paragraph rasterizer, including
word wrapping, font leading and explicit newlines, vertically centered in its
required frame. It does not change the existing `text` node or its CoreText
measurement rules. Its `lineHeight` adds `max(0, (lineHeight - 1) * fontSize)`
paragraph line spacing. Its stroke is a copy of the paragraph scaled about the
frame center by `1 + strokeWidth / max(renderedFontSize, 1) * 0.5`, drawn behind
the fill; it is not a geometric glyph outline.

`autoFit` shrinks the requested font (never enlarges it) until the paragraph
fits the frame, with a bounded 12-step search down to one rendered pixel.
Tracking scales with the fitted font. Oversized content may still clip at the
minimum font size. Empty content paints nothing. Raster requests exceeding
16,384 pixels on either axis or 16,777,216 total pixels are rejected to bound
bitmap allocation; authors should keep frame dimensions and font sizes modest.

`gradient` overrides `color` for glyph fill only and leaves stroke unchanged.
It is an object with `stops` (2–8 objects with a literal `offset` in 0…1 and a
literal or expression `color`, sorted by offset), `from` and `to` (points in
node-local design units, top-left origin). Colors extend beyond the endpoints.
All font fields use the same generic font contract as `text`.

The bundled `studio.decor-text` exposes content, dimensions, font family,
weight, size, alignment, line height, tracking, auto-fit, solid/gradient fill,
gradient direction and stroke as params. Native Decor Text's gradient is
currently a white placeholder and its auto-fit flag is inactive; these two
new component behaviors are tested independently, not claimed as native pixel
parity. Native letter spacing historically passes `letterSpacing / fontSize`
to AppKit; matching that output requires converting to component tracking in
rendered pixels. No native style type appears in component JSON.

Deferred to a later version, each requiring an ADR amendment or a reviewed
spec change: `areaChart`, `intervalTimeline`, `routeMap`, `weatherIcon`,
`textEffect`.

Capability nodes MUST honor `if`, `opacity`, `frame` and clipping like base
nodes.

### 7.3 Fonts

```json
"font": { "family": "system", "size": 44, "weight": "bold" }
```

- `family`: `system`, `system-rounded`, `system-monospaced`, or a family name
  from the host font library. Bundled fonts are not supported in v0.1.
- `size`: design units, 1..512.
- `weight`: `ultraLight`, `light`, `regular`, `medium`, `semibold`, `bold`,
  `heavy`, `black`.
- `family` and `weight` may be expressions, typically `=fontParam` for a
  `font` param and an `enum` param of weights. An empty family resolves to
  `system`.
- Missing families resolve to `system`; the Inspector SHOULD warn.

### 7.4 Repeat

`repeat` is the only control flow beyond `if`:

```json
{
  "type": "repeat",
  "frame": [0, 0, "=width", 240],
  "over": "=laps",
  "as": "lap",
  "index": "index",
  "max": 64,
  "children": [ ... ]
}
```

- `over` is an expression returning a list, usually `=bindingName`.
- `as` and `index` name the item and zero-based index in scope for children
  and their frames. Their defaults are `item` and `index`.
- `max` is a number or expression, defaults to 64, and is clamped to
  0...512. Iteration stops at `max`.
- `repeat` does not lay out or translate children; each child computes its own
  frame in component coordinates, usually from `index`. A group frame bounds
  clipping/effects but does not establish a new coordinate origin.
- Nested `repeat` is not allowed in v0.1.

## 8. Expressions

A string whose first character is `=` is an expression. All other strings,
numbers and booleans are literals. The language is pure: no assignment, no
I/O, no clocks, no randomness.

### 8.1 Grammar

```
expr         := ternary
ternary      := or ( "?" expr ":" expr )?
or           := and ( "||" and )*
and          := equality ( "&&" equality )*
equality     := comparison ( ("==" | "!=") comparison )*
comparison   := additive ( ("<" | "<=" | ">" | ">=") additive )*
additive     := product ( ("+" | "-") product )*
product      := unary ( ("*" | "/" | "%") unary )*
unary        := ("!" | "-") unary | postfix
postfix      := primary ( "." IDENT | "[" expr ] )*
primary      := NUMBER | STRING | "true" | "false" | "null"
              | IDENT | call | "(" expr ")"
call         := IDENT "(" [ expr ( "," expr )* ] ")"
```

- `NUMBER` is a decimal literal; `STRING` uses double quotes with `\"`, `\\`,
  `\n`, `\t`.
- Identifiers resolve in this order: repeat scope (`item`, index name),
  bindings, params, builtins.
- Unknown identifiers and members resolve to `null`.
- `.` accesses record fields; `[i]` indexes zero-based lists.
- Truthiness: `false`, `null`, `0`, `""`, and empty lists are falsey.

### 8.2 Semantics

- Arithmetic follows IEEE doubles. Division or modulo by zero yields `null`.
- Comparison of incompatible types yields `false` for `==`/`!=`, and `null`
  for ordering operators.
- `null` propagates through arithmetic and builtins unless the builtin is
  defined for null.
- The result type is checked where the field requires a specific type; a
  mismatch makes the node render as if `if` were false and records a
  diagnostic in Debug builds.

### 8.3 Builtins

| Builtin | Result |
|---|---|
| `min(a, b, ...)`, `max(a, b, ...)` | number or null |
| `clamp(x, lo, hi)` | number |
| `abs(x)`, `round(x)`, `floor(x)`, `ceil(x)` | number |
| `lerp(a, b, t)` | number |
| `map(x, inLo, inHi, outLo, outHi)` | number, clamped |
| `sum(list)`, `avg(list)`, `count(list)` | number |
| `first(list)`, `last(list)`, `at(list, i)` | value |
| `coalesce(a, b, ...)` | first non-null value |
| `exists(x)` | bool |
| `format(value, pattern)` | string; patterns in 8.4 |
| `concat(a, b, ...)` | string |
| `upper(s)`, `lower(s)` | string |
| `slice(s, start, length)` | string |
| `mix(colorA, colorB, t)` | color |
| `alpha(color, a)` | color |
| `signal(path)` | current value for a path in section 5; null when unavailable |
| `series(path, windowSeconds, samples)` | series for an `activity.*` path; window relative to the playhead |
| `metric(id, unit...)` | host-formatted record `{ value, unit, label, shortLabel, icon }`; see 5.4 |
| `width`, `height` | component design size (constants) |
| `pi` | 3.141592653589793 |

Builtin argument types are checked at compile time where possible.

### 8.4 Format patterns

| Pattern | Example output |
|---|---|
| `integer` | `148` |
| `decimal:1` | `4.6` |
| `duration` | `1:02:33` or `2:33` |
| `pace` | `4:32` |
| `clock` | `07:45` |
| `percent` | `72%` |
| `signed` | `+12` / `-3` |
| `distance:km` | `12.34` |
| `distance:mi` | `7.67` |

`format(null, pattern)` returns the placeholder `—` (em dash). Components that
want a different placeholder use `coalesce` before formatting.

## 9. Params And Inspector

Params define the user-editable surface. The Inspector is generated; authors
cannot supply arbitrary SwiftUI.

```json
{
  "id": "accent",
  "type": "color",
  "label": { "en": "Accent", "zh-Hans": "强调色" },
  "section": { "en": "Style", "zh-Hans": "样式" },
  "default": "#FF4D4F"
}
```

Common fields: `id` (`[a-z][a-zA-Z0-9_]*`, unique), `type`, `label`,
`section` (default `General`), `description?`, `default` (required),
`advanced?` (bool, places the control in Advanced), `when?` (expression over
params; the control is hidden when falsey).

| Type | Extra fields | Inspector control |
|---|---|---|
| `number` | `min`, `max` (both required), `step?`, `unit?`, `style?` (`slider` default, `field`, `stepper`) | Dense slider with editable value, or field/stepper |
| `bool` | — | Toggle row |
| `color` | — | Color well with hex entry and opacity |
| `enum` | `options` (2..32 `{ "value": string, "label": localized }`) | Segmented control for ≤4 options, menu otherwise |
| `string` | `maxLength` (default 64, max 512) | Text field |
| `font` | — | Host font picker |
| `metric` | `signals` (allowed paths from 5.1), `series` (bool, allow series selection) | Metric picker constrained to the list |

Rules:

1. Params are ordered by array order; sections by first appearance.
2. Every control MUST be rendered through the existing `InspectorDense*`
   primitives so generated and native Inspectors stay visually identical.
3. A numeric param's `default` MUST be within `min`...`max`; a color default
   MUST be a literal color; an enum default MUST be one of its options.
4. `metric` params hold a signal path string. Components read it with
   `signal(metricParam)` or `series(metricParam, ...)`. The picker MUST
   present localized display names and units for the allowed paths.
5. A discrete change records one undo point through `ProjectDocument`. A
   continuous control (slider drag, color well drag, stepper press-and-hold)
   begins, updates and finishes a single continuous undo transaction.
6. Unknown params in a saved project MUST be retained across edits and saves.

## 10. Project Persistence

A component instance is stored as:

```json
{
  "kind": "component",
  "component": {
    "id": "community.alice.hr-pill",
    "version": "1.2.0",
    "digest": "sha256:…",
    "source": "imported",
    "definition": { "...": "embedded component document" },
    "assets": { "assets/logo.png": "<base64 asset bytes>" }
  },
  "params": { "accent": "#FF4D4F", "radius": 36, "showTrend": true },
  "positionX": 0.03,
  "positionY": 0.74,
  "scale": 1.0,
  "isVisible": true,
  "isLocked": false,
  "opacity": 1.0
}
```

Rules:

1. Bundled components (`studio.*`) are referenced by id, version and digest;
   their definition is not embedded. Imported components MUST embed the
   definition so projects remain renderable after the source package is
   removed or updated.
2. On load, if the embedded definition's digest does not match, the host MUST
   use the embedded definition and warn; rendering is authoritative from the
   embedded bytes.
3. Loading a project with a component version newer than the host supports
   MUST fail that element's validation with a clear message, not guess.
4. `positionX`, `positionY`, `scale`, visibility, lock and opacity reuse the
   existing `OverlayElement` semantics and `ProjectDocument` mutation API.
5. This adds a new element kind and raises the project schema to version 2.
   Existing version 1 projects and native element types MUST continue to load
   and render unchanged. Migration of native elements to components is out of
   scope for v0.1.
6. The digest is SHA-256 over the canonical JSON encoding (sorted keys, no
   insignificant whitespace), not over the package file bytes, so reformatting
   an embedded definition does not change its identity. When an embedded
   definition's recomputed digest differs from the stored digest, rendering
   uses the embedded bytes.
7. Imported and project components MUST embed the bytes of every asset their
   `image` nodes reference, keyed by package path (`assets/name.png`) and stored
   base64-encoded by the ordinary JSON encoder. A node that references an asset
   missing from the package is a validation error and the element is not added.
   Bundled components carry no `assets` field because the host ships their
   bytes.

## 11. Validation, Failure And Limits

### 11.1 Validation

At import and project load the host MUST validate, in order:

1. JSON syntax and package structure.
2. JSON Schema conformance (strict; unknown keys rejected).
3. Semantic rules: unique ids, referenced bindings/params/assets exist,
   frames and limits are within bounds, `repeat.max` within range, expression
   parse and static type checks, color and font literals valid.
4. Compilation to the render graph, including expression AST limits.

Validation errors MUST name the JSON pointer and a human-readable message.

### 11.2 Failure behavior

- **Import**: invalid packages are rejected and never installed.
- **Project load / preview**: an invalid instance renders a neutral
  placeholder rectangle with an error badge; the Inspector shows the
  diagnostic. Other overlays continue to render.
- **Export**: an invalid instance fails the export with an error naming the
  component and the validation messages. Silently omitting an overlay is not
  acceptable.
- **Runtime**: a component MUST NOT crash the host. Type mismatches, missing
  data and nulls degrade to skipped nodes or placeholders.

### 11.3 Limits

| Limit | Value |
|---|---|
| Nodes per component | 512 |
| Node nesting depth (groups) | 16 |
| `repeat` iterations | 512 |
| Expression length | 512 characters |
| Expression AST depth | 32 |
| Series samples | 1024 |
| Text lines per node | 8 |
| Text literal length | 1024 characters |
| Assets | 32 files, 8 MiB each, 32 MiB total |
| Package `component.json` | 1 MiB |
| Component size | 8192 × 8192 design units |

## 12. Performance

- Parsing, validation and compilation happen once per component+definition
  digest; never per frame.
- Per frame, only expressions that depend on time, series, or changing
  records are re-evaluated. Static subtrees SHOULD be cached. Caching may use
  a SkPicture-like replay path added to the bridge in a later revision.
- A component MUST draw within the budget defined by the export benchmark
  suite; v0.1 acceptance requires no meaningful regression on the fixed
  synthetic suite at 1080p and 4K.
- Capability nodes are native and share caches (route snapshots, weather
  icons) with the existing modules.

## 13. Security And Licensing

1. Components are passive data. They MUST NOT trigger network access, file
   access, process execution, environment reads, keychain access, or URL
   opening.
2. Asset references are restricted to the package itself.
3. The host MUST NOT render a component from an untrusted path outside the
   imported package or the bundled component directory.
4. Packages MUST declare an SPDX license. Bundled examples MUST use synthetic
   data and assets with documented provenance, per
   `docs/assets-and-licenses.md`.
5. Fonts are host-owned. Bundled font files are deferred pending a license
   review.
6. Downloadable declarative content still needs App Store policy review
   (guideline 2.5.2 and sandbox behavior). This specification does not assert
   compliance.

## 14. Versioning

- The `spec` value is the contract version. Hosts advertise supported spec
  versions at import and load.
- Component `version` is independent and follows semantic versioning:
  - PATCH: visual fixes that preserve params and meaning.
  - MINOR: additive params, nodes or fields with safe defaults.
  - MAJOR: renamed/removed params, changed defaults that alter output, or a
    required new spec feature.
- Adding a base node, capability node, builtin, signal, record field or param
  type is a spec MINOR bump and requires documentation and tests.
- Removing or changing semantics is a spec MAJOR bump.
- A project stores the component version it was authored with; the host MUST
  NOT silently upgrade an imported component inside a project.

## 15. Migration From Native Overlays

Native overlay types remain the authoritative implementation until ported.
Numeric overlays are the exception: ADR 0014 removed the native numeric types
without migrating saved projects, and `studio.numeric` replaces them.

1. Port one overlay at a time, starting with a numeric metric overlay.
2. The component and native renderer render the same fixture; compare with
   the existing Skia snapshot/parity tooling.
3. Only after parity acceptance, switch the Overlay Pool preset to the
   component and keep the native renderer as a comparison path.
4. Remove a native renderer, its style fields, its Inspector detail view and
   its tests only in a separate reviewed change.
5. The mapping from a legacy element to a component instance is documented per
   overlay before any automatic migration is proposed. v0.1 does not migrate
   existing projects.

## 16. Open Questions For Review

1. Built-in components are **read-only**. The app exposes their definition for
   inspection and offers "Duplicate to My Components", which creates an
   editable imported copy with a new id. Editing a bundled definition in place
   is not supported.
2. Does the project file embed imported definitions verbatim, or normalized?
   (Proposal: verbatim bytes plus digest, for reproducibility.)
3. Should `zone.*` and `weather.*` be part of the v0.1 contract even though
   their capability nodes are deferred? (Proposal: yes, signals now;
   capability nodes later.)
4. Is a hosted component gallery desirable, and if so how are licensing and
   review handled? (Not in v0.1.)
5. Should text rendering expose font features or letter spacing in v0.1?
   (Proposal: letter spacing only; OpenType features later.)
6. Which Inspect metrics gate acceptance: 100% pixel match for numeric
   overlays, or the existing changed-pixel ratio thresholds? (Proposal: the
   existing Skia parity thresholds.)

## 17. Conformance Checklist

A v0.1 implementation is conformant when:

- [ ] The JSON Schema validates both example components.
- [ ] The expression evaluator implements section 8 including null
      propagation and limits, with unit tests.
- [ ] Bindings and builtins expose only the section 5 contract.
- [ ] Base and capability nodes render through the Skia bridge with clipping.
- [ ] Generated Inspector controls reuse `InspectorDense*` primitives and
      `ProjectDocument` undo semantics.
- [ ] Invalid components fail import, preview and export per section 11.
- [ ] One numeric overlay is ported with screenshot parity evidence.
- [ ] The export benchmark suite shows no meaningful regression.
- [ ] Docs, project log and an authoring guide are updated.
