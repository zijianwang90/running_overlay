# Media Pool UI Design Spec

Last updated: 2026-11-05

## Purpose

The left-side pool panel is the source library area for project inputs, addable overlay modules, and reusable overlay layout templates. It contains three sibling modes:

- `Media Pool`: imported video files and the activity-first media import workflow.
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
- Compact rows with clear filename, duration, capture time, and an alignment status symbol.
- Selected rows follow macOS list rules: the system selection color while the list has keyboard focus, the gray unemphasized selection color otherwise. See [Media Pool HIG review](media-pool-hig-review.md).
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
| `media.rowHover`            | `NSColor.quaternarySystemFill` | Hover row                |
| `media.rowSelected`         | `NSColor.selectedContentBackgroundColor` | Selected row, list focused |
| `media.rowSelectedUnfocused` | `NSColor.unemphasizedSelectedContentBackgroundColor` | Selected row, list not focused |
| `media.focusRing`           | `NSColor.keyboardFocusIndicatorColor` | List focus ring |
| `media.menuBackground`      | `#1D2228`   | Context menu                            |
| `media.menuHover`           | `#2F8CFF`   | Active menu item                        |
| `media.thumbnailBackground` | `NSColor.underPageBackgroundColor` | Thumbnail/file icon well |
| `row.height`                | `68-76 px`  | Default media row height                |
| `thumbnail.size`            | `42x42 px`  | Optional thumbnail/icon well            |
| `toolbar.iconButton`        | `30x30 px`  | Header actions                          |
| `search.height`             | `30 px`     | Search/filter field                     |
| `pool.switchHeight`         | `32 px`     | Media/Overlay pool segmented switch     |
| `pool.switchRadius`         | `8 px max`  | Mode switch container and selected item |
| `overlay.tileHeight`        | `56-64 px`  | Overlay Pool add tiles                  |
| `overlay.categoryHeight`    | `24 px`     | Metrics/Charts/Route segmented control  |
| `template.rowHeight`        | `28-30 px`  | Templates Pool row height               |
| `template.footerHeight`     | `44 px`     | Templates Pool sticky footer, matching Preview playback bar |
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

- Drag/drop video import, refused before an activity exists.
- Click, Shift-click and Command-click selection of clips and folders.
- Command+A selects all visible clips when the Media Pool list has focus.
- Double-click previews a media-pool source item, or toggles a folder.
- Keyboard navigation (see Interaction Rules).
- Context menu actions (see Context Menu).
- Status filter (`All` / `Ready` / `Aligned`) and name search.
- Alternating row backgrounds.
- Focus loss clears transient media-pool preview.

Selection model: `MediaPoolSelection` (`Sources/RunningOverlay/UI/MediaPoolSelection.swift`)
holds the outline-view rules and is unit tested in `MediaPoolSelectionTests`.

## Layout

Top to bottom:

1. Unified window toolbar: compact pool mode switch beside the window controls
2. Active pool header
3. Active pool controls
4. Active pool content
5. Empty states when needed

Recommended panel width: 300-380 px. The mockup is square for design transfer only.

## Pool Mode Switch

The unified window toolbar starts with a compact three-option switch after the window controls:

- `Media Pool`
- `Overlay Pool`
- `Templates`

Visual rules:

- Keep it in the window toolbar, above the Media/Preview/Inspector panel headers. It replaces global FIT/Videos import buttons as the primary entry point into media and overlay resources.
- Use the short visible labels `Media`, `Overlays`, and `Templates` so none truncate in the titlebar. Keep the full pool names in help and accessibility labels.
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
- Render `PoolModeSwitch` in the native window toolbar with a width derived from `mediaPoolWidth`.
- Render `MediaBrowserView` for `.media`.
- Render `OverlayPoolView` for `.overlay`.
- Render `TemplatePoolView` for `.templates`.
- Pass the active pool binding into `PoolPanelView`.
- Keep the existing horizontal resize handle and width state in `MainEditorView`.

## Header Bar

Content:

- Left title: `Media`, followed by the visible clip count (`6 clips`) once media exists.
- Right toolbar icon buttons:
  - `folder.badge.plus`: New Folder (with the selected clips, if any).
  - `plus`: Import Videos. Disabled until an activity is imported.
- Select All and Clear Selection are not buttons: use ⌘A, Esc, or click empty space.

Icon guidance:

- Use system symbols in SwiftUI if lucide is not available.
- Keep icon-only actions at 30x30 px.
- Add `.help(...)` and accessibility labels for every icon-only button.
- Disabled buttons should use muted foreground and no hover fill.

## Search And Filter Strip

- System search field (`NSSearchField`, small), placeholder `Search`. It filters
  `displayName`. ⌘F focuses it; Esc and the cancel button clear it.
- Status filter: a small segmented control with `All`, `Ready` (clock) and
  `Aligned` (checkmark circle). The symbols match the row status symbols.
  `All` is selected by default.
- Activity status row, when an activity is loaded: a green checkmark, the
  activity file name and workout summary, a small Workout type pop-up
  (`Picker(.menu)`, with the up/down indicator), and a `⋯` menu containing
  `Replace Activity…`. This is the only Workout type control in the panel.

## Media Rows

Each row contains:

- Optional thumbnail/file icon well on the left.
- Optional mark dot or mark strip.
- Primary filename.
- Secondary duration.
- Secondary capture date/time.
- Right-side alignment status symbol plus color, so status reads without color:
  `checkmark.circle.fill` green (aligned), `clock` yellow (ready to match),
  `questionmark.circle` gray (needs manual placement). Hovering shows the status
  help text, which is also the accessibility label.
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
- Hover: `media.rowHover`.
- Selected, list focused: `media.rowSelected` with white text and symbols, and a
  focus ring around the list.
