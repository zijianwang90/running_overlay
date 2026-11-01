# Running Overlay Resolve

Running Overlay Resolve is an independent DaVinci Resolve product that renders
activity graphics inside Resolve. It does not require the Swift macOS app or
produce intermediate overlay videos.

## Current Development Slice

The Workflow panel imports FIT or GPX data or normalized activity JSON,
checks a reference video track, and creates or updates a live Numeric overlay
on a dedicated video track. The panel supports seventeen numeric metrics,
original vector numeric icons, a minimal distance timeline and an offline route
map with a time-driven position marker, an HR zone bar, a compact elevation
chart, and the Easy Run/Race weather card. Up to sixteen independent instances,
including duplicate metrics, share one Fuse. Stack, row and grid provide initial
layouts; each instance has native Fusion position and style controls. Route Map
retains FIT/GPX GPS and segment boundaries, but does not yet provide road-map
imagery. See the [user guide](docs/user-guide.zh-CN.md) for controls and the
[parity inventory](docs/mac-app-parity.md) for remaining work.

The plugin cross-checks source identity and trim against a temporary Resolve
OTIO export. Missing source frame rates, retimes, freeze frames, reverse,
compound/multicam references, unknown effects, and ambiguous capture timestamps
block synchronization with an explanation. Source clips are never moved or
trimmed. The sync map preserves cuts, gaps, real activity time, and source trims.

Settings are stored locally per Resolve project and timeline: activity data,
confirmed capture times, optional one- or two-anchor camera calibration, and an
offline historical-weather snapshot.
Opening the panel restores those settings. Read-only polling notices changes
while the panel is open; every apply also rescans before updating. Updates use
immutable data revisions and retain existing widget styles. Changes to reference
extent replace only the owned overlay clip, preserving its Fusion composition.

FIT records support normal and compressed timestamps, including 5-bit rollover;
timer stop/start events keep their real-time position. UTF-8 GPX track points
provide timestamps, segment-aware distance, pace, elevation, and common numeric
extensions. GPX does not contain FIT timer events, so sparse point intervals are
kept as real elapsed time without inferring a pause. Unknown metrics remain
missing rather than copying a nearby value.
Synchronization checks pause during Resolve renders, and updates are refused
until export finishes. Automatic scans wait eight seconds after completion so a
slow host does not trigger continuous polling.

## Development

Requirements:

- Node.js 22 or newer;
- Resolve Studio 21 and its local Developer SDK for the Workflow panel;
- the current `RunningOverlayNumeric.fuse` installed in Resolve's Fusion Fuses
  directory. Restart Resolve after updating it.

```sh
cd RunningOverlayResolve
npm run check
npm run assemble
npm run fixture:bundle
```

Assembly copies the version-matched `WorkflowIntegration.node` from the installed
SDK into ignored `dist/` output. This SDK binary is not committed or redistributed.
Assembly preserves generated test bundles outside its installable payloads.

Install `dist/workflow-plugin` in Resolve's Workflow Integration Plugins directory
as `com.runningoverlay.resolve`, and install
`dist/fusion/Fuses/RunningOverlayNumeric.fuse` in the user's Fusion Fuses directory.
Launch through **Workspace > Workflow Integrations > Running Overlay Resolve**;
a standalone Electron launch cannot establish the host connection.

## Using The Panel

The panel is one screen with a single primary button whose label always names
the next step. Edits save automatically; only that button changes Resolve.

1. Open a Resolve timeline and the Workflow panel. The current timeline is
   scanned automatically; use ↻ to scan again.
2. Choose a FIT or GPX file (or the synthetic activity JSON).
3. Pick the reference video track from the track chips. A fresh timeline with
   no clips on V1 switches to the first track with clips once.
4. **Time alignment** infers the recording timezone from filename clocks and the
   activity, and shows the clips against the activity on a strip. Check the
   zone and strip, then press **Use file times** to accept the detected times for
   all files at once. Files without a usable time, and camera drift pairs, are
   under **Clip details**.
