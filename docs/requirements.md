# Running Overlay Product Requirements

Last updated: 2026-04-28 (Preview corner-handle scaling now directly updates overlay `scale`)

## 1. Product Summary

Running Overlay is a native macOS application that imports one FIT activity file and multiple video files, aligns the videos to the activity timeline, lets the user design data overlay elements, and exports transparent overlay video clips matching each source video segment.

The initial product focuses on running, but the data model and UI should avoid assumptions that block cycling or other FIT-based sports later.

## 2. Core User Goal

Given a completed activity and one or more videos recorded during that activity, the user can generate transparent MOV overlay files that can be composited in Final Cut Pro, DaVinci Resolve, Premiere, or similar video editors.

## 3. Primary Workflow

1. User imports a FIT file.
2. User batch-imports video files.
3. App reads activity data from the FIT file and derives the master activity timeline.
4. App reads video metadata, timecode, creation time, and filename time patterns and keeps imported videos in the media pool.
5. User explicitly matches selected media to the current layer or a new layer, or manually drags media onto the timeline.
6. User configures project resolution and frame rate.
7. User designs data overlay elements in the video preview.
8. User exports one transparent overlay clip per timeline video segment.

## 4. Project Settings

The main interface has a small gear icon in the lower-right corner. Clicking it opens current project settings.

Initial settings:

- Timeline resolution presets:
  - 16:9: 1280x720, 1920x1080, 2560x1440, 3840x2160
  - 9:16: 720x1280, 1080x1920, 1440x2560, 2160x3840
- Project frame rate presets:
  - 23.976
  - 24
  - 25
  - 29.97
  - 30
  - 50
  - 59.94
  - 60
- Layer data update frame rate presets:
  - 1 fps
  - 5 fps
  - 10 fps
  - 15 fps
  - 30 fps

The layer data update frame rate controls how often FIT-derived values change in overlay preview and export. It is separate from the project video frame rate: a 30 fps project can still update data values at 1, 5, 10, or 15 fps when the user wants a less jittery data layer.

Open questions:

- Whether custom resolution should be supported in the first release.
- Whether imported video frame rates should influence the default project frame rate.

## 5. Main Layout

The app follows a professional video-editing layout inspired by Final Cut Pro and DaVinci Resolve:

- Left/top-left: media browser and imported video file management.
- Center/top: video preview/player.
- Right/top-right: context-sensitive parameter panel.
- Bottom: multi-track timeline.
- Top-right: export button.
- Lower-right: project settings gear.
- Default visual appearance: dark editing workspace similar to Final Cut Pro and DaVinci Resolve, not a white/light system theme.
- App chrome and panels should use the shared app UI design tokens from `docs/design/system/app-ui.md`: near-black root background, charcoal panels, raised headers, subtle borders, compact controls, and blue primary accent.
- Media Pool, Preview, Timeline, Inspector, settings, export, and status surfaces should use a consistent panel/header/row/control language.

Layout interaction requirements:

- The media browser, preview, and inspector widths are adjustable by dragging their boundaries.
- The media browser default width is 380 px with a 300 px minimum.
- The inspector default width is 460 px with a 460 px minimum.
- Media Pool width must remain stable across all media operations; importing, matching, or filtering media must not change the Media Pool pane width.
- Inspector width must remain stable when switching between outer/detail/editing states or when selecting a timeline clip; internal Inspector hierarchy changes must not resize the right pane.
- Resizable split panes should keep stable minimum widths so dense controls and row labels do not collapse.
- The timeline spans the full window width instead of being constrained to the preview column.
- The upper editor area and bottom timeline height are adjustable by dragging their shared boundary.
- A new empty project starts without sample media, sample clips, sample overlay elements, or a fake activity timeline.
- Empty panels should render as neutral empty work areas, not as mock content.
- The top header bars of Media, Preview, and Inspector should use a unified header height.
- Header icon/menu button heights across Media, Preview, and Inspector should use a unified compact control size.

## 6. FIT Timeline

The FIT file defines the master timeline.

Requirements:

