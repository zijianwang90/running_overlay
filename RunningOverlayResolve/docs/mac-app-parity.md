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
| HR Zone | Partial (v16) | Numeric `Z1`…`Z6` label from the instance HR ranges and existing inclusive first-match rule; optional Mac-style text tint/palette pending |
| Pace | Partial | Unit options and full numeric styles |
| Avg Pace | Implemented (v8) | Real elapsed ÷ distance with pace units; host export checked |
| Lap Pace | Implemented (v19) | FIT lap boundaries; pace from the current lap start to the sampled record; relies on device lap messages |
| Calories | Partial | Direct record widget implemented; lap/session fallback pending |
| Elapsed Time | Partial (`elapsed`) | Match formats and pause behavior at boundaries |
| Real Time | Implemented (v9) | `HH:mm:ss` or `h:mm:ss a`, seconds truncated as on Mac. Mac uses the rendering machine's timezone; Resolve uses an explicit per-instance UTC offset seeded from the recording timezone at activity start, so an activity crossing a DST change keeps one offset. Host export checked |
| Date | Implemented (v15) | Six en_US_POSIX patterns; per-instance fixed UTC offset applied to the activity instant. Host export checked |
| Distance | Partial | Units and full numeric styles |
| Distance Timeline | Partial (v10) | Minimal template: progress, ticks, markers, axis labels, glow and shadow implemented; other presets/stats/elevation pending |
| Elevation | Partial | Meter widget implemented; units and display modes pending |
| Elevation Chart | Partial (v13) | Race full-profile smoothed gradient area, line-only, cursor, guide and meter label; other presets, progress mode, axes/stats pending |
| Cadence | Partial | Widget implemented; activity-specific cadence semantics pending |
| Power | Partial | Watt widget implemented; full numeric styles pending |
| Running Gauge | Partial (v17) | Circular dial, outer ring, 60 ticks, optional distance/time progress ring, four configurable regions and dividers; the remaining seven Mac layouts, presets, glass, glow and per-region typography pending |
| Interval HUD Bar | Partial (v20) | Phase/rep/remaining time or distance, lap progress bar and phase colors; HR/pace zone bar, metric slots and layered styling pending |
| Interval Timeline | Partial (v20) | Full-lap proportional segments by time or distance, phase colors, labels, current segment and marker; centered window, overflow hints and filtering pending |
| Interval Countdown | Partial (v20) | Phase-colored ring, time/distance center value, remaining/elapsed direction, phase, rep, helper and caption; per-role fonts/glow/borders pending |
| Interval Work Summary | Partial (v20) | Last completed active lap, lap time/pace/distance/HR/power/cadence, configurable primary and three secondary slots, display window; max HR and per-role typography pending |
| Zone Edge Bar | Partial (v12) | Five/six editable HR ranges, edge/free placement, active emphasis, current/threshold markers; pace mode and shared project physiology settings pending |
| Route Map | Partial (v11) | FIT/GPX GPS retained; offline Mercator trace and time-driven cursor implemented; map imagery/provider, other presets and stats pending |
| Vertical Oscillation | Implemented (v8) | cm/mm units; host export checked |
| Ground Contact Time | Implemented (v8) | Host export checked |
| Stride Length | Implemented (v8) | Meters only, as on Mac; host export checked |
| Vertical Ratio | Implemented (v8) | Derived from oscillation and stride; zero stride shows `--` |
| GCT Balance | Implemented (v8) | Right-side encoding normalized to left percent; host export checked |
| Temperature | Implemented (v8) | °C/°F; FIT, FIT-else-manual or manual source. Mac pairs FIT on/off with an optional manual value |
| Grade | Implemented (v8) | FIT field; GPX derived within a segment when both elevations exist |
| Custom Numeric | Partial (v15) | 19 record sources, number/integer/duration/clock/date/pace/percent/coordinate formats, precision and custom unit. HR-zone, elevation gain and generic FIT fields pending |
| Weather Widget | Partial (v14) | Open-Meteo historical fetch cached in the project, offline card render, ten conditions, °C/°F, FIT override, SimpleCard layout; forecasts/presets/geocoding pending |
| Solid Color | Partial (v18) | Rectangle, rounded rectangle and circle with fill/opacity, size and corner radius; borders/effects pending |
| Icon | Partial (v18) | Original vector glyph set, tint and size; SF Symbols and user SVG/PNG assets intentionally unsupported (licensing/asset pipeline) |
| Text | Partial (v18) | Single-line text, size, color and left/center/right alignment; font selection, multiline, stroke and auto-fit pending (Mac text is still a placeholder) |

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

