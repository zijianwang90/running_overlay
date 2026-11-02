# Running Overlay Resolve Testing

## Route Map Background And Follow Camera — 2026-11-01

v22 adds an optional cached Mapbox background to the Route Map without changing
the offline render contract. When the panel has a public `pk.*` token and a Route Map widget is configured,
one Static Images snapshot is fetched per apply, using the same Web Mercator
bounds and coverage factor as the Fuse. The 1280×1280@2x PNG and token-free metadata are
written into the immutable bundle (`map.png`, `map.json`) and recorded in the
manifest. The token stays in local project settings; it is never written into the
bundle, templates, logs or repository.

The control-plane script creates or updates a Loader marked
`RunningOverlay.ManagedMapLoader`, connects it to the Fuse's optional `MapImage`
input, and sets `RouteMapBackground` only for route-map widgets. Removing the
token deletes the managed Loader and turns the background off. Fetch failures
(401, timeout, non-PNG) are reported as `Map background skipped: …` and do not
block data, overlay creation or the transparent trace.

The Fuse draws the snapshot with `Image:Transform` using sizes relative to the
source image, multiplies it through a circular/square card mask, and applies the
same camera to the trace, arrow and attribution. The follow camera pans to the
sampled route point; zoom is clamped to 1–8; course-up rotates the snapshot and
trace together while the arrow stays upright. Attribution text is drawn over the
card in addition to the logo and attribution baked into the snapshot.

Tests: six mapbox tests use a mocked fetch and no network, covering frame
coverage and square math, GPS gaps and a single fix, URL and token validation,
PNG-signature rejection, snapshot writing without the token, bundle manifest
entries and one-snapshot caching in the workflow service. Fusion-script tests
assert the managed Loader, `MapImage` connection and `RouteMapBackground` write.
157 Node/Lua tests and static checks pass.

Host evidence: Resolve Studio 21.1.1, independent `RO Numeric v7 Validation`
project, synthetic 100-record Toronto route on Bloor/Yonge/Church/Bathurst, at
1920×1080 ProRes 4444 with alpha. Frame 108120 rendered the cached snapshot with
the trace on Bloor and Church Streets; frame 108180 moved the follow camera to
Bathurst and Bloor; the course-up frame rotated the map and labels with the arrow
pointing up. The `Fusion Clip 2` overlay on video track 2 of the validation
timeline was removed for the inspection because it covered the Fuse output — that
baked overlay, not the Fuse, was the source of the earlier apparent figure-eight
trace. The validation project was altered as described and is disposable; the
original `Overlay Test` project was not touched.

Licensing and remaining checks: the snapshot includes Mapbox's baked logo and
attribution and is cropped by the card mask; a text attribution is drawn, but
placement and Mapbox terms need focused human review. A single snapshot softens at
high camera zoom for long races, live tiles and provider alternatives are not
implemented, and MapKit parity, UHD and non-16:9 verification remain pending.

## Distance Timeline Module — 2026-11-01

v21 completes the Distance Timeline's module content beyond the v10 minimal track.
The label is independently toggleable with editable text, font, style, size,
color and spacing; up to four metric-driven custom values render inline after the
main value with their own group/item gaps, size, color and opacity. Axis
typography also drives an optional marker-distance label, endpoints and distance
points can sit below or above the track, and the background/border expand to
cover every visible axis band. The four-slot stats bar supports Top, Bottom, Left
and Right attachment, Inside grouping, width/height overrides, screen-direction
offsets, item gap, divider, corner radius, background opacity and separate value
and label typography. Its cards reuse the shared metric values, add Progress, and
keep the approved adjacent-record interpolation rule.

Geometry follows the Mac layout: the content bounds union the 1.7× axis bands,
and an attached bar is placed outside those bounds with the 6-point gap. A
Bottom bar now sits completely below the axis row; the first host render exposed
a flipped sign that pushed it upward over the track, and the regression test pins
the corrected bottom edge. Stats slots default to Distance and Pace, matching
the Mac config; the Mac's 42-point bar with a 30-point value is intentionally
not enlarged, because it is the same default the Mac app uses.

Tests: the Lua module test now covers the label, both custom values, marker
label, background/border, stats bar background, divider, value and label text,
Inside bounds union and the corrected attached placement. 135 Node/Lua tests
pass, including the fengari execution of the real Fuse code.

Host evidence: Resolve Studio 21.1.1, independent `RO Numeric v7 Validation`
project, synthetic `style-validation` timeline at 1920×1080, ProRes 4444 with
alpha. A frame at 108120 with Widget 5's label, custom values, marker label,
background, border and stats bar enabled rendered all six features; the stats
bar sat below the START/FINISH row with no overlap. Resetting those inputs
rendered the template-default minimal timeline unchanged. The validation project
was saved and the original `Overlay Test` project was reloaded. Only 1080p was
inspected; preset visual variants, the media slot, route/elevation underlays and
live undo remain unchecked.

## Template Library — 2026-11-01

The panel presents the built-in templates and a saved-template library instead
of restoring three fixed choices without management. Saved templates are stored
by `src/workflow/template-library.js` in one JSON file under the application
user-data directory and are shared by every Resolve project; applying one copies
it into the project configuration. `src/domain/user-templates.js` validates the
stored form: one to sixteen elements, normalized names, metric names from the
widget catalog, finite positions, and style keys limited to Fuse suffix strings
with number, text or point values. Instance state, data-file inputs
(`ActivityFile`, `SyncFile`), `TimelineOriginFrame`, `TimeOffset`, `Metric`,
`Enabled` and `Position` are rejected so a template file cannot bind or
redirect renderer data.

Saving reads live values with `templateCaptureScript`, which returns each active
slot's metric, position and 300-plus style inputs as JSON keyed by slot number.
`pairCapturedSlots` pairs those slots with panel widgets by metric in slot order,
which also works on a cut overlay whose pieces keep separate compositions.
`composeTemplateElements` then prefers live values and falls back to the selected
template's placement for widgets not yet on the overlay.