- The minimum timeline range is the full FIT activity duration, fitted across the available timeline width.
- The timeline ruler starts at activity start and ends at activity finish.
- Hovering on the ruler shows basic data:
  - Activity elapsed time.
  - Real-world timestamp.
  - Distance.
- Ruler hover data should be extensible so future versions can expose configurable fields.
- The timeline zoom maximum is initially targeted around 200 pixels per second. This value may be adjusted after interaction testing.

Current implementation status:

- FIT file selection is available from the toolbar and app command menu.
- A first-pass FIT parser reads standard record and session messages for timing, distance, heart rate, speed-derived pace, elevation, cadence, power, and calories when present.
- Timeline ruler hover currently displays elapsed time, real-world time, and distance.
- After importing a FIT file, the timeline shows the full activity ruler even before videos are imported.

## 7. Video Import And Alignment

The user can batch-import multiple video files.

Automatic placement should attempt alignment using, in priority order to be refined during implementation:

1. Embedded video metadata creation time.
2. Timecode metadata, when available.
3. Filename time patterns.
4. Other media metadata that can be reliably mapped to a real timestamp.

Current implementation status:

- Batch video import is available from the toolbar and command menu.
- Video files can be dragged from Finder directly into the media browser to append-import them.
- The app reads video duration and creation-date metadata through AVFoundation.
- The app attempts filename date parsing for common patterns such as `YYYYMMDD_HHMMSS`.
- Imported videos are listed in the media browser with duration, alignment status, tag mark, and inferred timestamp when available.
- Videos with inferred timestamps near the FIT activity are marked as ready for timestamp matching but are not automatically placed on timeline tracks.
- Media browser rows can be selected individually, multi-selected, or all selected from the visible filtered list.
- Media browser search should filter visible rows by filename.
- Media browser status chips should provide real `All`, `Ready`, and `Aligned` filters.
- Command+A should select all visible filtered media rows when the media browser is active.
- The active media browser should not display an outer system focus ring.
- Media browser rows should use alternating dark row backgrounds, hover fills, compact file icon wells, selected-row accent strips, and status pills instead of horizontal divider lines.
- The media browser supports user color tag marks from the context menu and filtering by tag from the browser header.
- Selected media can be matched from the context menu to the current layer or to a new layer.
- Media can be removed from the media pool from the context menu; removing media also removes timeline clips that reference it.
- The no-media state should be FIT-first: before FIT import it should show `Import FIT`; after FIT import it should show `Import Videos`, a short explanation, drag/drop affordance, and supported-format hint.

If timestamp matching is unavailable or insufficient:

- User can drag media from the media browser onto the timeline.
- User can adjust timeline position manually.

Current implementation status:

