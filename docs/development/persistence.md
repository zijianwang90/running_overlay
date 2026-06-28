# Persistence, Undo, and Redo

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
