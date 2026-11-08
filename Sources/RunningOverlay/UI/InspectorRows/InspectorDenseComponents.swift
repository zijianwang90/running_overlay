import SwiftUI
import AppKit

struct InspectorDenseRow<Trailing: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    var label: String
    var minHeight: CGFloat = NumericTokens.rowHeight
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: NumericTokens.space3) {
            Text(label)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(isEnabled ? NumericTokens.textSecondary : NumericTokens.textDisabled)
                .frame(width: NumericTokens.labelColumnWidth, alignment: .leading)
            HStack(spacing: NumericTokens.space2) {
                trailing
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(minHeight: minHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }
}

struct InspectorDenseReadout: View {
    var text: String
    var isNumeric = false

    var body: some View {
        Text(text)
            .font(isNumeric ? NumericTokens.numericFont : NumericTokens.bodyFont)
            .foregroundStyle(NumericTokens.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
    }
}

/// Label for an Inspector `Menu`. Apply `inspectorMenuStyle()` to the menu so
/// the system indicator is hidden and this label draws the HIG one: a pop-up
/// (choose one value) shows up/down chevrons, a pull-down (run a command)
/// shows a single down chevron.
struct InspectorDenseMenuLabel: View {
    enum Kind {
        case popUp
        case pullDown
    }

    @Environment(\.isEnabled) private var isEnvironmentEnabled
    var systemImage: String?
    var title: String
    var isEnabled: Bool = true
    var kind: Kind = .popUp

    var body: some View {
        let enabled = isEnabled && isEnvironmentEnabled
        HStack(spacing: NumericTokens.space2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(enabled ? NumericTokens.textSecondary : NumericTokens.textDisabled)
            }
            Text(title)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(enabled ? NumericTokens.textPrimary : NumericTokens.textDisabled)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: kind == .popUp ? "chevron.up.chevron.down" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(enabled ? NumericTokens.textSecondary : NumericTokens.textDisabled)
        }
        .padding(.horizontal, NumericTokens.space2)
        .frame(maxWidth: .infinity)
        .frame(height: NumericTokens.controlHeight)
        .background(NumericTokens.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
    }
}

extension View {
    /// Pairs with `InspectorDenseMenuLabel`, which draws its own indicator.
    func inspectorMenuStyle() -> some View {
        menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
    }
}

struct InspectorDenseSliderRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var displayText: String
    var isEnabled: Bool = true

    var body: some View {
        InspectorDenseRow(label: label) {
            Slider(value: $value, in: range, onEditingChanged: { editing in
                if !editing { project.finishContinuousEdit() }
            })
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
            .accessibilityValue(displayText)
            InspectorDenseValueField(label: label, value: $value, range: range, displayText: displayText)
        }
        .disabled(!isEnabled)
    }
}

/// Editable readout beside an Inspector slider. Shows the caller's formatted
/// text and accepts a typed value in the same display units, committed on
/// Return or when focus leaves. Escape cancels the edit.
struct InspectorDenseValueField: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.isEnabled) private var isEnabled
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var displayText: String

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    /// Set by a commit so the next readout replaces the draft even while the
    /// field keeps focus after Return.
    @State private var syncsNextReadout = false

    var body: some View {
        TextField(label, text: $draft)
            .textFieldStyle(.plain)
            .labelsHidden()
            .font(NumericTokens.valueFieldFont)
            .monospacedDigit()
            .foregroundStyle(isEnabled ? NumericTokens.textPrimary : NumericTokens.textDisabled)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .frame(width: NumericTokens.valueFieldWidth)
            .padding(.horizontal, 6)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .stroke(isFocused ? NumericTokens.accentBlue : NumericTokens.borderSubtle, lineWidth: isFocused ? 2 : 1)
            )
            .onAppear { draft = displayText }
            .onChange(of: displayText) { _, newText in
                if !isFocused || syncsNextReadout { draft = newText }
                syncsNextReadout = false
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            // Return commits in place, like a native field; resigning first
            // responder through AppKit does not update `@FocusState`.
            .onSubmit { commit() }
            .onExitCommand {
                draft = displayText
                isFocused = false
            }
            .accessibilityLabel(label)
    }

    private func commit() {
        guard draft != displayText,
              let parsed = InspectorNumericInput.value(from: draft, displayText: displayText, range: range),
              parsed != value else {
            // Nothing to apply (including a clamp back to the current value),
            // so the readout will not change; restore it now.
            draft = displayText
            return
        }
        syncsNextReadout = true
        value = parsed
        project.finishContinuousEdit()
    }
}

