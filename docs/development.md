# Running Overlay Development Guide

Last updated: 2026-04-28

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
- App-level UI uses the shared dark editor design tokens from `docs/design/system/app-ui.md` through `EditorTheme`.
- Left Pool, Preview controls, Timeline, Inspector, status bar, export progress, project settings, and export dialog share dark panel/header/control colors, compact sizing, subtle borders, and system typography.
- Resizable panes keep stable minimum widths so media controls do not collapse when selection hierarchy changes.
- Left Pool default width is 380 px (min 300 px) and Inspector default width is 460 px (min 460 px); both panels remain user-resizable via custom drag handles.
- The horizontal three-column layout in `MainEditorView` is implemented as a single `HStack` with `@State`-tracked widths (`mediaPoolWidth`, `inspectorWidth`) and custom `HorizontalResizeHandle` dividers instead of `HSplitView`. This guarantees that internal Inspector selection changes (`outer/clip/overlay detail`) and Left Pool content changes (e.g., switching Media Pool/Overlay Pool/Templates, importing media, or matching clips) cannot reset the left or right pane widths.
- `MainEditorView` owns the active left-pool mode. The compact `Media Pool` / `Overlay Pool` / `Templates` switch sits in the top app toolbar, aligned to the left pane width, while `PoolPanelView` renders the selected pool content below. The app toolbar no longer carries global FIT/Videos import buttons.
- Media, Preview, and Inspector top headers share a unified header height and shared compact header button size tokens.
- The initial `VSplitView` allocation favors the top editor stack more strongly by using a lower default Timeline ideal height (`180`) with a `160` minimum, while keeping the split boundary user-draggable.

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
- Timer start/stop events are parsed into `ActivityAnnotatedSegment` pause spans. These spans stay on the real elapsed-time axis and are available to timeline UI without changing video alignment.
- Compressed timestamp headers are accepted only enough to route to local message definitions; full compressed timestamp reconstruction is not implemented yet.
- Broad FIT profile coverage, CRC validation, deeper pause semantics for data sampling, and timezone/device drift handling are still pending.

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
- The media browser row layout follows the design-system row reference with 72 px rows, 42 px thumbnail wells, compact metadata, compact alignment-status dots with hover help text, and optional mark dots.
- The context menu Mark submenu uses circular color icons for each mark option.
- The no-media empty state is FIT-first: before activity data is loaded it shows `Import FIT`; after a FIT is loaded it shows the drag/drop video prompt, `Import Videos`, a short matching-workflow description, and a supported-format hint. Video drops before FIT import are rejected with a status message.
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
- Timeline styling follows `docs/design/panels/timeline/timeline-ui.md` and `docs/design/panels/timeline/timeline-ui.spec.json`, including compact header controls, dark alternating lane bands, subtle ruler ticks, square-adjacent clip joins with dark splice borders, and compact hover info pills.
- FIT track rendering uses the existing `ActivityTimeline.laps` / `LapRecord.kind` interval classification to color WU, RUN, REST, and CD phases for interval workouts, while steady activities keep the default green FIT bar and timer-paused spans remain gray overlays.
- Dropping a media item creates or moves a timeline clip at the drop location.
- Media drag-over highlights the target layer, and the AppKit timeline exposes only one new layer drop target beyond existing layers.
- `TimelineClip` stores `startTime` and `alignmentOffset` separately.
- Existing timeline clips can be dragged horizontally to change their effective start time. For timestamp-matched clips, dragging preserves the automatic matched start and changes `alignmentOffset`; for manually placed clips, dragging changes the editable aligned time and preserves `alignmentOffset`.
- Inspector timing fields update the selected clip's aligned time and alignment offset with 0.01 second precision, preserve in-progress numeric typing until focus leaves the field, and format to fixed precision only after commit.
- Timestamp-matched clips show their automatic matched start as a read-only `Auto Matched Start` row instead of exposing it as an editable start field.
- While playback is paused and the playhead is inside the selected clip, editing the clip offset moves the playhead by the same effective-start delta so the visible video frame stays still during alignment.
- Double-clicking Inspector timing labels resets start or offset to the default `0.00 s` value.
- Inspector action applies the selected offset to all clips in the currently selected timeline layer.
- Timeline clips use a dedicated clip detail Inspector with the same compact header, dense 34 px section-row layout, back action, and destructive delete affordance as overlay detail inspectors.
- Timeline drawing and high-frequency interactions are handled by an AppKit `NSView` embedded in SwiftUI.
- The AppKit timeline handles self-drawn ruler, ruler hover data, tracks, clips, playhead, clip dragging, ruler seeking, `C`-held hover scrubbing, media drop, and Command-scroll zoom.
- The AppKit timeline draws a muted-red playhead with a small downward-pointing triangle inside the ruler band; the triangle's tip connects to a thin vertical line that extends from the ruler through the visible tracks, and neither part is allowed to extend above the ruler.
- Selected timeline clips draw a 2 px white border on top of their blue fill, replacing the default dark splice border for the selected block only.
- The ruler hover info pill draws in a reserved band above the time scale as a rounded panel with a small downward-pointing arrow on its bottom edge whose tip aligns with the hovered ruler position.
- AppKit timeline inputs are passed as explicit SwiftUI values so FIT import, playhead, zoom, selection, and media changes reliably refresh the timeline.
- Timeline model time is project time. `TimelineModel.fitStartTime` maps project time back to FIT activity elapsed time.
- Imported video clips are placed by real timestamp relative to FIT start and are no longer clamped to `0...activity.duration`.
- Project bounds are the union of the FIT layer span and all video clip spans, allowing pre-start and post-finish race footage.
- The AppKit timeline draws a dedicated `FIT` layer above video layers.
- The FIT layer overlays timer-paused segments in gray and shows a `Timer Paused` hover tooltip on those spans. Interval phase blocks also show English hover tooltips with lap kind, lap number, elapsed range, and duration.
- In collapsed mode, FIT track blocks are clipped to the actual FIT activity range, so video-only spans before start or after finish do not show a green FIT bar.
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
- Selected clips expose a dense detail Inspector for camera/track renaming, start time, and offset. Duration editing is intentionally hidden until trim-length adjustment is needed.

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
- Inspector overlay UI follows the dark tool-panel design spec in `docs/design/panels/inspector/inspector-ui.md`, with tokenized colors, spacing, compact added-overlay rows, and selected-overlay detail screens. Add-overlay tiles now live in the left `Overlay Pool`.
- Project Settings Font Library persists favorite overlay-menu fonts and the default font family globally; its `Restore Defaults` action returns to the default monospaced overlay set (`PT Mono`, `Monaco`, `Menlo`, `Andale Mono`) with `PT Mono` as the default.
- Overlay detail panels share reusable inspector modules for cross-overlay consistency: `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows` (Layout) and `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows` (Stats Bar). New detail views should reuse these modules instead of creating per-overlay variants.
- Interval Timeline uses the same fixed footer pattern as other dense overlay detail views: header and `Reset` / `Done` footer stay pinned while Timeline, Current, Rail, Labels, Background, Border, and Effects sections scroll.
- Shared `Layout` rows are now fixed to `Position`, `Scale`, `Width`, `Height`, and `Opacity`; `Rotation` is intentionally removed from the shared Layout section across overlay detail panels.
- Inspector default width is 460 px and minimum width is 460 px; the panel is user-resizable through the custom `HorizontalResizeHandle`, and `ParameterPanelView` does not impose its own width frame so internal outer/detail/editing state switches cannot resize the right column or squeeze tile content.
- Inspector segmented controls are implemented with native SwiftUI segmented `Picker` (`.pickerStyle(.segmented)`) instead of custom button rows, including shared dense controls used by Numeric Overlay, Running Gauge, and Route Map detail views.
- Preview overlay elements can be dragged and clamped within the preview coordinate space.
- Preview drag uses measured rendered overlay frames for snapping: with safe guides enabled, overlay edges snap to 90%/80% guide lines and overlay center axes snap to the canvas center crosshair; visible overlays also snap to each other's left/center/right and top/center/bottom alignment lines during drag.
- Inspector supports selected overlay font family, font weight, font size (value text), scale, color presets, independent label/unit controls, and advanced background controls.
- SwiftUI overlay previews route configurable text through the shared overlay font helper. macOS system UI font family aliases such as `SF Pro` and `SF Pro Display` render with `Font.system(size:weight:)` to avoid SwiftUI font descriptor weight diagnostics. Custom font families still use `Font.custom(...).weight(...)`; visible weight changes depend on whether that family provides matching weight faces, so single-weight families such as Monaco may not visibly respond to every weight option.
- Numeric overlays (heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, power) use the dense `NumericOverlayDetailView` Inspector defined in `docs/design/overlays/numeric/numeric-overlay-ui.md`. `ParameterPanelView` routes these `OverlayElementType` values through the new view; other overlay types continue to use `OverlayDetailView`.
- Numeric Overlay 1.0 removes the numeric style preset picker and divider controls. Numeric preview/export always uses the Minimal Clean render path and disables divider rendering even if old project/template data decodes `textPreset` or `dividerEnabled`.
- Numeric Overlay 1.0 supports a configurable SF Symbol icon attachment. `OverlayElementType.defaultNumericIconSystemName` seeds each newly added metric, while `OverlayStyle.iconEnabled`, `iconSystemName`, `iconPosition`, `iconTextAlignment`, `iconSize`, `iconColor`, `iconOpacity`, and `iconSpacing` drive the Inspector and shared SwiftUI preview/export path. Numeric Icon and Decor Icon SF Symbol selection share `SFSymbolPicker`, which keeps direct text entry but adds a searchable bundled SF Symbol name catalog generated from public CoreGlyphs symbol order data, sport-first default browsing, cached renderability checks, current-symbol preview, recent symbols, and default reset.
- Numeric overlay preview/export positioning is top-leading anchored rather than center anchored. Value and label rows resolve to leading alignment so incomplete or shorter dynamic content keeps the same left edge and grows to the right; inline unit alignment still honors `unitTextAlignment` as its top/middle/bottom anchor. Preview placement uses deterministic alignment guides instead of async content-size measurement; numeric drag uses canvas-coordinate pointer location plus a grab offset to track the overlay's top-left corner, then runs a top-leading snap/clamp path so edge snapping still works.
- `OverlayStyle` carries the numeric-overlay editor state: `unitOption`, `showLabel`, `showUnit`, `customLabel`, `labelPosition`, `unitPosition`, `labelFont*`, `unitFont*`, `icon*`, `rotationDegrees`, `accentColor`, `backgroundEnabled` / `backgroundColor` / `backgroundRadius` / `backgroundPaddingX` / `backgroundPaddingY` / `backgroundFadeOut*` / `backgroundBlurRadius`, and `shadowEnabled` / `shadowOffsetX` / `shadowOffsetY`. All new fields decode with safe defaults so old saved projects and overlay templates load unchanged.
- `OverlayValueFormatter.value(for:element:activity:elapsedTime:)` is element-aware: it picks the unit option and label/unit/custom-label rules from `OverlayStyle` to produce the rendered string and the Inspector's live preview. Elapsed Time overlays render active elapsed time from `ActivityTimeline.activeElapsedTime(at:)`, subtracting FIT timer-paused spans from the real elapsed-time axis so the value matches watch moving/workout time.
- `OverlayElementType.isNumericOverlay` and `OverlayElementType.defaultUnitOption` drive routing into the numeric editor and the unit defaults applied by `ProjectDocument.addOverlayElement`.
- `OverlayRenderModel` and `OverlayFrameRenderer` honor the new background and shadow style fields on the `.minimal` text preset so the same configuration is consistent between preview, calibration PNG, and MOV export.
- `ProjectDocument` exposes setters for every numeric overlay field plus `resetOverlayStyle` used by the numeric Inspector's footer Reset action; all setters are undoable.
- Text overlays expose a first-position built-in style picker with Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, and Split Label text presets.
- Running Gauge is available as a composite circular dashboard overlay with distance, elapsed time, pace, and heart rate in one module.
- Running Gauge supports Minimal Sport, High Contrast, Trail Adventure, Tech Future, and Retro Digital style presets through the Inspector.
- Route Map is available as a featured overlay module backed by FIT GPS latitude/longitude when present.
- Route Map supports Minimal, Gradient, Glow, and MapKit presets through the Inspector.
- Route Map preview attempts a MapKit snapshot for the MapKit preset and falls back to a local dark grid when a snapshot is unavailable.
- Route Map export preloads MapKit snapshots once before MOV/PNG rasterization and passes them into the shared SwiftUI Route Map view as static render assets; if snapshot loading fails, export falls back to the local route/map grid.
- Inspector supports normalized X/Y position entry plus shadow opacity and radius controls.
- Up and down arrow keys nudge the selected overlay element vertically by one percent of the preview canvas.
- Overlay Pool shows add tiles grouped by Metrics, Charts, and Route; clicking a tile calls `ProjectDocument.addOverlayElement`, which selects the new overlay and opens its detail Inspector. Featured add tiles use the same card shape and border treatment as other tiles without a left-side blue accent strip.
- Inspector shows a dark outer state when no overlay element is selected, but it only contains `Added Overlays`; it no longer carries the selectable overlay catalog.
- Inspector added-overlay rows show icon, type, live value preview, visibility toggle, lock toggle, delete, and detail navigation without sorting affordances.
- Added Overlays rows expose a context menu (`Copy Properties` / `Paste Properties`) for overlay configuration transfer.
- Overlay visibility now gates both Preview rendering and `OverlayFrameRenderer` export rendering.
- Overlay lock is persisted and currently blocks Preview canvas selection/drag plus position writes in `ProjectDocument.moveOverlay` / `setOverlayPosition`.
- Overlay configuration paste is category-gated through `OverlayElementType.pasteCategory`; numeric overlays can paste only within the numeric group.
- Distance Timeline is a dedicated module with minimal, dense, sport, splits, glass, neon, lower-third, and route presets, backed by `DistanceTimelineStyle`.
- Distance Timeline preview/export rendering supports distinct progress treatments, optional system-icon media slots for sport/lower-third, border/background controls, ticks, marker, glow, fade amount, route elevation underlay, and sampled GPS route geometry when available.
- Distance Timeline Value is separate from Label, owns the value font controls, can be disabled, switches metric/imperial units, and supports a Custom Values master toggle that expands four inline metric slots with independent group gap, item gap, size, color, and opacity. Group gap offsets the whole custom group without compressing custom text or changing item gap.
- Distance Timeline adds fine-grained controls for Value-to-progress gap, Progress Marker style/color, Label font/color/size/weight and Label-to-Value gap, plus Axis Label font/color/size/weight. Preview and export use the same `DistanceTimelineStyle` fields.
- Distance Timeline Percent was removed from Content and represented by the dedicated Stats Bar, which supports up to four metric slots, top/bottom/left/right placement, separate Inside mode for all four sides, adjustable width/height, item gap, and X/Y offset.
- Route Map Stats Bar now follows the same full shared control surface as Distance Timeline (Placement, Inside, Layout, Size, Width, Offset, Item Gap, Background, Dividers, Radius, Slot 1-4), with Enabled in the section header.
- Route Map and Distance Timeline Stats Bars now share a single renderer path in both Preview and Export (based on the Distance Timeline Stats Bar rendering logic), so future overlay modules can reuse one rendering implementation.
- For Route Map, when Stats Bar is inside the container it reserves map content padding so route lines are not covered; inside bar background is clipped by container shape/radius for a fused edge appearance.
- For Route Map left/right Stats Bar placements, rendering always switches to vertical stack flow and applies `itemSpacing` as row gap.
- Dense and Splits Distance Timeline progress fills render as solid bars; tick marks and axis labels provide the technical/split visual detail.
- The Glass preset no longer fakes a glass fill; its background is disabled until a real blur/material effect is implemented.
- Distance Timeline axis labels use separate **Start / Finish** and **More Points** toggles, each with its own below/above placement and offset; Mode switches start/finish copy vs distance numerals (`0 <unit>` origin); Axis typography also styles the optional marker distance label. Marker size is a dedicated scale multiplier on the progress marker.
- Distance Timeline background/border bounds expand to cover Axis Labels and Stats Bars with Inside enabled at their current side/offset, while attached outside Stats Bars keep their own bar background. Preview selection uses the same dynamic bounds.
- Distance Timeline ticks expose density control, and left/right Stats Bar backgrounds expand to cover all vertical slots.
- Distance Timeline media slots use the generic `OverlayIconSlot` model; the current UI exposes it only for Distance Timeline, but the Codable data and deterministic SVG renderer are reusable by other overlay modules.
- Distance Timeline SVG import embeds static or animated SVG source in `OverlayStyle.distanceTimeline.mediaSlot`; preview and export sample animated SVG from overlay elapsed time so rendered frames are deterministic.
- Interval Timeline is available as a horizontal interval-workout schedule overlay that complements Interval HUD Bar: it uses existing `ActivityTimeline.laps`, renders as a compact title-free timeline rail, keeps the current lap centered and enlarged by default, and summarizes hidden repetitions for high-count workouts such as `1min x25`. See `docs/design/overlays/interval-timeline/interval-timeline-overlay-ui.md` and `docs/overlay-modules/interval-timeline-overlay.md`.
- Zone Edge Bar is available as an independent HR/pace zone overlay for edge-pinned or free placement. It reads Project Settings HR/pace zones and thresholds, renders current and threshold markers, supports horizontal and vertical bars, and shares the HR-zone palette used by Project Settings and Interval HUD Bar. See `docs/design/overlays/zone-edge-bar/zone-edge-bar-overlay-ui.md` and `docs/overlay-modules/zone-edge-bar-overlay.md`.
- Elevation chart overlays render line/area charts with playhead markers; Smoothing filters quantized elevation samples and draws curved paths in both preview and export, including Progress mode.
- Running Gauge overlays render circular ticks, a progress ring, section dividers, and core run metrics in both preview and export.
- Route Map overlays render the route path, start marker, finish marker, and current-position marker in both preview and export.
- `OverlayRenderModel` provides the shared layout data used by SwiftUI preview and AVFoundation export rendering.
- Text preset selection is stored on `OverlayStyle`, decodes old templates as the Minimal preset, and is honored by both preview and export renderers.
- Preview overlay positions, drag deltas, guides, font sizes, padding, and chart dimensions are based on the fitted project canvas inside the preview area, so resizing split panes keeps overlays anchored to the same normalized video position.
- Preview can show 90%/80% safety guides and center crosshairs from an in-preview header toggle.
- Preview draws temporary snap guide lines while an overlay drag is actively snapped; these lines are non-interactive and live only in Preview editing, not export rendering.
- Selected overlays show a subtle blue selection border and corner handles on the fitted canvas.
- Corner handles in preview are interactive: dragging a handle updates the selected overlay `scale` directly via `ProjectDocument.setOverlayScale`, with continuous undo grouped to drag end.
- Playback advances the timeline playhead at 30 Hz while active.
- Left and right arrow keys step the timeline playhead backward or forward by one project frame, using the current project frame rate.
- Timeline ruler click/drag seeks the playhead; holding `C` while moving the mouse across the timeline time area scrubs the playhead to the hovered time, with the timeline consuming the `C` key events while the mouse is over it to avoid invalid-key beeps; timeline tracks show a red playhead indicator.

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

