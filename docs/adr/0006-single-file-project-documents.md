# ADR 0006: Single-File Project Documents With Media Bookmarks

Date: 2026-10-26

## Status

Accepted

## Context

Users had no supported way to save and reopen a project; the only persistence
was a Debug-only snapshot in the Export dialog. ADR 0005 deliberately shipped
overlay templates first. The editor is a single window owned by one
app-level `ProjectDocument`, and the App Store build runs in the App Sandbox
with user-selected file access only, so file URLs stored in a project stop
being readable after relaunch.

## Decision

- Save projects as single `.roproj` files containing the versioned JSON
  encoding of `ProjectPerformanceSnapshot`, declared as the exported type
  `io.github.zijianwang90.runningoverlay.project` conforming to
  `public.json`.
- Keep the single-window editor and implement Save, Save As, Open, Open
  Recent, New, and unsaved-changes prompts in `ProjectDocument` and an app
  delegate instead of adopting `NSDocument` or `DocumentGroup`.
- Store a security-scoped bookmark for every media file and for every Open
  Recent entry, using the `com.apple.security.files.bookmarks.app-scope`
  entitlement.
- Store the parsed activity in the project, so reopening never needs the
  original FIT or GPX file.
- Reject files whose `schemaVersion` is newer than the app supports. New
  fields stay optional so older files keep decoding.

## Consequences

Benefits:

- One shared schema for project files, Debug snapshots, and the headless
  export benchmark.
- Reopened projects regain media access in the sandbox and follow moved or
  renamed files.
- No refactor of the app-wide `ProjectDocument` ownership model.

Costs:

- No system autosave, Versions browsing, or multiple open projects; autosave
  and crash recovery must be built separately.
- Projects embed absolute media paths and bookmarks, so they are private data
  and are not portable across Macs without relinking.
- Custom SVG and font assets live in the local asset store and are not yet
  carried inside project files.
- Unsaved-changes tracking depends on mutations registering undo points or
  setting the flag explicitly.
