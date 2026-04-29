# Media Pool UI Design Spec

Last updated: 2026-04-29

## Purpose

The left-side pool panel is the source library area for project inputs, addable overlay modules, and reusable overlay layout templates. It contains three sibling modes:

- `Media Pool`: imported video files and the FIT-first media import workflow.
- `Overlay Pool`: available overlay modules that can be added to the preview.
- `Templates`: built-in and user overlay layout templates.

The Media Pool supports import visibility, selection, source preview, timestamp matching, tag filtering, and context-menu actions. The Overlay Pool moves the selectable overlay catalog out of the Inspector so the Inspector can focus on added overlays and detail editing. Templates moves overlay template management out of Project Settings so template application, saving, import, export, and user-template management are all in one left-panel workflow. This refresh aligns the left pool styling with the Inspector design language documented in [Inspector UI Design Spec](../inspector/inspector-ui.md).

This spec is implementation-facing. Use it to restyle `MediaBrowserView` while preserving current behavior.

## Design Reference

Media Pool mockup

Media Pool empty mockup

## Design Direction

The left pool should feel like a professional video editor bin, not a generic system list. Keep the UI dense and scannable:

- Dark panel background with alternating row bands.
- A compact top mode switch controls `Media Pool`, `Overlay Pool`, and `Templates`, similar to a production editor's source/effects panel switch.
- Compact rows with clear filename, duration, capture time, and a compact alignment status indicator.
- Selected rows use a controlled blue/charcoal highlight, not a full washed-out system selection.
- Menus feel native to macOS but visually belong to the app: dark, elevated, rounded, bordered.
- Color marks are small, fast-to-scan dots or strips, not dominant labels.
- Overlay module choices live in `Overlay Pool`; the Inspector should not duplicate the add-overlay catalog.
- Overlay template management lives in `Templates`; Project Settings should not duplicate save/load/import/export template controls.

Use the same app-level visual tokens as the Inspector where possible.

## Design Tokens

Prefer reusing shared tokens from `inspector-ui.md`. Media-specific values:


| Token                       | Hex / Value | Usage                                   |
| --------------------------- | ----------- | --------------------------------------- |
| `media.panel`               | `#15191D`   | Media panel background                  |
| `media.header`              | `#1B2025`   | Header bar                              |
| `media.rowEven`             | `#1B2025`   | Alternating row                         |
| `media.rowOdd`              | `#171C21`   | Alternating row                         |
| `media.rowHover`            | `#222932`   | Hover row                               |
| `media.rowSelected`         | `#263244`   | Selected row                            |
| `media.rowSelectedBorder`   | `#2F8CFF`   | Selected row left or top accent         |
| `media.menuBackground`      | `#1D2228`   | Context menu                            |
| `media.menuHover`           | `#2F8CFF`   | Active menu item                        |
| `media.thumbnailBackground` | `#101418`   | Thumbnail/file icon well                |
| `row.height`                | `68-76 px`  | Default media row height                |
| `thumbnail.size`            | `42x42 px`  | Optional thumbnail/icon well            |
| `toolbar.iconButton`        | `30x30 px`  | Header actions                          |
| `search.height`             | `30 px`     | Search/filter field                     |
| `pool.switchHeight`         | `32 px`     | Media/Overlay pool segmented switch     |
| `pool.switchRadius`         | `8 px max`  | Mode switch container and selected item |
| `overlay.tileHeight`        | `56-64 px`  | Overlay Pool add tiles                  |
| `overlay.categoryHeight`    | `24 px`     | Metrics/Charts/Route segmented control  |
| `template.rowHeight`        | `28-30 px`  | Templates Pool row height               |
| `template.footerButton`     | `32 px`     | Templates Pool import/save actions      |


Mark colors:


| Mark   | Fill      |
| ------ | --------- |
| Red    | `#FF5A5F` |
| Orange | `#FF9342` |
| Yellow | `#FFD166` |
| Green  | `#51C96B` |
| Blue   | `#2F8CFF` |
| Purple | `#B657E8` |
| Gray   | `#9EA3AA` |


## Current Implementation Mapping

Current SwiftUI entry point:

- `Sources/RunningOverlay/UI/PoolPanelView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/TemplatePoolView.swift`

Existing behavior to preserve:

- Drag/drop video import.
- Single selection and Command-click multi-selection.
- Command+A selects all visible media when the Media Pool is active.
- Double-click previews a media-pool source item.
- Context menu actions:
  - `Auto Match to Current Layer`
  - `Match to New Layer`
  - `Mark`
  - `Select All`
  - `Delete from Media Pool`
