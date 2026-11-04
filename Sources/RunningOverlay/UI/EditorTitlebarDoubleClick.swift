import AppKit

/// The action macOS performs when the user double-clicks a window's title bar,
/// plus the hit-testing rules for deciding when such a double-click belongs to
/// the title bar rather than to a toolbar control.
enum EditorTitlebarDoubleClick {
    enum Action: Equatable {
        case zoom
        case minimize
        case none
    }

    /// Mirrors System Settings > Desktop & Dock > "Double-click a window's
    /// title bar to" (`AppleActionOnDoubleClick`), including the legacy
    /// minimize preference.
    static func systemAction(from defaults: UserDefaults = .standard) -> Action {
        action(
            rawValue: defaults.string(forKey: "AppleActionOnDoubleClick"),
            legacyMinimizes: defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick")
        )
    }

    static func action(rawValue: String?, legacyMinimizes: Bool) -> Action {
        if let rawValue {
            switch rawValue.lowercased() {
            case "maximize", "zoom":
                return .zoom
            case "minimize":
                return .minimize
            case "none":
                return .none
            default:
                return .zoom
            }
        }
        return legacyMinimizes ? .minimize : .zoom
    }

    /// The top strip of the window that AppKit treats as title bar and toolbar.
    /// `locationInWindow` and the window frame share a bottom-left origin and
    /// the same height.
    static func pointIsInTitlebar(
        _ point: NSPoint,
        windowHeight: CGFloat,
        titlebarHeight: CGFloat
    ) -> Bool {
        guard titlebarHeight > 0, windowHeight > 0 else { return false }
        return point.y >= windowHeight - titlebarHeight && point.y <= windowHeight
    }

    /// Whether the view is, or sits inside, a control the user can interact
    /// with. A double-click there belongs to the control, not the title bar.
    @MainActor
    static func isInteractiveControl(_ view: NSView) -> Bool {
        var candidate: NSView? = view
        while let current = candidate {
            if current is NSControl || current is NSTextView {
                return true
            }
            candidate = current.superview
        }
        return false
    }
}

/// Carries an event from AppKit's non-isolated monitor block onto the main
/// actor. Safe because the block already runs on the main thread and the value
/// never escapes that call.
private struct MonitorEvent: @unchecked Sendable {
    let event: NSEvent
}

/// Restores the standard title bar double-click action for the editor window.
///
/// A custom window-toolbar background makes SwiftUI host its own bar background
/// and mark the title bar transparent. AppKit then skips the native title bar
/// double-click action, so the bar can be dragged but not double-clicked to
/// zoom or restore. This performs the system-preferred action itself, without
/// touching window dragging or toolbar controls.
@MainActor
final class EditorTitlebarDoubleClickGuard {
    static let shared = EditorTitlebarDoubleClickGuard()

    private weak var window: NSWindow?
    private var monitor: Any?

    func install(on window: NSWindow) {
        self.window = window
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            // AppKit delivers monitor events on the main thread, but the
            // monitor block is not actor-isolated.
            let boxedEvent = MonitorEvent(event: event)
            let handled = MainActor.assumeIsolated {
                EditorTitlebarDoubleClickGuard.shared.handle(boxedEvent.event)
            }
            return handled ? nil : event
        }
    }

    /// Returns whether the double-click was consumed by the title bar action.
    private func handle(_ event: NSEvent) -> Bool {
        guard let window,
              event.window === window,
              event.clickCount == 2,
              !window.styleMask.contains(.fullScreen),
              let themeFrame = window.contentView?.superview,
              let hitView = themeFrame.hitTest(event.locationInWindow)
        else { return false }

        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        guard EditorTitlebarDoubleClick.pointIsInTitlebar(
            event.locationInWindow,
            windowHeight: window.frame.height,
            titlebarHeight: titlebarHeight
        ), !EditorTitlebarDoubleClick.isInteractiveControl(hitView) else {
            return false
        }

        switch EditorTitlebarDoubleClick.systemAction() {
        case .zoom:
            guard window.isResizable else { return false }
            window.performZoom(nil)
        case .minimize:
            guard window.isMiniaturizable else { return false }
            window.performMiniaturize(nil)
        case .none:
            return false
        }
        return true
    }
}
