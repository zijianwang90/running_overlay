import AppKit
import SwiftUI
import Testing
@testable import RunningOverlay

/// Collapsible Inspector section headers are real buttons so keyboard and VoiceOver
/// can reach them. Their pointer behaviour must stay as it was: one click anywhere on
/// the header row (except an accessory toggle) flips the section exactly once.
@MainActor
struct InspectorSectionHeaderTests {
    private final class SectionState {
        var isExpanded = true
        var isEnabled = false
    }

    private struct LayoutHarness: View {
        let state: SectionState
        @State private var isExpanded = true
        var body: some View {
            CollapsibleLayoutInspectorSection(isExpanded: $isExpanded) {
                Text("Layout body row")
            }
            .onChange(of: isExpanded) { _, newValue in state.isExpanded = newValue }
        }
    }

    private struct BorderHarness: View {
        let state: SectionState
        @State private var isExpanded = true
        @State private var isOn = false
        var body: some View {
            CollapsibleBorderInspectorSection(isExpanded: $isExpanded, isOn: isOn, onSetEnabled: { isOn = $0; state.isEnabled = $0 }) {
                Text("Border body row")
            }
            .onChange(of: isExpanded) { _, newValue in state.isExpanded = newValue }
        }
    }

    @Test func buttonHeaderTogglesOncePerClickAnywhereOnTheRow() {
        let state = SectionState()
        let window = hostingWindow(LayoutHarness(state: state))

        click(window, x: 60)
        #expect(state.isExpanded == false)
        click(window, x: 160)
        #expect(state.isExpanded == true)
        click(window, x: 310)
        #expect(state.isExpanded == false)
    }

    @Test func headerWithAccessoryTogglesOncePerClickAndLeavesTheSwitchAlone() {
        let state = SectionState()
        let window = hostingWindow(BorderHarness(state: state))

        // Title area (inside the header Button) and the chevron (pointer-only fallback target).
        click(window, x: 60)
        #expect(state.isExpanded == false)
        click(window, x: 310)
        #expect(state.isExpanded == true)
        #expect(state.isEnabled == false)
    }

    @Test func accessoryToggleStaysIndependentOfTheHeaderButton() {
        let state = SectionState()
        let window = hostingWindow(BorderHarness(state: state))

        // The mini switch sits left of the chevron; clicking it must not collapse the section.
        click(window, x: 280)
        #expect(state.isEnabled == true)
        #expect(state.isExpanded == true)
    }

    // MARK: Helpers

    private func hostingWindow<V: View>(_ view: V) -> NSWindow {
        let host = NSHostingView(rootView: view.frame(width: 340, height: 300, alignment: .top))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 340, height: 300)
        window.orderFrontRegardless()
        pump(host)
        return window
    }

    private func pump(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        view.layoutSubtreeIfNeeded()
    }

    /// Clicks at `x` within the section header (window origin is bottom-left).
    private func click(_ window: NSWindow, x: CGFloat) {
        let point = NSPoint(x: x, y: window.frame.height - NumericTokens.sectionHeaderHeight / 2)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: type == .leftMouseDown ? 1 : 0
            )
            if let event { window.sendEvent(event) }
        }
        if let content = window.contentView { pump(content) }
    }
}
