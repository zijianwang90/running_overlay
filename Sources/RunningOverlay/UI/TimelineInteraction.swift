import AppKit

/// Holding C over the timeline scrubs the playhead. The key is only taken
/// while no text input has focus, so typing "c" in a field always works.
enum TimelineHoverScrubKey {
    static let keyCode: UInt16 = 8

    static func shouldConsume(keyCode: UInt16, isMouseOverTimeline: Bool, isTextInputFocused: Bool) -> Bool {
        keyCode == Self.keyCode && isMouseOverTimeline && !isTextInputFocused
    }
}

/// Delete and Forward Delete remove the timeline selection.
enum TimelineDeleteKey {
    static let deleteKeyCode: UInt16 = 51
    static let forwardDeleteKeyCode: UInt16 = 117

    static func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        (keyCode == deleteKeyCode || keyCode == forwardDeleteKeyCode)
            && modifiers.intersection([.command, .option, .control]).isEmpty
    }
}

/// Click selection with the standard macOS modifiers.
enum TimelineClipSelection {
    enum Mode: Equatable {
        /// Plain click: select only this clip.
        case replace
        /// Command-click: add or remove this clip.
        case toggle
        /// Shift-click: select the clips between the anchor and this clip on
        /// the same layer.
        case range
    }

    static func mode(for modifiers: NSEvent.ModifierFlags) -> Mode {
        if modifiers.contains(.command) { return .toggle }
        if modifiers.contains(.shift) { return .range }
        return .replace
    }

    struct Result: Equatable {
        var selection: Set<TimelineClip.ID>
        var anchor: TimelineClip.ID?
    }

    static func click(
        _ clipID: TimelineClip.ID,
        mode: Mode,
        current: Set<TimelineClip.ID>,
        anchor: TimelineClip.ID?,
        tracks: [TimelineTrack]
    ) -> Result {
        switch mode {
        case .replace:
            return Result(selection: [clipID], anchor: clipID)
        case .toggle:
            var selection = current
            if selection.remove(clipID) == nil {
                selection.insert(clipID)
                return Result(selection: selection, anchor: clipID)
            }
            return Result(selection: selection, anchor: anchor)
        case .range:
            guard let anchor,
                  let track = tracks.first(where: { $0.clips.contains { $0.id == clipID } }),
                  track.clips.contains(where: { $0.id == anchor }) else {
                return Result(selection: [clipID], anchor: clipID)
            }
            let ordered = track.clips.sorted { $0.effectiveStartTime < $1.effectiveStartTime }
            guard let from = ordered.firstIndex(where: { $0.id == anchor }),
                  let to = ordered.firstIndex(where: { $0.id == clipID }) else {
                return Result(selection: [clipID], anchor: clipID)
            }
            let range = min(from, to)...max(from, to)
            return Result(selection: Set(ordered[range].map(\.id)), anchor: anchor)
        }
    }
}

/// Header readouts.
enum TimelineHeaderText {
    /// Visible duration at the current zoom, e.g. "30 s", "2 min", "1.5 h".
    static func zoomReadout(visibleDuration: TimeInterval) -> String {
        let seconds = max(visibleDuration, 0)
        if seconds < 60 {
            return "\(max(Int(seconds.rounded()), 1)) s"
        }
        if seconds < 3600 {
            return "\(Int((seconds / 60).rounded())) min"
        }
        let hours = (seconds / 3600 * 10).rounded() / 10
        return hours == hours.rounded() ? "\(Int(hours)) h" : String(format: "%.1f h", hours)
    }

    /// "2 of 3" when some layers are excluded from the preview, else nil.
    static func previewLayerCount(trackNames: [String], disabled: Set<String>) -> String? {
        let shown = trackNames.filter { !disabled.contains($0) }.count
        guard !trackNames.isEmpty, shown < trackNames.count else { return nil }
        return "\(shown) of \(trackNames.count)"
    }
}

/// Pointer shape for a position on the timeline canvas.
enum TimelinePointer: Equatable {
    case arrow
    /// Click or drag seeks (ruler, playhead line).
    case positioning
    case openHand
    case closedHand
    /// Clips cannot move while gaps are hidden.
    case notAllowed

    enum Target: Equatable {
        case none
        case ruler
        case playhead
        case clip
    }

    static func pointer(for target: Target, isCollapsed: Bool, isDraggingClip: Bool) -> TimelinePointer {
        if isDraggingClip { return .closedHand }
        switch target {
        case .none: return .arrow
        case .ruler, .playhead: return .positioning
        case .clip: return isCollapsed ? .notAllowed : .openHand
        }
    }

    @MainActor var cursor: NSCursor {
        switch self {
        case .arrow: .arrow
        case .positioning: .resizeLeftRight
        case .openHand: .openHand
        case .closedHand: .closedHand
        case .notAllowed: .operationNotAllowed
        }
    }

    static let collapsedClipHelp = "Show gaps to move clips"
}