- Media browser items can be dragged onto timeline tracks.
- If no videos have been matched, the timeline still shows a default drop track when FIT or media context exists.
- If no FIT or media has been imported, the timeline is completely empty and does not show a playhead, FIT layer, or fake track.
- Dropping a media item creates or moves a timeline clip at the drop time.
- While dragging media over the timeline, the target layer is highlighted.
- When dragging below existing layers, exactly one new layer drop target is exposed.
- Manually placed media is marked as aligned by manual placement.
- Existing timeline clips can be dragged horizontally to adjust their timeline position. For timestamp-matched media, dragging changes the clip offset while preserving the automatic matched start; for manually placed media, dragging changes the editable aligned time while preserving the offset.
- The timeline uses project time, not only activity elapsed time, so video clips can start before the FIT activity begins or continue after the FIT activity ends.
- The FIT activity is shown as an independent `FIT` layer whose span represents activity elapsed `00:00` through activity finish.
- The FIT layer defaults to filling the timeline when there are no out-of-range clips, but videos with real timestamps before start or after finish can extend the project timeline to the left or right.
- The FIT layer can be dragged horizontally to manually align activity data against the imported videos.
- The timeline interaction surface is implemented as an AppKit self-drawing view embedded in SwiftUI.
- Empty FIT/media-ready timelines show a default `Layer 1` lane.
- Timeline track labels are visually separated from the central timeline lane area.
- During playback, the timeline scrolls horizontally to keep the playhead visible.
- Timeline zoom can be controlled by Command + Plus, Command + Minus, Command + mouse wheel/trackpad scroll, macOS trackpad pinch, and the timeline zoom slider.
- Timeline zoom slider uses a fine-grained low-end scale so small slider movement does not jump abruptly from fit view to a large zoom value.
- Timeline zooming keeps the current playhead in view and recenters the view on the playhead when zoom changes.
- The timeline header includes per-track preview enable/disable controls in an eye-icon menu. The previous explicit preview-track picker has been removed; preview track auto-selection is implicit, and users only need to toggle individual track visibility.
- The timeline header includes an icon-only collapse/expand toggle. Collapsed mode hides gaps without video; for a single layer, clips are displayed back-to-back, and for multiple layers, FIT-only regions with no video on any layer are hidden while overlapping video spans remain aligned.
- In collapsed mode, the FIT layer should only draw green FIT blocks where the visible video span overlaps the FIT activity range. Video-only spans outside the activity should remain empty above the clip.
- The timeline collapse state is communicated by the header control style; the timeline must not introduce a separate `Gaps hidden` status row/band.
- When the timeline is collapsed, playback skips hidden empty regions and continues at the next video span.
- When the timeline is collapsed, existing video clips cannot be dragged horizontally; users must expand the timeline before timing edits that depend on full time context.
- Collapsed timeline joins should visually read like video-editor splice points, with square internal clip edges and clear dark block borders rather than full-height separators.
- Timeline clip titles are constrained inside their clip blocks and truncated instead of overflowing adjacent clips or lanes.
- Timeline clip block widths must reflect actual video duration at the current zoom level, including fit view; text may be hidden when the block is too narrow.
- Large layout split boundaries expose resize cursors on hover.

When timestamp matching is applied:

- User can still fine-tune clip position because camera time and FIT time may not match exactly.
- Clips inferred before activity start keep negative project positions instead of being cropped to `00:00`.
- Clips inferred after activity finish keep their post-finish project positions instead of being cropped to activity duration.

## 8. Timeline Editing

Requirements:

- Timeline supports multiple tracks for multi-camera workflows.
- Imported clips appear on tracks as movable timeline items.
- User can drag media from the media browser to the timeline.
- User can fine-tune clip timing on the timeline.
- Basic keyboard shortcuts:
  - Space: play/pause.
  - Command + Plus: zoom in timeline.
  - Command + Minus: zoom out timeline.
  - Command + mouse wheel/trackpad scroll on timeline: zoom timeline.
  - Trackpad pinch on timeline: zoom timeline.
  - Left Arrow / Right Arrow: step the timeline playhead backward or forward by one project frame.
- Timeline should expose a visible zoom slider in the timeline header.
- Timeline should expose a collapse/expand control next to the zoom slider for hiding and restoring no-video gaps.
- Resizable region dividers should show resize cursors on hover.

Current implementation status:

- Selected clips expose track/camera name editing in the Inspector.
- Selected clips expose a start-time input in the Inspector. Duration editing is deferred until clip trim-length adjustment is needed.
- Selected clips should use the same dense detail Inspector treatment as overlay detail views: compact header with back/action controls and dense section rows.

Future requirements:

- Direct timeline trim handles.
- Snapping.
- Markers.
- Audio waveform display.

Editing history requirements:

- User editing operations should support undo and redo.
- Pressing Delete or Forward Delete should delete the selected timeline clip or selected overlay element.
- Delete and Forward Delete should work when focus is inside the AppKit timeline canvas.
- The app should activate and become keyboard-focused when the user clicks inside the timeline so shortcuts are delivered to the app rather than another foreground app.
- Undo and redo should be project-level and apply consistently across timeline and overlay editing.
- Continuous gestures such as dragging and slider changes should be grouped into one undoable action where practical.

## 9. Parameter Panel

The right parameter panel is context-sensitive.

When a timeline clip is selected:

