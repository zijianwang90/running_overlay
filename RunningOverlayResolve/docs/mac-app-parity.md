# Mac App Feature Parity

## Release Goal

Keep Resolve development on `codex/resolve-plugin-poc`. No pull request is open;
open one and merge to `main` only after the parity gates below are met. This replaces
the earlier plan to merge the usable four-metric prototype first.

Parity means that users can produce the same supported overlay content and
styles, with equivalent data semantics and reliable project handoff. Resolve
supplies the video editor, playback, animation and final delivery workflow;
rebuilding Studio's timeline UI is not a parity requirement. Similar feature
names alone do not establish parity. Differences must be recorded explicitly.

Baseline inspected: Mac app and Resolve code at commit `b8842cc`, 2026-10-31.
Recheck this baseline as the Mac app changes. This is a code inventory, not a
claim that every Mac app feature has been host-tested in Resolve.

## Evidence

- [Mac element catalog](../../Sources/RunningOverlay/Overlay/OverlayElement.swift):
  34 element types, of which 21 are numeric overlays.
- [Mac value formatting](../../Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift)
  and [render models](../../Sources/RunningOverlay/Overlay/OverlayRenderModel.swift).
- [Mac overlay development guide](../../docs/development/overlays-and-preview.md)
  and [module specifications](../../docs/overlay-modules/README.md).
- [Mac activity import](../../docs/development/app-and-import.md) and
  [template model](../../Sources/RunningOverlay/Overlay/OverlayTemplate.swift).
- Resolve [widget catalog](../src/domain/widgets.js),
  [activity model](../src/domain/activity.js),
  [render bundle](../src/io/render-data.js), and
  [Numeric Fuse](../fusion/Fuses/RunningOverlayNumeric.fuse).

## Overlay Inventory

“Partial” means there is a working implementation but its complete Mac style or
value contract is not yet reproduced. “Data only” means a normalized field is
available, but there is no selectable/rendered widget.

| Mac element | Resolve status | Work required |
|---|---|---|
| Heart Rate | Partial | Numeric styles, units, zone coloring |
| HR Zone | Missing | Zone settings, classification, palette |
| Pace | Partial | Unit options and full numeric styles |
| Avg Pace | Implemented (v8) | Real elapsed ÷ distance with pace units; host export checked |
| Lap Pace | Missing | Lap data and Mac selection semantics |
| Calories | Partial | Direct record widget implemented; lap/session fallback pending |
| Elapsed Time | Partial (`elapsed`) | Match formats and pause behavior at boundaries |
| Real Time | Implemented (v9) | `HH:mm:ss` or `h:mm:ss a`, seconds truncated as on Mac. Mac uses the rendering machine's timezone; Resolve uses an explicit per-instance UTC offset seeded from the recording timezone at activity start, so an activity crossing a DST change keeps one offset. Host export checked |
| Date | Missing | Explicit timezone and date formatting |
| Distance | Partial | Units and full numeric styles |
| Distance Timeline | Partial (v10) | Minimal template: progress, ticks, markers, axis labels, glow and shadow implemented; other presets/stats/elevation pending |
| Elevation | Partial | Meter widget implemented; units and display modes pending |
| Elevation Chart | Missing | Profile, cursor, range and styles |
| Cadence | Partial | Widget implemented; activity-specific cadence semantics pending |
| Power | Partial | Watt widget implemented; full numeric styles pending |
| Running Gauge | Missing | Gauge metrics, ranges and presets |
| Interval HUD Bar | Missing | Workout structure, zones and renderer |
| Interval Timeline | Missing | Workout structure, lap timeline and renderer |
| Interval Countdown | Missing | Work/rest phase and countdown semantics |
| Interval Work Summary | Missing | Work-interval aggregation and styles |
| Zone Edge Bar | Missing | Zone settings and renderer |
| Route Map | Partial (v11) | FIT/GPX GPS retained; offline Mercator trace and time-driven cursor implemented; map imagery/provider, other presets and stats pending |
| Vertical Oscillation | Implemented (v8) | cm/mm units; host export checked |
| Ground Contact Time | Implemented (v8) | Host export checked |
| Stride Length | Implemented (v8) | Meters only, as on Mac; host export checked |
| Vertical Ratio | Implemented (v8) | Derived from oscillation and stride; zero stride shows `--` |
| GCT Balance | Implemented (v8) | Right-side encoding normalized to left percent; host export checked |
| Temperature | Implemented (v8) | °C/°F; FIT, FIT-else-manual or manual source. Mac pairs FIT on/off with an optional manual value |
| Grade | Implemented (v8) | FIT field; GPX derived within a segment when both elevations exist |
| Custom Numeric | Missing | Selectable source, precision, units and formats |
| Weather Widget | Missing | Weather inputs/cache/assets and full module behavior |
| Solid Color | Missing | Shape, fill, geometry, opacity and effects |
| Icon | Missing | Licensed asset handling and renderer |
| Text | Missing | Text, typography, layout and effects |