- Stroke controls.
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
- Phase C: initial template list UI in Project Settings. Completed, then superseded by the left `Templates` Pool.
- Phase D: apply/delete templates with undo support for apply. Completed.
- Phase E: import/export template file. Completed.

Current implementation:

- `OverlayTemplate` is a versioned Codable schema that stores metadata and `OverlayTemplateElement` values.
- Template elements store overlay type, normalized position, scale, visibility, lock state, and style.
- `OverlayTemplateStore` persists the local template library as JSON under Application Support.
- `ProjectDocument` loads templates on startup, saves/replaces templates by name, applies templates to the current overlay layout, deletes templates, and imports/exports standalone `.rotemplate` files.
- Applying a template routes through `ProjectDocument.registerUndoPoint()` so the previous overlay layout can be restored with undo.
- Template management lives in the left `Templates` Pool and has been removed from Project Settings. The pool uses compact name-only rows, built-in templates (`Easy Run`, `Interval Workout`, `Race`), user-template context menus, an icon-only import footer button, and a primary `Save Current as Template` footer button.
- `Easy Run` is the first authored built-in template and loads from `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`; `Interval Workout` and `Race` are still generated from code-defined first-pass element mappings.
- Applying a template from Templates Pool confirms before replacing existing overlays; when the current overlay layout is empty, it applies immediately without a replacement confirmation.

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
- `Export Test Clip` renders a three-second transparent MOV around the current playhead position using the current overlay layout and active FIT data (falling back to synthetic data when no FIT activity is loaded).
- Export now uses a single SwiftUI-based renderer path that rasterizes shared overlay views (`ImageRenderer`) on each frame and encodes transparent MOV output.
- Preview and export invoke the same shared overlay view entry points (`OverlaySharedTextPresetView`, `OverlaySharedDistanceTimelineView`, `OverlaySharedRouteMapView`) and differ only by `isInteractive` flags.
- Route Map export resolves its `MapSnapshotRequest` from the same layout inputs as preview, preloads matching `NSImage` snapshots before frame rendering, and supplies them to `OverlaySharedRouteMapView` so `ImageRenderer` does not depend on asynchronous view tasks for the map background.
- Shared entry points now also include elevation chart, running gauge, Interval HUD Bar, and Zone Edge Bar (`OverlaySharedElevationChartView`, `OverlaySharedRunningGaugeView`, `OverlaySharedIntervalHUDBarView`, `OverlaySharedZoneEdgeBarView`) so SwiftUI export covers current overlay controls on the same component path.
- Interval HUD Bar style decodes missing newer fields from defaults, allowing early HUD project snapshots to load after the ordered metrics, remaining-primary, and typography controls were added.
- `SwiftUIOverlayVideoExporter` removes its old per-type fallback drawing implementations and keeps only the shared component path used by preview.
- `Export Test Frame` renders a PNG through the same SwiftUI export rasterization path at the current playhead position.
- `Export Overlay JSON` serializes the current `OverlayLayout` as `overlay_configuration.json` for reproducible renderer-debug snapshots.
- `Save Project Snapshot` / `Restore Project Snapshot` in the Export dialog write and load a JSON snapshot of exportable project state for repeatable performance benchmarking.
- `--benchmark-export <snapshot.json>` starts Running Overlay in non-interactive benchmark mode, restores the snapshot, exports all timeline clips through `SwiftUIOverlayVideoExporter`, writes outputs into `running_overlay_benchmark_<timestamp>` under the current working directory unless `--benchmark-output <directory>` is provided, and terminates with a non-zero exit code on failure.
- Main `Export` no longer exposes legacy mode toggles and always uses SwiftUI shared-component export.
- Test clip/frame time sampling uses the same activity-time conversion as preview (`timeline.activityElapsed(atProjectTime:)`) before Layer Data FPS quantization.
- `renderPNG` now supports the same post-render vertical row flip option used by MOV export, so test frame outputs match preview orientation.
- Text preset export accent color now resolves from `element.style.accentColor` rather than `NSColor.controlAccentColor`.
- Apply project frame rate, resolution, bitrate, and Layer Data FPS.
- Generate output filenames with `_overlay.mov`.
- `ProjectDocument` owns structured export progress state for overall and per-output progress.
- The toolbar displays export progress while exporting; clicking the progress control opens a persistent popover with item-level progress.
- The export progress popover keeps the per-output queue in a fixed-height scroll view so long export queues remain reachable.
- Export can be cancelled from the progress popover; the exporter checks cancellation between segments and while rendering frames.
- Export reuses `AVAssetWriterInputPixelBufferAdaptor`'s pixel buffer pool instead of allocating a fresh pixel buffer every frame.
- Export caches attributed text layouts by text/style/sample output, reducing repeated font and string layout work across frames.
- `SwiftUIOverlayVideoExporter` owns MOV encoding, frame timing, and progress while rasterizing shared SwiftUI overlay components per frame.
- Export creates an explicit flipped `NSGraphicsContext` for text drawing so backgrounds and text render through the same bitmap context without global CGContext inversion.
- Export text is rendered through a 2x supersampled transparent offscreen bitmap before compositing back into the output frame, reducing jagged edges on large saturated text and alpha-shadow boundaries.
- Export scales font sizes, padding, rounded corners, shadows, distance timeline geometry, and elevation chart geometry from the shared 1280x720 render reference to the selected project resolution.
- Export renders distance timeline and elevation chart overlays with the same shared progress and sample data used by preview.
- Test clip/frame exports use current overlay content instead of fixed calibration reference overlays.
- Export vertically flips completed pixel-buffer rows before appending frames, compensating for the `CVPixelBuffer` to MOV orientation path so the encoded result matches the preview coordinate system.
- Export reuses the previous `ImageRenderer` output when adjacent video frames quantize to the same Layer Data sample time, while still appending every output frame.
- MOV export uses an `ExportRenderPlan` that separates static decor overlays from dynamic data overlays, caches the static layer once, and renders dynamic overlays into a padded union rect when the rect stays below 85% of the canvas.
- When the dynamic rect reaches the full-frame fallback threshold, MOV export uses a single full-frame render/draw path instead of layered drawing to avoid fallback overhead.
- Full-frame fallback renders `SwiftUIOverlayFrameView` directly; the cropped `SwiftUIOverlayLayerView` wrapper is reserved for static layers and dynamic-region rendering.
- When full-frame fallback is caused by far-apart dynamic overlays rather than a truly large single overlay, MOV export may use `renderPath=perOverlay`: each dynamic overlay renders through the cropped layer wrapper into its own padded rect, then all local images are composited in one pixel-buffer context.
- Per-overlay rendering is intentionally conservative: it requires no static decor overlays, a reliable render rect for every dynamic overlay, and total padded overlay area below 85% of the canvas. Otherwise the exporter keeps the v5 full-frame path.
- Per-overlay and dynamic-region compositing converts SwiftUI top-left render rects into pixel-buffer draw rects before drawing into `CGContext`; full-frame renders still draw at the full canvas rect.
- Inside the per-overlay path, Route Map overlays with no visible stats bar can prerender the static map/route layer once per export task and render only the current marker per unique Layer Data sample. Route maps with visible stats bars stay on the normal per-overlay render because their text values are elapsed-time dependent.
- Inside the per-overlay path, nearby simple numeric overlays may render as a single `SwiftUIOverlayLayerView` batch when their padded union is smaller than their individual padded areas and below 45% of the canvas. The batch keeps the existing SwiftUI visual path and is profiled under the first grouped numeric overlay type.
- Export-performance benchmarks should use the fixed snapshot at `/Users/codywang/Documents/Video Production/0509 纽约/running_overlay_project_snapshot.json` through `swift run RunningOverlay --benchmark-export ... --benchmark-output ...`, with each optimization round writing to a new numbered output directory.
- Distance Timeline static/dynamic SwiftUI splitting was benchmarked and reverted after Test10/Test11 because the additional SwiftUI render passes increased `imageRenderDuration` more than the reduced draw cost helped.
- `ImageRenderer` and pixel-buffer CGContext operations run inside autorelease boundaries to reduce temporary object buildup during long exports.
- Each completed export task writes `export_profile_<timestamp>.json` and `export_profile_<timestamp>.csv` into the destination folder with whole-export totals, per-segment timing/reuse metrics, static/dynamic layer metrics, render-path diagnostics, per-overlay render metrics, and frame-level outlier metrics.
- Export profiling stores per-segment render/draw/frame p50, p95, max, slow-frame count, and the 10 slowest frame samples in JSON so benchmark outliers can be tied back to frame index and `sampleElapsed`.

Pending:

- Visual snapshot checks for preview/export overlay render parity.
- Codec fallback handling if HEVC with alpha is unavailable on a machine.

Export performance optimization directions:

- Introduce frame-scoped render caches for static overlay layers (background shapes, static labels, static map tiles) and composite only dynamic layers each frame.
- Add per-overlay dirty-region change detection so exporter rerenders only overlay bounds whose sampled output changes.
- Avoid adding more SwiftUI `ImageRenderer` passes for the same overlay unless a fixed-snapshot benchmark proves a net win.
- Parallelize non-UI preprocessing work (sample-time preparation, layout precompute, route/elevation intermediate buffers) while keeping `ImageRenderer` use on `MainActor`.
- Add adaptive quality knobs for export jobs (supersampling factor, shadow quality, optional map detail level) with profile-based defaults.
- Extend structured export profiling with optional deeper per-frame samples, memory high-water mark, and benchmark fixtures once summary/segment artifacts identify the bottlenecks.

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
