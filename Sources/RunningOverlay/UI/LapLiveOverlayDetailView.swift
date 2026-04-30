import SwiftUI

struct LapLiveOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<LapLiveSection> = Set(LapLiveSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        sectionView(.appearance, element: element) { appearanceSection(element) }
                        sectionView(.progress, element: element) { progressSection(element) }
                        sectionView(.metrics, element: element) { metricsSection(element) }
                        sectionView(.recovery, element: element) { recoverySection(element) }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .padding(.bottom, NumericTokens.panelPaddingY)
                }
            } else {
                Spacer()
            }
        }
    }

    private enum LapLiveSection: String, CaseIterable {
        case layout, appearance, progress, metrics, recovery

        var title: String {
            switch self {
            case .layout: "Layout"
            case .appearance: "Card"
            case .progress: "Progress Bar"
            case .metrics: "Active Metrics"
            case .recovery: "Rest / Recovery"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .appearance: "rectangle.grid.1x2"
            case .progress: "chart.bar.fill"
            case .metrics: "speedometer"
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
            .help("Back")

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "stopwatch")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Lap Live")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NumericTokens.textPrimary)
                    Text("Charts")
                        .font(NumericTokens.captionFont)
                        .foregroundStyle(NumericTokens.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NumericTokens.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                }
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
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(NumericTokens.borderSubtle)
        }
    }

    private func sectionView<Content: View>(
        _ section: LapLiveSection,
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
                VStack(spacing: 0) { content() }
            }
        }
    }

    @ViewBuilder
    private func appearanceSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapLive
        InspectorDenseSliderRow(
            label: "Card Width",
            value: Binding(
                get: { s.cardWidth },
                set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.cardWidth = v } }
            ),
            range: 120...500,
            displayText: String(format: "%.0f pt", s.cardWidth)
        )
        InspectorDenseSliderRow(
            label: "Corner Radius",
            value: Binding(
                get: { s.cornerRadius },
                set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.cornerRadius = v } }
            ),
            range: 0...32,
            displayText: String(format: "%.0f pt", s.cornerRadius)
        )
        InspectorDenseSliderRow(
            label: "Background",
            value: Binding(
                get: { s.backgroundOpacity },
                set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.backgroundOpacity = v } }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", s.backgroundOpacity * 100)
        )
    }

    @ViewBuilder
    private func progressSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapLive
        InspectorDenseRow(label: "Enabled") {
            Toggle("", isOn: Binding(
                get: { s.showProgressBar },
                set: { v in project.mutateLapLiveStyle(elementID) { $0.showProgressBar = v } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        if s.showProgressBar {
            InspectorDenseRow(label: "Mode") {
                Picker("", selection: Binding(
                    get: { s.progressMode },
                    set: { v in project.mutateLapLiveStyle(elementID) { $0.progressMode = v } }
                )) {
                    Text("Distance").tag(LapProgressMode.distance)
                    Text("Time").tag(LapProgressMode.time)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: s.progressColor
                ) { color in
                    project.mutateLapLiveStyle(elementID) { $0.progressColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { s.progressOpacity },
                    set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.progressOpacity = v } }
                ),
                range: 0...1,
                displayText: String(format: "%.0f%%", s.progressOpacity * 100)
            )
        }
    }

    @ViewBuilder
    private func metricsSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapLive
        ForEach(s.activeMetrics.indices, id: \.self) { i in
            let cfg = s.activeMetrics[i]
            InspectorDenseRow(label: cfg.metric.label) {
                Toggle("", isOn: Binding(
                    get: { cfg.visible },
                    set: { v in project.mutateLapLiveStyle(elementID) { $0.activeMetrics[i].visible = v } }
                ))
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }
        }
    }

    @ViewBuilder
    private func recoverySection(_ element: OverlayElement) -> some View {
        let s = element.style.lapLive
        InspectorDenseRow(label: "Rest Mode") {
            Picker("", selection: Binding(
                get: { s.restMode },
                set: { v in project.mutateLapLiveStyle(elementID) { $0.restMode = v } }
            )) {
                ForEach(LapLiveRestMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }

        if s.restMode == .recovery {
            ForEach(RecoveryMetric.allCases) { metric in
                let isOn = s.recoveryMetrics.contains(metric)
                InspectorDenseRow(label: metric.label) {
                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { on in
                            project.mutateLapLiveStyle(elementID) { style in
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
                    set: { v in project.mutateLapLiveStyle(elementID) { $0.recoveryProgressEnabled = v } }
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
                        project.mutateLapLiveStyle(elementID) { $0.progressColor = color }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let s = element.style.lapLive
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
                    set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.cardWidth = v } }
                ),
                widthRange: 120...500,
                heightBinding: Binding(
                    get: { s.cardWidth },
                    set: { v in project.mutateLapLiveStyleContinuous(elementID) { $0.cardWidth = v } }
                ),
                heightRange: 120...500
            )
        }
    }

}
