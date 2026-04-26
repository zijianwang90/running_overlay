import AppKit
import SwiftUI

struct SplitCursorRegion: NSViewRepresentable {
    var cursor: NSCursor

    func makeNSView(context: Context) -> SplitCursorNSView {
        SplitCursorNSView(cursor: cursor)
    }

    func updateNSView(_ nsView: SplitCursorNSView, context: Context) {
        nsView.cursor = cursor
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

final class SplitCursorNSView: NSView {
    var cursor: NSCursor

    init(cursor: NSCursor) {
        self.cursor = cursor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func splitResizeCursor(_ cursor: NSCursor, edge: Edge, thickness: CGFloat = 8) -> some View {
        overlay(alignment: alignment(for: edge)) {
            SplitCursorRegion(cursor: cursor)
                .frame(
                    width: edge == .leading || edge == .trailing ? thickness : nil,
                    height: edge == .top || edge == .bottom ? thickness : nil
                )
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .top:
            return .top
        case .leading:
            return .leading
        case .bottom:
            return .bottom
        case .trailing:
            return .trailing
        }
    }
}