5. Toggle metrics and choose **Stack**, **Row**, or **Grid**. Size, font, color,
   and exact position stay in Fusion.
6. Press **Create overlay**. The plugin creates the composition and connects its
   data inputs automatically.
7. Play or park the playhead in Resolve on a clear moment, such as the start or
   a stop, and adjust **Data timing** until the numbers change when it happens
   on screen. Positive values show later activity data. The same control is the
   **Data Time Offset (s)** input on the Numeric node's Sync page in Fusion,
   with ±0.1 s and ±1 s buttons and an optional sync readout.
8. Save the Resolve project. After editing the reference track, press
   **Update overlay**; it preserves the offset, Fusion positions, styles, and
   animation.

Filename tokens such as `PRO_VID_20260702_184703_00_009.mp4` supply a local wall
clock candidate, never an inferred UTC instant. The timezone inference only
preselects a zone; nothing is used until **Use file times** or a per-file
confirmation. Named timezones use the offset for the selected date; skipped
daylight-saving times are rejected and repeated hours need an explicit choice
in Clip details. Changing a time or zone clears its confirmation.

The offset applies to the whole overlay. Panel writes are refused while an
update runs or Resolve renders; an offset animated in Fusion is edited only
there. `fusion/Templates/Edit/Generators/` contains an experimental generator
for checking Edit Inspector exposure of the offset; it is not part of the
managed workflow (see the testing guide).

The panel has a dark frameless header in place of the native macOS traffic-light
bar. Drag the title to move it; use the header minimize and close buttons.

The generated transparent still and internal Fusion carrier are setup resources,
not rendered overlay media. Retain the plugin's Application Support directory
(`Running Overlay Resolve`), including all bundle revisions: saved projects and
undo history can still reference older revisions. Settings and bundles are local
to this computer; transferring a project to another computer is not yet a
portable packaging workflow.

For a separate transparent export, use a duplicate timeline containing only the
overlay, then export QuickTime ProRes 4444 with **Export Alpha** and **Straight**
alpha. This path passed the 1080p30 host check, including transparent gaps. Keep
the original source timeline intact. Ordinary final composites include the
source video beneath the live widget. See the testing guide for coverage limits
and the optional decoded-alpha checker.

## Weather

The Weather card uses the same public Open-Meteo archive service as the Mac app;
no API key is required. Choose or change the activity, then press **Fetch
historical weather** in the panel. The request uses the activity's start date
and first GPS point. The returned snapshot is saved with the project and copied
into the immutable activity bundle, so Resolve preview and Deliver never access
the network. Editing the location label changes only the displayed text. Weather
needs GPS in the activity; activities without coordinates show placeholders.

## Limits

- Ordinary constant-speed source clips only; unsupported timing is rejected.
- Broader FIT profiles, full overlay-catalog parity, and production OFX packaging
  remain follow-up work. GPX import supports UTF-8 track points with explicit
  timezone timestamps; route-only files and timezone-free dates are rejected.
- One managed composition per reference timeline. Duplicated ownership markers
  or removed markers on a known managed clip require repair before updating.
- Updates retain the Numeric Fuse and each metric's styles and animations.
  Replacing a
  clip to change its duration does not preserve separate Edit-page clip effects.
- Fusion data changes form one undo transaction. Creating/replacing timeline
  clips uses several SDK actions; it is not one timeline-level undo operation.
- Change detection runs while the panel is open and again at apply time. The
  renderer does not inspect the live timeline or automatically regenerate data.
- Signing, distribution, broad camera metadata confidence, and the remaining
  production rendering matrix are outside this development slice.

See the [Chinese end-to-end user guide](docs/user-guide.zh-CN.md),
[requirements](docs/requirements.md), [architecture](docs/architecture.md),
and [testing and host findings](docs/testing.md). The repository's root license
and contribution rules apply to this subproject.