/// Parses text typed into an Inspector value field. The field shows values in
/// display units, so a percentage readout ("92%") takes "80" or "80%" as 0.8.
enum InspectorNumericInput {
    static func value(from text: String, displayText: String, range: ClosedRange<Double>) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = leadingNumber(in: trimmed) else { return nil }
        let scale = trimmed.contains("%") || displaysPercent(displayText, range: range) ? 100.0 : 1.0
        return min(max(number / scale, range.lowerBound), range.upperBound)
    }

    /// A word readout such as "Off" or "Equal" stands in for a percentage on
    /// unit-interval sliders.
    private static func displaysPercent(_ displayText: String, range: ClosedRange<Double>) -> Bool {
        if displayText.contains("%") { return true }
        return leadingNumber(in: displayText) == nil && range.upperBound <= 1
    }

    private static func leadingNumber(in text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let match = normalized.firstMatch(of: /[-+]?(\d+\.?\d*|\.\d+)/) else { return nil }
        return Double(match.output.0)
    }
}

struct InspectorDenseAxisField: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.isEnabled) private var isEnabled
    var axis: String
    @Binding var value: Double
    var precision: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(axis)
                .font(NumericTokens.captionFont)
                .foregroundStyle(isEnabled ? NumericTokens.textMuted : NumericTokens.textDisabled)
            TextField(axis, value: $value, format: .number.precision(.fractionLength(precision)))
                .textFieldStyle(.plain)
                .font(NumericTokens.numericFont)
                .foregroundStyle(isEnabled ? NumericTokens.textPrimary : NumericTokens.textDisabled)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onSubmit { project.finishContinuousEdit() }
        }
        .padding(.horizontal, NumericTokens.space2)
        .frame(maxWidth: .infinity)
        .frame(height: NumericTokens.controlHeight)
        .background(NumericTokens.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
    }
}

struct InspectorDenseSegmented<Value: Hashable & Identifiable, Label: View>: View {
    var values: [Value]
    @Binding var selection: Value
    @ViewBuilder var label: (Value) -> Label

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(values) { value in
                label(value)
                    .tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(height: NumericTokens.segmentedVisibleHeight)
        .frame(maxWidth: .infinity)
    }
}

/// Disclosure header shared by every collapsible Inspector section. The
/// disclosure chevron leads, points right when collapsed and down when
/// expanded, and an optional enable checkbox sits before the title.
struct InspectorSectionHeader<Trailing: View>: View {
    var title: String
    @Binding var isExpanded: Bool
    var isOn: Binding<Bool>?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NumericTokens.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if let isOn {
                Toggle(title, isOn: isOn)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Enable \(title)")
            }

            Text(title)
                .font(NumericTokens.sectionTitleFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .lineLimit(1)
                .accessibilityHidden(true)

            Spacer(minLength: NumericTokens.space2)
            trailing
        }
        .padding(.leading, NumericTokens.sectionHeaderPaddingLeading)
        .padding(.trailing, NumericTokens.panelPaddingX)
        .frame(height: NumericTokens.sectionHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .contentShape(Rectangle())
        .onTapGesture {
            isExpanded.toggle()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }
}

extension InspectorSectionHeader where Trailing == EmptyView {
    init(title: String, isExpanded: Binding<Bool>, isOn: Binding<Bool>? = nil) {
        self.init(title: title, isExpanded: isExpanded, isOn: isOn) { EmptyView() }
    }
}

/// A collapsible Inspector section. When the section has an enable checkbox
/// and it is off, every row in the body is disabled so no child control looks
/// adjustable while it has no effect.
struct InspectorCollapsibleSection<Content: View>: View {
    var title: String
    @Binding var isExpanded: Bool
    var isOn: Binding<Bool>?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        isExpanded: Binding<Bool>,
        isOn: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.isOn = isOn
        self.content = content
    }

