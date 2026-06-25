# Running Overlay Roadmap

Last updated: 2026-04-24

## Milestone 0: Documentation Bootstrap

Status: completed

- Product requirements.
- Development guide.
- Architecture notes.
- Project log.
- Initial ADR.

## Milestone 1: App Skeleton

Status: completed

- Native macOS project.
- Main editor layout.
- Project settings UI.
- Placeholder timeline.
- Placeholder preview and parameter panel.

## Milestone 2: FIT Timeline

Status: in progress

- FIT import.
- Activity timeline model.
- Timeline ruler.
- Ruler hover data.

Completed so far:

- Native `.fit` file picker.
- First-pass FIT parser for standard record/session messages.
- Activity timeline population from parsed FIT data.
- Full-width timeline ruler hover with elapsed time, real-world time, and distance.
- Extended FIT record parsing for running dynamics: vertical oscillation, ground contact time, stride length, ground contact balance, temperature, grade.
- Full lap data parsing (FIT message type 19): lap index, start/end elapsed time, distance, pace, heart rate, cadence, power, ascent, kind (warmup/active/rest/cooldown classification).
- `ActivityTimeline` lap query methods: `currentLap(at:)`, `lapElapsedTime(at:)`, `lapProgress(at:byDistance:)`.

## Milestone 3: Video Import And Placement

Status: completed

- Batch video import.
- Metadata extraction.
- Automatic timeline placement.
- Manual placement fallback.

Completed so far:

- Native multi-select video import.
- AVFoundation duration and creation-date metadata read.
- Filename timestamp parsing for common date patterns.
- Media browser refresh with alignment status.
- Finder-to-media-browser video drop import.
- First-pass automatic placement onto timeline tracks.
- Manual drag from media browser to timeline.
- Default empty timeline drop track when no clips are aligned.

Remaining future improvements:

- Timecode metadata.
- More robust camera grouping and alignment confidence.

## Milestone 4: Timeline Editing

Status: completed for first-pass AppKit editing

- Multi-track timeline.
- Clip selection and movement.
- Timeline zoom.
- Keyboard shortcuts.
- Clip offset panel.

Completed so far:

- Clip selection.
- Direct horizontal dragging of existing timeline clips.
- Delete selected timeline clips.
- Highlight media drop target layers and expose one new layer target during drag.
- Inspector-based clip offset adjustment.
- Apply selected offset to all clips in the current timeline layer.
- AppKit self-drawing timeline surface for smoother interaction.
- Distinct label column and lane area in the timeline.
- DaVinci-style full-height playhead with a large ruler head.
- Collapsed timeline mode that hides no-video gaps and skips hidden gaps during playback.
- Collapse-mode clip drag lock and joined splice-style clip/FIT block borders.
- Icon-only collapse/expand control and fully empty initial timeline state.
- Clip title truncation inside clip blocks.
- Trackpad pinch zoom on the timeline canvas.
- Duration-accurate clip widths in fit view and zoomed views.
- Left/right arrow one-frame playhead stepping based on project frame rate.

Remaining future improvements:

- Track management.
- Snapping and trimming.

## Milestone 5: Overlay Designer

Status: in progress

- Add overlay elements.
- Preview overlay rendering.
- Drag and scale controls.
- Initial font controls.
- Live data binding.

Completed so far:

- Add overlay elements from the Inspector library.
- Live value formatting from FIT activity data at the playhead.
- Drag overlay elements in the preview.
- Inspector font family, font weight, font size, scale, color, and background opacity controls.
- Text overlay built-in style picker with Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, and Split Label presets.
- Inspector normalized X/Y position entry, shadow controls, and arrow-key nudging.
- Playhead playback and ruler seeking.
- Distance Timeline module rewrite with preset-aware rendering, dense Inspector controls, media-slot groundwork, border/background controls, ticks, marker, glow, fade, and route elevation underlay.
- Elevation line chart rendering.
- Running Gauge composite circular dashboard rendering.
- Project Layer Data FPS setting for throttled overlay value updates.
- Shared preview/export rendering for text style presets.
- Shared preview/export rendering for Running Gauge presets.
- Extended numeric overlay types: vertical oscillation, ground contact time, stride length, vertical ratio, ground contact balance, temperature, grade.
- Retired the early Lap List, Lap Card, and Lap Live prototypes so the next interval-training UI can be built around the Interval HUD Bar design.

Pending:

- Broaden reusable `OverlayIconSlot` controls beyond Distance Timeline to other overlay modules that need custom icons.
- Full SVG path/paint coverage, raster image persistence, and video-loop support for icon slots.
- Fine-grained Distance Timeline fade masks that affect background/track layers without lowering primary text opacity.
- Overlay positioning precision tools.

## Milestone 5.1: Overlay Templates

Status: in progress