Import accepts the portable `.rortemplate` JSON (`format:
running-overlay-resolve-template`, schema version 1) and Mac `.rotemplate`
files. Mac files contribute visible element types and positions only, with the
Mac top-down Y flipped; `elapsedTime` maps to `elapsed`, unknown visible types
fail, and more than sixteen elements is refused with a count. Export writes the
portable format.

Tests: template normalization and rejection cases for metric, name, position,
style values, excluded style keys and element count; library save, rename,
duplicate, update, export, import and delete on a temporary directory; file
round-trip; Mac import mapping, hidden-element removal and the sixteen-widget
limit; configuration compatibility with and without a library copy, including a
legacy file; Lua capture of active slots, slot one's `Red`/`Green`/`Blue`/`Alpha`
input names, string escaping, excluded inputs, failure acknowledgment and
pairing with duplicate metrics; and saved-template seeding of text, number and
point inputs through the generated update script, including an input the current
Fuse does not have. Panel tests cover grouped widget addition, capacity, remove
using the latest configuration, confirmation before replacing an existing
overlay's widgets, built-in and saved rows, and a saved template that later
leaves the library. 148 Node tests pass.

Host evidence: the built panel was rendered from the assembled plugin with
stubbed IPC for layout review, and the capture script was run read-only against
the cut `Overlay Test` overlay in Resolve Studio 21.1.1. Both pieces returned
four active slots with positions and 378 style values each in about 1 s; pairing
the captured slots with the widget list, composing, normalizing and round-
tripping produced a 32 KB template with every widget styled. The panel was
installed afterwards; interactive save, import and apply were not yet exercised
in the host.

## Built-In Templates — 2026-11-01

The Workflow panel replaces the Stack/Row/Grid choices with the Mac app's
built-in Easy Run, Race and Interval Workout templates. `src/domain/templates.js`
holds each template's element centers from the Mac 1920×1080 `.rotemplate` files
and flips Y to Fusion's bottom-up axis at full precision; the same file is
loaded by the control plane and the sandboxed panel. Saved configurations
without a template default to Easy Run, and the old `layoutPreset` field is
ignored.

Choosing a template replaces the widget list and keeps the identity of metrics
shared with the previous template, so their Fusion slots, styles and animations
survive. `dataUpdateScript` positions the first instance of each metric from the
template, gives duplicates and off-template metrics deterministic free slots,
and records the template plus widget list in `RunningOverlay.TemplateSignature`,
so a changed selection repositions widgets on the next update. Later manual
Fusion position edits otherwise stay authoritative.

Tests: exact template inventory and order, every element metric and position
against the Mac baseline, Race equal to Easy Run plus the zone bar and elevation
chart, unknown template rejection, duplicate/off-template fallbacks,
order-insensitive template matching, generated Lua position and signature
strings, and panel handlers for template selection, shared instance identity,
dropped widgets and the modified-list note.

Host evidence: assembled and reinstalled the panel, restarted Resolve, and
opened it on the independent validation project. The Template card showed Easy
Run, Race and Interval Workout with Easy Run selected; selecting Race updated
the note, left Heart Rate, Pace, Cadence, Power, Time and Clock active, and
autosave persisted `templateId: "race"` with the eleven-widget list. The
original `Overlay Test` project was reloaded; human review remains required for
the template positions.

## Template Style Seeding — 2026-11-01

Each built-in template element now carries a `styles` map of Fuse input suffixes
and values read from the same Mac `.rotemplate` file. For the Easy Run and Race
templates: every element hides the numeric label; Pace, Heart Rate, Cadence and
Power use the template's teal label and its 70 % shadow with a 4-pixel
lower-right offset; Route Map uses a 95 % / 7-pixel shadow; Distance Timeline
uses 90 % / 5 pixels with thickness 3; Zone Edge Bar uses 34 % / 8 pixels;
Elevation Chart disables the shadow. Numeric elements also seed their type sizes:
value, unit, label and icon points times the element scale over the 1280-point
reference (Pace/Heart Rate/Cadence/Power 34/20/16/22 pt at 0.75 scale; Elapsed
Time and Real Time 26/20/16/22 pt at 1.0). The control plane writes these inputs
only when an instance is first assigned to a slot (`fresh` or no previous slot
ownership), so a template switch keeps every existing Fusion slot and a resync
never overwrites later Inspector edits. Font family stays approximate, as
accepted; no fonts are redistributed.

The Fuse now also anchors a numeric element the way the Mac does: its top-left
corner sits at `Position`, inset by the minimal preset's 10×6 design-point
padding, instead of the value's baseline. The Fuse's own defaults changed to the
Mac numeric defaults (28/20/16 pt value/unit/label), replacing the earlier
0.065 value size that rendered roughly three times too large.

Tests: template style values per element, generated Lua style table and the
new-instance guard, the Fuse type defaults, the top-left anchor for the value,
unit and icon, and a fengari syntax check of the generated update script for all
three templates. 134 Node tests pass.

Host evidence: Resolve Studio 21.1.1, independent `RO Numeric v7 Validation`
project. The panel created a fresh Race overlay on an added synthetic 1920×1080
30 fps timeline (`style-validation`) with a synthetic seven-minute GPX. The new
slots held the exact template values: Heart Rate and Pace `ShowLabel 0`, label
`0.25/0.82/0.38`, shadow `0.7` and `±0.00208333`; Cadence and Power the same
numeric style; Route Map `0.95 / 0.00364583`; Distance Timeline
`0.9 / 0.00260417 / 3`; Zone Edge Bar `0.34 / 0.00416667`; Elevation Chart
`ShadowEnabled 0`.

After the anchor and type-size fix, a 1080p ProRes 4444 render at timeline frame
108120 showed the Mac-scale numeric values with their units and icons, the clock
and elapsed rows fully inside the frame, and the weather card clear of the
elapsed row. A generated update script then added a duplicate-pace probe to an
unused slot: it received `ValueSize 0.019921875`, `UnitSize 0.01171875`,
`LabelSize 0.009375`, `IconSize 0.012890625`, hidden label, teal label and the
70 % shadow, while the existing Heart Rate and Pace slots kept their previous
values. Save and reload of the project returned every probe value; the probe was
then removed and the validation project saved. An Easy Run overlay rendered from
the same template data at the same frame also placed the four left numerics, the
top distance timeline, the route map, the weather card and the clock/elapsed rows
without clipping or overlap. The original `Overlay Test` project was reloaded.
Only 1080p was inspected; the teal label color was not
visible because labels are hidden, and UHD/animation remain unchecked.