    @Environment(\.inspectorRevealSection) private var revealSection
    @State private var revealsAfterLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSectionHeader(title: title, isExpanded: $isExpanded, isOn: isOn)
                .id(InspectorSectionScrollID.header(title))
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                }
                .disabled(isOn.map { !$0.wrappedValue } ?? false)
                Color.clear
                    .frame(height: 0)
                    .id(InspectorSectionScrollID.end(title))
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            revealsAfterLayout = expanded
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            guard revealsAfterLayout else { return }
            revealsAfterLayout = false
            revealSection(title, height)
        }
    }
}

enum InspectorSectionScrollID: Hashable {
    case header(String)
    case end(String)
}

/// Scrolls the Inspector so a section the user just expanded is in view.
/// The default does nothing; `inspectorRevealsExpandedSections()` installs
/// the real action around a detail panel's scroll view.
struct InspectorRevealSectionAction {
    var action: (_ title: String, _ sectionHeight: CGFloat) -> Void = { _, _ in }

    func callAsFunction(_ title: String, _ sectionHeight: CGFloat) {
        action(title, sectionHeight)
    }
}

extension EnvironmentValues {
    @Entry var inspectorRevealSection = InspectorRevealSectionAction()
}

private struct InspectorRevealsExpandedSections: ViewModifier {
    @State private var viewportHeight: CGFloat = 0

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
                .environment(\.inspectorRevealSection, InspectorRevealSectionAction { title, sectionHeight in
                    withAnimation(.easeOut(duration: 0.2)) {
                        // A section that fits scrolls just enough to show its
                        // last row, which keeps its header on screen. A taller
                        // one pins its header to the top instead.
                        if sectionHeight <= viewportHeight {
                            proxy.scrollTo(InspectorSectionScrollID.end(title))
                        } else {
                            proxy.scrollTo(InspectorSectionScrollID.header(title), anchor: .top)
                        }
                    }
                })
        }
    }
}

extension View {
    /// Wrap a detail panel that contains `InspectorCollapsibleSection`s so
    /// expanding a section near the bottom scrolls it into view.
    func inspectorRevealsExpandedSections() -> some View {
        modifier(InspectorRevealsExpandedSections())
    }
}

/// Borderless icon button for Inspector chrome: no resting background, a
/// light fill on hover, and a stronger fill while pressed.
struct InspectorIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InspectorIconButtonBody(configuration: configuration)
    }
}

private struct InspectorIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
            .background(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).fill(fill))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        guard isEnabled else { return NumericTokens.textDisabled.opacity(0.6) }
        return configuration.isPressed || isHovered ? NumericTokens.textPrimary : NumericTokens.textSecondary
    }

    private var fill: Color {
        guard isEnabled else { return .clear }
        if configuration.isPressed { return Color.white.opacity(0.16) }
        return isHovered ? Color.white.opacity(0.08) : .clear
    }
}

