# Running Overlay Development Guide

Last updated: 2026-04-26

## 1. Engineering Principles

- Build as a native macOS app.
- Keep timing and data models independent from UI pixel coordinates.
- Treat FIT parsing, media metadata parsing, timeline alignment, overlay layout, and export rendering as separate subsystems.
- Prefer deterministic project files and serializable models early, even before the full UI is complete.
- Update documentation in the same step as product or implementation changes.
- Project mutations should be routed through `ProjectDocument` methods so undo/redo, persistence, and future validation can be handled consistently.

## 2. Proposed Technology Direction

This project is intended to be a native macOS application.

Current bootstrap choice:

- Language: Swift.
- UI: SwiftUI for the main app shell and panels.
- Project bootstrap: Swift Package executable target.

Initial recommendation for upcoming implementation:

- Media preview and export: AVFoundation.
- Timeline rendering UI: SwiftUI first, with AppKit interop if interaction precision requires it.
- Default appearance: AppKit `darkAqua` with SwiftUI dark color scheme at the root view.
- FIT parsing: evaluate existing Swift FIT libraries first; implement a focused parser only if library quality or licensing is unsuitable.
- Persistence: project document model encoded as JSON or a Swift-native document format during early development.

Items to validate before implementation:

- Whether transparent MOV export should use ProRes 4444 by default.
- Whether AVFoundation can satisfy alpha export requirements directly for the selected codec and macOS deployment target.
- Which FIT parser is reliable enough for Garmin-produced FIT files.

## 3. Suggested App Modules

The implementation should evolve toward these boundaries:

- `App`: app entry, window setup, commands, keyboard shortcuts.
- `Project`: project document, settings, persistence.
- `FitData`: FIT parsing, activity timeline, data sampling.
- `MediaImport`: video import, metadata extraction, filename time parsing.
- `Timeline`: tracks, clips, selection, zoom, playhead, alignment offsets.
- `Overlay`: overlay element model, layout, styling, data binding.
- `Preview`: video preview and overlay preview composition.
- `Export`: shared frame renderer, MOV encoder, batch export, calibration PNG/MOV output, progress reporting.

## 4. Core Data Models

Initial model concepts:

```text
Project
  settings: ProjectSettings
  activity: ActivityTimeline
  mediaItems: [MediaItem]
  timeline: Timeline
  overlayLayout: OverlayLayout

ProjectSettings
  resolution
  frameRate
  layerDataFrameRate
  bitrate

ActivityTimeline
  startTimestamp
  endTimestamp
  duration
  records: [ActivityRecord]

MediaItem
  id
  fileURL
  metadata
  inferredStartTimestamp
  duration
  cameraGroupId

TimelineClip
  id
  mediaItemId
  trackId
  activityStartTime
  sourceStartTime
  duration
  alignmentOffset

OverlayElement
  id
  type
  frame
  style
  dataBinding
```

Timing values should use a high-precision representation such as `CMTime` for media and a consistent duration type for activity time. Conversion boundaries should be explicit.

## 5. Development Phases

### Phase 0: Documentation And Project Bootstrap

- Create product requirements.
- Create development guide.
- Create architecture notes.
- Create roadmap and project log.
- Decide Xcode project structure.

### Phase 1: Native App Shell

- Status: completed as an initial SwiftUI skeleton.
- Create macOS app project.
- Build main layout:
  - media browser
  - preview area
  - parameter panel
  - timeline
  - project settings entry
  - export entry
- Add initial project state.
- Wire basic selection flow.

Current implementation:

