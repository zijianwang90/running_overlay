import SwiftUI

/// Dense Inspector detail panel for the Running Gauge overlay.
///
/// Mirrors the design language of `NumericOverlayDetailView` (same tokens,
/// row sizes, segmented controls, swatch strips, section disclosure pattern)
/// while exposing the full Running Gauge surface area: style preset, data
/// layout + per-region metric configuration, dial, outer ring, progress ring,
/// ticks, dividers, typography, color, and effects.
struct RunningGaugeOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<GaugeSection> = [.style, .dataLayout, .regions]
    @State private var expandedRegion: RunningGaugeRegion?
    @State private var outerRingExpanded = true
    @State private var progressRingExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                RunningGaugeOverlayHeader(element: element)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.style) { styleSection(element) }
                        layoutInspectorSection(element)
                        sectionView(.dataLayout) { dataLayoutSection(element) }
                        sectionView(.regions) { regionsSection(element) }
                        sectionView(.dial) { dialSection(element) }
                        sectionView(.ring) { ringSection(element) }
                        sectionView(.ticks) { ticksSection(element) }
                        sectionView(.dividers) { dividersSection(element) }
                        sectionView(.typography) { typographySection(element) }
                        sectionView(.color) { colorSection(element) }
                        sectionView(.effects) { effectsSection(element) }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Style preset

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

    // MARK: - Layout (position / scale / opacity; no width/height for square gauge)

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
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
                elementID: elementID
            )
        }
    }

    // MARK: - Data layout

    @ViewBuilder
    private func dataLayoutSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Layout") {
            Menu {
                ForEach(RunningGaugeLayoutPreset.allCases) { layout in
                    Button {
                        project.setOverlayGaugeLayout(elementID, layout: layout)
                        expandedRegion = nil
                    } label: {
                        if layout == gauge.layoutPreset {
                            Label(layout.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(layout.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: gauge.layoutPreset.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    // MARK: - Region list + per-region settings

    @ViewBuilder
    private func regionsSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        VStack(spacing: NumericTokens.rowGap) {
            ForEach(gauge.regions) { region in
                regionRow(region)
                if expandedRegion == region.region {
                    regionDetail(region)
                        .padding(.leading, NumericTokens.space3)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func regionRow(_ region: RunningGaugeRegionConfig) -> some View {
        let isOpen = expandedRegion == region.region
        InspectorDenseRow(label: region.region.label) {
            HStack(spacing: NumericTokens.space2) {
                Menu {
                    ForEach(OverlayGaugeMetric.selectableCases) { metric in
                        Button {
                            project.updateOverlayGaugeRegion(elementID, region: region.region) { config in
                                config.metric = metric
                            }
                        } label: {
                            if metric == region.metric {
                                Label(metric.label, systemImage: "checkmark")
                            } else {
                                Text(metric.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: region.metric.label)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)

                Button {
                    expandedRegion = isOpen ? nil : region.region
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumericTokens.textMuted)
                        .frame(width: 22, height: NumericTokens.controlHeight)
                }
                .buttonStyle(.plain)
                .help(isOpen ? "Hide region settings" : "Show region settings")
            }
        }
    }

    @ViewBuilder
    private func regionDetail(_ region: RunningGaugeRegionConfig) -> some View {
        let element = project.selectedOverlay(elementID)
        InspectorDenseRow(label: "Label") {
            TextField(region.metric.compactLabel, text: Binding(
                get: { region.customLabel },
                set: { newValue in
                    project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.customLabel = newValue }
                }
            ), onCommit: { project.finishContinuousEdit() })
            .textFieldStyle(.plain)
            .font(NumericTokens.bodyFont)
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        }
        InspectorDenseRow(label: "Show Label") {
            gaugeToggle(isOn: region.showLabel) { newValue in
                project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.showLabel = newValue }
            }
        }
        InspectorDenseRow(label: "Show Unit") {
            gaugeToggle(isOn: region.showUnit) { newValue in
                project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.showUnit = newValue }
            }
        }
        InspectorDenseSliderRow(
            label: "Value Size",
            value: Binding(
                get: { region.valueFontScale },
                set: { newValue in
                    project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.valueFontScale = newValue.gaugeQuantized(to: 0.02) }
                }
            ),
            range: 0.30...1.40,
            displayText: String(format: "%.2f", region.valueFontScale)
        )
        InspectorDenseRow(label: "Value Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { region.valueWeight },
                set: { newValue in
                    project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.valueWeight = newValue }
                }
            )) { weight in
                Text(weight.label)
            }
        }
        InspectorDenseRow(label: "Value Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: region.valueColor ?? element?.style.gauge.primaryTextColor ?? .white
            ) { color in
                project.updateOverlayGaugeRegion(elementID, region: region.region) { $0.valueColor = color }
            }
        }
    }

    // MARK: - Dial

    @ViewBuilder
    private func dialSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Background") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: gauge.dialBackgroundColor
            ) { color in
                project.mutateGaugeStyle(elementID) { $0.dialBackgroundColor = color }
            }
        }
        InspectorDenseSliderRow(
            label: "Opacity",
            value: gaugeBinding(\.dialBackgroundOpacity, of: gauge),
            range: 0...1,
            displayText: String(format: "%.0f%%", gauge.dialBackgroundOpacity * 100)
        )
        InspectorDenseRow(label: "Glass Effect") {
            gaugeToggle(isOn: gauge.glassEffectEnabled) { newValue in
                project.mutateGaugeStyle(elementID) { $0.glassEffectEnabled = newValue }
            }
        }
    }

    // MARK: - Ring (outer + progress)

    @ViewBuilder
    private func ringSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        VStack(spacing: 0) {
            gaugeSubsectionHeader(
                title: "Outer Ring",
                isOn: gauge.outerRingEnabled,
                isExpanded: outerRingExpanded,
                onToggleOn: { newValue in
                    project.mutateGaugeStyle(elementID) { $0.outerRingEnabled = newValue }
                },
                onToggleExpanded: { outerRingExpanded.toggle() }
            )
            if gauge.outerRingEnabled && outerRingExpanded {
                InspectorDenseRow(label: "Outer Color") {
                    InspectorDenseSwatchStrip(
                        presets: NumericOverlayDetailView.colorPresets,
                        selected: gauge.outerRingColor
                    ) { color in
                        project.mutateGaugeStyle(elementID) { $0.outerRingColor = color }
                    }
                }
                InspectorDenseSliderRow(
                    label: "Outer Opacity",
                    value: gaugeBinding(\.outerRingOpacity, of: gauge),
                    range: 0...1,
                    displayText: String(format: "%.0f%%", gauge.outerRingOpacity * 100)
                )
                InspectorDenseSliderRow(
                    label: "Outer Width",
                    value: gaugeBinding(\.outerRingWidthScale, of: gauge),
                    range: 0.005...0.06,
                    displayText: String(format: "%.3f", gauge.outerRingWidthScale)
                )
            }

            gaugeSubsectionHeader(
                title: "Progress Ring",
                isOn: gauge.progressRingEnabled,
                isExpanded: progressRingExpanded,
                onToggleOn: { newValue in
                    project.mutateGaugeStyle(elementID) { $0.progressRingEnabled = newValue }
                },
                onToggleExpanded: { progressRingExpanded.toggle() }
            )
            if gauge.progressRingEnabled && progressRingExpanded {
                InspectorDenseRow(label: "Progress Mode") {
                    Menu {
                        ForEach(RunningGaugeProgressMode.allCases) { mode in
                            Button {
                                project.mutateGaugeStyle(elementID) { $0.progressMode = mode }
                            } label: {
                                if mode == gauge.progressMode {
                                    Label(mode.label, systemImage: "checkmark")
                                } else {
                                    Text(mode.label)
                                }
                            }
                        }
                    } label: {
                        InspectorDenseMenuLabel(title: gauge.progressMode.label)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: NumericTokens.controlHeight)
                }
                InspectorDenseRow(label: "Progress Color") {
                    InspectorDenseSwatchStrip(
                        presets: NumericOverlayDetailView.colorPresets,
                        selected: gauge.progressColor
                    ) { color in
                        project.mutateGaugeStyle(elementID) { $0.progressColor = color }
                    }
                }
                InspectorDenseSliderRow(
                    label: "Track Opacity",
                    value: gaugeBinding(\.progressTrackOpacity, of: gauge),
                    range: 0...1,
                    displayText: String(format: "%.0f%%", gauge.progressTrackOpacity * 100)
                )
                InspectorDenseSliderRow(
                    label: "Ring Width",
                    value: gaugeBinding(\.progressRingWidthScale, of: gauge),
                    range: 0.005...0.06,
                    displayText: String(format: "%.3f", gauge.progressRingWidthScale)
                )
                InspectorDenseRow(label: "Rounded Caps") {
                    gaugeToggle(isOn: gauge.progressRoundedCaps) { newValue in
                        project.mutateGaugeStyle(elementID) { $0.progressRoundedCaps = newValue }
                    }
                }
            }
        }
    }

    // MARK: - Ticks

    @ViewBuilder
    private func ticksSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Tick Marks") {
            gaugeToggle(isOn: gauge.tickMarksEnabled) { newValue in
                project.mutateGaugeStyle(elementID) { $0.tickMarksEnabled = newValue }
            }
        }
        if gauge.tickMarksEnabled {
            InspectorDenseRow(label: "Tick Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: gauge.tickColor
                ) { color in
                    project.mutateGaugeStyle(elementID) { $0.tickColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Tick Count",
                value: Binding(
                    get: { Double(gauge.tickCount) },
                    set: { newValue in
                        project.mutateGaugeStyle(elementID) { $0.tickCount = max(6, Int(newValue.rounded())) }
                    }
                ),
                range: 12...120,
                displayText: "\(gauge.tickCount)"
            )
            InspectorDenseSliderRow(
                label: "Major Every",
                value: Binding(
                    get: { Double(gauge.majorTickEvery) },
                    set: { newValue in
                        project.mutateGaugeStyle(elementID) { $0.majorTickEvery = max(1, Int(newValue.rounded())) }
                    }
                ),
                range: 1...12,
                displayText: "\(gauge.majorTickEvery)"
            )
            InspectorDenseSliderRow(
                label: "Tick Opacity",
                value: gaugeBinding(\.tickOpacity, of: gauge),
                range: 0...1,
                displayText: String(format: "%.0f%%", gauge.tickOpacity * 100)
            )
            InspectorDenseSliderRow(
                label: "Major Opacity",
                value: gaugeBinding(\.majorTickOpacity, of: gauge),
                range: 0...1,
                displayText: String(format: "%.0f%%", gauge.majorTickOpacity * 100)
            )
        }
    }

    // MARK: - Dividers

    @ViewBuilder
    private func dividersSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Dividers") {
            gaugeToggle(isOn: gauge.dividerEnabled) { newValue in
                project.mutateGaugeStyle(elementID) { $0.dividerEnabled = newValue }
            }
        }
        if gauge.dividerEnabled {
            InspectorDenseRow(label: "Divider Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: gauge.dividerColor
                ) { color in
                    project.mutateGaugeStyle(elementID) { $0.dividerColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Divider Opacity",
                value: gaugeBinding(\.dividerOpacity, of: gauge),
                range: 0...1,
                displayText: String(format: "%.0f%%", gauge.dividerOpacity * 100)
            )
            InspectorDenseSliderRow(
                label: "Divider Width",
                value: gaugeBinding(\.dividerWidth, of: gauge),
                range: 0.5...4,
                displayText: String(format: "%.1f", gauge.dividerWidth)
            )
        }
    }

    // MARK: - Typography

    @ViewBuilder
    private func typographySection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        project.mutateGaugeStyle(elementID) { $0.fontName = name }
                    } label: {
                        if name == gauge.fontName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: gauge.fontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseRow(label: "Monospaced") {
            gaugeToggle(isOn: gauge.monospacedDigits) { newValue in
                project.mutateGaugeStyle(elementID) { $0.monospacedDigits = newValue }
            }
        }
        InspectorDenseRow(label: "Primary Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { gauge.primaryFontWeight },
                set: { newValue in project.mutateGaugeStyle(elementID) { $0.primaryFontWeight = newValue } }
            )) { weight in
                Text(weight.label)
            }
        }
        InspectorDenseRow(label: "Secondary") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { gauge.secondaryFontWeight },
                set: { newValue in project.mutateGaugeStyle(elementID) { $0.secondaryFontWeight = newValue } }
            )) { weight in
                Text(weight.label)
            }
        }
    }

    // MARK: - Color

    @ViewBuilder
    private func colorSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Primary Text") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: gauge.primaryTextColor
            ) { color in
                project.mutateGaugeStyle(elementID) { $0.primaryTextColor = color }
            }
        }
        InspectorDenseRow(label: "Secondary") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: gauge.secondaryTextColor
            ) { color in
                project.mutateGaugeStyle(elementID) { $0.secondaryTextColor = color }
            }
        }
        InspectorDenseRow(label: "Accent") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: gauge.accentColor
            ) { color in
                project.mutateGaugeStyle(elementID) { $0.accentColor = color }
            }
        }
    }

    // MARK: - Effects

    @ViewBuilder
    private func effectsSection(_ element: OverlayElement) -> some View {
        let gauge = element.style.gauge
        InspectorDenseRow(label: "Shadow") {
            gaugeToggle(isOn: gauge.shadowEnabled) { newValue in
                project.mutateGaugeStyle(elementID) { $0.shadowEnabled = newValue }
            }
        }
        if gauge.shadowEnabled {
            InspectorDenseSliderRow(
                label: "Shadow Opacity",
                value: gaugeBinding(\.shadowOpacity, of: gauge),
                range: 0...1,
                displayText: String(format: "%.0f%%", gauge.shadowOpacity * 100)
            )
            InspectorDenseSliderRow(
                label: "Shadow Radius",
                value: gaugeBinding(\.shadowRadius, of: gauge),
                range: 0...30,
                displayText: String(format: "%.0f", gauge.shadowRadius)
            )
        }
        InspectorDenseRow(label: "Glow") {
            gaugeToggle(isOn: gauge.glowEnabled) { newValue in
                project.mutateGaugeStyle(elementID) { $0.glowEnabled = newValue }
            }
        }
        if gauge.glowEnabled {
            InspectorDenseRow(label: "Glow Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: gauge.glowColor
                ) { color in
                    project.mutateGaugeStyle(elementID) { $0.glowColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Glow Opacity",
                value: gaugeBinding(\.glowOpacity, of: gauge),
                range: 0...1,
                displayText: String(format: "%.0f%%", gauge.glowOpacity * 100)
            )
            InspectorDenseSliderRow(
                label: "Glow Radius",
                value: gaugeBinding(\.glowRadius, of: gauge),
                range: 0...24,
                displayText: String(format: "%.0f", gauge.glowRadius)
            )
        }
    }

    // MARK: - Helpers

    private func gaugeBinding(_ keyPath: WritableKeyPath<RunningGaugeStyle, Double>, of current: RunningGaugeStyle) -> Binding<Double> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { newValue in
                project.mutateGaugeStyle(elementID) { gauge in
                    gauge[keyPath: keyPath] = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func gaugeToggle(isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { newValue in
            set(newValue)
        }))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
    }

    @ViewBuilder
    private func gaugeSubsectionHeader(
        title: String,
        isOn: Bool,
        isExpanded: Bool,
        onToggleOn: @escaping (Bool) -> Void,
        onToggleExpanded: @escaping () -> Void
    ) -> some View {
        HStack(spacing: NumericTokens.space2) {
            Text(title)
                .font(NumericTokens.bodyFont.weight(.medium))
                .foregroundStyle(NumericTokens.textSecondary)
            Spacer()
            gaugeToggle(isOn: isOn, set: onToggleOn)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NumericTokens.textMuted)
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: NumericTokens.sectionHeaderHeight)
        .background(NumericTokens.panelBackground.opacity(0.72))
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpanded()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func sectionView<Body: View>(
        _ section: GaugeSection,
        @ViewBuilder content: () -> Body
    ) -> some View {
        let isOpen = openSections.contains(section)
        VStack(alignment: .leading, spacing: 0) {
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

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.resetOverlayStyle(elementID) },
            onTrailingTap: { project.selection = .none }
        )
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
                Text(element.style.gauge.layoutPreset.compactLabel)
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
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(NumericTokens.borderSubtle)
        }
    }
}

// MARK: - Section model

enum GaugeSection: String, CaseIterable {
    case style
    case layout
    case dataLayout
    case regions
    case dial
    case ring
    case ticks
    case dividers
    case typography
    case color
    case effects

    var title: String {
        switch self {
        case .style: "Style Preset"
        case .layout: "Position & Scale"
        case .dataLayout: "Data Layout"
        case .regions: "Region Settings"
        case .dial: "Dial"
        case .ring: "Ring"
        case .ticks: "Ticks"
        case .dividers: "Dividers"
        case .typography: "Typography"
        case .color: "Color"
        case .effects: "Effects"
        }
    }

    var systemImage: String {
        switch self {
        case .style: "gauge"
        case .layout: "scope"
        case .dataLayout: "square.grid.2x2"
        case .regions: "slider.horizontal.3"
        case .dial: "circle.fill"
        case .ring: "circle.dashed"
        case .ticks: "minus"
        case .dividers: "line.3.horizontal"
        case .typography: "textformat"
        case .color: "paintpalette"
        case .effects: "sparkles"
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