- Selected, list not focused (or window inactive): `media.rowSelectedUnfocused`
  with normal text colors.
- Multi-selected: same selected style per row.
- Source-previewed item may use an additional play indicator if needed, but do not confuse it with selection.

Text:

- Filename: 13 px semibold, primary text.
- Metadata: 11-12 px regular, secondary text, monospaced digits: duration as
  `4:12` (`1:02:05` past an hour, matching the Timeline) and start time without
  seconds (`8:39 AM`). The full date and time is in the row's help tag.
- Alignment status symbol: 12 pt in an 18 pt hover target.

Folder rows:

- Disclosure triangle, fixed `folder` symbol (it does not change with expansion),
  name, and clip count.
- A click selects the folder. The triangle, ←/→, or a double-click expands and
  collapses it.

## Context Menu

Menus show only commands that apply to the clicked row. When the clicked row
is part of the selection, the commands act on the whole selection and the first
item names the count (`Auto Match 2 Clips to Current Layer`).

Clip rows:

1. `Auto Match to Current Layer`, `Match to New Layer`, `Match to Layer ▸`
2. `Show in Finder` (⇧⌘R), `Move to Folder ▸`, `Move to Root` (when any clip is in a folder)
3. `Delete from Media Pool` (⌘⌫)

Folder rows:

1. The match commands, acting on the folder's clips (omitted for an empty folder)
2. `Rename`, `New Folder`
3. `Delete Folder, Keep Clips` and `Delete Folder and N Clips` (⌘⌫)

Empty space: `Import Videos…`, `New Folder`, `Select All`.

Delete is undoable, so it is not red and has no confirmation.

The `Mark` submenu below is not implemented.

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
- Title: `Import Activity`
- Secondary text: `Start with running activity data`
- Primary action: `Import Activity`
- Step indicator: plain text with symbols, `① Activity · ② Videos`; not a control.
- Secondary disabled or muted hint: `Then import videos`
- Use a subtle dashed rounded rectangle drop zone boundary, but do not imply video drop is ready before activity import.
- Dragging a video here is refused while the pointer moves (no `+` cursor), and the
  copy changes to `Import an Activity First` / `Videos are matched to a FIT or GPX activity.`
  No error is shown after the drop.

Activity imported, no media:

- Center icon: `video.badge.plus`
- Text: `Drop videos here`
- Secondary text: `Import clips to match them with your running activity`
- Primary action: `Import Videos`
- Optional format hint: `MP4, MOV`
- Step indicator: `✓ Activity · ② Videos`.
- The dashed drop zone turns accent-colored and the title reads `Release to Import` while a file is dragged over it.
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

- Overlay Pool should remain available before activity import. Layout work is valid without activity data.
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

- `Templates` is the third window-toolbar pool mode beside `Media` and `Overlays`.
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
- Clicking the row applies the template immediately when no overlays exist, or after confirmation when replacing existing overlays.
- Built-in rows do not expose rename, duplicate, export, or delete actions.

Initial built-in template contents:

- `Easy Run`: bundled from `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`.
- `Interval Workout`: bundled from `Sources/RunningOverlay/Resources/Templates/IntervalWorkout.rotemplate`.
- `Race`: bundled from `Sources/RunningOverlay/Resources/Templates/Race.rotemplate`.

User templates:

- Section title: `User Templates`
- Default empty row: `No saved templates yet`.
- User template rows use the same compact 28-30 px plain text row treatment as built-in templates.
- No leading icon.
- No trailing ellipsis or visible action button.
- Clicking the row applies the template immediately when no overlays exist, or after confirmation when replacing existing overlays.
- Right-clicking a user template row opens a context menu:
  - `Rename`
  - `Duplicate`
  - `Update Template`
  - `Export...`
  - `Delete`
- Update Template should confirm before overwriting the saved template with the current overlay setup.
- Delete should confirm before removing the template.

Template application:

- Applying any built-in or user template clears the current overlay layout and replaces it with the chosen template.
- The UI must show a confirmation before replacing current overlays; if the current overlay layout is empty, apply the template directly without showing a replacement confirmation.
- Confirmation copy should make replacement explicit, e.g. `Replace current overlays with "Race"?`
- Applying a template should register an undo point through `ProjectDocument`.
- After applying, prefer clearing selection so the user sees the whole applied layout before editing individual overlays.

Footer:

- Sticky footer at the bottom of Templates Pool.
- Footer height matches the Preview bottom playback bar height.
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

- Single click selects a clip or folder row. Shift-click extends from the anchor; Command-click toggles.
- Double-click on a clip selects it and opens transient source preview; on a folder it toggles expansion.
- Dragging a row provides the media item id to timeline drop targets.
- Right-click actions apply to all selected items if the clicked item is already selected; otherwise apply only to the clicked item.
- Keyboard, while the list has focus:
  - ↑/↓ move the selection; Shift+↑/↓ extend it.
  - ← collapses an expanded folder or selects a clip's folder; → expands a folder.
  - Return renames the selected folder.
  - ⌘⌫ (and ⌫, ⌦) delete the selection as one undo step. A selected folder is deleted with its clips.
  - ⌘A selects all visible clips (not folders). Esc clears the selection.
  - ⇧⌘R shows the selected clips in Finder.
- Collapsing a folder moves selection from its hidden clips onto the folder and keeps the rest of the selection.
- Changing filters must remove selected rows that are no longer visible.
- Media Pool selection and the editor selection are exclusive: selecting media clears `ProjectDocument.selection`; selecting an overlay or clip clears the selected media rows and takes keyboard focus away from the list.
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

- Should Media Pool rows show real video thumbnails, or keep icon wells for performance and simplicity?
- Should tag color be a dot, a left stripe, or both for selected rows?