- Swift Package target: `RunningOverlay`.
- App entry: `Sources/RunningOverlay/App/RunningOverlayApp.swift`.
- Shared project state: `Sources/RunningOverlay/Project/ProjectDocument.swift`.
- Main layout and panels: `Sources/RunningOverlay/UI/`.
- Domain model modules: `FitData`, `MediaImport`, `Timeline`, and `Overlay`.
- Main editor uses horizontal and vertical split views so media, preview, inspector, and timeline boundaries are draggable.
- Initial app state is empty: no sample media, sample timeline clips, sample overlay elements, or fake FIT duration.
- App-level UI uses the shared dark editor design tokens from `docs/design/app-ui.md` through `EditorTheme`.
- Media Pool, Preview controls, Timeline, Inspector, status bar, export progress, project settings, and export dialog share dark panel/header/control colors, compact sizing, subtle borders, and system typography.
- Resizable panes keep stable minimum widths so media controls do not collapse when selection hierarchy changes.
- Media Pool default width is 380 px (min 300 px) and Inspector default width is 400 px (min 320 px); both panels remain user-resizable via custom drag handles.
- The horizontal three-column layout in `MainEditorView` is implemented as a single `HStack` with `@State`-tracked widths (`mediaPoolWidth`, `inspectorWidth`) and custom `HorizontalResizeHandle` dividers instead of `HSplitView`. This guarantees that internal Inspector selection changes (`outer/clip/overlay detail`) and Media Pool content changes (e.g., importing media or matching all clips) cannot reset the left or right pane widths.
- Media, Preview, and Inspector top headers share a unified header height and shared compact header button size tokens.

### Phase 2: FIT Import And Activity Timeline

- Status: completed for first-pass import and placement.
- Import a FIT file.
- Parse activity start/end, duration, distance, heart rate, pace, elevation, cadence, power, calories when available.
- Show timeline ruler from activity start to end.
- Show ruler hover data.

Current implementation:

- `Sources/RunningOverlay/FitData/FitFileParser.swift` contains a focused first-pass FIT parser.
- `ProjectDocument.importFitFile()` opens a native macOS file picker and loads the selected `.fit` file.
- The parser currently handles standard FIT definition/data messages and extracts record/session fields needed for the initial timeline.
- FIT import success and failure details are printed to stdout, so they are visible when launching with `swift run RunningOverlay`.
- Developer field definitions are read and skipped so standard fields in files with developer data remain parseable.
- Record elapsed times are normalized after parsing with the final activity start date so overlay values sample the correct FIT record over time.
- Compressed timestamp headers are accepted only enough to route to local message definitions; full compressed timestamp reconstruction is not implemented yet.
- Broad FIT profile coverage, CRC validation, pause handling, and timezone/device drift handling are still pending.

### Phase 3: Video Import And Metadata Alignment

- Status: in progress.
- Batch import videos.
- Extract creation time, timecode, duration, and technical metadata.
- Infer activity placement.
- Show unaligned media state.
- Allow drag-to-timeline placement.

Current implementation:

- `Sources/RunningOverlay/MediaImport/MediaMetadataReader.swift` reads video duration and metadata creation dates using AVFoundation.
- `FilenameDateParser` extracts timestamps from common filename patterns.
- `ProjectDocument.importVideos()` opens a native multi-select video file picker.
- `ProjectDocument.importVideoURLs()` is shared by file-picker import and Finder-to-media-browser drop import.
- File-picker imports replace the current media browser contents; Finder drops append supported video files.
- Imported videos stay in the media pool until the user explicitly matches them or drags them to the timeline.
- Items with inferred timestamps near the FIT activity are marked ready for timestamp matching instead of being placed automatically.
- Media browser rows support multi-selection, select-all-visible, tag filtering, right-click tag assignment, explicit matching to the current layer or a new layer, and deletion from the media pool.
- The media browser includes filename search plus real status chips for `All`, `Ready`, and `Aligned`; filter changes prune selections that are no longer visible.
- The media browser captures Command+A while active to select all visible filtered media rows without showing a system focus ring.
- The media browser uses custom dark alternating row backgrounds, hover fills, selected-row accent strips, centered compact file icon wells, and status pills instead of system list separators.
- The context menu Mark submenu uses circular color icons for each mark option.
- The no-media empty state includes a drag/drop prompt, an `Import Videos` action, a short matching-workflow description, and a supported-format hint.
- First-pass camera/source grouping uses the first filename token.

Pending:

- Timecode metadata extraction.
- More robust camera grouping.
- Alignment confidence and diagnostics.

### Phase 4: Timeline Editing

- Status: completed for first-pass timeline editing.
- Implement tracks and timeline clips.
- Implement clip selection and movement.
- Implement timeline zoom.
- Implement keyboard shortcuts.
- Implement clip fine-tuning controls and apply-to-camera action.

Current implementation:

