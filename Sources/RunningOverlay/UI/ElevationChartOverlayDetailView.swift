import SwiftUI

struct ElevationChartOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<Section> = Set(Section.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.preset) { presetSection(element) }
                        layoutSection(element)
                        sectionView(.chart) { chartSection(element) }
                        sectionView(.lineFill) { lineFillSection(element) }
                        sectionView(.markers) { markersSection(element) }
                        sectionView(.axis) { axisSection(element) }
                        sectionView(.bigNumbers) { bigNumbersSection(element) }
                        statsBarSection(element)
                        sectionView(.background) { backgroundSection(element) }
                        sectionView(.effects) { effectsSection(element) }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
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

    private func header(_ element: OverlayElement) -> some View {
        HStack(spacing: NumericTokens.space3) {
            Button { project.selection = .none } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumericTokens.accentBlue)
                .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("Elevation Chart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text(element.style.elevationChart.preset.label)
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            Spacer()
            Button(role: .destructive) { project.deleteOverlay(element.id) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.dangerRed)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) { Divider().overlay(NumericTokens.borderSubtle) }
    }

    @ViewBuilder
    private func presetSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Preset") {
            Menu {
                ForEach(ElevationChartPreset.allCases) { preset in
                    Button { project.setOverlayElevationChartPreset(elementID, preset: preset) } label: {
                        if preset == style.preset { Label(preset.label, systemImage: "checkmark") }
                        else { Text(preset.label) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: style.preset.label)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func layoutSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        CollapsibleLayoutInspectorSection(isExpanded: binding(for: .layout)) {
            OverlayLayoutRows(
                elementID: elementID,
                widthBinding: elevationBinding(\.width, of: style, continuous: true),
                widthRange: 220...720,
                heightBinding: elevationBinding(\.height, of: style, continuous: true),
                heightRange: 110...320,
                opacityBinding: elevationBinding(\.backgroundOpacity, of: style, continuous: true)
            )
        }
    }

    @ViewBuilder
    private func chartSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Style") {
            InspectorDenseSegmented(values: ElevationChartRenderStyle.allCases, selection: elevationBinding(\.chartStyle, of: style)) { Text($0.label) }
        }
        InspectorDenseRow(label: "Smoothing") { toggle(style.smoothingEnabled) { set(\.smoothingEnabled, to: $0) } }
        InspectorDenseRow(label: "Progress") {
            InspectorDenseSegmented(values: ElevationChartProgressMode.allCases, selection: elevationBinding(\.progressMode, of: style)) { Text($0.label) }
        }
        InspectorDenseRow(label: "Padding") {
            InspectorDenseAxisField(axis: "X", value: elevationBinding(\.chartPaddingX, of: style, continuous: true), precision: 0)
            InspectorDenseAxisField(axis: "Y", value: elevationBinding(\.chartPaddingY, of: style, continuous: true), precision: 0)
        }
    }

    @ViewBuilder
    private func lineFillSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Line") {
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.lineColor) { set(\.lineColor, to: $0) }
        }
        InspectorDenseSliderRow(label: "Line Width", value: elevationBinding(\.lineWidth, of: style, continuous: true), range: 0.5...8, displayText: String(format: "%.1f", style.lineWidth))
        InspectorDenseSliderRow(label: "Line Opacity", value: elevationBinding(\.lineOpacity, of: style, continuous: true), range: 0...1, displayText: percent(style.lineOpacity))
        InspectorDenseRow(label: "Fill") { toggle(style.fillEnabled) { set(\.fillEnabled, to: $0) } }
        InspectorDenseRow(label: "Gradient") {
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.fillStartColor) { set(\.fillStartColor, to: $0) }
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.fillEndColor) { set(\.fillEndColor, to: $0) }
        }
        InspectorDenseSliderRow(label: "Fill Opacity", value: elevationBinding(\.fillOpacity, of: style, continuous: true), range: 0...1, displayText: percent(style.fillOpacity))
        InspectorDenseRow(label: "Dual Area") { toggle(style.dualAreaEnabled) { set(\.dualAreaEnabled, to: $0) } }
    }

    @ViewBuilder
    private func markersSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Current") { toggle(style.currentMarkerEnabled) { set(\.currentMarkerEnabled, to: $0) } }
        InspectorDenseRow(label: "Marker Color") {
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.markerColor) { set(\.markerColor, to: $0) }
        }
        InspectorDenseRow(label: "Value Label") { toggle(style.markerLabelEnabled) { set(\.markerLabelEnabled, to: $0) } }
    }

    @ViewBuilder
    private func axisSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Grid") { toggle(style.gridEnabled) { set(\.gridEnabled, to: $0) } }
        InspectorDenseRow(label: "Labels") { toggle(style.axisLabelsEnabled) { set(\.axisLabelsEnabled, to: $0) } }
    }

    @ViewBuilder
    private func bigNumbersSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Enabled") { toggle(style.bigNumbersEnabled) { set(\.bigNumbersEnabled, to: $0) } }
        InspectorDenseRow(label: "Metric") {
            InspectorDenseSegmented(values: ElevationChartBigMetric.allCases, selection: elevationBinding(\.bigNumberMetric, of: style)) { Text($0.label) }
        }
        InspectorDenseSliderRow(label: "Size", value: elevationBinding(\.bigNumberFontSize, of: style, continuous: true), range: 24...84, displayText: "\(Int(style.bigNumberFontSize))")
    }

    @ViewBuilder
    private func statsBarSection(_ element: OverlayElement) -> some View {
        let config = element.style.elevationChart.statsBar
        CollapsibleStatsBarInspectorSection(
            isExpanded: binding(for: .statsBar),
            title: SharedStatsBarInspectorUI.sectionTitle,
            systemImage: SharedStatsBarInspectorUI.sectionSystemImage,
            isBarEnabled: config.visible,
            onSetBarEnabled: { isVisible in setStats { $0.visible = isVisible } }
        ) {
            StatsBarInspectorRows(
                isOn: config.visible,
                placement: config.placement,
                availablePlacements: SharedStatsBarInspectorUI.placements,
                layoutMode: config.layoutMode,
                height: config.height,
                heightRange: SharedStatsBarInspectorUI.heightRange,
                heightLabel: SharedStatsBarInspectorUI.heightLabel,
                backgroundOpacity: config.backgroundOpacity,
                dividerOpacity: config.dividerOpacity,
                cornerRadius: config.cornerRadius,
                cornerRadiusRange: SharedStatsBarInspectorUI.cornerRadiusRange,
                valueTypography: .init(
                    fontName: config.valueFontName,
                    fontSize: config.valueFontSize,
                    fontWeight: config.valueFontWeight,
                    color: config.valueColor,
                    onSetFontName: { value in setStats { $0.valueFontName = value } },
                    onSetFontSize: { value in setStats { $0.valueFontSize = value.rounded() } },
                    onSetFontWeight: { value in setStats { $0.valueFontWeight = value } },
                    onSetColor: { value in setStats { $0.valueColor = value } }
                ),
                labelTypography: .init(
                    fontName: config.labelFontName,
                    fontSize: config.labelFontSize,
                    fontWeight: config.labelFontWeight,
                    color: config.labelColor,
                    onSetFontName: { value in setStats { $0.labelFontName = value } },
                    onSetFontSize: { value in setStats { $0.labelFontSize = value.rounded() } },
                    onSetFontWeight: { value in setStats { $0.labelFontWeight = value } },
                    onSetColor: { value in setStats { $0.labelColor = value } }
                ),
                slots: config.slots.map { ($0.metric, $0.visible) },
                availableMetrics: SharedStatsBarInspectorUI.metrics,
                extraLayout: .init(
                    width: config.width,
                    offsetX: config.offsetX,
                    offsetY: config.offsetY,
                    itemSpacing: config.itemSpacing,
                    onSetWidth: { value in setStats { $0.width = value.rounded() } },
                    onSetOffsetX: { value in setStats { $0.offsetX = value.rounded() } },
                    onSetOffsetY: { value in setStats { $0.offsetY = value.rounded() } },
                    onSetItemSpacing: { value in setStats { $0.itemSpacing = value.rounded() } }
                ),
                onSetPlacement: { placement in setStats { $0.placement = placement } },
                onSetLayoutMode: { mode in setStats { $0.layoutMode = mode } },
                onSetHeight: { value in setStats { $0.height = value.rounded() } },
                onSetBackgroundOpacity: { value in setStats { $0.backgroundOpacity = value } },
                onSetDividerOpacity: { value in setStats { $0.dividerOpacity = value } },
                onSetCornerRadius: { value in setStats { $0.cornerRadius = value.rounded() } },
                onSetSlotMetric: { index, metric in project.mutateElevationChartStyle(elementID) { $0.setStatsBarMetric(metric, at: index) } },
                onSetSlotVisible: { index, visible in project.mutateElevationChartStyle(elementID) { $0.setStatsBarVisible(visible, at: index) } }
            )
        }
    }

    @ViewBuilder
    private func backgroundSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Enabled") { toggle(style.backgroundEnabled) { set(\.backgroundEnabled, to: $0) } }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.backgroundColor) { set(\.backgroundColor, to: $0) }
        }
        InspectorDenseSliderRow(label: "Opacity", value: elevationBinding(\.backgroundOpacity, of: style, continuous: true), range: 0...1, displayText: percent(style.backgroundOpacity))
        InspectorDenseSliderRow(label: "Radius", value: elevationBinding(\.cornerRadius, of: style, continuous: true), range: 0...40, displayText: "\(Int(style.cornerRadius))")
        InspectorDenseRow(label: "Border") { toggle(style.borderEnabled) { set(\.borderEnabled, to: $0) } }
        InspectorDenseSliderRow(label: "Border Opacity", value: elevationBinding(\.borderOpacity, of: style, continuous: true), range: 0...1, displayText: percent(style.borderOpacity))
    }

    @ViewBuilder
    private func effectsSection(_ element: OverlayElement) -> some View {
        let style = element.style.elevationChart
        InspectorDenseRow(label: "Shadow") { toggle(style.shadowEnabled) { set(\.shadowEnabled, to: $0) } }
        InspectorDenseSliderRow(label: "Shadow Opacity", value: elevationBinding(\.shadowOpacity, of: style, continuous: true), range: 0...1, displayText: percent(style.shadowOpacity))
        InspectorDenseSliderRow(label: "Shadow Radius", value: elevationBinding(\.shadowRadius, of: style, continuous: true), range: 0...40, displayText: "\(Int(style.shadowRadius))")
        InspectorDenseRow(label: "Line Glow") { toggle(style.glowEnabled) { set(\.glowEnabled, to: $0) } }
    }

    private var footerBar: some View {
        HStack(spacing: NumericTokens.space2) {
            Button("Reset") { project.mutateElevationChartStyle(elementID) { $0 = .default } }
            Spacer()
            Button("Done") { project.selection = .none }
        }
        .buttonStyle(.borderless)
        .font(NumericTokens.captionFont)
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: 38)
        .background(NumericTokens.panelBackgroundElevated)
    }

    private func sectionView<Content: View>(_ section: Section, @ViewBuilder content: () -> Content) -> some View {
        let isOpen = openSections.contains(section)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.icon)
                    .frame(width: 16)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture {
                if isOpen { openSections.remove(section) }
                else { openSections.insert(section) }
            }
            .overlay(alignment: .top) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }

            if isOpen {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func binding(for section: Section) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { newValue in
                if newValue { openSections.insert(section) }
                else { openSections.remove(section) }
            }
        )
    }

    private func elevationBinding<Value>(_ keyPath: WritableKeyPath<ElevationChartStyle, Value>, of style: ElevationChartStyle, continuous: Bool = false) -> Binding<Value> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { value in
                if continuous {
                    project.mutateElevationChartStyleContinuous(elementID) { $0[keyPath: keyPath] = value }
                } else {
                    project.mutateElevationChartStyle(elementID) { $0[keyPath: keyPath] = value }
                }
            }
        )
    }

    private func set<Value>(_ keyPath: WritableKeyPath<ElevationChartStyle, Value>, to value: Value) {
        project.mutateElevationChartStyle(elementID) { $0[keyPath: keyPath] = value }
    }

    private func setStats(_ mutate: @escaping (inout DistanceTimelineStatsBarConfig) -> Void) {
        project.mutateElevationChartStyle(elementID) { mutate(&$0.statsBar) }
    }

    private func toggle(_ value: Bool, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { value }, set: onSet))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private var colorPresets: [(name: String, color: OverlayColor)] {
        NumericOverlayDetailView.colorPresets
    }
}

private enum Section: CaseIterable, Hashable {
    case preset
    case layout
    case chart
    case lineFill
    case markers
    case axis
    case bigNumbers
    case statsBar
    case background
    case effects

    var title: String {
        switch self {
        case .preset: "Preset"
        case .layout: "Layout"
        case .chart: "Chart"
        case .lineFill: "Line & Fill"
        case .markers: "Markers"
        case .axis: "Axis & Labels"
        case .bigNumbers: "Big Numbers"
        case .statsBar: "Stats Bar"
        case .background: "Background"
        case .effects: "Effects"
        }
    }

    var icon: String {
        switch self {
        case .preset: "wand.and.stars"
        case .layout: "scope"
        case .chart: "chart.xyaxis.line"
        case .lineFill: "paintpalette"
        case .markers: "mappin.and.ellipse"
        case .axis: "textformat.size"
        case .bigNumbers: "number"
        case .statsBar: SharedStatsBarInspectorUI.sectionSystemImage
        case .background: "square.on.square"
        case .effects: "sparkles"
        }
    }
}
