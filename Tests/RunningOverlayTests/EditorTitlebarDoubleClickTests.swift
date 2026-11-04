import AppKit
import Testing
@testable import RunningOverlay

struct EditorTitlebarDoubleClickTests {
    @Test func unsetPreferenceZooms() {
        #expect(EditorTitlebarDoubleClick.action(rawValue: nil, legacyMinimizes: false) == .zoom)
    }

    @Test(arguments: [
        ("Maximize", false, EditorTitlebarDoubleClick.Action.zoom),
        ("maximize", false, .zoom),
        ("Zoom", false, .zoom),
        ("Minimize", false, .minimize),
        ("None", false, .none),
        ("Maximize", true, .zoom),
    ])
    func preferenceMapsToAction(
        rawValue: String?,
        legacyMinimizes: Bool,
        expected: EditorTitlebarDoubleClick.Action
    ) {
        #expect(
            EditorTitlebarDoubleClick.action(
                rawValue: rawValue, legacyMinimizes: legacyMinimizes
            ) == expected
        )
    }

    @Test func legacyMinimizePreferenceIsHonored() {
        #expect(EditorTitlebarDoubleClick.action(rawValue: nil, legacyMinimizes: true) == .minimize)
    }

    @Test func unknownPreferenceFallsBackToZoom() {
        #expect(EditorTitlebarDoubleClick.action(rawValue: "Something Else", legacyMinimizes: false) == .zoom)
    }

    @Test func titlebarRegionCoversToolbarButNotContent() {
        #expect(EditorTitlebarDoubleClick.pointIsInTitlebar(
            NSPoint(x: 200, y: 800), windowHeight: 825, titlebarHeight: 38
        ))
        #expect(EditorTitlebarDoubleClick.pointIsInTitlebar(
            NSPoint(x: 200, y: 787), windowHeight: 825, titlebarHeight: 38
        ))
        #expect(!EditorTitlebarDoubleClick.pointIsInTitlebar(
            NSPoint(x: 200, y: 786), windowHeight: 825, titlebarHeight: 38
        ))
    }

    @Test func missingTitlebarHasNoDoubleClickRegion() {
        #expect(!EditorTitlebarDoubleClick.pointIsInTitlebar(
            NSPoint(x: 200, y: 500), windowHeight: 825, titlebarHeight: 0
        ))
    }

    @MainActor
    @Test func toolbarControlsAreExcludedFromTitlebarDoubleClicks() {
        let container = NSView()
        let button = NSButton()
        let segmented = NSSegmentedControl()
        let field = NSTextField()
        let background = NSView()
        container.addSubview(button)
        container.addSubview(segmented)
        container.addSubview(field)
        container.addSubview(background)

        #expect(EditorTitlebarDoubleClick.isInteractiveControl(button))
        #expect(EditorTitlebarDoubleClick.isInteractiveControl(segmented))
        #expect(EditorTitlebarDoubleClick.isInteractiveControl(field))
        #expect(!EditorTitlebarDoubleClick.isInteractiveControl(background))
    }

    @MainActor
    @Test func controlsNestedInTheBarBackgroundAreExcluded() {
        let barBackground = NSView()
        let host = NSView()
        let button = NSButton()
        barBackground.addSubview(host)
        host.addSubview(button)

        #expect(EditorTitlebarDoubleClick.isInteractiveControl(button))
        #expect(!EditorTitlebarDoubleClick.isInteractiveControl(host))
        #expect(!EditorTitlebarDoubleClick.isInteractiveControl(barBackground))
    }
}
