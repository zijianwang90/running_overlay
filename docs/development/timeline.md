# Timeline Development

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
- FIT track rendering uses `ActivityTimeline.workoutStructure` and `LapRecord.kind` to color WU, RUN, REST, CD, and generic lap phases for Structured workouts, while Normal activities keep the default green FIT bar and timer-paused spans remain gray overlays.
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

