import SwiftUI

struct LapCardOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<LapCardSection> = Set(LapCardSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                Divider().overlay(NumericTokens.borderSubtle)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        sectionView(.appearance, element: element) { appearanceSection(element) }
                        sectionView(.columns, element: element) { columnsSection(element) }
                        sectionView(.recovery, element: element) { recoverySection(element) }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
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

    private enum LapCardSection: String, CaseIterable {
        case layout, appearance, columns, recovery

        var title: String {
            switch self {
            case .layout: "Layout"
            case .appearance: "Card"
            case .columns: "Columns"
            case .recovery: "Recovery (Rest Lap)"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .appearance: "rectangle.grid.1x2"
            case .columns: "list.bullet"
            case .recovery: "heart.fill"
            }
        }
    }

    private func header(element: OverlayElement) -> some View {
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

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "rectangle.badge.checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Lap Card")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NumericTokens.textPrimary)
                    Text("Charts")
                        .font(NumericTokens.captionFont)
                        .foregroundStyle(NumericTokens.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NumericTokens.controlBackground)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.panelPaddingY)
    }

    private func sectionView<Content: View>(
        _ section: LapCardSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isOpen = openSections.contains(section)
        return VStack(alignment: .leading, spacing: NumericTokens.rowGap) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Button {
                    if isOpen { openSections.remove(section) } else { openSections.insert(section) }
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
                VStack(spacing: NumericTokens.rowGap) { content() }
            }
        }
        .padding(.bottom, NumericTokens.space2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1)
        }
    }

    @ViewBuilder
    private func appearanceSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapCard
        InspectorDenseSliderRow(
            label: "Card Width",
            value: Binding(
                get: { s.cardWidth },
                set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.cardWidth = v } }
            ),
            range: 120...600,
            displayText: String(format: "%.0f pt", s.cardWidth)
        )
        InspectorDenseSliderRow(
            label: "Corner Radius",
            value: Binding(
                get: { s.cornerRadius },
                set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.cornerRadius = v } }
            ),
            range: 0...32,
            displayText: String(format: "%.0f pt", s.cornerRadius)
        )
        InspectorDenseSliderRow(
            label: "Background",
            value: Binding(
                get: { s.backgroundOpacity },
                set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.backgroundOpacity = v } }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", s.backgroundOpacity * 100)
        )
    }

    @ViewBuilder
    private func columnsSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapCard
        ForEach(s.columns.indices, id: \.self) { i in
            let col = s.columns[i]
            InspectorDenseRow(label: col.column.label) {
                Toggle("", isOn: Binding(
                    get: { col.visible },
                    set: { v in project.mutateLapCardStyle(elementID) { $0.columns[i].visible = v } }
                ))
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }
        }
    }

    @ViewBuilder
    private func recoverySection(_ element: OverlayElement) -> some View {
        let s = element.style.lapCard
        InspectorDenseRow(label: "Show Recovery") {
            Toggle("", isOn: Binding(
                get: { s.showRecoverySection },
                set: { v in project.mutateLapCardStyle(elementID) { $0.showRecoverySection = v } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }

        if s.showRecoverySection {
            ForEach(RecoveryMetric.allCases) { metric in
                let isOn = s.recoveryMetrics.contains(metric)
                InspectorDenseRow(label: metric.label) {
                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { on in
                            project.mutateLapCardStyle(elementID) { style in
                                if on {
                                    if !style.recoveryMetrics.contains(metric) {
                                        style.recoveryMetrics.append(metric)
                                    }
                                } else {
                                    style.recoveryMetrics.removeAll { $0 == metric }
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(NumericTokens.accentBlue)
                }
            }

            InspectorDenseRow(label: "Recovery Progress") {
                Toggle("", isOn: Binding(
                    get: { s.recoveryProgressEnabled },
                    set: { v in project.mutateLapCardStyle(elementID) { $0.recoveryProgressEnabled = v } }
                ))
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }

            if s.recoveryProgressEnabled {
                InspectorDenseRow(label: "Progress Color") {
                    InspectorDenseSwatchStrip(
                        presets: NumericOverlayDetailView.colorPresets,
                        selected: s.progressColor
                    ) { color in
                        project.mutateLapCardStyle(elementID) { $0.progressColor = color }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapCard
        CollapsibleLayoutInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.layout) },
                set: { newValue in
                    if newValue { openSections.insert(.layout) }
                    else { openSections.remove(.layout) }
                }
            )
        ) {
            OverlayLayoutInspectorRows(
                elementID: elementID,
                widthBinding: Binding(
                    get: { s.cardWidth },
                    set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.cardWidth = v } }
                ),
                widthRange: 120...600,
                heightBinding: Binding(
                    get: { s.cardWidth },
                    set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.cardWidth = v } }
                ),
                heightRange: 120...600,
                opacityBinding: Binding(
                    get: { s.backgroundOpacity },
                    set: { v in project.mutateLapCardStyleContinuous(elementID) { $0.backgroundOpacity = v } }
                )
            )
        }
    }

    private var footerBar: some View {
        HStack {
            Button {
                project.deleteOverlay(elementID)
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.panelPaddingY * 0.75)
    }
}