Earlier in the same validation session the managed node was deleted from the
`carrier` timeline of that project and the project saved, so `carrier` no longer
carries an overlay. `carrier` is a scratch timeline; no user timeline was
touched.

## Interval Components And Workout Structure — 2026-11-01

v20 adds automatic workout classification and four interval metrics (30–33). The
FIT parser now reads lap distance, elapsed time, average pace/HR/cadence/power and
ascent; the JS analyzer ports the Mac repeated-work-lap, steady-plan and normal
rules, including the uniform auto-lap guard. Validation checks lap statistics and
workout-structure enums; render TSV carries lap stats and one workout row.

Tests: analyzer cases for intervals, steady plans, normal laps and auto-lap
duration patterns; Lua tests for HUD phase/rep/remaining/progress, timeline
segments and marker, countdown time/distance and remaining/elapsed modes, work
summary display window, primary/secondary metrics and unit formatting, metric
registration and Inspector visibility. All fixtures are synthetic.

Host evidence: v20 installed and rendered in the independent validation project
with a synthetic five-lap workout, 1920×1080 ProRes 4444 alpha, Time Offsets
150/1000/150/880. At the work segment the HUD showed orange WORK, 1/2 and 2:08
left over a partly filled progress bar; the countdown showed the same 2:08,
CURRENT SET, WORK 1/2, clockwise remaining arc and `remaining` caption; the
timeline showed five phase-colored segments labelled 5:00/5:00/5:00/5:00/10:00
with the marker inside the cooldown. After the last work lap ended the summary
showed 5:00 LAP TIME with 5'23" /km, 880 m and 170 bpm secondaries. The slot and
activity path were restored, the validation project saved, and the original
project reloaded.

Limits: HUD HR/pace zone modes, metric slots, timeline centered window/filtering,
summary max HR, per-role fonts, glow and borders are not implemented. The palette
is fixed to the Mac defaults.

## Lap Pace And Lap Data — 2026-11-01

v19 adds FIT lap parsing, normalized lap boundaries and the Lap Pace metric (29).
The parser reads lap message 19 start time (field 2), end time (253) and total
distance (9), converts ends to activity elapsed time and interpolates start
distance from records. `validateActivity` enforces strictly increasing starts and
non-decreasing distances; render TSV adds `lap` rows. The Fuse selects the latest
lap at or before the current real time and computes in-lap pace.

Tests execute real Lua for the current-lap boundary, zero in-lap distance,
pre-lap and no-lap missing values, and metric registration order. Parser tests
check synthetic lap messages and interpolated boundaries; render-data tests
round-trip laps and reject unordered starts/decreasing distances. No private FIT
data is used.

Host evidence: installed v19 after saving and restarting Resolve. In the
independent synthetic validation project, a copy of the activity bundle with two
lap rows rendered Lap Pace `5'41"` at Time Offset 300 and `5'42"` at 1200 in
1920×1080 ProRes 4444; the values reflect real in-lap time over in-lap distance.
The slot and activity path were restored, the validation project saved, and the
original project reloaded.

Limits: no manual laps, distance-based auto laps, segment-aware lap exclusion, or
multi-lap history. GPX has no lap structure and shows `--`.

## Historical Weather — 2026-11-01

v14 adds the Easy Run/Race weather card and a control-plane weather cache.
`src/weather/weather.js` uses injected fetch/clock so tests perform no network.
Coverage: one UTC-day archive request with the activity start date and first
GPS point, exact start-hour selection, nearest-sample fallback, full WMO mapping,
required/non-null hourly data, numeric ranges, missing GPS, activity/start/GPS
cache binding, TSV-safe metadata, and stale-cache rejection. Bundle tests assert
`weather` rows survive activity TSV round trips. Configuration tests assert
weather persists, accepts a relabelled location, drops when the activity
identity/start changes, and rejects invalid conditions. Renderer tests execute
the real Fuse: cached condition, °C/°F conversion, FIT override with and without
the cache, placeholder card, hidden content rows, slot 16 and Inspector group
switching, plus `read_activity` parsing weather metadata. Host evidence: installed v14
(after saving and restarting Resolve), opened the independent synthetic
validation project, pointed the Fuse at a copied bundle with synthetic weather
metadata, and rendered 1920x1080 ProRes 4444 alpha. The card showed Rain, New
York, Thursday, 19° and 72% RH with white text, vector rain icon, blue card,
divider, border and 22% shadow. All 188 configured inputs survived save, close
and reopen; the original project was restored. Real activity/API fidelity,
UHD/non-16:9 output and the remaining card presets still need validation and
human visual review.

## Race HR Zone Bar And Elevation Chart — 2026-11-01

v12 adds editable five/six HR ranges, inclusive first-match classification, edge
and free placement/orientation, active width/height emphasis, inactive opacity,
current/threshold markers, optional values/zone labels, border, glow and shadows.
v13 adds cached full elevation profiles, fixed template Gaussian smoothing,
Catmull-Rom flattening, gradient area/line-only rendering, time-driven cursor,
guide and value label. Long profiles retain bucket extrema/endpoints and bound
vector work to 512 anchors before curve flattening. No provider/network added.

Tests execute real Lua: boundary overlaps/rounding, invalid ranges, missing HR,
all four edge marker directions, five zones, slot 16 and Inspector switching;
negative/constant/missing elevation, smoothing endpoints, sample-index spacing,
time-domain cursor clamps independent of distance, gradient parts, missing-cursor
suppression, line-only and bounded long-profile extrema. Script tests check
appended metric IDs, installation guards, Race chart position and new-instance
shadow defaults. Synthetic fixtures contain no private activity data.

