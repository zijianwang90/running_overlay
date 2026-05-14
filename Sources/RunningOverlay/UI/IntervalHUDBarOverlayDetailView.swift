import SwiftUI

struct IntervalHUDBarOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<IntervalHUDBarInspectorSectionKind> = Set(IntervalHUDBarInspectorSectionKind.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: binding(for: .layout)) {
                            OverlayLayoutInspectorRows(elementID: elementID)
                        }

                        IntervalHUDBarInspectorSection(
                            title: "HUD Bar",
                            systemImage: "rectangle.split.3x1",
                            isExpanded: binding(for: .hudBar)
                        ) {
                            sizeRows(element.style.intervalHUDBar)
                            modeRows(element.style.intervalHUDBar)
                        }

                        IntervalHUDBarInspectorSection(
                            title: "Metrics",
                            systemImage: "waveform.path.ecg",
                            isExpanded: binding(for: .metrics)
                        ) {
                            metricRows(element.style.intervalHUDBar)
                        }

                        IntervalHUDBarInspectorSection(
                            title: "Bottom Bar",
                            systemImage: "rectangle.bottomthird.inset.filled",
                            isExpanded: binding(for: .bottomBar),
                            headerToggle: Binding(
                                get: { element.style.intervalHUDBar.bottomBarEnabled },
                                set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.bottomBarEnabled = value } }
                            )
                        ) {
                            bottomBarRows(element.style.intervalHUDBar)
                        }

                        IntervalHUDBarInspectorSection(
                            title: "Typography",
                            systemImage: "textformat.size",
                            isExpanded: binding(for: .typography)
                        ) {
                            typographyRows(element.style.intervalHUDBar)
                        }

                        IntervalHUDBarDividerInspectorModule(elementID: elementID, element: element)
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Interval Overlay")
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

    private func binding(for section: IntervalHUDBarInspectorSectionKind) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { isOpen in
                if isOpen {
                    openSections.insert(section)
                } else {
                    openSections.remove(section)
                }
            }
        )
    }

    @ViewBuilder
    private func sizeRows(_ style: IntervalHUDBarStyle) -> some View {
        InspectorDenseSliderRow(
            label: "Width",
            value: intervalBinding(\.width, current: style),
            range: 420...1100,
            displayText: "\(Int(style.width.rounded()))"
        )
        InspectorDenseSliderRow(
            label: "Height",
            value: intervalBinding(\.height, current: style),
            range: 84...180,
            displayText: "\(Int(style.height.rounded()))"
        )
    }

    @ViewBuilder
    private func modeRows(_ style: IntervalHUDBarStyle) -> some View {
        toggleRow("Rep", isOn: style.showsRep) { value in
            project.mutateIntervalHUDBarStyle(elementID) { $0.showsRep = value }
        }
        toggleRow("Current Training", isOn: style.showsPhase) { value in
            project.mutateIntervalHUDBarStyle(elementID) { $0.showsPhase = value }
        }
        if style.showsPhase {
            InspectorDenseRow(label: "Training Detail") {
                InspectorDenseSegmented(values: IntervalHUDBarPhaseDetailMode.allCases, selection: Binding(
                    get: { style.phaseDetailMode },
                    set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.phaseDetailMode = value } }
                )) { mode in
                    Text(mode.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            InspectorDenseRow(label: "REST Detail") {
                InspectorDenseSegmented(values: IntervalHUDBarPhaseDetailMode.allCases, selection: Binding(
                    get: { style.restPhaseDetailMode },
                    set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.restPhaseDetailMode = value } }
                )) { mode in
                    Text(mode.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        toggleRow("Remaining", isOn: style.showsRemaining) { value in
            project.mutateIntervalHUDBarStyle(elementID) { $0.showsRemaining = value }
        }
        if style.showsRemaining {
            InspectorDenseRow(label: "Remaining") {
                InspectorDenseSegmented(values: IntervalHUDBarRemainingPrimary.allCases, selection: Binding(
                    get: { style.remainingPrimary },
                    set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.remainingPrimary = value } }
                )) { mode in
                    Text(mode.label)
                }
            }
        }
        toggleRow("HR Zone", isOn: style.showsZone) { value in
            project.mutateIntervalHUDBarStyle(elementID) { $0.showsZone = value }
        }
        if style.showsZone {
            InspectorDenseRow(label: "Zone Mode") {
                InspectorDenseSegmented(values: IntervalHUDBarZoneDisplayMode.allCases, selection: Binding(
                    get: { style.zoneDisplayMode },
                    set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.zoneDisplayMode = value } }
                )) { mode in
                    Text(mode.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            InspectorDenseRow(label: "HR Drop") {
                InspectorDenseSegmented(values: IntervalHUDBarHRDropMode.allCases, selection: Binding(
                    get: { style.hrDropMode },
                    set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.hrDropMode = value } }
                )) { mode in
                    Text(mode.label)
                }
            }
        }
    }

    @ViewBuilder
    private func bottomBarRows(_ style: IntervalHUDBarStyle) -> some View {
        if style.bottomBarEnabled {
            InspectorDenseRow(label: "Type") {
                Menu {
                    ForEach(IntervalHUDBarBottomBarMode.selectableCases) { mode in
                        Button {
                            project.mutateIntervalHUDBarStyle(elementID) { $0.bottomBarMode = mode }
                        } label: {
                            if mode == style.bottomBarMode {
                                Label(mode.label, systemImage: "checkmark")
                            } else {
                                Text(mode.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: style.bottomBarMode.label)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)
            }
            if style.bottomBarMode == .lapProgress {
                InspectorDenseRow(label: "Progress") {
                    InspectorDenseSegmented(values: IntervalHUDBarProgressMode.allCases, selection: Binding(
                        get: { style.progressMode },
                        set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.progressMode = value } }
                    )) { mode in
                        Text(mode.label)
                    }
                }
            }
            InspectorDenseSliderRow(
                label: "Spacing",
                value: Binding(
                    get: { style.bottomBarSpacing },
                    set: { value in
                        project.mutateIntervalHUDBarStyleContinuous(elementID) {
                            $0.bottomBarSpacing = value.rounded()
                        }
                    }
                ),
                range: 0...40,
                displayText: "\(Int(style.bottomBarSpacing.rounded()))"
            )
            if style.bottomBarMode == .heartRateZones || style.bottomBarMode == .paceZones {
                InspectorDenseSliderRow(
                    label: "Active Zone Width",
                    value: Binding(
                        get: { style.activeZoneWidthShare },
                        set: { value in
                            project.mutateIntervalHUDBarStyleContinuous(elementID) {
                                $0.activeZoneWidthShare = value.quantizedNumeric(to: 0.05)
                            }
                        }
                    ),
                    range: 0...0.5,
                    displayText: style.activeZoneWidthShare <= 0 ? "Equal" : String(format: "%.0f%%", style.activeZoneWidthShare * 100)
                )
                InspectorDenseSliderRow(
                    label: "Active Zone Height",
                    value: Binding(
                        get: { style.activeZoneHeightScale },
                        set: { value in
                            project.mutateIntervalHUDBarStyleContinuous(elementID) {
                                $0.activeZoneHeightScale = value.quantizedNumeric(to: 0.05)
                            }
                        }
                    ),
                    range: 1...2,
                    displayText: String(format: "%.2gx", style.activeZoneHeightScale)
                )
                InspectorDenseSliderRow(
                    label: "Zone Gap",
                    value: Binding(
                        get: { style.zoneSegmentGap },
                        set: { value in
                            project.mutateIntervalHUDBarStyleContinuous(elementID) {
                                $0.zoneSegmentGap = value.quantizedNumeric(to: 0.5)
                            }
                        }
                    ),
                    range: 0...12,
                    displayText: String(format: "%.1f", style.zoneSegmentGap)
                )
                InspectorDenseSliderRow(
                    label: "Corner Radius",
                    value: Binding(
                        get: { style.bottomBarCornerRadius },
                        set: { value in
                            project.mutateIntervalHUDBarStyleContinuous(elementID) {
                                $0.bottomBarCornerRadius = value.quantizedNumeric(to: 0.5)
                            }
                        }
                    ),
                    range: 0...12,
                    displayText: String(format: "%.1f", style.bottomBarCornerRadius)
                )
                InspectorDenseSliderRow(
                    label: "Inactive Opacity",
                    value: Binding(
                        get: { style.inactiveZoneOpacity },
                        set: { value in
                            project.mutateIntervalHUDBarStyleContinuous(elementID) {
                                $0.inactiveZoneOpacity = value.quantizedNumeric(to: 0.05)
                            }
                        }
                    ),
                    range: 0.2...1,
                    displayText: String(format: "%.0f%%", style.inactiveZoneOpacity * 100)
                )
                toggleRow("Zone Marker", isOn: style.zoneMarkerEnabled) { value in
                    project.mutateIntervalHUDBarStyle(elementID) { $0.zoneMarkerEnabled = value }
                }
                if style.zoneMarkerEnabled {
                    InspectorDenseRow(label: "Marker Position") {
                        InspectorDenseSegmented(values: IntervalHUDBarZoneMarkerPosition.allCases, selection: Binding(
                            get: { style.zoneMarkerPosition },
                            set: { value in project.mutateIntervalHUDBarStyle(elementID) { $0.zoneMarkerPosition = value } }
                        )) { position in
                            Text(position.label)
                        }
                    }
                    toggleRow("Marker Value", isOn: style.zoneMarkerShowsValue) { value in
                        project.mutateIntervalHUDBarStyle(elementID) { $0.zoneMarkerShowsValue = value }
                    }
                }
            }
            toggleRow("Glow", isOn: style.bottomBarGlowEnabled) { value in
                project.mutateIntervalHUDBarStyle(elementID) { $0.bottomBarGlowEnabled = value }
            }
            if style.bottomBarGlowEnabled {
                InspectorDenseSliderRow(
                    label: "Intensity",
                    value: Binding(
                        get: { style.bottomBarGlowIntensity },
                        set: { value in project.mutateIntervalHUDBarStyleContinuous(elementID) { $0.bottomBarGlowIntensity = value.quantizedNumeric(to: 0.05) } }
                    ),
                    range: 0...1,
                    displayText: String(format: "%.0f%%", style.bottomBarGlowIntensity * 100)
                )
            }
        }
    }

    private func toggleRow(_ label: String, isOn: Bool, onSet: @escaping (Bool) -> Void) -> some View {
        InspectorDenseRow(label: label) {
            Toggle("", isOn: Binding(get: { isOn }, set: onSet))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private func metricRows(_ style: IntervalHUDBarStyle) -> some View {
        ForEach(Array(style.metricSlots.enumerated()), id: \.element.id) { index, slot in
            InspectorDenseRow(label: "Metric \(index + 1)") {
                Menu {
                    ForEach(IntervalHUDBarMetric.numericCases) { metric in
                        Button {
                            project.mutateIntervalHUDBarStyle(elementID) { hud in
                                guard index < hud.metricSlots.count else { return }
                                hud.metricSlots[index].metric = metric
                                hud.metricSlots[index].unitOption = metric.defaultUnitOption
                            }
                        } label: {
                            if slot.metric == metric {
                                Label(metric.label, systemImage: "checkmark")
                            } else {
                                Text(metric.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: slot.metric.label)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)

                if slot.metric.unitOptions.count > 1 {
                    Menu {
                        ForEach(slot.metric.unitOptions) { unit in
                            Button {
                                project.mutateIntervalHUDBarStyle(elementID) { hud in
                                    guard index < hud.metricSlots.count else { return }
                                    hud.metricSlots[index].unitOption = unit
                                }
                            } label: {
                                if slot.unitOption == unit {
                                    Label(unit.label, systemImage: "checkmark")
                                } else {
                                    Text(unit.label)
                                }
                            }
                        }
                    } label: {
                        InspectorDenseMenuLabel(title: slot.unitOption.label)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: NumericTokens.controlHeight)
                }

                Button {
                    project.mutateIntervalHUDBarStyle(elementID) { hud in
                        guard index < hud.metricSlots.count else { return }
                        hud.metricSlots.remove(at: index)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: NumericTokens.controlHeight, height: NumericTokens.controlHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NumericTokens.textSecondary)
                .help("Remove metric")
            }
        }

        InspectorDenseRow(label: "Add") {
            Menu {
                ForEach(IntervalHUDBarMetric.numericCases) { metric in
                    Button(metric.label) {
                        project.mutateIntervalHUDBarStyle(elementID) { hud in
                            hud.metricSlots.append(IntervalHUDBarMetricSlot(metric: metric))
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(systemImage: "plus", title: "Add Metric")
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func typographyRows(_ style: IntervalHUDBarStyle) -> some View {
        typographyRoleRows("Labels", role: .labels, text: style.labelText)
        typographyRoleRows("Primary", role: .primaryValues, text: style.primaryValueText)
        typographyRoleRows("Phase", role: .phase, text: style.phaseText)
        typographyRoleRows("Phase Detail", role: .phaseDetail, text: style.phaseDetailText)
        typographyRoleRows("Metric Value", role: .metricValues, text: style.metricValueText)
        typographyRoleRows("Metric Unit", role: .metricUnits, text: style.metricUnitText)
    }

    @ViewBuilder
    private func typographyRoleRows(_ label: String, role: IntervalHUDBarTypographyRole, text: IntervalHUDBarTextStyle) -> some View {
        InspectorDenseRow(label: label) {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        updateTextStyle(role) { $0.fontName = name }
                    } label: {
                        if name == text.fontName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: text.fontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseSliderRow(
            label: "\(label) Size",
            value: Binding(
                get: { text.fontSize },
                set: { value in updateTextStyleContinuous(role) { $0.fontSize = value.rounded() } }
            ),
            range: 8...72,
            displayText: "\(Int(text.fontSize.rounded()))"
        )
        InspectorDenseRow(label: "\(label) Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { text.fontWeight },
                set: { value in updateTextStyle(role) { $0.fontWeight = value } }
            )) { weight in
                Text(weight.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.mutateIntervalHUDBarStyle(elementID) { $0 = .default } },
            onTrailingTap: { project.selection = .none }
        )
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }

    private func intervalBinding(_ keyPath: WritableKeyPath<IntervalHUDBarStyle, Double>, current: IntervalHUDBarStyle) -> Binding<Double> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { value in
                project.mutateIntervalHUDBarStyleContinuous(elementID) { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func updateTextStyle(_ role: IntervalHUDBarTypographyRole, _ mutate: @escaping (inout IntervalHUDBarTextStyle) -> Void) {
        project.mutateIntervalHUDBarStyle(elementID) { hud in
            switch role {
            case .labels: mutate(&hud.labelText)
            case .primaryValues: mutate(&hud.primaryValueText)
            case .phase: mutate(&hud.phaseText)
            case .phaseDetail: mutate(&hud.phaseDetailText)
            case .metricValues: mutate(&hud.metricValueText)
            case .metricUnits: mutate(&hud.metricUnitText)
            }
        }
    }

    private func updateTextStyleContinuous(_ role: IntervalHUDBarTypographyRole, _ mutate: @escaping (inout IntervalHUDBarTextStyle) -> Void) {
        project.mutateIntervalHUDBarStyleContinuous(elementID) { hud in
            switch role {
            case .labels: mutate(&hud.labelText)
            case .primaryValues: mutate(&hud.primaryValueText)
            case .phase: mutate(&hud.phaseText)
            case .phaseDetail: mutate(&hud.phaseDetailText)
            case .metricValues: mutate(&hud.metricValueText)
            case .metricUnits: mutate(&hud.metricUnitText)
            }
        }
    }
}

private struct IntervalHUDBarDividerInspectorModule: View {
    @EnvironmentObject private var project: ProjectDocument

    let elementID: OverlayElement.ID
    let element: OverlayElement
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "minus")
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text("Divider")
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { element.style.dividerEnabled },
                    set: { project.setOverlayDividerEnabled(elementID, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isExpanded {
                InspectorDenseRow(label: "Color") {
                    InspectorDenseSwatchStrip(
                        presets: NumericOverlayDetailView.colorPresets,
                        selected: element.style.dividerColor,
                        action: { project.setOverlayDividerColor(elementID, color: $0) }
                    )
                    .disabled(!element.style.dividerEnabled)
                    .opacity(element.style.dividerEnabled ? 1 : 0.5)
                }
                InspectorDenseSliderRow(
                    label: "Thickness",
                    value: Binding(
                        get: { element.style.dividerThickness },
                        set: { project.setOverlayDividerThickness(elementID, thickness: $0.quantizedNumeric(to: 0.5)) }
                    ),
                    range: 0.5...16,
                    displayText: String(format: "%.1f", element.style.dividerThickness),
                    isEnabled: element.style.dividerEnabled
                )
                InspectorDenseSliderRow(
                    label: "Alpha",
                    value: Binding(
                        get: { element.style.dividerOpacity },
                        set: { project.setOverlayDividerOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
                    ),
                    range: 0...1,
                    displayText: String(format: "%.0f%%", element.style.dividerOpacity * 100),
                    isEnabled: element.style.dividerEnabled
                )
            }
        }
    }
}

private enum IntervalHUDBarInspectorSectionKind: CaseIterable {
    case layout
    case hudBar
    case metrics
    case bottomBar
    case typography
}

private struct IntervalHUDBarInspectorSection<Content: View>: View {
    var title: String
    var systemImage: String
    @Binding var isExpanded: Bool
    var headerToggle: Binding<Bool>?
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        headerToggle: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.headerToggle = headerToggle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                if let headerToggle {
                    Toggle("", isOn: headerToggle)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .frame(height: NumericTokens.sectionHeaderHeight)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}
