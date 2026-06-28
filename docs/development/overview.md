# Development Overview

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
