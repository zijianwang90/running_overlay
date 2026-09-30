# Running Overlay Resolve Requirements

Last updated: 2026-09-30

## Product Boundary

Running Overlay Resolve is a sibling product, not a bridge to Running Overlay
Studio. A user must be able to install and use it without installing or
launching the macOS app. It may reference the main product's overlay catalog,
data semantics, default styling, and reviewed visual examples.

## Primary Workflow

1. Import FIT or GPX activity data from the Resolve Workflow panel.
2. Scan a chosen reference video track without moving or trimming user clips.
3. Automatically accept only capture-time matches supported by sufficiently
   independent evidence; explain and request confirmation for ambiguous dates.
4. Create or update a Running Overlay Fusion composition.
5. Add, select, position, and style live overlay widgets inside Resolve.
6. Preview and Deliver from the same renderer without an intermediate overlay
   video.

## Timing And Alignment

- FIT/GPX real timestamps are the alignment authority. Timer pauses do not
  compress the alignment axis.
- Timeline, source, activity, and renderer time domains remain explicit.
- Stored timeline authority uses integer frames and rational frame rates.
- Stored activity authority uses integer microseconds.
- Every ordinary edit is represented by a piecewise segment mapping timeline
  frames to activity real elapsed time.
- Source trims must contribute `sourceStartFrame / sourceFrameRate` to the
  first visible frame's capture instant.
- Missing segments and activity-out-of-range frames render transparent; values
  must not clamp to the first or final sample.
- Renderer protocol/file failures must produce a visible diagnostic rather than
  a plausible blank result. Optional gap diagnostics must remain disabled by
  default so intentional gaps still render transparent.
- A single confirmed anchor establishes camera offset. Two separated anchors
  may establish bounded linear clock drift.
- Variable speed, reverse, freeze, and speed ramps must be represented by
  explicit rate segments or rejected with a user-facing diagnostic.

## Trust And Safety

- Resolve `Date Added`, filesystem modification time, and timezone-free dates
  must never be silently accepted as capture start.
- A single plausible creation date requires confirmation unless a vendor-
  specific contract proves its semantics.
- High confidence requires agreement between independent evidence groups, not
  two UI fields derived from the same container tag.
- Analysis remains local. Bundles must not include athlete identity, device
  serial numbers, raw private metadata, or unrelated source paths.
- The plugin does not reorder, move, trim, or ripple-delete user media during
  alignment.

## Capture-Time Selection

- Recognize one valid bounded `YYYYMMDD_HHMMSS` token in the original source
  filename, including hyphen separators. Invalid or multiple tokens supply no
  candidate. Filename wall time has no timezone or automatic confirmation.
- Use a calendar and hour/minute/second and timezone selectors for source starts
  and both sides of camera clock pairs. Do not require ISO text entry.
- Offer a shared recording timezone and explicit batch application to unconfirmed
  filename/manual candidates; preserve already confirmed sources and untouched
  absolute metadata candidates.
- Resolve named timezone offsets for the chosen date. Reject missing DST hours;
  require an occurrence choice for repeated hours. Keep saved subsecond precision
  until date/clock values are edited.
- Invalidate confirmation when a source's date, clock, or timezone changes.
  Preserve partial picker drafts during scans; reject incomplete clock pairs on
  save/apply. Persist zone preferences with backward-compatible defaults.
- Use a dark frameless draggable header with explicit minimize and close
  controls. Keep the unsaved-change close guard.

## P0 Acceptance Criteria

- A synthetic 30000/1001 timeline with a 12-second source trim maps its first
  visible frame to the expected FIT microsecond.
- A later jump cut maps to its own source capture time rather than continuous
  program duration.
- One ambiguous timestamp produces a review diagnostic and no applied segment.
- A sandboxed Workflow panel can scan an ordinary reference track and produce
  a data-only bundle.
- Numeric Fuse renders Heart Rate, Pace, Distance, and pause-adjusted Elapsed
  Time from the bundle with a native position control.
- A composition starting at the sync map's timeline start needs no manually
  calculated origin frame.
- Project checks do not require private FIT, GPS, or video files.

## P0 Non-Goals

- Visual parity for the full overlay catalog.
- Automatic composition/node creation.
- Production OFX packaging, signing, or notarization.
- Cross-platform media metadata extraction.
- Compressed FIT timestamp reconstruction or broad FIT profile support.
- GPX import.
- Multicam, compound-clip, and variable-retime resolution.
- Audio, optical-flow, or camera-telemetry correlation.

## P1: Managed Overlay And Saved Synchronization

- Reject missing/invalid source FPS and unverified source-time mappings. A
  temporary local OTIO scan must corroborate ordinary source identity and trim.
  Never assume every TimelineItem is at normal speed.
- The reference fingerprint includes timeline origin, reference extent, rational
  frame rate, track selection and enabled state, item enabled state, media and
  camera identity, geometry, and mapping diagnostics.
- Apply a two-anchor clock model to both the first sample and progression inside
  each sync segment.
- Create one owned Fusion composition on a separate video track. Automatically
  connect data and set an explicit composition origin, including zero.
- Repeated apply updates the owned composition without duplicating it. Preserve
  Fusion widget parameters, animations, and node connections when the reference
  extent changes. Never replace or trim reference media.
- Restore normalized activity, capture confirmations, reference track, and camera
  anchors by stable project/timeline identity. Persist only validated versioned
  settings, using atomic replacement and private local file permissions.
- Detect stale synchronization after reference edits, track disablement, or loss
  of the managed overlay. Rescan at apply time and reject stale panel snapshots.
- Write each apply to a new immutable bundle revision. Do not delete old revisions
  automatically: saved compositions and undo can still use them.
- Reject duplicate ownership and missing ownership markers on known managed
  clips instead of guessing which clip may be overwritten.

## Activity File Compatibility

- Decode compressed FIT timestamps using the previous full timestamp, including
  five-bit rollover and later reference resets. Reject a compressed message
  without a valid full timestamp reference.
- Import timed UTF-8 GPX track points with explicit timezone timestamps,
  segment-aware distance, elevation, speed or coordinate-derived pace, and
  supported numeric extensions. Do not infer a timer pause from a sparse GPX
  interval or add distance across separate track segments.
- Preserve real elapsed time and microsecond timestamps in the normalized
  activity and compiled sync map. Missing values stay unavailable through
  interpolation and Fusion rendering rather than borrowing adjacent metrics.

## Multi-Widget Numeric Editing

- Let the Workflow panel add, remove, and reorder any unique selection of Heart
  Rate, Pace, Distance, and Elapsed Time, with one to four widgets active.
- Offer vertical, horizontal, and two-column grid starting positions. A changed
  selection or preset reapplies those positions in list order.
- Create and connect the managed renderer automatically. Users do not wire
  Fusion nodes. Each metric has its own native Fusion position and style inputs.
- Persist the selection, order, and preset per project and timeline. Old saved
  configurations default to one Heart Rate widget without a schema-version bump.
- An ordinary synchronization keeps each active metric's position, size, color,
  font, and animation controls. Removing a metric disables its display; adding
  it again may reuse its previous Fusion styling.