- Show clip position fine-tuning controls.
- Fine-tuning is relative to the app's current best FIT-to-video alignment.
- Provide numeric second-based inputs for manually placed clip aligned time and alignment offset. Timestamp-matched clips show the automatic matched start as read-only and expose offset as the adjustment control.
- Double-clicking timing field labels should reset the corresponding value to its default.
- Provide an action: "Apply to all clips in this layer".
- The action applies the same offset to all clips in the currently selected timeline layer.

Current implementation status:

- Selected clips show title, camera/source group, start-time input, and offset input.
- Start and offset inputs edit seconds to two decimal places.
- Double-clicking the Start or Offset label resets the value to `0.00 s`.
- Selected clip Inspector includes a destructive delete action in the detail header and a layer-wide offset apply action directly below the Offset row.
- The layer-wide apply action copies the selected clip's offset to all clips in the same timeline layer.
- Dragging a clip on the timeline changes its effective start time while preserving its current offset value.

When no timeline clip is selected:

- Show the data overlay editor.
- Show a list of already-added overlay elements.
- Clicking an added overlay element in the list selects it, matching preview selection behavior.
- Added overlay elements can be deleted from the list.

When an overlay element is selected:

- Show that overlay element's detail controls.
- Initial implementation only needs font controls.

## 10. Data Overlay Editor

The user can add overlay elements to the preview.

Initial overlay elements:

- Heart rate.
- Pace.
- Calories.
- Activity elapsed time.
- Real-world time.
- Distance.
- Distance timeline.
- Current elevation.
- Live elevation chart.
- Cadence.
- Power.
- Running Gauge.

Overlay canvas requirements:

- Added elements appear over the video preview.
- User can select overlay elements.
- User can drag elements to position them.
- User can scale elements.
- Overlay positions are normalized to the project preview canvas, not to the outer app panel, so resizing or dragging preview split boundaries must keep elements anchored to the same video-relative location.
- Overlay preview sizing should scale with the fitted preview canvas size so text, padding, guides, and chart elements remain proportional when the preview region changes.
- Parameter panel reflects the selected overlay element.
- Initial detail editing can be limited to font settings.

Current implementation status:

- Overlay elements display sampled values from the activity timeline at the current playhead.
- Overlay values are sampled at the current playhead quantized by the project Layer Data FPS setting.
- Preview overlay elements can be dragged within the preview.
- The left Overlay Pool owns the add-overlay catalog and groups add tiles by Metrics, Charts, and Route.
- Inspector uses a compact dark tool-panel layout for added-overlay management and selected-overlay detail states.
- Inspector width is preserved across outer/detail/editing hierarchy states so internal selection changes do not resize the right panel or truncate tile labels.
- The Inspector outer state shows added overlays as live-value rows and does not duplicate Overlay Pool add tiles.
- Inspector segmented controls use native macOS segmented pickers for keyboard/focus and accessibility behavior.
- This includes segmented controls in Overlay Pool and dense detail inspectors (Numeric Overlay, Running Gauge, and Route Map).
- Clicking an add tile creates the overlay and opens its detail editor.
- Selected overlay elements expose current value, normalized position, scale, preset, font family, font weight, font size, foreground color, background opacity, shadow opacity, and shadow radius controls in the Inspector detail state.
- Numeric overlays (heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, power, and advanced running metrics) use the dense `NumericOverlayDetailView` Inspector with Content, Layout, Typography (value), Label, Unit, Color, Background, and Effects sections matching `docs/design/overlays/numeric/numeric-overlay-ui.md`. Shared Layout uses Position/Scale/Width/Height/Opacity (no Rotation).
- Numeric overlay defaults now standardize to `Minimal Clean` for all numeric types.
- Numeric overlay style supports per-overlay unit option, label/unit visibility toggles, custom label text, independent label/unit positions (`top/bottom/left/right`), independent label/unit typography (`font`, `size`, `weight`), rotation, accent color, background enable/color/radius/padding plus fade-out + gaussian blur controls, and shadow enable/offset controls. New fields decode with safe defaults so existing projects and templates remain compatible.
- Added-overlay rows now support per-element visibility and lock toggles with persistent model fields.
- Visibility off hides the element in both Preview and exported overlay frames.
- Lock on keeps the element visible but prevents Preview-canvas selection and dragging.
- Added-overlay rows and Preview overlays provide context-menu actions for copying and pasting overlay properties.
- Property paste is limited to the same overlay category (for example, numeric -> numeric only).
- Selected text overlays expose a built-in style picker as the first Inspector control, with Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, Split Label, Inline Ghost, Accent Bar, Sport Neon, and Serif Editorial presets.
- Numeric overlay presets carry recommended typography tokens (value font family/weight/size, label/unit visibility, label/unit defaults, background, accent color); selecting a preset snaps those fields so the overlay matches the design intent without further tuning.
- Selected Running Gauge overlays use the dense `RunningGaugeOverlayDetailView` Inspector with eleven sections that share the exact tokens, row heights, controls, and section disclosure behavior of `NumericOverlayDetailView`: Style Preset, Position & Scale, Data Layout, Region Settings, Dial, Ring, Ticks, Dividers, Typography, Color, Effects.
  - Style Preset offers Minimal Sport, High Contrast Sport, Road Run, Trail Adventure, Future Tech, Retro Digital, and Premium Glass; selecting a preset reseeds the gauge sub-style without touching the user's data layout / region bindings.
  - Data Layout offers seven layout presets (Top / Bottom, Top / Middle / Bottom, Three Zones, Top + Two Middle + Bottom, Top + Three Middle + Bottom, Four Zones, Five Zones); choosing a layout regenerates the recommended per-region metric defaults.
  - Region Settings lists every visible region with an inline metric picker (Distance, Pace, Elapsed Time, Real Time, Heart Rate, Power, Cadence, Elevation, Calories) and an expandable per-region drawer for Custom Label, Show Label / Show Unit, Value Size, Value Weight, and Value Color.
  - Dial / Ring / Ticks / Dividers / Effects sections expose every renderer-consumed parameter (dial color + opacity + glass; outer ring + progress ring + progress mode + caps; tick count + major-every + opacities; divider color/opacity/width; shadow + glow). Conditional sub-rows show only when the parent toggle is on.
  - Typography offers Font, Monospaced Digits, and primary/secondary Weight; Color offers Primary Text, Secondary, and Accent swatch strips.
- Space starts/stops playhead playback, and the overlay values update as playhead time changes.
- Left and right arrows move the timeline playhead by exactly one project frame for fine timing checks.
- Timeline ruler click/drag updates the current playhead.
- Timeline ruler hover data appears above the time scale, not under the cursor, with an arrow pointing to the hovered ruler position.
- A muted red playhead with a small downward-pointing triangle inside the ruler band is shown on timeline tracks. The vertical line starts from inside the ruler and extends down through the visible tracks; neither the line nor the triangle is allowed to extend above the ruler.
- The Distance Timeline overlay renders a configurable compact progress module with minimal, dense, sport, splits, glass, neon, lower-third, and route presets.
- Distance Timeline presets can control value/label/percent content, background, border, padding, track height, ticks, current marker, glow, fade amount, media slot for applicable presets, route elevation underlay, and GPS sampled route geometry for the route preset.
- Distance Timeline media slots support system icons plus embedded static or animated SVG assets. Embedded SVG assets must persist through overlay templates and render deterministically in preview and export.
- The live elevation chart overlay renders as a compact line chart with a playhead marker.
- The Running Gauge overlay renders a circular dashboard with a configurable dial background, optional outer ring, optional tick marks (count + major-every), optional progress ring (with mode: distance target / elapsed time / HR zone / power zone / pace intensity / custom), optional divider lines, and per-region data text. The active layout preset (one of seven) determines which regions are rendered, and each region independently binds a metric (Distance / Pace / Elapsed Time / Real Time / Heart Rate / Power / Cadence / Elevation / Calories), label visibility, unit visibility, value font scale/weight, and value color. Preview and export share the same `RunningGaugeLayoutEngine` region-frame and divider-segment helpers.
- Overlay preview and export share the same render layout model for sampled values, normalized positions, base element dimensions, font sizes, padding, progress, and chart samples.
- Text presets are stored with overlay style data and render consistently in preview, calibration PNGs, and transparent video export.
- Gauge presets are stored with overlay style data and render consistently in preview, calibration PNGs, and transparent video export.
- Preview overlay placement and drag behavior are based on the actual fitted project canvas inside the preview panel, avoiding offset drift when split panes resize the preview area.
- A small Preview header switch can show or hide preview safety guides, including 90%/80% safe frames and center crosshairs.
- Selected overlays show a subtle blue selection border and small corner handles.
- Dragging selected-overlay corner handles scales the overlay and writes directly to the element `scale` model value.

