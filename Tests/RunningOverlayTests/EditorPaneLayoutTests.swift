import Foundation
import Testing
@testable import RunningOverlay

struct EditorPaneLayoutTests {
    @Test func launchAtMinimumWindowWidthFitsAllPanes() {
        let layout = EditorPaneLayout(
            availableWidth: EditorPaneLayout.minimumWindowWidth,
            preferredMediaWidth: 380,
            preferredInspectorWidth: 460
        )
        #expect(layout.mediaWidth == 318)
        #expect(layout.inspectorWidth == 460)
        #expect(layout.mediaWidth + layout.inspectorWidth + 520 + 2 == 1300)
    }

    @Test(arguments: [CGFloat(1300), 1362, 1440, 1600, 1962, 2400])
    func expandedPanesAndDragLimitsFitWindow(width: CGFloat) {
        let layout = EditorPaneLayout(
            availableWidth: width,
            preferredMediaWidth: 720,
            preferredInspectorWidth: 720
        )
        #expect(layout.mediaWidth >= 300)
        #expect(layout.inspectorWidth >= 460)
        #expect(layout.mediaWidth <= 720)
        #expect(layout.inspectorWidth <= 720)
        #expect(layout.mediaWidth + layout.inspectorWidth + 520 + 2 <= width)
        #expect(layout.mediaMaxWidth + layout.inspectorWidth + 520 + 2 <= width)
        #expect(layout.inspectorMaxWidth + layout.mediaWidth + 520 + 2 <= width)
    }

    @Test func wideningRestoresPreferredPaneWidths() {
        let compact = EditorPaneLayout(
            availableWidth: 1300, preferredMediaWidth: 600, preferredInspectorWidth: 600
        )
        let expanded = EditorPaneLayout(
            availableWidth: 1800, preferredMediaWidth: 600, preferredInspectorWidth: 600
        )
        #expect(compact.mediaWidth < expanded.mediaWidth)
        #expect(compact.inspectorWidth < expanded.inspectorWidth)
        #expect(expanded.mediaWidth == 600)
        #expect(expanded.inspectorWidth == 600)
    }
}
