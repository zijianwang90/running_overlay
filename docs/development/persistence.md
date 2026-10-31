# Persistence, Undo, and Redo

### Undo And Redo

- Status: foundation implemented.

Current implementation:

- `ProjectDocument` owns a project snapshot undo/redo stack.
- Project settings persist aspect ratio separately from resolution. Older
  snapshots that contain only resolution infer their aspect ratio during
  decoding, while mismatched saved values normalize to the nearest compatible
  short-edge resolution tier.
- `Command-Z` and `Shift-Command-Z` are wired to project undo and redo.
- Delete and Forward Delete remove the selected timeline clip or overlay element.
- The AppKit timeline canvas handles Delete and Forward Delete directly when it has focus.
- The app sets a regular activation policy at launch, and timeline mouse-down activates the app and makes the timeline canvas first responder.
- Overlay add/delete, timeline clip delete, and core overlay/timeline edits register undo snapshots.
- Continuous edits use a begin/end style snapshot so drag and slider gestures can undo as a single operation.
- Imported overlay templates are normalized before entering the local library:
  name conflicts receive the next `Copy` name and template UUID conflicts are
  replaced with a fresh UUID so SwiftUI list identity, apply, rename, duplicate,
  export, and delete actions always target one row.
- OpenWeather credentials use macOS Keychain in bundled app builds. Local
  `swift run RunningOverlay` launches, which do not have an app bundle
  identifier, use an in-memory credential store to avoid development Keychain
  access prompts. Developers can also force the in-memory store with
  `RUNNING_OVERLAY_DISABLE_KEYCHAIN=1`.

### Project Files

- Status: implemented (ADR 0006).
- `ProjectFileFormat` encodes and decodes `.roproj` files. It reads
  `schemaVersion` first and refuses files newer than
  `ProjectFileFormat.currentSchemaVersion`. Additive fields must be optional
  so older files still decode; bump the version only for changes an older
  build cannot read correctly.
- `ProjectDocument.writeProject(to:)` and `loadProject(from:)` are the
  UI-free entry points used by tests. `saveProject()`, `saveProjectAs()`,
  `openProject()`, `openRecentProject(path:)`, and `newProject()` wrap them
  with panels and alerts.
- `hasUnsavedChanges` is set by `registerUndoPoint()`,
  `registerContinuousUndoPoint()`, `undo()`, `redo()`, and the preview-track
  setters, which are the only persistent mutations that skip undo. A new
  persistent mutation that does not register an undo point must set it
  explicitly. While it is true the app disables sudden and automatic
  termination.
- Saving writes a bookmark per media file (`FileBookmark`): security-scoped in
  the sandboxed app, plain otherwise. Opening resolves each bookmark, starts
  security-scoped access for the lifetime of the project, and reports media
  whose files are missing. Open Recent stores bookmarks for project files in
  user defaults (`RecentProjectStore`).
- Opening, New Project, and Debug snapshot restore reset undo history.

### Autosave And Crash Recovery

- `AutosaveStore` keeps one recovery copy (`Recovery.roproj` plus
  `Recovery.json` with the save time and the original project's path and
  bookmark) under Application Support. Tests inject a temporary directory.
- `startAutosaving()` (called at app launch) triggers `autosaveIfNeeded()`
  every 30 seconds and on `NSApplication.willResignActiveNotification`. It
  writes only when `hasUnsavedChanges` is true and `editGeneration` changed
  since the last copy; every `markEdited()` call advances the generation.
- The snapshot is taken on the main actor, then compact JSON is encoded and
  written in a detached utility task. A 5-hour, 1 Hz activity encodes to about
  8 MB in about 120 ms (release build), which is too long to block the main
  thread. A counter that advances whenever the copy is removed lets an
  in-flight autosave detect a save, open, or reset that happened while it was
  writing and discard its now-stale copy.
- `writeProject`, `loadProject`, `resetToNewProject`, and app termination
  after Save or Don't Save remove the copy. Recovery
  (`recoverAutosavedProject()`) keeps it until the work is saved or
  discarded.
- `offerAutosaveRecoveryIfNeeded()` runs once per launch: when the editor
  window appears, or earlier if Finder hands over a project to open.

Pending:

- Broader coverage audit for every future project mutation.
- More granular labels for undo menu item names.
- Carrying custom SVG and font assets inside project files.