**Approved difference — missing samples (2026-10-31).** Mac interpolates across
any run of records missing a field, however long, and holds the last value at
either end. Resolve interpolates only between adjacent records that both carry
the field and otherwise shows `--`. The user chose to keep this: Resolve never
displays values the activity file did not record. It applies to every
record-based metric and counts as a user-approved exception for the release gate.

Resolve now supports up to sixteen independently identified numeric instances,
including duplicate metrics. Each identity retains a persisted renderer slot.
Legacy heart-rate/pace/distance/elapsed inputs are adopted during upgrade. Fuse v6
was validated with a synthetic eight-metric export and duplicate styling; see
the testing record for the initial unreproduced crash, successful 4444 alpha
retry, real v5/v6 comparison and remaining UI validation limits.

**Visual acceptance (2026-11-01).** The user accepts approximate typography across Fusion and SwiftUI. Exact glyph rasterization and pixel matching are not a gate. Numeric icons are original project vectors, not redistributed SF Symbols. Route Map currently draws a transparent offline trace; both Mac templates use a dark MapKit snapshot, so this remains partial parity.

## Shared Capabilities

| Area | Current Resolve behavior | Parity acceptance |
|---|---|---|
| Numeric styling | v7 adds separate value/label/unit fonts, sizes, colors/opacity, custom labels, visibility and attachments; v9 adds layered text shadow; v10 adds original vector icons and label/unit alignment. Template fonts are approximately matched; host persistence and export checked | Value/label/unit/icon controls, attachment positions, separate typefaces/sizes/colors/opacities, presets and effects match supported Mac fields |
| Units and formatting | v7 metric-specific km/mi/m, pace /km /mi /500m, elevation m/ft and elapsed formats; Lua tested and imperial host export checked | Metric-specific unit choices, precision, missing values and boundary formatting match Mac |
| Element layout | Stack/row/grid presets; Fusion positioning | Independent instances, visibility, ordering and reusable layouts; equivalent placement at supported resolutions |
| Activity import | FIT/GPX; limited normalized fields and timer-pause annotations | Retain fields required by all supported widgets, laps, workout structure and GPS; preserve provenance and gaps |
| Calories | Direct record calories | Match Mac lap-total/session-total fallback, explicitly distinguishing estimates |
| Templates | None | Save/apply/import/export reusable layouts with versioned data and asset provenance; define supported interchange with Mac templates |
| Editing after cuts | Per-piece offset; data/layout updates refused | Apply chosen style changes across pieces without changing offsets, source mapping or animation; unsupported cases fail before mutation |
| Project persistence | Local config plus immutable local bundles | Save/reopen, relink, missing-data diagnostics, offline use and cross-machine handoff without developer paths |
| Preview/export | Same Fuse; short 1080p composite host check | Equivalent values/styles in viewer and Deliver; transparent output, UHD, frame-rate and color-management matrix |
| Install/upgrade | Local SDK assembly and manual installation | Reproducible installation, compatible version checks, upgrade/recovery and documented licensing |
| Undo | Fusion transactions | Discrete edits undo once; continuous edits follow an explicit gesture contract; verify in host |

