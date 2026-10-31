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

    @Test func hiddenPanesTakeNoWidthAndFreeSpaceForTheOtherPane() {
        let noInspector = EditorPaneLayout(
            availableWidth: 1000, preferredMediaWidth: 380, preferredInspectorWidth: 460,
            showsMedia: true, showsInspector: false
        )
        #expect(noInspector.inspectorWidth == 0)
        #expect(noInspector.mediaWidth == 380)
        #expect(noInspector.mediaMaxWidth == CGFloat(1000 - 520 - 1))

        let noMedia = EditorPaneLayout(
            availableWidth: 1000, preferredMediaWidth: 380, preferredInspectorWidth: 460,
            showsMedia: false, showsInspector: true
        )
        #expect(noMedia.mediaWidth == 0)
        #expect(noMedia.inspectorWidth == 460)

        let previewOnly = EditorPaneLayout(
            availableWidth: 600, preferredMediaWidth: 380, preferredInspectorWidth: 460,
            showsMedia: false, showsInspector: false
        )
        #expect(previewOnly.mediaWidth == 0)
        #expect(previewOnly.inspectorWidth == 0)
    }

    @Test func minimumWindowWidthFollowsVisiblePanes() {
        #expect(EditorPaneLayout.minimumWindowWidth(showsMedia: true, showsInspector: true) == EditorPaneLayout.minimumWindowWidth)
        #expect(EditorPaneLayout.minimumWindowWidth(showsMedia: true, showsInspector: false) == CGFloat(520 + 300 + 1))
        #expect(EditorPaneLayout.minimumWindowWidth(showsMedia: false, showsInspector: true) == CGFloat(520 + 460 + 1))
        #expect(EditorPaneLayout.minimumWindowWidth(showsMedia: false, showsInspector: false) == 520)
    }

    @Test(arguments: [(true, false), (false, true), (false, false)])
    func visiblePanesFitTheirMinimumWindow(showsMedia: Bool, showsInspector: Bool) {
        let width = EditorPaneLayout.minimumWindowWidth(showsMedia: showsMedia, showsInspector: showsInspector)
        let layout = EditorPaneLayout(
            availableWidth: width, preferredMediaWidth: 720, preferredInspectorWidth: 720,
            showsMedia: showsMedia, showsInspector: showsInspector
        )
        let dividers = CGFloat((showsMedia ? 1 : 0) + (showsInspector ? 1 : 0))
        #expect(layout.mediaWidth + layout.inspectorWidth + 520 + dividers <= width)
    }
}