Future requirements:

- Stroke, richer chart style, and animation controls.
- Copy/paste and grouping.

## 10.1 Overlay Templates

Overlay templates are separate from full project files. A template stores reusable overlay design configuration so a user can apply the same layout and visual style across many FIT files and video batches.

Template goals:

- Let users save a finished overlay layout as a reusable named template.
- Let users apply a saved template to the current project.
- Let users manage templates without saving the full project.
- Let users export/import template files for backup or transfer.

Template contents:

- Template schema version.
- Template name.
- Canvas reference resolution or aspect ratio used when created.
- Overlay elements:
  - Element type.
  - Normalized position.
  - Scale.
  - Visibility.
  - Lock state.
  - Built-in text preset when present.
  - Built-in gauge preset when present.
  - Font family, size, weight.
  - Foreground color.
  - Background opacity.
  - Shadow opacity and radius.
  - Future style fields such as stroke, shadow, alignment, number format, units, and chart style.

Template must not include:

- FIT file path or parsed FIT data.
- Video file paths or video metadata.
- Timeline tracks or clips.
- Current playhead.
- Current sampled values such as the current heart rate or distance.

Template behavior:

- Applying any built-in or user template replaces the current overlay layout.
- Applying any template requires confirmation before replacement.
- Applying a template should be undoable.
- Saving a template should not affect timeline or media state.
- Deleting a template should not affect the current project unless that template is currently only being previewed.

Initial template UI:

- Template management is exposed through the left `Templates` Pool, not Project Settings.
- The top Pool switch includes `Media Pool`, `Overlay Pool`, and `Templates`.
- `Templates` Pool includes:
  - `Built-in Templates`: `Easy Run`, `Interval Workout`, and `Race`.
  - `Easy Run` is backed by the bundled `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate` file so it can carry a fully authored overlay layout and styles.
  - `User Templates`: saved local templates, empty by default.
  - A compact footer with a small icon-only import button and a long `Save Current as Template` primary button.
- Template rows are compact name-only rows:
  - No leading icons.
  - No trailing apply buttons.
  - No visible ellipsis/menu buttons.
  - Row click applies the template after confirmation.
- User template row context menu actions:
  - Rename.
  - Duplicate.
  - Export.
  - Delete.
- The footer import button is the only import entry inside Templates Pool; built-in template rows and blank built-in space should not show an import context menu.

Current implementation status:

- Local overlay template persistence exists; the UI now lives in the left `Templates` Pool instead of Project Settings.
- Users can save the current overlay layout as a named local template.
- Templates are persisted as JSON under Application Support.
- Users can apply, delete, import, and export local templates.
- Applying a template replaces the current overlay layout and participates in project undo/redo.
- The `Easy Run` built-in template loads from the bundled `EasyRun.rotemplate` resource; generated built-in mappings are used for the remaining first-pass built-ins.
- Saved template JSON includes schema version, name, timestamps, reference project resolution, and overlay elements.

Open questions:

- Whether applying a template should preserve existing element IDs for undo/edit continuity or create new IDs.

## 10.2 Route Map Overlay