Mac-only infrastructure (App Store submission, Studio pane geometry and macOS
security-scoped bookmarks) is not duplicated literally. Equivalent outcomes
such as installation, editing and portable media access remain required.

## Delivery Order

### Template-First Priority

New widget work first completes the components of the bundled Easy Run and Race
templates (`Sources/RunningOverlay/Resources/Templates/`), ahead of the generic
order below. Race contains the nine Easy Run elements plus two:

| Template element | Templates | Resolve status |
|---|---|---|
| Pace, Heart Rate, Cadence, Power | Both | Numeric values and original vector icons available; typography approximately matched to Monaco/PT Mono |
| Elapsed Time | Both | Available |
| Real Time | Both | v9 |
| Text shadow | All but Race elevation chart | v9 for numerics; featured widgets need their own shadow pass |
| Distance Timeline | Both | v10 minimal renderer; full module parity pending |
| Route Map | Both | v11 offline trace and cursor; dark MapKit background not implemented |
| Weather Widget | Both | Missing; needs a weather data source and background styling |
| Zone Edge Bar, Elevation Chart | Race | Missing |

Template files are large because every element stores every module's sub-style;
they embed no route or image assets.

### 1. Numeric Widgets And Styles

First increment: expose elevation, cadence, power and calories using the fields
already carried by the bundle. Preserve old projects and existing metric IDs.
Before expanding the renderer, define stable widget instances and persistence
so later duplicate metrics and templates do not depend on fixed metric slots.

Acceptance:

- Each added metric can be chosen, positioned and rendered in Resolve.
- Synthetic records verify source values, conversions and missing samples.
- Existing four-metric projects reopen unchanged; preview and Deliver use the
  same inputs and formatter semantics.
- Document the current direct-record-only calorie behavior until the separate
  lap/session fallback increment is implemented.

Subsequent increments: units/formatting, independent numeric style fields, the
remaining numeric metrics, and presets. Use the Mac renderer and formatter as
behavior references; do not copy undocumented assumptions into Lua.

### 2. Featured Widgets And Reusable Styles

Build each widget against its current module specification. Acquire its data
prerequisites first: GPS for maps, elevation series for charts, workout/lap and
zone models for interval widgets. Cover decor elements and weather as explicit
work items rather than leaving them outside the parity definition.

Add templates and selective style propagation across cut pieces. Style changes
must preserve every piece's offset, timing, source origin and animation. Data
updates after cuts remain outside the current lightweight offset workflow;
revisit only if a parity use case requires them.

Acceptance: each catalog row has synthetic data coverage, renderer coverage,
host preview/export evidence, and documented style equivalence. Templates
round-trip all supported fields and assets without silent loss.

### 3. Data And Project Integrity

Complete import semantics and recovery/portability. Define compatibility and
asset handling before claiming cross-app template exchange. Follow the same
real-time versus moving-time distinction as Studio.

Acceptance: exercise pause boundaries, missing fields, GPS gaps, laps, estimated
values, save/reopen, missing bundles, relink and transfer to another machine.
No public tests depend on private activity records, GPS or media.

### 4. Delivery And Release Gate

Validate full-length composite and alpha-only output, common rational frame
rates, UHD, color management and realistic widget counts. Establish concrete
performance budgets from host measurements. Finish installation and upgrade.

Before merging to main:

- Every catalog row and shared capability has accepted evidence or an explicit
  user-approved exception; blank rows are incomplete work.
- Current docs, synthetic fixtures, focused checks and `./scripts/check.sh` pass.
- Host validation covers save/reopen, undo, preview/export parity and migration.
- Licensing, credentials/privacy, timing conversion, codecs and compatibility
  receive the focused human review required by AGENTS.md.
- Refresh the Mac baseline and account for features added during development.

## Current Verified Host Coverage

See [testing records](testing.md) for evidence and limits. Validated development
behavior includes four numeric metrics, per-piece timing independence,
playhead-following timing controls, source-frame-1004 correction at 29.97, and a
short composite Deliver export across one ripple-edited boundary. These checks
do not establish the release gate above.
