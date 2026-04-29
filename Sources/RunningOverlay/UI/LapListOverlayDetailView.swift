import SwiftUI

struct LapListOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<LapListSection> = Set(LapListSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        sectionView(.appearance, element: element) { appearanceSection(element) }
                        sectionView(.progress, element: element) { progressSection(element) }
                        sectionView(.columns, element: element) { columnsSection(element) }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                }
                Divider().overlay(NumericTokens.borderSubtle)
                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Section model

    private enum LapListSection: String, CaseIterable {
        case layout, appearance, progress, columns

        var title: String {
            switch self {
            case .layout: "Layout"
            case .appearance: "List"
            case .progress: "Progress Bar"
            case .columns: "Columns"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .appearance: "square.grid.2x2"
            case .progress: "chart.bar.fill"
            case .columns: "list.bullet"
            }
        }
    }

    // MARK: - Header

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
                Image(systemName: "list.number")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Lap List")
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
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(NumericTokens.borderSubtle)
        }
    }

    // MARK: - Section wrapper

    private func sectionView<Content: View>(
        _ section: LapListSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isOpen = openSections.contains(section)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture {
                if isOpen {
                    openSections.remove(section)
                } else {
                    openSections.insert(section)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isOpen {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    // MARK: - Appearance section

    @ViewBuilder
    private func appearanceSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapList
        InspectorDenseSliderRow(
            label: "Visible Rows",
            value: Binding(
                get: { Double(s.visibleRowCount) },
                set: { v in project.mutateLapListStyle(elementID) { $0.visibleRowCount = min(max(Int(v.rounded()), 1), 10) } }
            ),
            range: 1...10,
            displayText: "\(s.visibleRowCount)"
        )
        InspectorDenseRow(label: "Anchor", minHeight: NumericTokens.anchorGridRowHeight) {
            Picker("", selection: Binding(
                get: { s.currentRowAnchor },
                set: { v in project.mutateLapListStyle(elementID) { $0.currentRowAnchor = v } }
            )) {
                ForEach(LapListAnchor.allCases) { anchor in
                    Text(anchor.label.components(separatedBy: " / ").first ?? anchor.label)
                        .tag(anchor)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .tint(NumericTokens.accentBlue)
            .frame(height: NumericTokens.segmentedVisibleHeight)
            .frame(maxWidth: .infinity)
        }
        InspectorDenseSliderRow(
            label: "Row Height",
            value: Binding(
                get: { s.rowHeight },
                set: { v in project.mutateLapListStyleContinuous(elementID) { $0.rowHeight = v } }
            ),
            range: 20...72,
            displayText: String(format: "%.0f pt", s.rowHeight)
        )
        InspectorDenseSliderRow(
            label: "Row Spacing",
            value: Binding(
                get: { s.rowSpacing },
                set: { v in project.mutateLapListStyleContinuous(elementID) { $0.rowSpacing = v } }
            ),
            range: 0...12,
            displayText: String(format: "%.0f pt", s.rowSpacing)
        )
        InspectorDenseSliderRow(
            label: "Background",
            value: Binding(
                get: { s.backgroundOpacity },
                set: { v in project.mutateLapListStyleContinuous(elementID) { $0.backgroundOpacity = v } }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", s.backgroundOpacity * 100)
        )
        InspectorDenseRow(label: "Fade Out") {
            Toggle("", isOn: Binding(
                get: { s.fadeEnabled },
                set: { v in project.mutateLapListStyle(elementID) { $0.fadeEnabled = v } }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        if s.fadeEnabled {
            InspectorDenseSliderRow(
                label: "Min Opacity",
                value: Binding(
                    get: { s.fadeMinOpacity },
                    set: { v in project.mutateLapListStyleContinuous(elementID) { $0.fadeMinOpacity = v } }
                ),
                range: 0...0.9,
                displayText: String(format: "%.0f%%", s.fadeMinOpacity * 100)
            )
        }
    }

    // MARK: - Progress section

    @ViewBuilder
    private func progressSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapList
        InspectorDenseRow(label: "Enabled") {
            Toggle("", isOn: Binding(
                get: { s.progressBarEnabled },
                set: { v in project.mutateLapListStyle(elementID) { $0.progressBarEnabled = v } }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        if s.progressBarEnabled {
            InspectorDenseRow(label: "Mode") {
                Picker("", selection: Binding(
                    get: { s.progressMode },
                    set: { v in project.mutateLapListStyle(elementID) { $0.progressMode = v } }
                )) {
                    Text("Distance").tag(LapProgressMode.distance)
                    Text("Time").tag(LapProgressMode.time)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(NumericTokens.accentBlue)
                .frame(height: NumericTokens.segmentedVisibleHeight)
                .frame(maxWidth: .infinity)
            }
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: s.progressColor
                ) { color in
                    project.mutateLapListStyle(elementID) { $0.progressColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { s.progressOpacity },
                    set: { v in project.mutateLapListStyleContinuous(elementID) { $0.progressOpacity = v } }
                ),
                range: 0...1,
                displayText: String(format: "%.0f%%", s.progressOpacity * 100)
            )
        }
    }

    // MARK: - Columns section

    @ViewBuilder
    private func columnsSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapList
        ForEach(s.columns.indices, id: \.self) { i in
            let col = s.columns[i]
            InspectorDenseRow(label: col.metric.label) {
                Toggle("", isOn: Binding(
                    get: { col.visible },
                    set: { v in project.mutateLapListStyle(elementID) { $0.columns[i].visible = v } }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }
        }
    }

    // MARK: - Shared layout section

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapList
        CollapsibleLayoutInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.layout) },
                set: { newValue in
                    if newValue { openSections.insert(.layout) }
                    else { openSections.remove(.layout) }
                }
            )
        ) {
            OverlayLayoutRows(
                elementID: elementID,
                widthBinding: Binding(
                    get: { s.rowHeight * 6.5 },
                    set: { v in project.mutateLapListStyleContinuous(elementID) { $0.rowHeight = min(max(v / 6.5, 20), 72) } }
                ),
                widthRange: 130...468,
                heightBinding: Binding(
                    get: { Double(s.visibleRowCount) * (s.rowHeight + s.rowSpacing) },
                    set: { v in
                        project.mutateLapListStyle(elementID) {
                            let rowPlusSpacing = max($0.rowHeight + $0.rowSpacing, 1)
                            $0.visibleRowCount = min(max(Int((v / rowPlusSpacing).rounded()), 1), 10)
                        }
                    }
                ),
                heightRange: 20...840,
                opacityBinding: Binding(
                    get: { s.backgroundOpacity },
                    set: { v in project.mutateLapListStyleContinuous(elementID) { $0.backgroundOpacity = v } }
                )
            )
        }
    }

    // MARK: - Footer

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
