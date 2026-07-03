# App Bootstrap and Data Import

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
- Calories prefer direct record-level values. When a FIT file omits record calories but provides lap `total_calories`, such as some COROS exports, the parser estimates cumulative record calories from lap totals; when only session calories are available, it falls back to a linear session-total estimate.
- Timer start/stop events are parsed into `ActivityAnnotatedSegment` pause spans. These spans stay on the real elapsed-time axis and are available to timeline UI without changing video alignment.
- FIT lap classification runs through `WorkoutStructureAnalyzer`, which infers Normal vs Structured workouts from the full lap sequence instead of a fixed absolute speed threshold. Structured workouts keep an internal subtype (`interval`, `steadyPlan`, or `genericLaps`) while the import UI exposes only `Auto`, `Normal`, and `Structured`.
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