- Tag filter menu.
- Alternating row backgrounds.
- Focus loss clears transient media-pool preview.

## Layout

Top to bottom:

1. Top app toolbar: pool mode switch aligned to the left pane width
2. Active pool header
3. Active pool controls
4. Active pool content
5. Empty states when needed

Recommended panel width: 300-380 px. The mockup is square for design transfer only.

## Pool Mode Switch

The top app toolbar starts with a compact three-option switch aligned to the left pane width:

- `Media Pool`
- `Overlay Pool`
- `Templates`

Visual rules:

- Keep it in the top toolbar's left slot, above the Media/Preview/Inspector panel headers. It replaces global FIT/Videos import buttons as the primary entry point into media and overlay resources.
- Use icon + label for both choices:
  - `Media Pool`: `play.rectangle` or another clear video/source icon.
  - `Overlay Pool`: stacked squares, sparkles, or layer icon.
  - `Templates`: document stack, rectangle stack, or bookmark/template icon.
- Selected item uses the app blue accent fill or a blue-accented dark fill.
- Unselected item uses `control.background` with muted text and a subtle border.
- Height: 32 px.
- Corner radius: 8 px max.
- Padding: 12 px horizontal, 8-10 px vertical around the switch.
- Do not add a separate card around the switch; it belongs directly to the app chrome.

Interaction:

- Switching pools must not reset the left panel width.
- Resizing the left pane should keep the switch visually aligned to the left pane content width.
- Switching pools must not clear media row selection unless the selected media becomes invalid through a later media action.
- The active mode is local UI state. It does not need to persist in project files.
- Keyboard focus should remain inside the left pool when the user switches modes.

Recommended implementation:

- Keep `@State private var activePool: PoolKind = .media` in `MainEditorView`.
- Render `PoolModeSwitch` in the top toolbar with a width derived from `mediaPoolWidth`.
- Render `MediaBrowserView` for `.media`.
- Render `OverlayPoolView` for `.overlay`.
- Render `TemplatePoolView` for `.templates`.
- Pass the active pool binding into `PoolPanelView`.
- Keep the existing horizontal resize handle and width state in `MainEditorView`.

## Header Bar

Content:

- Left title: `Media`
- Right toolbar icon buttons:
  - Select all visible media
  - Clear selection
  - View/filter menu
  - Dropdown chevron or additional options

Icon guidance:

- Use system symbols in SwiftUI if lucide is not available.
- Keep icon-only actions at 30x30 px.
- Add `.help(...)` and accessibility labels for every icon-only button.
- Disabled buttons should use muted foreground and no hover fill.

## Search And Filter Strip

Add a compact search field below or integrated into the header:

- Placeholder: `Search media`
- Height: 30 px
- Background: `control.background`
- Border: `border.subtle`

Status/filter row:

- Left: clip count, e.g. `8 clips`
- Filter chips: `All`, `Ready`, `Aligned`
- `All` selected by default.

Implementation note:

- The current model supports tag filtering but does not obviously expose a search query state or `Ready`/`Aligned` filters in the mockup form. It is acceptable to implement visual-ready structure incrementally:
  - Add search only if it filters `displayName`.
  - Keep existing tag filter menu if status chips are deferred.
  - Do not show filter chips that do not work.

## Media Rows

Each row contains:

- Optional thumbnail/file icon well on the left.
- Optional mark dot or mark strip.
- Primary filename.
- Secondary duration.
- Secondary capture date/time.
- Right-side alignment status dot. Hovering the dot shows the full status label, e.g. `Aligned by timestamp`.
- Do not show a trailing more/ellipsis affordance unless it opens a visible row action menu.

Example filenames:

- `PRO_VID_20260425_083915_00_001.mp4`
- `PRO_VID_20260425_085810_00_002.mp4`
- `PRO_VID_20260425_090526_00_003.mp4`
- `PRO_VID_20260425_093449_00_004.mp4`
- `PRO_VID_20260425_093814_00_005.mp4`
- `PRO_VID_20260425_094640_00_006.mp4`
- `PRO_VID_20260425_095711_00_007.mp4`
- `PRO_VID_20260425_100454_00_008.mp4`

Row states:

- Default: alternating dark backgrounds.
- Hover: slightly elevated dark fill.
- Selected: `media.rowSelected` plus a subtle blue accent line or border.
- Multi-selected: same selected style per row.
- Source-previewed item may use an additional play indicator if needed, but do not confuse it with selection.

Text:

- Filename: 13 px semibold, primary text.
- Metadata: 11-12 px regular, secondary text.
- Alignment status dot: 8-9 px circular indicator using success/warning/muted status color, with the full status label exposed as hover help and accessibility text.
- Use monospaced digits for duration if it improves scanning.

## Context Menu

The context menu should remain functionally equivalent to the current SwiftUI `.contextMenu`.

Menu items:

1. `Auto Match to Current Layer`
2. `Match to New Layer`
3. Separator
4. `Mark` with chevron and submenu
5. Separator
6. `Select All`
7. `Delete from Media Pool`

Mark submenu:

- `Red`
- `Orange`
- `Yellow`
- `Green`
- `Blue`
- `Purple`
- `Gray`
- `Clear Mark`

Submenu visual:

- Add color dots beside color names when feasible.
- The hovered menu row uses `accent.blue`.
- Destructive menu item can use normal text by default and `danger.red` only on hover/focus or if a confirmation pattern is added.

SwiftUI note:

- Native `.contextMenu` styling is OS-controlled. If exact visual styling is required, implement a custom popover/menu later. For v1, preserving native behavior is more important than forcing custom menu rendering.

## Empty States

No FIT and no media:

- Center icon: `waveform.path.ecg`
- Title: `Import FIT`
- Secondary text: `Start with running activity data`
- Primary action: `Import FIT`
- Step indicator: `1 FIT` active, `2 Videos` inactive.
- Secondary disabled or muted hint: `Then import videos`
- Use a subtle dashed rounded rectangle drop zone boundary, but do not imply video drop is ready before FIT import.

FIT imported, no media:

- Center icon: `video.badge.plus`
- Text: `Drop videos here`
- Secondary text: `Import clips to match them with your running activity`
- Primary action: `Import Videos`
- Optional format hint: `MP4, MOV`
- Step indicator: `1 FIT` complete, `2 Videos` active.
- Use a subtle dashed rounded rectangle drop zone only when drag/drop import is active.
- Keep background consistent with the panel.

Filtered empty:

- Center icon: filter icon.
- Text: `No media with this mark` or `No media matches the current filter`.

Empty states should be compact and functional. Avoid large illustration cards.

## Overlay Pool

Purpose:

- Overlay Pool is the catalog of addable overlay modules.
- It replaces the Inspector's `Add Overlay` section.
- It should reuse the same overlay definitions currently backing the Inspector tiles: type, label, hint, icon, category, and accent status.

Header:

- Title: `Overlay Pool`
- Optional status text: `Add overlays`
- Avoid extra toolbar actions unless they are real and immediately useful.

Controls:

- Category segmented control:
  - `Metrics`
  - `Charts`
  - `Route`
- Height: 24 px.
- Use full-segment hit targets.
- Center the category control within the Overlay Pool content area.
- Selected segment uses blue accent; unselected segments use dark controls with muted text.

Tiles:

- Two-column grid at 360-380 px panel width.
- One-column fallback below 320 px if text starts to clip.
- Tile height: 56-64 px.
- Tile content:
  - Leading icon.
  - Primary label, e.g. `Heart Rate`, `Pace`, `Distance`, `Running Gauge`, `Route Map`.
  - Secondary hint, e.g. `bpm`, `min/km`, `GPS path`.
- Featured overlays may use a small blue accent line, but tile icons and primary labels stay the same white primary text as other overlays.
- Tile tap calls `project.addOverlayElement(tile.type)`.
- After adding, prefer selecting the new overlay and opening its detail Inspector so the next action is editing.

Empty and disabled states:

- Overlay Pool should remain available before FIT import. Layout work is valid without activity data.
- If a module depends on unavailable FIT channels, keep the tile enabled and let the preview value show its existing empty/default state.
- Do not hide overlay types based on current FIT data unless there is a clear future compatibility rule.

Inspector boundary:

- The Inspector outer state should only show `Added Overlays`.
- The Inspector should keep overlay row management: visibility, lock, delete, and detail navigation.
- Overlay detail views remain in the Inspector.
- The Inspector should not show `Metrics`, `Charts`, `Route`, or add-overlay tiles after this refactor.

## Templates Pool

Purpose:

- Templates Pool is the single home for applying, saving, importing, exporting, and managing overlay templates.
- It replaces the Overlay Templates controls currently exposed in Project Settings.
- Template rows are intentionally minimal. Users identify templates by name, so rows should not carry decorative thumbnails, leading icons, trailing buttons, or ellipsis controls.

Header:

- Title: `Templates`
- Optional status text: `Apply layouts`
- Avoid toolbar actions in the header. Template actions belong in rows, context menus, or the sticky footer.

Pool switch:

- `Templates` is the third top-toolbar pool mode beside `Media Pool` and `Overlay Pool`.
- Keep the selected state visually consistent with the other two pool modes.

Section headers:

- Use an Inspector-style header row for `Built-in Templates` and `User Templates`.
- Header text is white primary text, not muted uppercase.
- Header background uses the elevated panel/header surface.
- Header spans the full Templates Pool content width and includes a subtle bottom divider.

Built-in templates:

- Section title: `Built-in Templates`
- Rows:
  - `Easy Run`
  - `Interval Workout`
  - `Race`
- Row height: 28-30 px.
- Row content: template name only.
- No leading icon.
- No trailing apply button.
- Clicking the row applies the template after confirmation.
- Built-in rows do not expose rename, duplicate, export, or delete actions.

Initial built-in template contents:

- `Easy Run`: bundled from `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`.
- `Interval Workout`: Elapsed Time, Pace, Heart Rate, Lap Live.
- `Race`: Distance Timeline, Running Gauge, Route Map, Pace.
- `Interval Workout` and `Race` are first-pass placeholder mappings. Each element should receive a reasonable normalized position so templates do not stack every overlay at center.

User templates:

- Section title: `User Templates`
- Default empty row: `No saved templates yet`.
- User template rows use the same compact 28-30 px plain text row treatment as built-in templates.
- No leading icon.
- No trailing ellipsis or visible action button.
- Clicking the row applies the template after confirmation.
- Right-clicking a user template row opens a context menu:
  - `Rename`
  - `Duplicate`
  - `Export...`
  - `Delete`
- Delete should confirm before removing the template.

Template application:

- Applying any built-in or user template always clears the current overlay layout and replaces it with the chosen template.
- The UI must show a confirmation before replacing current overlays.
- Confirmation copy should make replacement explicit, e.g. `Replace current overlays with "Race"?`
- Applying a template should register an undo point through `ProjectDocument`.
- After applying, prefer clearing selection so the user sees the whole applied layout before editing individual overlays.

Footer:

- Sticky footer at the bottom of Templates Pool.
- One horizontal row:
  - Left: small square secondary import button, 32x32 px, icon-only (`tray.and.arrow.down` or `square.and.arrow.down`), help text `Import Template`.
  - Right: long blue primary button, height 32 px, label `Save Current as Template`, plus icon, fills remaining width.
- Import opens a file picker for standalone template files.
- Save is disabled when the current overlay layout has no elements, or shows a status message if disabled styling is not available.
- Saving can auto-generate a default name such as `Template 1`; a rename action can refine it afterward.

Import/export:

- Import adds a standalone template file to the local user template library. It does not apply the template automatically.
- The footer import button is the only import entry inside Templates Pool; built-in template rows and blank built-in space must not show an import context menu.
- Export is available only from a user template row context menu.
- Export writes the selected template as a standalone shareable template file.
- If imported template names collide, generate a readable copy name rather than overwriting without confirmation.

## Interaction Rules

- Single click selects a row.
- Command-click toggles selection.
- Double-click selects the row and opens transient source preview.
- Dragging a row provides the media item id to timeline drop targets.
- Right-click actions apply to all selected items if the clicked item is already selected; otherwise apply only to the clicked item.
- `Select All` acts on visible/filtered media.
- Changing filters must remove selected IDs that are no longer visible.
- Losing Media Pool focus clears transient media-pool preview.

## Recommended Components

- `PoolPanelView`
- `PoolModeSwitch`
- `MediaPoolPanel`
- `MediaPoolHeader`
- `MediaPoolToolbarButton`
- `MediaPoolSearchField`
- `MediaPoolFilterStrip`
- `MediaPoolRow`
- `MediaStatusPill`
- `MediaTagDot`
- `MediaPoolEmptyState`
- `OverlayPoolView`
- `OverlayPoolHeader`
- `OverlayCategorySwitch`
- `OverlayAddTile`
- `TemplatePoolView`
- `TemplatePoolSection`
- `TemplatePoolRow`
- `TemplatePoolFooter`
- `TemplateReplaceConfirmation`

Reuse a shared app theme where possible:

- `InspectorTheme` may become `EditorTheme` or `RunningOverlayTheme`.
- Media-specific colors should extend, not fork, the Inspector token set.

## Open Product Questions

- Should search be added now, or should it wait until media libraries become larger?
- Should `Ready` and `Aligned` filter chips be real filters or only future design placeholders?
- Should Media Pool rows show real video thumbnails, or keep icon wells for performance and simplicity?
- Should tag color be a dot, a left stripe, or both for selected rows?