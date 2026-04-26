import SwiftUI

/// Dense Inspector detail panel for the Running Gauge overlay.
///
/// Mirrors the design language of `NumericOverlayDetailView` (see
/// `docs/design/numeric-overlay-ui.md`) — same tokens, row sizes, segmented
/// controls, swatch strips, and section disclosure pattern — but exposes only
/// the parameters the gauge renderer actually consumes.
struct RunningGaugeOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<GaugeSection> = Set(GaugeSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                RunningGaugeOverlayHeader(element: element)
                Divider().overlay(NumericTokens.borderSubtle)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.style, element: element) { styleSection(element) }
                        sectionView(.layout, element: element) { layoutSection(element) }
                        sectionView(.typography, element: element) { typographySection(element) }
                        sectionView(.color, element: element) { colorSection(element) }
                        sectionView(.background, element: element) { backgroundSection(element) }
                    }
                    .padding(.horizontal, NumericTokens.panelPaddingX)
                    .padding(.vertical, NumericTokens.panelPaddingY)
                }

                Divider().overlay(NumericTokens.borderSubtle)
                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func styleSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Preset") {
            Menu {
                ForEach(OverlayGaugePreset.allCases) { preset in
                    Button {
                        project.setOverlayGaugePreset(elementID, gaugePreset: preset)
                    } label: {
                        if preset == element.style.gaugePreset {
                            Label(preset.compactDisplayLabel, systemImage: "checkmark")
                        } else {
                            Text(preset.compactDisplayLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.gaugePreset.compactDisplayLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func layoutSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Anchor") {
            InspectorAnchorGrid(position: element.position) { anchor in
                project.setOverlayPosition(elementID, position: anchor)
                project.finishContinuousEdit()
            }
        }
        InspectorDenseRow(label: "Position") {
            HStack(spacing: NumericTokens.space2) {
                InspectorDenseAxisField(
                    axis: "X",
                    value: Binding(
                        get: { Double(element.position.x) },
                        set: {
                            project.setOverlayPosition(elementID, position: CGPoint(x: $0, y: element.position.y))
                            project.finishContinuousEdit()
                        }
                    ),
                    precision: 3
                )
                InspectorDenseAxisField(
                    axis: "Y",
                    value: Binding(
                        get: { Double(element.position.y) },
                        set: {
                            project.setOverlayPosition(elementID, position: CGPoint(x: element.position.x, y: $0))
                            project.finishContinuousEdit()
                        }
                    ),
                    precision: 3
                )
            }
        }
        InspectorDenseSliderRow(
            label: "Scale",
            value: Binding(
                get: { element.scale },
                set: { project.setOverlayScale(elementID, scale: $0.gaugeQuantized(to: 0.05)) }
            ),
            range: 0.25...4,
            displayText: String(format: "%.2fx", element.scale)
        )
        InspectorDenseSliderRow(
            label: "Rotation",
            value: Binding(
                get: { element.style.rotationDegrees },
                set: { project.setOverlayRotation(elementID, degrees: $0.rounded()) }
            ),
            range: -180...180,
            displayText: "\(Int(element.style.rotationDegrees))°"
        )
    }

    @ViewBuilder
    private func typographySection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        project.setOverlayFontName(elementID, fontName: name)
                    } label: {
                        if name == element.style.fontName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.fontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: Binding(
                get: { element.style.fontSize },
                set: { project.setOverlayFontSize(elementID, fontSize: $0.rounded()) }
            ),
            range: 12...96,
            displayText: "\(Int(element.style.fontSize.rounded()))"
        )
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { element.style.fontWeight },
                set: { project.setOverlayFontWeight(elementID, fontWeight: $0) }
            )) { weight in
                Text(weight.label)
            }
        }
    }

    @ViewBuilder
    private func colorSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Accent") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.foregroundColor
            ) { color in
                project.setOverlayForegroundColor(elementID, color: color)
            }
        }
    }

    @ViewBuilder
    private func backgroundSection(_ element: OverlayElement) -> some View {
        InspectorDenseSliderRow(
            label: "Opacity",
            value: Binding(
                get: { element.style.backgroundOpacity },
                set: { project.setOverlayBackgroundOpacity(elementID, opacity: $0.gaugeQuantized(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.backgroundOpacity * 100)
        )
    }

    // MARK: - Composite components

    @ViewBuilder
    private func sectionView<Body: View>(
        _ section: GaugeSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Body
    ) -> some View {
        let isOpen = openSections.contains(section)
        VStack(alignment: .leading, spacing: NumericTokens.rowGap) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Button {
                    if isOpen {
                        openSections.remove(section)
                    } else {
                        openSections.insert(section)
                    }
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumericTokens.textMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)

            if isOpen {
                VStack(spacing: NumericTokens.rowGap) {
                    content()
                }
            }
        }
        .padding(.bottom, NumericTokens.space2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }

    private var footerBar: some View {
        HStack(spacing: NumericTokens.space2) {
            Button {
                project.resetOverlayStyle(elementID)
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Button {
                project.selection = .none
            } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorPrimaryButtonStyle())
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }
}

// MARK: - Header

private struct RunningGaugeOverlayHeader: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement

    var body: some View {
        HStack(spacing: NumericTokens.space3) {
            Button {
                project.selection = .none
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .buttonStyle(.plain)
            .help("Back")

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "gauge")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Gauge")
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle, lineWidth: 1))
            }

            Spacer()

            Button(role: .destructive) {
                project.deleteOverlay(element.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.dangerRed)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
    }
}

// MARK: - Section model

enum GaugeSection: String, CaseIterable {
    case style
    case layout
    case typography
    case color
    case background

    var title: String {
        switch self {
        case .style: "Style"
        case .layout: "Layout"
        case .typography: "Typography"
        case .color: "Color"
        case .background: "Background"
        }
    }

    var systemImage: String {
        switch self {
        case .style: "gauge"
        case .layout: "scope"
        case .typography: "textformat"
        case .color: "paintpalette"
        case .background: "rectangle.fill"
        }
    }
}

private extension OverlayGaugePreset {
    var compactDisplayLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension Double {
    func gaugeQuantized(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