Route Map Overlay is a featured overlay module that renders the activity route as a customizable map or abstract route graphic. Detailed design lives in [Route Map Overlay Design](overlay-modules/route-map-overlay.md).

Product requirements:

- Support route-only styles that do not require network access.
- Support a future map-backed style through a pluggable map snapshot provider.
- Use FIT GPS latitude/longitude when available.
- Share preview and export rendering behavior.
- Cache route geometry and map snapshots so export does not depend on per-frame network calls.
- Let templates save route map style and layout, but not activity coordinates, API tokens, or cached map images.
- Provide graceful unavailable states when an activity has no GPS data or the selected map provider cannot load.

Initial style targets:

- Minimal route.
- Gradient route.
- Glow route.
- Map style.

Open questions:

- How much start/end location privacy protection should be enabled by default.

Current implementation status:

- FIT record parsing reads `position_lat` and `position_long` into activity records.
- FIT timer pause spans should be represented as non-destructive activity annotations on the FIT layer. Paused spans use a muted gray color and a hover tooltip labeled `运动暂停`, while keeping the underlying timeline based on real elapsed time so video alignment is not shifted.
- `ActivityTimeline` exposes route points and interpolated current route point lookup.
- Route Map can be added from the overlay library.
- Inspector exposes Minimal, Gradient, Glow, and MapKit route styles.
- Preview and export render route path, start marker, finish marker, and current-position marker.
- MapKit is the first provider abstraction and the preview attempts `MKMapSnapshotter` for the MapKit preset.
- When MapKit snapshot loading is unavailable, the MapKit preset falls back to a local dark grid background.
- Route Map and Distance Timeline share one Stats Bar inspector component and one full control set; Enabled is in the section header, and all row controls are aligned between modules.
- Route Map Stats Bar inside mode reserves map content padding for the bar lane (route geometry does not render underneath the bar).
- Route Map Stats Bar on left/right edges renders as top-to-bottom stack, and `Item Gap` is applied as vertical spacing.

Remaining:

- Persist and manage user-provided custom map API/Mapbox-style endpoints.
- Use cached map snapshots during export instead of the current local fallback background.
- Add route simplification and richer metric-based gradient coloring.

## 11. Playback

Initial playback requirements:

- Space toggles play and pause.
- K toggles play and pause.
- L starts forward playback when paused; while playing, repeated L presses step forward speed through 2x, 4x, and 8x.
- Preview playhead is tied to the FIT master timeline.
- Visible overlays should update according to the activity data at the playhead.
- Video clips on timeline should preview at their aligned positions.
- The preview area should contain playback controls below the video canvas: previous clip, stop, play/pause, and next clip. Reverse playback is not required.

Current implementation status:

- The preview displays the source video for the first timeline clip that contains the current playhead.
- Double-clicking a media-pool item temporarily previews that source video from the beginning and starts playback without moving the timeline playhead.
- When the media browser loses focus, temporary media-pool preview should clear and the preview should return to timeline playhead mode.
- Source video time is calculated from `playhead - clip.effectiveStartTime`.
- When no clip contains the current playhead, the preview remains black and does not show sample media.
- During playback over a video clip, the AVPlayer playback clock updates the project playhead so overlay values follow the actual video time.
- When no clip contains the current playhead, the app falls back to timer-based playhead advancement.
- Users can disable preview for specific tracks to reveal lower/other tracks at the same playhead time.
- Disabled preview tracks affect preview only; timeline clip export still exports every clip individually.
- Frame stepping.
- Proxy media.
- Dropped-frame diagnostics.

## 12. Export

The export button is in the upper-right area of the interface. Clicking it opens an export dialog.

Initial export options:

- Export format: transparent MOV overlay video.
- Codec:
  - H.265 with alpha.
  - ProRes 4444.
- Destination folder, defaulting to the folder containing the first video in the media pool and falling back to `~/Movies` when no video files are loaded.
- Resolution: from project settings.
- Frame rate: from project settings.
- Layer data update frame rate: from project settings.
- Bitrate: default 30 Mbps.
- Bitrate range: 5-100 Mbps.

Export behavior:

- When an export is active, the toolbar shows a progress control in the upper-right area.
- Clicking the progress control shows a popover with overall progress and per-output progress rows.
- The export queue inside the progress popover has a fixed-height scrollable area so large batch exports do not push the popover beyond the screen.
- The progress popover allows cancelling the active export.
- After the user cancels export, the export queue/progress popover state clears immediately instead of lingering in a failed or partial state.
- Batch export one overlay clip for each video segment on the timeline.
- Each overlay clip's start and end match the corresponding timeline video segment start and end.
- Overlapping timeline clips are exported separately, one output file per clip.
- Full activity export can ignore all video segments and render one overlay file covering the entire FIT activity.
- `Export Test Clip` renders a short transparent MOV anchored to the current playhead position, using the current overlay configuration.
- `Export Test Frame` renders a PNG at the current playhead position through the SwiftUI shared-component rasterization path.
- Main `Export` always uses the SwiftUI shared-component rasterization path (legacy export mode removed).
- `Export Overlay JSON` writes the current `OverlayLayout` configuration to JSON for inspection, debugging, and reproducible style snapshots.
- Test clip/frame sampling time must use the same playhead-to-activity conversion and Layer Data FPS quantization path as preview (`activityElapsed(atProjectTime:)` + quantization).
- Test frame PNG orientation must match preview/export coordinates (no vertical inversion in the saved image).
- Text preset accent colors in export must come from each overlay style's accent color instead of system accent defaults.
- Activity data is sampled from the FIT timeline for each segment using the configured Layer Data FPS cadence.
- Export rendering scales overlay dimensions from the 720p preview reference so text, padding, and graphic sizes remain proportional at 1080p, 2K, and 4K output sizes.
- Exported text should be antialiased through supersampled rendering before compositing into the final transparent frame, especially for large colored timer overlays.
- Exported distance timeline and elevation chart elements should match their preview counterparts instead of falling back to static text; Distance Timeline export uses the same preset-aware layout as preview.
- Output filename follows the source video filename with `_overlay.mov` appended before or after the extension pattern to be finalized.

Example:

- Source: `run_camera_a_001.mov`
- Overlay: `run_camera_a_001_overlay.mov`

Future requirements:

- User-defined export presets.
- Burned-in composite export.
- Alpha codec selection.
- Per-track or per-camera export selection.
- Export performance optimizations:
  - Incremental frame rendering with static-layer caching so unchanged overlay layers are reused across adjacent frames.
  - Per-overlay dirty-region rendering and composition to avoid full-canvas redraw on every frame.
  - Optional adaptive layer data sampling for slowly changing metrics during long exports.
  - Optional hardware-accelerated compositing path (Metal/Core Image) for large resolutions and long clips.
  - Export telemetry output (frame encode time, render time, dropped/slow frames) for profiling and regression tracking.

## 13. Data Accuracy Requirements

The application should preserve alignment accuracy as a first-class concern.

Initial targets:

- FIT timestamp parsing should retain real timestamps and elapsed activity time.
- Timeline placement should store offsets using time values, not rounded pixels.
- Rendering should sample data by time, not by UI frame positions.
- Rendering should use the same Layer Data FPS quantization as preview so exported overlay values match what the user saw while editing.
- UI zoom and display rounding must not change stored timing.

Open questions:

- Required precision for exported overlay values.
- Handling pauses, elapsed time versus moving time, and FIT records with missing fields.
- Handling FIT files with local timestamps, timezone metadata, or device clock drift.

## 14. Non-Goals For Initial Phase

- Full nonlinear video editing.
- Direct publishing to social platforms.
- Cloud sync.
- Mobile app.
- Complex color grading or audio editing.
- Full template marketplace.

## 15. Glossary

- FIT file: Activity data file format commonly produced by Garmin and other sports devices.
- Master timeline: The activity timeline derived from the FIT file.
- Source video: User-imported camera video.
- Overlay clip: Exported transparent video containing only data graphics.
- Camera/source group: A set of clips believed to come from the same recording device or camera angle.
