# Running Overlay — macOS App UI Kit

Interactive click-through prototype of the Running Overlay macOS editor.

## Layout

Four-panel editor matching the real app layout:
- **Left (300px):** Media Pool — clip list, search, filter, context menu
- **Center:** Preview — video canvas with overlays, playback controls
- **Right (360px):** Inspector — overlay add tiles + added elements list; overlay detail editor
- **Bottom (200px):** Timeline — FIT track, video clip tracks, playhead, zoom

## Screens / States

1. **Default** — app loaded with media clips and 2 overlays
2. **Inspector Detail** — click an overlay row → opens Running Gauge detail editor
3. **Numeric Detail** — click Pace row → opens dense numeric overlay panel
4. **Media Context Menu** — right-click a media row → context menu with mark submenu
5. **Empty Media State** — toggled via a toolbar button for demo

## Components

- `MediaPanel` — header, search, filter chips, rows with marks
- `PreviewPanel` — canvas with overlay elements, playback bar
- `InspectorOuter` — add tiles (tabbed), added elements rows
- `InspectorDetail` — Running Gauge detail with style/animation sections
- `NumericDetail` — dense Pace inspector with collapse sections
- `TimelinePanel` — FIT track, clip blocks, playhead, ruler, drop lane

## Design tokens

All colors/sizes sourced from `../../colors_and_type.css` and `EditorTheme.swift`.