**Weather scope (2026-11-01).** The Resolve panel makes the same keyless
Open-Meteo archive request as the Mac app, for the activity's start date and
first GPS point, but queries in UTC and selects the hour containing the real
activity start instant. This deliberately avoids the Mac fetcher's device-
timezone hour comparison. The snapshot is validated against the activity
identity, start instant and first coordinates, saved in panel settings, and
copied into the immutable activity data; Fusion renders only that snapshot, so
preview, Deliver and project handoff need no network. The card reproduces the
shared Easy Run/Race SimpleCard: condition, original vector condition icon,
divider, location, weekday, temperature and humidity with the template's blue
glass colors, corner radius, border and 35% shadow. Typography is approximate,
as accepted above. Location text can be relabelled in the panel; automatic
reverse geocoding, forecasts, the other card presets, and the Mac's global
weather preferences remain pending. If the cache is absent the card shows the
Mac's sunny/`--` placeholder state; a stale cache is dropped rather than shown.

**Race module scope (2026-11-01).** HR bars use explicit inclusive bpm ranges,
with the first matching range winning overlaps, matching Mac classification.
Resolve stores ranges and threshold per instance in Fusion; it does not read the
Mac app's global preferences or infer max HR. Elevation uses full-profile sample
index spacing, elapsed-time progress and the template's fixed 0.85 smoothing.
Long profiles retain per-bucket extrema/endpoints with bounded drawing geometry.
A completely missing profile shows `NO ELEVATION` rather than the Mac's synthetic
zero profile, and missing current elevation suppresses the cursor. The gradient
is approximated with raster bands; exact raster parity is not claimed.

## Shared Capabilities

| Area | Current Resolve behavior | Parity acceptance |
|---|---|---|
| Numeric styling | v7 adds separate value/label/unit fonts, sizes, colors/opacity, custom labels, visibility and attachments; v9 adds layered text shadow; v10 adds original vector icons and label/unit alignment; new instances seed the Mac template's label visibility/color and shadows. Template fonts are approximately matched; host persistence and export checked | Value/label/unit/icon controls, attachment positions, separate typefaces/sizes/colors/opacities, presets and effects match supported Mac fields |
| Units and formatting | v7 metric-specific km/mi/m, pace /km /mi /500m, elevation m/ft and elapsed formats; Lua tested and imperial host export checked | Metric-specific unit choices, precision, missing values and boundary formatting match Mac |
| Element layout | Template positions from the Mac 1920×1080 element centers, then Fusion positioning; duplicates and off-template widgets use deterministic free slots | Independent instances, visibility, ordering and reusable layouts; equivalent placement at supported resolutions |
| Activity import | FIT/GPX; limited normalized fields and timer-pause annotations | Retain fields required by all supported widgets, laps, workout structure and GPS; preserve provenance and gaps |
| Calories | Direct record calories | Match Mac lap-total/session-total fallback, explicitly distinguishing estimates |
| Templates | Built-in Easy Run, Race and Interval Workout lists and starting positions | Custom save/apply, import/export of reusable layouts with versioned data and asset provenance; define supported interchange with Mac templates |
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
| Pace, Heart Rate, Cadence, Power | Both | Numeric values, original vector icons and template-seeded label visibility, label color and shadow; typography approximately matched to Monaco/PT Mono |
| Elapsed Time | Both | Available |
| Real Time | Both | v9 |
| Text shadow | All but Race elevation chart | v9 shared shadow; new instances seed the template's radius, offset, opacity and thickness for numerics, route and timeline |
| Distance Timeline | Both | v10 minimal renderer with template shadow; full module parity pending |
| Route Map | Both | v11 offline trace and cursor with template shadow; dark MapKit background not implemented |
| Weather Widget | Both | v14 cached Open-Meteo card with template glass styling and 35% shadow |
| Zone Edge Bar | Race | v12 HR renderer with template shadow; five/six ranges configured per instance in Fusion |
| Elevation Chart | Race | v13 compact full-profile renderer with template shadow disabled; other module modes pending |

Template files are large because every element stores every module's sub-style;
they embed no route or image assets.

**Template style seeding (2026-11-01).** The panel now treats both the Mac
template positions and a small set of non-typographic style fields as starting
values. When an instance is first assigned to a slot, the control plane writes
the template's label visibility, numeric label color and shadow, plus the
route/timeline/zone/elevation shadow values. A resync never re-seeds an existing
slot, so Inspector edits and animation survive data and widget-list updates.
Font family and exact point sizes remain approximate, as accepted above, and no
font files are redistributed.

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