- Media browser items can be dragged onto timeline tracks.
- Selected media browser items can be matched from the right-click menu to the current timeline layer or to a new layer.
- Timeline shows a default empty `Layer 1` track when no clips exist but FIT or media context exists.
- Timeline drawing separates the label column from the central lane area with distinct backgrounds and a vertical divider.
- Timeline styling follows `docs/design/timeline-ui.md` and `docs/design/timeline-ui.spec.json`, including compact header controls, dark alternating lane bands, subtle ruler ticks, square-adjacent clip joins with dark splice borders, and compact hover info pills.
- Dropping a media item creates or moves a timeline clip at the drop location.
- Media drag-over highlights the target layer, and the AppKit timeline exposes only one new layer drop target beyond existing layers.
- `TimelineClip` stores `startTime` and `alignmentOffset` separately.
- Existing timeline clips can be dragged horizontally to change their effective start time.
- Inspector start and offset fields update the selected clip's effective start time and alignment offset with 0.01 second precision.
- Double-clicking Inspector timing labels resets start or offset to the default `0.00 s` value.
- Inspector action applies the selected offset to clips with the same camera/source group.
- Timeline drawing and high-frequency interactions are handled by an AppKit `NSView` embedded in SwiftUI.
- The AppKit timeline handles self-drawn ruler, ruler hover data, tracks, clips, playhead, clip dragging, ruler seeking, media drop, and Command-scroll zoom.
- The AppKit timeline draws a muted-red playhead with a small downward-pointing triangle inside the ruler band; the triangle's tip connects to a thin vertical line that extends from the ruler through the visible tracks, and neither part is allowed to extend above the ruler.
- Selected timeline clips draw a 2 px white border on top of their blue fill, replacing the default dark splice border for the selected block only.
- The ruler hover info pill draws as a rounded panel with a small downward-pointing arrow on its bottom edge whose tip aligns with the hovered ruler position.
- AppKit timeline inputs are passed as explicit SwiftUI values so FIT import, playhead, zoom, selection, and media changes reliably refresh the timeline.
- Timeline model time is project time. `TimelineModel.fitStartTime` maps project time back to FIT activity elapsed time.
- Imported video clips are placed by real timestamp relative to FIT start and are no longer clamped to `0...activity.duration`.
- Project bounds are the union of the FIT layer span and all video clip spans, allowing pre-start and post-finish race footage.
- The AppKit timeline draws a dedicated draggable `FIT` layer above video layers.
- A FIT-only project shows the activity ruler and an empty video lane before media import.
- During playback, the scroll view keeps the playhead visible horizontally.
- Clip dragging is previewed inside the AppKit view and committed to the project model once on mouse-up.
- Timeline zoom can be changed by command shortcuts, Command-scroll, macOS trackpad pinch, and the SwiftUI zoom slider above the AppKit canvas.
- Timeline zoom slider uses a normalized nonlinear 0-100 control mapped to pixels-per-second, with much finer control near the fit/low-zoom end.
- The SwiftUI/AppKit timeline bridge tracks zoom changes and recenters the scroll view on the current playhead after each zoom update.
- Timeline header supports automatic preview track choice and per-track preview disable toggles in an eye-icon menu. The previous explicit preview-track picker (`Auto` / per-track names) has been removed because the eye-menu visibility toggles already cover the same workflow.
- Timeline header includes an icon-only collapse/expand toggle. Collapsed mode hides gaps without video so one-layer projects show clips back-to-back, while multi-layer projects preserve overlapping video spans and remove FIT-only gaps.
- Collapsed playback skips hidden empty timeline regions, so playback continues from one visible video span to the next instead of playing blank FIT-only sections.
- Collapsed timeline mode disables horizontal dragging of existing video clips because hidden gaps remove the normal time-reference context; clips can still be selected.
- Collapsed timeline rendering uses DaVinci-like joined clip edges, with square internal edges and dark borders on clip and FIT blocks instead of full-height separator lines.
- Timeline clip labels are clipped and middle-truncated inside their blue clip blocks so filenames do not spill into adjacent timeline space.
- Timeline clip block widths are always proportional to clip duration at the current zoom level, including fit view; labels are hidden when a clip is too narrow to contain text.
- A completely empty project timeline draws as an empty work area without a playhead, FIT layer, or default track; the default drop lane appears only after FIT or media context exists.
- Split-view boundary cursor hints are implemented with transparent AppKit cursor rect views that do not intercept drag events.
- `ProjectDocument.layerDataSampleTime` maps project playhead time through `fitStartTime`, then quantizes by `settings.layerDataFrameRate` before FIT-derived overlay values are read.
- Selected clips expose Inspector controls for camera/track renaming, start time, and offset. Duration editing is intentionally hidden until trim-length adjustment is needed.