Host evidence: installed v12/v13 after saving and restarting Resolve; independent
synthetic validation project, 1920×1080 ProRes 4444 alpha. Race-style bottom bar
showed active zone, inward arrow and threshold T. Both components were rendered
at activity 323.25 s and 1223.25 s via Time Offset; 189 configured inputs survived
save/close/reopen. Frames were inspected for geometry, cursor movement and fill.
The original project was restored. Gradient bands use single-sample fills to
avoid antialias seams, with the outline rendered at normal quality.

Limits: no live viewer undo acceptance, UHD/non-16:9 matrix or real-time long-
activity performance measurement. These are partial module implementations:
per-instance HR ranges, HR-only zones, full-profile elevation with fixed smoothing
and approximate gradient; no axes/stats/progress mode. No golden images updated.
Focused human review remains required for the visual output and time mapping.

## Numeric Icons, Distance Timeline And Offline Route — 2026-11-01

v10 adds original vector numeric icons, line-box label/unit alignment, the minimal
distance timeline with distance/time fallback, units, ticks, marker variants, axis
labels, element/progress glow and shared shadows. Template Monaco/PT Mono sizing
is corrected using their font units; unknown fonts retain native Fusion sizing.
Exact SwiftUI/Fusion typography is not an acceptance requirement.

v11 adds GPS retention from FIT signed semicircles and GPX track segments to JSON
and appended TSV columns, cached aspect-preserving Mercator route geometry,
antimeridian unwrapping, separate paths across GPS gaps/segments, a time-driven
position dot and optional endpoint markers. Numeric-only files remain valid.
Tests execute the actual Lua geometry, slot dispatch, marker visibility, NO GPS,
Inspector switching and font conversion; parser and bundle tests use authored
synthetic coordinates only, with no private GPS or map imagery.

Host evidence: Resolve Studio 21.1.1, independent synthetic validation project,
1920×1080 ProRes 4444 with alpha. v10's 178 inputs survived save/close/reopen;
numeric icons, corrected white units and timeline rendered. v11's 182 settings
survived save/close/reopen for both route renders; a fictional five-point loop
rendered with the cursor at activity 323.25 s and 1223.25 s via Time Offset.
Frames were visually inspected and the original project restored. Development
probe Fuses were removed. Captures/exports remain ignored local artifacts.

Remaining checks: live viewer interaction/undo, UHD and non-16:9 render matrix,
large GPS route playback cost and background-map provider integration. This is
an offline transparent trace, not full MapKit/template parity. Original glyphs
and visual output still need focused human review. (v22 later added the cached
background; see the section at the top.)

## Real Time And Text Shadow — 2026-10-31

Fuse v9 adds the Real Time metric and the Mac layered text shadow. Node tests run
the real Lua: 24/12-hour clocks with truncated seconds, fractional offsets,
midnight/noon, day wrap, missing start time, `startUtcUs` parsing from the
renderer file (in-memory `io`), shadow defaults, thickness layers and clamping, and
Process order: one offset silhouette per layer, blur, merge, then sharp text; zero
blur merges a sharp silhouette; disabled shadows draw nothing. Script tests cover
seeding the clock offset only for newly assigned instances, offset validation, and
the offset at activity start for named zones across DST, fixed offsets and the
computer-zone fallback.

Blur calibration (Resolve Studio 21.1.1, 1920×1080): a development-only probe Fuse
blurred a hard edge through `Image:Blur` Gaussian. The 16–84 % edge width gave
σ = 0.4293 × `BLUR_XSize` × width (22.9 px at 20/720). SwiftUI `ImageRenderer`
measured `.shadow(radius:)` as σ ≈ radius (4.10, 10.15, 20.34 px for 4, 10, 20).
With the derived constant, a 3 pt template blur measured σ = 4.75 px against 4.5
expected; the excess matches a fixed ~1.5 px edge spread. The probe was removed
from the installed Fuses afterwards. Only 16:9 1080p was measured.

Host: installed v9 after saving the open project and restarted Resolve. In the
separate synthetic project, applied Easy Run numeric styles (Monaco, scaled point
sizes, 70 % shadow offset 4,4 with blur 4 at scale 0.75) to pace and heart rate,
plus elapsed and a 12-hour Real Time at UTC−4; 63 inputs survived save/close/
reopen. A ProRes 4444 alpha frame showed `4:05:23 AM` and `00:05:23` for activity
time 323.25 s (08:00:00Z start, +1.25 s offset) with soft lower-right shadows. A
blur-0 render had shadow pixels at 0.7 alpha best matching the text at +4,+4 px
(expected 4.5). Original project restored. Not checked: live viewer, multi-layer
thickness on host, playback cost with many shadowed instances, other aspect ratios.

## Remaining Record-Based Numeric Metrics — 2026-10-31

Fuse v8 adds Avg Pace, Vertical Oscillation, Ground Contact Time, Stride Length,
Vertical Ratio, GCT Balance, Temperature and Grade. Node tests cover FIT field
scales, signed temperature and grade, right-side balance normalization, invalid
sentinels, GPX `atemp` and within-segment grade, bundle round trip through the
extended synthetic fixture, the metric-index contract between `widgets.js` and the
Fuse combo, and actual Lua formatting: units, rounding half away from zero for
negative temperature, temperature source fallback, and zero denominators.

Host: installed v8 and restarted Resolve Studio 21.1.1. In the separate synthetic
project, switched nine slots to the new metrics; 67 inputs survived save/close/
reopen. Three 1080p ProRes 4444 alpha frames exported (`yuva444p12le`). The alpha
matte showed values matching hand interpolation of the fixture: 9'24" /mi average,
8.5 cm, 244 ms, 1.12 m, 7.6 %, 49.8L / 50.2R, +1.0 %, manual-fallback 22 °C, and
`--` °F for FIT-only temperature inside a fixture gap. The `°` glyph rendered,
giving the first host evidence for non-ASCII text. Original project restored.

## Numeric Text Controls — 2026-10-31