struct InspectorDenseSwatchStrip: View {
    @Environment(\.isEnabled) private var isEnabled
    var presets: [(name: String, color: OverlayColor)]
    var selected: OverlayColor
    var action: (OverlayColor) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(compactPresets, id: \.name) { preset in
                Button {
                    action(preset.color)
                } label: {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(preset.color.isRouteMapEndCheckerboard ? Color.clear : Color(numericOverlay: preset.color))
                        .frame(width: NumericTokens.swatchSize, height: NumericTokens.swatchSize)
                        .overlay {
                            if preset.color.isRouteMapEndCheckerboard {
                                RouteMapCheckerboardSwatch(cornerRadius: 5)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(preset.color == selected ? NumericTokens.accentBlue : NumericTokens.borderStrong, lineWidth: preset.color == selected ? 2 : 1)
                        )
                        .overlay {
                            if preset.color == selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(preset.color == .white || preset.color == .yellow ? Color.black : Color.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(preset.name)
                .accessibilityLabel(preset.name)
            }

            Button {
                InspectorDenseColorPanelPresenter.shared.present(
                    color: selected.isRouteMapEndCheckerboard ? .white : selected,
                    onChange: action
                )
            } label: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(selected.isRouteMapEndCheckerboard ? Color.clear : Color(numericOverlay: selected))
                    .frame(width: NumericTokens.swatchSize, height: NumericTokens.swatchSize)
                    .overlay {
                        if selected.isRouteMapEndCheckerboard {
                            RouteMapCheckerboardSwatch(cornerRadius: 5)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(NumericTokens.borderStrong, lineWidth: 1)
                    )
                    .overlay {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(selected == .white || selected == .yellow ? Color.black.opacity(0.72) : Color.white.opacity(0.88))
                    }
            }
            .buttonStyle(.plain)
            .help("Custom Color")
            .accessibilityLabel("Custom Color")
        }
        // Swatches are colors rather than text, so fading them reads as
        // disabled without hurting label contrast.
        .opacity(isEnabled ? 1 : 0.4)
        .frame(height: NumericTokens.controlHeight)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var compactPresets: [(name: String, color: OverlayColor)] {
        if presets.contains(where: { $0.color.isRouteMapEndCheckerboard }) {
            return Array(presets.prefix(7))
        }
        let preferred: [OverlayColor] = [.white, .black, .red, .yellow, .green, .blue]
        return preferred.compactMap { color in
            presets.first { $0.color == color }
        }
    }
}

struct RouteMapCheckerboardSwatch: View {
    var cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / 3
            let cellHeight = proxy.size.height / 3
            ZStack {
                Color.white
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { column in
                        if (row + column).isMultiple(of: 2) {
                            Color.black
                                .frame(width: cellWidth, height: cellHeight)
                                .position(
                                    x: cellWidth * (CGFloat(column) + 0.5),
                                    y: cellHeight * (CGFloat(row) + 0.5)
                                )
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

@MainActor
private final class InspectorDenseColorPanelPresenter: NSObject {
    static let shared = InspectorDenseColorPanelPresenter()

    private var onChange: ((OverlayColor) -> Void)?

    func present(color: OverlayColor, onChange: @escaping (OverlayColor) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isContinuous = true
        panel.showsAlpha = true
        panel.color = NSColor(overlayColor: color)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        onChange?(OverlayColor(sender.color))
    }
}

private extension OverlayColor {
    init(_ color: NSColor) {
        let nsColor = color.usingColorSpace(.deviceRGB) ?? .white
        self.init(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
    }
}

private extension NSColor {
    convenience init(overlayColor: OverlayColor) {
        self.init(
            deviceRed: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            alpha: overlayColor.alpha
        )
    }
}

struct InspectorAnchorGrid: View {
    var position: CGPoint
    var onSelect: (CGPoint) -> Void

    private static let cellSize: CGFloat = 18
    private static let cellSpacing: CGFloat = 3

    private let anchors: [(label: String, point: CGPoint)] = [
        ("tl", CGPoint(x: 0.05, y: 0.05)), ("tc", CGPoint(x: 0.5, y: 0.05)), ("tr", CGPoint(x: 0.95, y: 0.05)),
        ("ml", CGPoint(x: 0.05, y: 0.5)),  ("mc", CGPoint(x: 0.5, y: 0.5)),  ("mr", CGPoint(x: 0.95, y: 0.5)),
        ("bl", CGPoint(x: 0.05, y: 0.95)), ("bc", CGPoint(x: 0.5, y: 0.95)), ("br", CGPoint(x: 0.95, y: 0.95))
    ]

    var body: some View {
        let columns = [
            GridItem(.fixed(Self.cellSize), spacing: Self.cellSpacing),
            GridItem(.fixed(Self.cellSize), spacing: Self.cellSpacing),
            GridItem(.fixed(Self.cellSize), spacing: Self.cellSpacing)
        ]
        LazyVGrid(columns: columns, spacing: Self.cellSpacing) {
            ForEach(anchors, id: \.label) { anchor in
                Button {
                    onSelect(anchor.point)
                } label: {
                    let isActive = isAnchored(to: anchor.point)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? NumericTokens.accentBlueSoft : NumericTokens.controlBackground)
                        .overlay(
                            Circle()
                                .fill(isActive ? NumericTokens.accentBlue : NumericTokens.textMuted)
                                .frame(width: 4, height: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isActive ? NumericTokens.accentBlue : NumericTokens.borderSubtle, lineWidth: 1)
                        )
                        .frame(width: Self.cellSize, height: Self.cellSize)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: (Self.cellSize * 3) + (Self.cellSpacing * 2))
    }

    private func isAnchored(to point: CGPoint) -> Bool {
        abs(position.x - point.x) < 0.02 && abs(position.y - point.y) < 0.02
    }
}

// MARK: - Tokens

enum NumericTokens {
    static let panelBackground = EditorTheme.panelBackground
    static let panelBackgroundElevated = EditorTheme.panelHeader
    static let controlBackground = EditorTheme.surfaceControl
    static let fieldBackground = EditorTheme.surfacePressed
    static let borderSubtle = EditorTheme.borderSubtle
    static let borderStrong = EditorTheme.borderStrong
    static let textPrimary = EditorTheme.textPrimary
    static let textSecondary = EditorTheme.textSecondary
    static let textMuted = EditorTheme.textMuted
    /// Disabled text stays readable instead of fading the whole row.
    static let textDisabled = EditorTheme.textMuted
    static let accentBlue = EditorTheme.accentBlue
    static let accentBlueSoft = EditorTheme.accentBlueSoft
    static let dangerRed = EditorTheme.dangerRed

    static let space2: CGFloat = 8
    static let space3: CGFloat = 10

    // Metrics follow macOS small controls: about 22pt controls in 28pt rows.
    static let sectionHeaderHeight: CGFloat = 28
    static let sectionHeaderPaddingLeading: CGFloat = 6
    static let rowHeight: CGFloat = 28
    static let anchorGridRowHeight: CGFloat = 64
    static let rowGap: CGFloat = 0
    static let sectionGap: CGFloat = 0
    static let labelColumnWidth: CGFloat = 104
    static let controlHeight: CGFloat = 22
    static let segmentedVisibleHeight: CGFloat = 22
    static let detailHeaderHeight: CGFloat = 40
    static let iconButtonSize: CGFloat = 24
    static let valueFieldWidth: CGFloat = 46
    static let swatchSize: CGFloat = 18
    static let panelPaddingX: CGFloat = 12
    static let panelPaddingY: CGFloat = 8
    static let controlRadius: CGFloat = 5

    static let sectionTitleFont = Font.system(size: 12, weight: .semibold)
    static let bodyFont = Font.system(size: 12, weight: .regular)
    static let bodyStrongFont = Font.system(size: 12, weight: .semibold)
    static let captionFont = Font.system(size: 11, weight: .regular)
    static let numericFont = Font.system(size: 12, weight: .regular).monospacedDigit()
    static let valueFieldFont = Font.system(size: 11, weight: .regular)
}

extension Color {
    init(numericOverlay color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

extension Double {
    func quantizedNumeric(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}

/// Swatch and font shortcuts shared by native overlay Inspectors.
@MainActor
enum InspectorPresets {
    static var fontPresets: [String] { FontLibraryManager.shared.effectiveFavorites }
    static let colorPresets: [(name: String, color: OverlayColor)] = [
        ("White", .white), ("Black", .black), ("Red", .red), ("Orange", .orange),
        ("Yellow", .yellow), ("Green", .green), ("Blue", .blue), ("Cyan", .cyan),
        ("Purple", .purple), ("Pink", .pink)
    ]
}