- Define versioned overlay template schema.
- Convert current overlay layout to a reusable template.
- Save named templates to a local user template library.
- Apply a template to the current overlay layout.
- Delete local templates.
- Import/export standalone template files.

Completed so far:

- Versioned Codable template schema.
- Local JSON template library under Application Support.
- Save current overlay layout as a named template.
- Initial apply/delete templates from Project Settings, now superseded by Templates Pool.
- Undo support when applying a template.
- Standalone `.rotemplate` import/export.
- Template management moved from Project Settings into the left `Templates` Pool.
- Built-in templates: `Easy Run`, `Interval Workout`, and `Race`.
- `Easy Run` now loads from the bundled `EasyRun.rotemplate` resource; `Interval Workout` and `Race` load from bundled `IntervalWorkout.rotemplate` and `Race.rotemplate` resources.
- Confirmation before any template replaces the current overlay layout.
- Compact user-template row context actions for rename, duplicate, export, and delete.

Pending:

- Template conflict handling and migration strategy for future schema versions.

Non-goals:

- Full project save/load.
- Saving FIT, video, timeline, or playhead state in templates.

## Milestone 5.2: Featured Overlay Modules

Status: in progress

- Route Map Overlay as a highlighted visual module.
- Dedicated module documentation for high-impact overlays that need custom data, rendering, caching, and service integration.

Completed so far:

- Added a dedicated `docs/overlay-modules/` documentation area.
- Drafted the Route Map Overlay design, including styles, GPS data needs, map API options, rendering architecture, caching, privacy, template behavior, and implementation phases.
- Extended FIT parsing and activity records with GPS latitude/longitude.
- Added the Route Map overlay type with independent map background, route color mode, and Glow controls.
- Added preview/export route rendering with start, finish, and current-position markers.
- Added MapKit snapshot provider scaffolding and preview-time MapKit snapshot loading for enabled map backgrounds.
- Retired the early Lap List overlay module in favor of the Interval HUD Bar direction — see `docs/overlay-modules/retired-lap-overlays.md` and `docs/overlay-modules/interval-hud-bar-overlay.md`.

Pending:

- Add persistent map snapshot caching for export.
- Add user-provided custom map API/Mapbox endpoint settings.
- Add route simplification and richer metric-based gradient coloring.

## Milestone 5.5: Real Preview

Status: in progress

- Show source video at the current playhead.
- Keep overlays visible above video.
- Sync video preview with project playhead during playback.

Completed so far:

- AVPlayerLayer-backed preview.
- First matching timeline clip is shown at the playhead.
- Source time is calculated from clip effective start.
- AVPlayer drives project playhead during video playback.
- Preview track selection and per-track preview disable toggles.

Pending:

- More robust clip-boundary handoff.

## Milestone 6: Transparent Overlay Export

Status: in progress

- Export dialog.
- Transparent MOV render pipeline.
- Batch segment export.
- Use project Layer Data FPS during render-time data sampling.
- Filename generation.

Completed so far:

- First-pass H.265 with alpha MOV writer.
- ProRes 4444 export option.
- Per-timeline-clip export, including overlapping clips.
- Full FIT activity overlay export.
- Project resolution, frame rate, bitrate, and Layer Data FPS applied.
- Toolbar export progress control with click-open popover and per-output progress rows.
- Export cancellation from the progress popover.
- PixelBufferPool and text layout caching in export renderer.

Pending:

- Export visual parity tests.
- Codec fallback.

## Milestone 7: Persistence And Reliability

Status: not started

- Project save/load.
- Error handling.
- Test fixtures.
- Export verification.

## Milestone 8: Mac App Store Readiness

Status: in progress

- Prepare a sandboxed, signed macOS app bundle for first Mac App Store submission.
- Add bundle metadata, entitlements, privacy manifest, release configuration, and
  App Store readiness documentation.
- Preserve the SwiftPM development workflow while adding a release packaging
  path.

Completed so far:

- Created the `codex/app-store-readiness` branch in a sibling worktree.
- Integrated the App Store readiness work into `develop` alongside the
  open-source repository structure and Keychain-based OpenWeather credentials.
- Added App Store bundle metadata, sandbox entitlements, privacy manifest, asset
  catalog placeholders, and release xcconfig.
- Added local validation, app bundle packaging, and archive-shape scripts.
- Added `docs/app-store-readiness.md` to track metadata, privacy, and release
  blockers.
- Selected `io.github.zijianwang90.runningoverlay` as the release Bundle ID and
  aligned the Keychain service under the same identifier namespace.

Pending:

- Register the selected bundle id and fill the team/signing values after Apple
  Developer Program membership activation.
- Add production macOS app icon images and App Store screenshots.
- Decide whether final upload will use a full Xcode app target/Organizer archive
  or a promoted script-built package.
- Complete sandbox, privacy report, and App Store Connect validation.