Fuse v7 adds metric-specific units/formats, custom labels, separate label/unit
visibility, fonts, sizes, RGBA colors and four attachment positions with spacing.
`numeric-renderer.test.js` executes the real Lua file with Fengari (development
only): formatting and conversions, missing/zero/nonfinite pace, negative elevation,
minute carry, UTF-8 codepoints, bounds expansion, Create input registration and
Process consumption of separate styling/visibility on primary and slot 16.
Host drawing primitives are mocked; this proves control wiring, not glyph appearance.

After explicit installation approval, installed v7 and restarted Resolve Studio
21.1.1. In a separate synthetic project, set and verified 61 input values across
save/close/reopen. Rendered three 1920×1080 ProRes 4444 frames with ExportAlpha;
ffprobe reports yuva444p12le. Inspected the extracted frame: imperial pace 8'49\",
distance 0.57 mi, elevation 342 ft, elapsed 05:23, custom green Arial Bold label
and blue Courier unit, plus all four attachment positions. Restored the original
project without editing its timeline. Live viewer interaction and non-ASCII font
glyph appearance remain unverified; export and persistence checks passed.
Sizes/spacing remain normalized to frame width; exact SwiftUI font metrics,
tracking, alignment options and block anchoring are not yet reproduced. Top units
render explicitly and mm:ss carries rounded seconds correctly rather than copying
those two current Mac implementation defects. No intermediate-version migration
matrix is required for this unreleased first version.

## Independent Numeric Instances — 2026-10-31

Fuse v6 adds elevation, cadence, power and calories and up to sixteen numeric
instances. Node tests cover duplicate identities versus duplicate metrics,
configuration round trips, the capacity bound and layout bounds. In Resolve
Lua, the Fuse compiled successfully; its real formatter produced expected
labels, values, units, zero calories and missing values for the four new
metrics. Generated update transactions were exercised against a fake Lua
composition: duplicate metrics received different slots, retained identities
kept their slots after removal, and unrelated state survived.

Host validation in a separate synthetic project on Resolve Studio 21.1.1:

- Installed Fuse v6 and exercised the real update transaction. Adopted legacy
  four-metric inputs with unchanged size, color and +1.25 s offset.
- Created all eight metrics and a duplicate power instance with its own green
  style. Exported 30 frames at 1920×1080, 30 fps, ProRes 422; inspected the image
  with elevation 104 m, cadence 172 spm, power 246 W, calories 46 kcal, and the
  separate green power instance also reading 246 W.
- Removed calories and added a new calories identity. The surviving duplicate
  retained slot 9 and its color. Ordinary resync and project save/close/reopen
  preserved the duplicate style, slot map and timing offset.
- Restored the original Overlay Test project without editing its timeline.

Follow-up acceptance:

- Exported the real pre-v6 user project to a separate imported clone. Loaded
  the actual v5 Fuse and the v6 Fuse across restarts and exported the same
  three frames at 1080p ProRes 422. Decoded RGB frames were byte-identical
  (SHA-256 `0403b519cf382c42998fe1d96bca69f870db5488d4333b0f3b84a3d9aaee7edf`),
  covering old values, positions, fonts, colors and offsets at that range.
- Clicked all eight metric choices in the real Workflow panel on the clone;
  saved configuration contained all eight metrics. A Duplicate click exposed
  an autosave closure bug: row handlers referenced a replaced configuration.
  Fixed handlers to resolve current state and added two regression tests running
  the real panel code for duplicate/remove after autosave and capacity checks.
- ProRes 4444 retry on the saved/reopened synthetic project succeeded, then
  explicit `ExportAlpha` succeeded with `yuva444p12le`. Extracted alpha showed
  transparent background and visible numeric glyphs. The initial crash remains
  recorded as an unreproduced host failure, not a proven codec defect.
- Final live Duplicate/Remove recheck was blocked when macOS denied assistive
  access. Actual handler regression tests and real renderer instance tests pass;
  the post-fix mouse-level check remains a limitation.
- Restored v6 installation and original Overlay Test project. Test clones and
  exports remain local; private project exports are ignored, not committed.

## Cut Overlay Deliver Validation — 2026-10-31

Validated in Resolve Studio 21.1.1 on a duplicate of a locally edited timeline
with two overlay pieces after a ripple delete. The duplicate and render jobs
were removed afterwards; the original timeline and offsets were preserved.
Private footage and exports remain local and are not repository fixtures.

- Exported two 45-frame ranges spanning the cut (15 frames before, 30 after),
  at 1920×1080, 30000/1001 fps, QuickTime ProRes 422, video only.
- The left piece retained its existing +1 s offset. The right piece was rendered
  once at +5 s and once at 0 s, with the sync readout enabled on the duplicate.
- The left 15 frames were pixel-identical between exports. The right frames
  changed, with elapsed time at the cut reading 00:45:09 versus 00:45:04;
  the readout confirmed +5.000 s versus +0.000 s.
- All 45 frames decoded in each export, with no black frames and visible content
  in all four numeric widget regions. The frames immediately before and after
  the cut were visually inspected without an overlay dropout.

This validates a short composite export at one edited boundary. Full-length
exports, alpha-only output, UHD, other frame rates, and managed color workflows
are outside this check.

## Data Time Offset And Simplified Panel — 2026-10-17

`test/time-offset.test.js` covers recording-timezone inference (preferred zone,
whole-hour fallback, no overlap), the alignment preview's source-in and offset
math, the draft offset seeding only a fresh renderer, offset validation, the
read/write Fusion transaction and its refusal to overwrite an animated offset,
acknowledgment parsing, the configuration draft field, renderer ownership after
creation (a stale panel draft cannot overwrite the mirror), composition handle
reuse between nudges, refusal during apply/context switch/rendering, and an
unreadable offset (old Fuse) reported without failing the scan. Adapter tests
check the per-track chip data.

The rebuilt panel was exercised in an isolated browser preview with the actual
renderer, pickers, and alignment helper over a stubbed Workflow API and
synthetic three-clip data: timezone inference, the strip, **Use file times**,
creation with a draft offset, slider drags (25 input events coalesced into 8
writes, final value preserved), nudges, metric toggles switching the primary
action to **Update overlay**, and Clip details. These are browser checks, not
host validation.

Not yet validated in Resolve; required before merge:

1. Install the updated Fuse (REG_Version 5) and restart Resolve. Confirm an
   existing managed overlay gains **Data Time Offset (s)** at 0 and renders as
   before.
2. Create an overlay with a draft offset; confirm the Fuse starts at that value.
3. During Edit page playback and while parked, drag the panel slider and use the
   nudge buttons. Record responsiveness, viewer refresh, and any playback
   stutter. Check Fusion inspector ±0.1 s/±1 s buttons and **Show Sync Readout**.
4. Undo/redo a panel nudge; save, close, and reopen the project; run
   **Update overlay** after a trim and after a range change. The offset must
   survive each.
5. Animate the offset in Fusion and confirm the panel locks its control.
6. Experimental Edit Inspector path: copy
   `fusion/Templates/Edit/Generators/Running Overlay Numeric (Experimental).setting`
   into Resolve's `Fusion/Templates/Edit/Generators` directory and restart.
   Place it above the video, point its activity/sync inputs at a bundle, and set
   **Composition Start Frame** to the generator's record start. Record whether
   the Edit Inspector shows the offset, whether the viewer updates live, and
   whether blade-cut pieces keep independent offsets and correct activity time.
7. Cut overlay: blade the managed overlay with the footage, then ripple delete.
   Park on each piece and confirm the panel names it within a second, that a
   nudge changes only that piece, that the primary action no longer updates, and
   that undoing the cuts restores normal behavior. Resolve 21.1.1 at 29.97 keeps
   the ownership marker and media pool item on both pieces, gives each its own
   composition, and keeps activity time correct after a ripple delete.

## Capture-Time Pickers And Frameless Panel — 2026-09-30

`test/capture-time.test.js` covers filename candidates and invalid/ambiguous
tokens, recording-date timezone conversion, legacy fixed offsets and retained
milliseconds, skipped/repeated DST hours (including a half-hour transition),
unconfirmed filename evidence refusing sync, confirmed source-trim mapping,
and optional timezone fields round-tripping old configurations. Adapter tests
verify recognition from the original media filename after timeline renaming.

The installed native Resolve Workflow panel opened with no macOS traffic-light
title bar, restored the current activity/widgets, and populated all three
filename date/time candidates. No capture confirmation or overlay update was
applied to that user timeline during this check.

In an isolated browser preview using authored synthetic activity and mocked
Workflow persistence, the actual renderer/picker code passed timezone selection,
batch timezone changes preserving confirmed sources, save/reload of confirmed
times and complete clock pairs, edit invalidation, partial drafts surviving
scans, incomplete-pair rejection, clear-pair behavior, and DST skipped/repeated
hour selection. Screenshots verified layout. Native Electron timezone-menu
interaction could not be reliably automated; these interaction assertions are
browser checks, not a new native-host apply or end-to-end alignment validation.
The browser close-confirmation attempt also blocked the automation connection;
native dragging/minimize/close and the unsaved-change prompt need a manual check.
No visual golden or private fixture was committed.

Root `./scripts/check.sh` passed 287 Swift and 49 Node tests; SDK assembly,
Markdown links, publication audit, and whitespace checks passed. Xcode emitted
the existing local CoreDevice/simulator warnings without failing the macOS
check. Focused human review of wall-time conversions and saved configuration
compatibility remains required before merge.

## Commands

```sh
cd RunningOverlayResolve
npm run check
npm run assemble
npm run fixture:bundle
```

`npm run check` performs JavaScript syntax checks, JSON parsing, required Fuse
marker checks, portable fixture validation, and all Node tests. It has no npm
runtime or development dependencies.

`npm run assemble` requires an installed Resolve Developer SDK. It copies the
local, version-matched `WorkflowIntegration.node` into ignored `dist/` output.
The SDK binary must not be committed.

### Checking Exported Alpha

For an optional local host check, install `ffmpeg` and `ffprobe` on PATH and run:

```sh
node scripts/check-render-alpha.mjs /path/to/overlay.mov --visible-frame 40 --gap-frame 150 --visible-frame 200
```

Frame numbers are zero-based indices in the exported file, not Resolve timeline
frame numbers. Choose visible and gap frames from the actual test sync map. The
example matches a 270-frame synthetic timeline with clips at 0–119 and 180–269.
Use a duplicate timeline containing only the managed overlay to isolate alpha
from source video. Never remove source clips from a working project for this test.

The checker decodes the alpha plane. A visible frame must have both transparent
background pixels and opaque glyph pixels; a gap frame must be entirely
transparent. Missing alpha, missing frames, and failed expectations exit nonzero.
This checks transparency, not glyph correctness or color accuracy. These local
media checks are optional and do not add FFmpeg or Resolve dependencies to CI.

## Automated Coverage

- FIT header/definition/data parsing for record, session, and timer events.
- Compressed FIT timestamps, rollover, missing full references, timer events,
  and later full-timestamp resets.
- GPX microsecond timestamps, timezone and XML validation, segment-aware
  distance/pace, missing metrics, and exact Resolve sync-map timing.
- Activity interpolation and out-of-range transparency semantics.
- 23.976/29.97/59.94 rational frame-rate conversion.
- Inclusive/exclusive Resolve end-frame normalization.
- Capture-evidence confidence and timezone behavior.
- One- and two-anchor camera clock calibration.
- Source-in-aware piecewise sync compilation across jump cuts.
- Review-only evidence refusal.
- Renderer activity/sync data round trips.
- Mocked read-only Resolve Promise API scan.
- Workflow persistence, context switching, stale/missing managed overlays, and literal-safe Fusion scripts.
- Rendering pauses scans and prevents apply from saving settings or mutating the
  timeline; checks resume when rendering ends.
- Decoded-alpha checks distinguish visible glyphs, transparent gaps, and opaque
  backgrounds; CLI frame expectations reject ambiguous or missing inputs.
- Static Fuse contract checks for automatic origin mapping, explicit reload,
  renderer-file guidance, and visible load diagnostics.

## Fixture Policy

