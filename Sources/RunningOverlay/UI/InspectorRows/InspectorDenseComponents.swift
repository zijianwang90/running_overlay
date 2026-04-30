import SwiftUI
import AppKit

struct InspectorDenseRow<Trailing: View>: View {
    var label: String
    var minHeight: CGFloat = NumericTokens.rowHeight
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: NumericTokens.space3) {
            Text(label)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textSecondary)
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

struct InspectorDenseMenuLabel: View {
    var systemImage: String?
    var title: String
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: NumericTokens.space2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            Text(title)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, NumericTokens.space2)
        .frame(maxWidth: .infinity)
        .frame(height: NumericTokens.controlHeight)
        .background(NumericTokens.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        .opacity(isEnabled ? 1 : 0.7)
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
            Text(displayText)
                .font(NumericTokens.captionFont.monospacedDigit())
                .foregroundStyle(NumericTokens.textSecondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.horizontal, NumericTokens.space2)
                .frame(height: NumericTokens.controlHeight)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        }
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }
}

struct InspectorDenseAxisField: View {
    @EnvironmentObject private var project: ProjectDocument
    var axis: String
    @Binding var value: Double
    var precision: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(axis)
                .font(NumericTokens.captionFont)
                .foregroundStyle(NumericTokens.textMuted)
            TextField(axis, value: $value, format: .number.precision(.fractionLength(precision)))
                .textFieldStyle(.plain)
                .font(NumericTokens.numericFont)
                .foregroundStyle(NumericTokens.textPrimary)
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
        .tint(NumericTokens.accentBlue)
        .frame(height: NumericTokens.segmentedVisibleHeight)
        .frame(maxWidth: .infinity)
    }
}

struct InspectorDetailFooterBar: View {
    var leadingTitle: String
    var leadingSystemImage: String
    var trailingTitle: String
    var trailingSystemImage: String
    var onLeadingTap: () -> Void
    var onTrailingTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing = NumericTokens.space2
            let unitWidth = max((proxy.size.width - spacing) / 3, 0)
            HStack(spacing: spacing) {
                Button(action: onLeadingTap) {
                    Label(leadingTitle, systemImage: leadingSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                .frame(width: unitWidth)

                Button(action: onTrailingTap) {
                    Label(trailingTitle, systemImage: trailingSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .frame(width: unitWidth * 2)
            }
        }
        .frame(height: NumericTokens.footerButtonHeight)
    }
}

struct InspectorDenseSwatchStrip: View {
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
                        .fill(Color(numericOverlay: preset.color))
                        .frame(width: NumericTokens.swatchSize, height: NumericTokens.swatchSize)
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
            }

            Button {
                InspectorDenseColorPanelPresenter.shared.present(color: selected, onChange: action)
            } label: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(numericOverlay: selected))
                    .frame(width: NumericTokens.swatchSize, height: NumericTokens.swatchSize)
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
        }
        .frame(height: NumericTokens.controlHeight)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var compactPresets: [(name: String, color: OverlayColor)] {
        let preferred: [OverlayColor] = [.white, .black, .red, .yellow, .green, .blue]
        return preferred.compactMap { color in
            presets.first { $0.color == color }
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
    static let borderSubtle = EditorTheme.borderSubtle
    static let borderStrong = EditorTheme.borderStrong
    static let textPrimary = EditorTheme.textPrimary
    static let textSecondary = EditorTheme.textSecondary
    static let textMuted = EditorTheme.textMuted
    static let accentBlue = EditorTheme.accentBlue
    static let accentBlueSoft = EditorTheme.accentBlueSoft
    static let dangerRed = EditorTheme.dangerRed

    static let space2: CGFloat = 8
    static let space3: CGFloat = 10

    // Numeric Overlay tokens (numeric-overlay-ui.spec.json).
    static let sectionHeaderHeight: CGFloat = 30
    static let rowHeight: CGFloat = 34
    static let anchorGridRowHeight: CGFloat = 64
    static let rowGap: CGFloat = 0
    static let sectionGap: CGFloat = 0
    static let labelColumnWidth: CGFloat = 112
    static let controlHeight: CGFloat = 26
    static let segmentedVisibleHeight: CGFloat = 24
    static let footerButtonHeight: CGFloat = 32
    static let iconButtonSize: CGFloat = 28
    static let swatchSize: CGFloat = 20
    static let panelPaddingX: CGFloat = 12
    static let panelPaddingY: CGFloat = 8
    static let controlRadius: CGFloat = 5

    static let sectionTitleFont = Font.system(size: 13, weight: .semibold)
    static let bodyFont = Font.system(size: 12, weight: .regular)
    static let bodyStrongFont = Font.system(size: 12, weight: .semibold)
    static let captionFont = Font.system(size: 10, weight: .medium)
    static let numericFont = Font.system(size: 12, weight: .medium, design: .monospaced)
}
