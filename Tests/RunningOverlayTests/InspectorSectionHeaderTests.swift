import SwiftUI
import Testing
@testable import RunningOverlay

/// Layout checks for the shared collapsible Inspector section shells.
///
/// These render with `ImageRenderer` and never create a window, a hosting view, a
/// run loop, or synthetic events, so they run on a headless CI runner. Keyboard focus,
/// Space activation, pointer clicks, and VoiceOver announcements need a live window
/// server and an accessibility client; they are verified by hand (see the Accessibility
/// section of `docs/design/panels/inspector/inspector-ui.md`).
@MainActor
struct InspectorSectionHeaderTests {
    private static let bodyHeight: CGFloat = 100
    private static let width: CGFloat = 320

    enum Shell: CaseIterable, Sendable {
        case layout, effects, border, background, statsBar
    }

    @Test(arguments: Shell.allCases)
    func collapsedShellIsExactlyOneHeaderRowTall(_ shell: Shell) throws {
        let collapsed = try #require(height(of: shell, isExpanded: false))
        #expect(collapsed == Int(NumericTokens.sectionHeaderHeight))
    }

    @Test(arguments: Shell.allCases)
    func expandedStateAddsTheSectionBodyBelowTheSameHeader(_ shell: Shell) throws {
        let collapsed = try #require(height(of: shell, isExpanded: false))
        let expanded = try #require(height(of: shell, isExpanded: true))
        #expect(expanded == collapsed + Int(Self.bodyHeight))
    }

    // MARK: Helpers

    private func height(of shell: Shell, isExpanded: Bool) -> Int? {
        let renderer = ImageRenderer(
            content: view(for: shell, isExpanded: isExpanded)
                .frame(width: Self.width)
                .fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = 1
        return renderer.cgImage?.height
    }

    private func view(for shell: Shell, isExpanded: Bool) -> AnyView {
        let expanded = Binding<Bool>.constant(isExpanded)
        let sectionBody = Color.red.frame(height: Self.bodyHeight)
        switch shell {
        case .layout:
            return AnyView(CollapsibleLayoutInspectorSection(isExpanded: expanded) { sectionBody })
        case .effects:
            return AnyView(CollapsibleEffectsInspectorSection(isExpanded: expanded) { sectionBody })
        case .border:
            return AnyView(CollapsibleBorderInspectorSection(isExpanded: expanded, isOn: true, onSetEnabled: { _ in }) { sectionBody })
        case .background:
            return AnyView(CollapsibleBackgroundInspectorSection(isExpanded: expanded, isOn: true, onSetEnabled: { _ in }) { sectionBody })
        case .statsBar:
            return AnyView(CollapsibleStatsBarInspectorSection(
                isExpanded: expanded,
                title: "Stats Bar",
                systemImage: "chart.bar",
                isBarEnabled: true,
                onSetBarEnabled: { _ in }
            ) { sectionBody })
        }
    }
}