Committed fixtures are synthetic JSON and an authored GPX track with fictional
coordinates. Tests construct FIT bytes in memory, so no personal activity file
is tracked. Fixtures contain no athlete name, device ID, real media path, or
personal GPS trace. `fixtures/activity.synthetic.gpx` was authored for this repository;
its two segments intentionally contain a spatial jump, a missing heart-rate
sample, and microsecond timestamps to check the importer contract.

## Required Manual Resolve Matrix

Before calling P0 host integration complete, test Resolve Studio 21 on macOS
with:

- Edit and Fusion page viewer controls;
- 24, 25, 30000/1001, 30, 50, and 60000/1001 fps;
- timeline starts at zero and 01:00:00:00;
- ordinary trim, gaps, jump cuts, disabled clips, and overlapping-track
  diagnostics;
- project close/reopen and media relink;
- 1080p and UHD, YRGB and color-managed projects;
- random scrub, reverse scrub, full Deliver, and multiple Fuse instances.

Variable speed, reverse playback, freeze frames, speed ramps, multicam, and
compound clips must be recognized as unsupported until their source-time
mapping is verified.

## Live Host Findings

On 2026-08-17, Resolve Studio 21 successfully loaded the Workflow plugin and
Numeric Fuse on a UHD 30 fps timeline starting at `01:00:00:00`. A generated
segment covered frames 108000–109502; Fusion local frame 1069 mapped to Resolve
frame 109069 and rendered the expected synthetic value of 123 bpm. This closes
the basic in-host data/read/render path but not the wider manual matrix above.

## P1 Host Findings — 2026-09-11 And 2026-09-13

Tested with local Resolve Studio 21.0.4 on macOS using generated solid-color
30 fps video and repository-authored synthetic activity JSON. No private source
media or activity files were used. Host projects and generated files are local
scratch data, not committed fixtures or visual golden updates.

| Check | Observed result |
|---|---|
| 24, 25, 29.97, 30, 50, 59.94 fps × zero / `01:00:00:00` origins | Twelve cases passed source-trim, reference-range, managed composition extent, and explicit origin-input assertions |
| 30 fps media with source frame 360 | First visible activity time remained 12,000,000 µs at every tested timeline rate |
| Leading gap and later source start | Gap had no sync segment; source trim contributed to the first visible sample |
| Repeated apply | One owned overlay; selected metric and color preserved |
| Reference extent increase | New owned range matched reference end; previous Fusion metric and color survived replacement |
| Workflow panel | Actual native bridge first creation and update completed; saved activity and capture confirmation restored on panel reopen |
| Resolve project save/close/reopen | Managed clip ID, Fusion data inputs, and explicit origin survived |
| Imported 2× speed, reverse, and freeze | Resolve OTIO round trips were classified as unsupported |
| Resolve Deliver | Completed a 270-frame 1080p30 ProRes 4444 final composite; the synthetic source remains visible beneath Numeric content |
| Fuse frame output | Rendered expected synthetic Numeric content with an RGBA transparent background |

The matrix validates source and composition geometry plus origin inputs; it is
not a claim that every frame of every frame-rate/color-management combination
has a golden-image comparison. Resolve OTIO truncates source starts at timeline
frame precision when source and timeline rates differ; regression tests preserve
source API authority within that corroboration interval.

The native Workflow bridge requires separate host testing: it returns unusable
empty objects for Fusion Tools, reports a parse error for void/nil results, and
executes composition scripts asynchronously. Node tests cover unique
acknowledgments, stale acknowledgment rejection, nil-result retries, persistence,
context changes, ownership checks, and sync protections; host tests additionally
exercise the actual Lua transaction and composition placement.

### Remaining Production Gates

- Full UHD/multi-widget performance and color-managed output matrix.
- Crosshair interaction on both Edit and Fusion pages across host versions.
- Signed installation, cross-machine packaging/relink, and broader media metadata.
- Broader alpha/export compatibility beyond the isolated 1080p30 ProRes 4444
  case below, including other codecs and color-management modes.
- Focused human review of time conversions, persistence, ownership/failure
  recovery, and Fusion versus timeline undo before merge or release.

### Final Automated Verification

On 2026-09-13 the repository check passed all 287 Swift tests and 28 Resolve
Node tests. Local SDK assembly, synthetic bundle generation, Markdown-link
validation, and source-publication audit passed. The final source also passed
the live-host create/repeat/range-replacement assertions. A final UI recheck
after the product-directory/status refinements was blocked by the locked Mac;
the earlier native Workflow first-create/update and project-reopen checks above
were completed.

## Follow-up Host Validation — 2026-09-28

Resolve Studio 21.0.4 on macOS completed native-panel activity import, capture
confirmation, and first creation on a fresh synthetic timeline. The product's
Application Support configuration and bundle location were used successfully.

A duplicated timeline containing only the managed Fusion overlay exported all
270 frames as a single QuickTime ProRes 4444 clip at 1920×1080, 30 fps, with
Export Alpha enabled and Straight alpha. Decoded frames 40 and 200 contained
transparent background and opaque glyphs; gap frame 150 was entirely transparent.
The new alpha checker passed all three assertions. The Fuse's PNG output also
passed. No golden snapshots or private media were used.

The earlier opaque-output observation was not an isolated overlay test: the
reproduced single-clip export still contained the solid-blue source video despite
the test's track-disable request. The isolated export establishes that the
managed overlay can retain alpha through Deliver. It does not establish the
behavior of track muting in every render mode. Use an overlay-only duplicate for
alpha validation instead of assuming a track-disable request removed the source.

Host testing also exposed continuous scans while exporting. The service now
pauses scans and rejects apply during rendering; the manager rechecks before
mutation. Polling waits after completion to allow idle time between slow scans.
The updated native panel displayed the rendering pause with apply disabled;
after export, it returned to the synchronized state with apply enabled. Reopening
the panel restored the saved activity and capture confirmation, and repeat apply
kept the same managed clip ID.

Final validation passed 287 Swift tests and 31 Node tests, SDK assembly,
synthetic bundle generation, Markdown links, source-publication audit, and
whitespace checks. Xcode reported local simulator/CoreDevice compatibility
warnings, but the macOS repository check completed successfully. Wider rendering
coverage and the focused human review listed above remain release gates.