Pending:

- Direct trim handles on the AppKit timeline.
- Snapping.

### Phase 5: Overlay Editing

- Status: in progress.
- Add overlay element creation.
- Render overlay elements over preview.
- Support selection, dragging, scaling.
- Implement initial font controls.
- Bind elements to sampled FIT data at playhead.

Current implementation:

- `OverlayValueFormatter` formats overlay values from `ActivityTimeline` at the current playhead.
- `ActivityTimeline` supports interpolation for distance, heart rate, pace, elevation, cadence, power, and calories.
- Overlay preview and Inspector value display use the project Layer Data FPS setting, so data values update at the configured cadence rather than every UI refresh.
- Inspector overlay UI follows the dark tool-panel design spec in `docs/design/inspector-ui.md`, with tokenized colors, spacing, compact rows, add-overlay tabs, overlay rows, and a selected-overlay detail screen.
- Inspector default width is 400 px and minimum width is 320 px; the panel is user-resizable through the custom `HorizontalResizeHandle`, and `ParameterPanelView` does not impose its own width frame so internal outer/detail/editing state switches cannot resize the right column or squeeze tile content.
- Preview overlay elements can be dragged and clamped within the preview coordinate space.
- Inspector supports selected overlay font family, font weight, font size, scale, color presets, and background opacity controls.
- Text overlays expose a first-position built-in style picker with Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, and Split Label text presets.
- Running Gauge is available as a composite circular dashboard overlay with distance, elapsed time, pace, and heart rate in one module.
- Running Gauge supports Minimal Sport, High Contrast, Trail Adventure, Tech Future, and Retro Digital style presets through the Inspector.
- Route Map is available as a featured overlay module backed by FIT GPS latitude/longitude when present.
- Route Map supports Minimal, Gradient, Glow, and MapKit presets through the Inspector.
- Route Map preview attempts a MapKit snapshot for the MapKit preset and falls back to a local dark grid when a snapshot is unavailable.
- Route Map export currently renders the local route/map fallback synchronously so MOV/PNG export does not depend on MapKit network/service timing.
- Inspector supports normalized X/Y position entry plus shadow opacity and radius controls.
- Up and down arrow keys nudge the selected overlay element vertically by one percent of the preview canvas.
- Inspector shows a dark add/manage outer state when no overlay element is selected; add tiles are grouped by Metrics, Charts, and Route, and newly added overlays open their detail screen.
- Inspector add-overlay tabs use full-segment hit targets, not text-only click regions.
- Inspector added-overlay rows show icon, type, live value preview, disabled visibility/lock placeholders, delete, and detail navigation without sorting affordances.
- Distance timeline overlays render as progress bars.
- Elevation chart overlays render as line charts with playhead markers.
- Running Gauge overlays render circular ticks, a progress ring, section dividers, and core run metrics in both preview and export.
- Route Map overlays render the route path, start marker, finish marker, and current-position marker in both preview and export.
- `OverlayRenderModel` provides the shared layout data used by SwiftUI preview and AVFoundation export rendering.
- Text preset selection is stored on `OverlayStyle`, decodes old templates as the Minimal preset, and is honored by both preview and export renderers.
- Preview overlay positions, drag deltas, guides, font sizes, padding, and chart dimensions are based on the fitted project canvas inside the preview area, so resizing split panes keeps overlays anchored to the same normalized video position.
- Preview can show 90%/80% safety guides and center crosshairs from an in-preview header toggle.
- Selected overlays show a subtle blue selection border and corner handles on the fitted canvas.
- Playback advances the timeline playhead at 30 Hz while active.
- Left and right arrow keys step the timeline playhead backward or forward by one project frame, using the current project frame rate.
- Timeline ruler click/drag seeks the playhead, and timeline tracks show a red playhead indicator.

### Preview Playback

- Status: in progress.

Current implementation:

- `PreviewCanvasView` uses `VideoPreviewPlayerView` to display real source video behind overlays.
- `VideoPreviewPlayerView` wraps an `AVPlayerLayer` in `NSViewRepresentable`.
- Preview owns its own compact header with title, project resolution/frame-rate metadata, safe guides toggle, and a static Fit menu placeholder.
- `PreviewCanvasView` computes the actual fitted canvas size from the project resolution aspect ratio and centers that canvas in the available preview region.
- `PreviewCanvasView` includes a DaVinci-style playback control strip below the video canvas with a centered previous/stop/play-pause/next cluster and a right-pinned playback-rate menu.
- The project chooses the first timeline clip containing the current playhead.
- Double-clicking a media-pool row switches preview to that source video at the beginning of the file, starts playback, and keeps source preview time independent from the timeline playhead.
- When the media browser loses focus or the user interacts with the preview/timeline, the preview returns to timeline mode.
- Source video time is derived from the clip's effective start time.
- Space and K toggle play/pause. L starts playback when paused, then steps forward speed through 2x, 4x, and 8x while playing.
- The playback-rate menu exposes direct 1x, 2x, 4x, and 8x choices backed by `ProjectDocument.playbackRate`.
- During playback over a video clip, `AVPlayer` is the timing source and reports source time back to the project playhead through a periodic time observer.
- During media-pool source preview, `AVPlayer` time updates only the temporary source preview position so pausing does not reset to the beginning and does not move the timeline playhead.
- During playback, `AVPlayer` is not repeatedly seeked on every playhead tick; it seeks on clip changes, paused/manual positioning, or large drift correction.
- The main editor timer advances playback only when the current playhead is not covered by a video clip.
- Preview clip selection can skip disabled tracks so users can inspect an underlying track without changing export behavior.
- `ProjectDocument` assigns updated `TimelineModel` values instead of mutating nested fields in place for playhead and zoom changes, making overlay and timeline refresh more reliable.

Preview pending:

- More robust clip-boundary handoff during playback.
- Audio mute/preview behavior.

Overlay pending:

- Stroke, shadow, and alignment controls.
- More chart styling controls.
- Keyboard and precision controls for overlay positioning.

### Overlay Templates

- Status: first local library implementation completed.

Design direction:

- Overlay templates should be implemented before full project files.
- Templates persist `OverlayLayout`-like data only, not FIT, media, timeline, playhead, or current sampled values.
- Template persistence should use a versioned, codable schema separate from future project persistence.
- Template application should route through `ProjectDocument` so it participates in undo/redo.
- Template files should be human-inspectable JSON unless there is a strong reason to package assets later.

Suggested model:

```text
OverlayTemplate
  schemaVersion
  id
  name
  createdAt
  updatedAt
  referenceResolution
  elements: [OverlayTemplateElement]

OverlayTemplateElement
  type
  position
  scale
  style
```

Suggested storage:

- Local user template library under Application Support.
- Optional import/export as standalone template files.

Implementation phases:

- Phase A: define Codable template schema and conversion to/from `OverlayLayout`. Completed.
- Phase B: save current overlay layout as a named local template. Completed.
- Phase C: template list UI in Project Settings. Completed.
- Phase D: apply/delete templates with undo support for apply. Completed.
- Phase E: import/export template file. Completed.

Current implementation:

- `OverlayTemplate` is a versioned Codable schema that stores metadata and `OverlayTemplateElement` values.
- Template elements store overlay type, normalized position, scale, and style only.
- `OverlayTemplateStore` persists the local template library as JSON under Application Support.
- `ProjectDocument` loads templates on startup, saves/replaces templates by name, applies templates to the current overlay layout, deletes templates, and imports/exports standalone `.rotemplate` files.
- Applying a template routes through `ProjectDocument.registerUndoPoint()` so the previous overlay layout can be restored with undo.
- Project Settings exposes save/apply/delete/import/export controls because template management is a low-frequency workflow.

Open engineering decisions:

- Template file extension.
- Whether template IDs should be stable UUIDs or derived from filenames.
- How to handle missing future style fields when reading old templates.

### Undo And Redo

- Status: foundation implemented.

Current implementation:

- `ProjectDocument` owns a project snapshot undo/redo stack.
- `Command-Z` and `Shift-Command-Z` are wired to project undo and redo.
- Delete and Forward Delete remove the selected timeline clip or overlay element.
- The AppKit timeline canvas handles Delete and Forward Delete directly when it has focus.
- The app sets a regular activation policy at launch, and timeline mouse-down activates the app and makes the timeline canvas first responder.
- Overlay add/delete, timeline clip delete, and core overlay/timeline edits register undo snapshots.
- Continuous edits use a begin/end style snapshot so drag and slider gestures can undo as a single operation.

Pending:

- Broader coverage audit for every future project mutation.
- Persistence integration with undo state boundaries.
- More granular labels for undo menu item names.

### Phase 6: Export

- Status: first-pass implementation completed.
- Export dialog selects destination, bitrate, clip-based export, or full-activity export.
- Export destination defaults to the folder containing the first video in the media pool, with `~/Movies` as the fallback before videos are loaded.
- Render transparent MOV overlays using H.265 with alpha or ProRes 4444.
- Batch export one overlay video for each timeline clip, including overlapping clips.
- Full-activity export ignores video clips and renders one overlay file from FIT start to finish.
- Calibration export renders a three-second transparent MOV with fixed overlay reference points plus safety guides, using the active FIT data when available and synthetic data otherwise.
- Calibration frame export renders a PNG with the same `OverlayFrameRenderer`, layout, activity data, and safety guides used by the calibration MOV.
- Apply project frame rate, resolution, bitrate, and Layer Data FPS.
- Generate output filenames with `_overlay.mov`.
- `ProjectDocument` owns structured export progress state for overall and per-output progress.
- The toolbar displays export progress while exporting; clicking the progress control opens a persistent popover with item-level progress.
- Export can be cancelled from the progress popover; the exporter checks cancellation between segments and while rendering frames.
- Export reuses `AVAssetWriterInputPixelBufferAdaptor`'s pixel buffer pool instead of allocating a fresh pixel buffer every frame.
- Export caches attributed text layouts by text/style/sample output, reducing repeated font and string layout work across frames.
- `OverlayFrameRenderer` owns overlay drawing for both PNG frames and MOV pixel buffers; `OverlayVideoExporter` owns only MOV encoding, frame timing, and progress.
- Export creates an explicit flipped `NSGraphicsContext` for text drawing so backgrounds and text render through the same bitmap context without global CGContext inversion.
- Export text is rendered through a 2x supersampled transparent offscreen bitmap before compositing back into the output frame, reducing jagged edges on large saturated text and alpha-shadow boundaries.
- Export scales font sizes, padding, rounded corners, shadows, distance timeline geometry, and elevation chart geometry from the shared 1280x720 render reference to the selected project resolution.
- Export renders distance timeline and elevation chart overlays with the same shared progress and sample data used by preview.
- Export can optionally render the same safety guides for calibration clips without affecting normal clip/full-activity exports.
- Export vertically flips completed pixel-buffer rows before appending frames, compensating for the `CVPixelBuffer` to MOV orientation path so the encoded result matches the preview coordinate system.

Pending:

- Visual snapshot checks for preview/export overlay render parity.
- Codec fallback handling if HEVC with alpha is unavailable on a machine.

### Phase 7: Polish And Reliability

- Add error handling.
- Add project persistence.
- Add sample-file regression tests.
- Add interaction polish and performance profiling.

## 6. Testing Strategy

Initial testing should cover:

- FIT parsing using representative sample files.
- Time alignment from media metadata and filename patterns.
- Timeline model operations independent of UI.
- Overlay data sampling at known timestamps.
- Layer Data FPS quantization and activity-duration clamping.
- Export filename generation.

Later testing should cover:

- Visual snapshot checks for overlay rendering.
- Export smoke tests.
- Performance tests on long activities and many video clips.
- UI interaction tests for timeline drag and zoom.

## 7. Documentation Maintenance

For each development step:

- Update `docs/requirements.md` if user-facing behavior changes.
- Update `docs/development.md` if implementation workflow or module boundaries change.
- Update `docs/architecture.md` if data flow, rendering flow, or subsystem responsibilities change.
- Add or update an ADR when a decision would be expensive to reverse.
- Add an entry to `docs/project-log.md` with date, summary, files changed, and verification performed.
