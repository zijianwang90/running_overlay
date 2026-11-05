import AppKit

/// Escape clears the editor selection, which returns the Inspector to the
/// overlay list.
///
/// A SwiftUI `onKeyPress` only sees keys while a SwiftUI view holds focus.
/// Selecting an overlay on the canvas or in the Inspector list does not move
/// keyboard focus, so Escape is watched at the window instead.
enum EditorEscapeKey {
    static let keyCode: UInt16 = 53

    static func shouldClearSelection(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        hasSelection: Bool,
        isTextInputFocused: Bool,
        hasAttachedSheet: Bool
    ) -> Bool {
        keyCode == Self.keyCode
            && modifiers.intersection([.command, .option, .control, .shift]).isEmpty
            && hasSelection
            && !isTextInputFocused
            && !hasAttachedSheet
    }

    /// Text fields own Escape (cancel editing), so it must not deselect.
    @MainActor static func isTextInput(_ responder: NSResponder?) -> Bool {
        guard let responder else { return false }
        if let textView = responder as? NSTextView, textView.isEditable {
            return true
        }
        return responder is NSTextField
    }
}

/// Carries an event from AppKit's non-isolated monitor block onto the main
/// actor. Safe because the block already runs on the main thread and the value
/// never escapes that call.
private struct EscapeMonitorEvent: @unchecked Sendable {
    let event: NSEvent
}

@MainActor
final class EditorEscapeKeyMonitor {
    static let shared = EditorEscapeKeyMonitor()

    private weak var window: NSWindow?
    private weak var project: ProjectDocument?
    private var monitor: Any?

    func install(on window: NSWindow, project: ProjectDocument) {
        self.window = window
        self.project = project
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let boxedEvent = EscapeMonitorEvent(event: event)
            let handled = MainActor.assumeIsolated {
                EditorEscapeKeyMonitor.shared.handle(boxedEvent.event)
            }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let window, let project, event.window === window else { return false }
        guard EditorEscapeKey.shouldClearSelection(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            hasSelection: project.selection != .none,
            isTextInputFocused: EditorEscapeKey.isTextInput(window.firstResponder),
            hasAttachedSheet: window.attachedSheet != nil
        ) else { return false }
        project.clearSelection()
        return true
    }
}