## Activity File Compatibility Validation — 2026-09-28

The updated native Workflow panel imported the authored four-point GPX fixture
into the saved synthetic project. It preserved the six-digit fractional start
time and capture confirmation. Create/Update Overlay synchronized two existing
video segments while retaining the owned managed-clip ID. A Fusion frame using
the missing heart-rate sample displayed `--` on the transparent Numeric widget.
No private activity or source media was used.

The Node regression suite covers compressed FIT timestamp rollover, full
timestamp resets, compressed timer events, GPX time zones and segment distance,
missing metrics, malformed input, and conversion through the render-data and
sync-map boundaries. The final repository and publication checks are recorded
in the current project log: 287 Swift and 40 Node tests passed, along with SDK
assembly, synthetic bundle generation, Markdown links, publication audit, and
whitespace checks. Focused human review of time conversion and Fusion rendering
remains required before merge.

## Multi-Widget Numeric Validation — 2026-09-29

The native Workflow panel added, removed, and reordered metrics, changed to the
two-column preset, saved settings, and restored the saved selection and preset
on reopening. Its original scratch `synthetic.mov` had disappeared from `/tmp`
between sessions, so the first scan correctly rejected the offline source.
After regenerating a matching local synthetic 320×180 ProRes source, the panel
scanned it without that diagnostic. **Create / Update Overlay** synchronized
two segments, retained the managed clip ID, enabled Heart Rate and Pace in grid
positions, and produced a 1920×1080 RGBA frame. The previously edited Pace size,
red channel, and two alpha keyframes survived this panel-driven update.

On the same local synthetic Resolve Studio 21 project, a host-driven Fusion
transaction connected one Numeric Fuse directly to MediaOut. A saved 1920×1080
RGBA frame displayed all four metrics in grid positions. Its alpha plane had
transparent background and nonzero glyph pixels. The host also accepted a
three-widget reorder and removal of Distance. A subsequent data resync retained
Pace size `0.091`, red channel `0.3`, position, and both alpha keyframes at
frames 0 and 100; the updated composition still rendered a frame.

The earlier two-Fuse Merge graph created and connected correctly, and each
Numeric node rendered individually, but saving its composite frame repeatedly
terminated Resolve. The managed renderer therefore uses one Fuse with separate
controls for the four metrics. The old graph was removed from the synthetic
test composition by the migration transaction. This does not establish a
general Merge/Fuse compatibility fix.

The Node suite covers legacy configuration defaults, metric uniqueness, preset
positions, and generated transaction structure. No visual golden was updated.
Full UHD/color-managed performance and a complete Deliver export with four
metrics remain manual release checks. Focused review should also inspect
existing manually changed single-widget Metric controls during migration.

## Date And Custom Numeric — 2026-11-01

v15 adds metric 22 (Date) and 23 (Custom Numeric) to the managed Fuse. Date uses
manual UTC civil-date arithmetic rather than `os.date`, because the Lua host
must not depend on locale, timezone or the UTC format flag. Six date patterns
match the Mac en_US_POSIX set, and the instance clock offset applies to the
activity instant. Custom Numeric tests cover source order, number/integer/
duration/clock/date/pace/percent/coordinate formatting, precision rounding,
unit override, missing values and derived average pace/vertical ratio.

The Lua suite executes the real Fuse at fixed epoch `1767254400000000`
(2026-01-01T08:00:00Z) so date and clock assertions are deterministic. Node
tests cover metric identity, panel/widget acceptance and Inspector combos.

Host evidence: installed v15 after saving and restarting Resolve. In the
independent `RO Numeric v7 Validation` project, slots 11 and 12 were set to Date
and Custom Numeric (Distance, 2 decimals). Save, restart and reopen retained
both metric IDs, positions, date format and custom controls. A 1920×1080 ProRes
4444 alpha render showed `2026-01-01` with the Calendar glyph and
`DISTANCE 930.51 m`; the unit and shadow rendered. Frames beyond the activity end
produce an empty composite because the existing Process path requires a sample,
so the midnight rollover is covered by the injection test rather than a host
offset. The original `Overlay Test` project was reloaded afterwards.

## HR Zone Label — 2026-11-01

v16 adds metric 24 (HR Zone), which reuses each slot's zone count/ranges and the
existing `heart_rate_zone` classification. The Lua test drives the real Process
path for rounded boundaries, missing HR, narrowed five-zone ranges and Inspector
visibility. Host evidence: slot 13 in `RO Numeric v7 Validation` rendered `Z2`
with the Heart glyph at 1080p ProRes 4444 alpha; save, close and reopen retained
metric 24, the enabled flag and zone range inputs. The original `Overlay Test`
project was restored.

## Running Gauge — 2026-11-01

v17 adds metric 25 (Running Gauge): dial fill, outer ring, ticks, dividers,
distance/time progress ring and four region bindings. The Lua test drives the
real Process path and checks all four region values, labels, units and the
shape count with effects toggled off. Progress fractions use normalized total
distance/duration and clamp to 0–1. Host evidence: slot 14 in
`RO Numeric v7 Validation` rendered a 260 px dial with 60 ticks, distance/time
progress ring, dividers and the four regions (`DIST 0.93 km`, `PACE 5'29" /km`,
`TIME 05:26`, `HR 146 bpm`) at 1080p ProRes 4444 alpha. Save, close and reopen
retained metric 25, size and progress mode. The original `Overlay Test` project
was restored.

## Decor Elements — 2026-11-01

v18 adds metrics 26–28 (Solid Color, Icon, Text). The Lua test covers rendering
with `sample_activity` returning nil: rectangle geometry from the position input,
fill color propagation, original-glyph icon selection/size and left/right text
alignment. Only project-owned glyphs are exercised; no SF Symbols or external
assets are used. Host evidence: the primary slot plus slots 15 and 16 in
`RO Numeric v7 Validation` rendered a tinted rounded rectangle, the original
Calendar glyph and `RUNNING OVERLAY` text at 1080p ProRes 4444 alpha. Save,
close and reopen retained metrics 27/26/28 and the text content. The original
`Overlay Test` project was restored.
