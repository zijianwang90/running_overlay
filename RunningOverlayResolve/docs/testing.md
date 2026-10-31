# Running Overlay Resolve Testing

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

The first export attempt with ProRes 4444 crashed Resolve. After reopening the
saved test project, ProRes 422 completed normally. The cause is unresolved;
4444/alpha output is not accepted for this increment. The synthetic test project
is retained for reproduction. Eight-widget panel interaction and an actual v5
project visual comparison remain manual follow-ups; migration above used v6
with the legacy identity map removed, rather than a v5 binary side by side.

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
