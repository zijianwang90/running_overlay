import SwiftUI

/// Dense Inspector detail panel for Numeric Overlay metrics.
/// See `docs/design/overlays/numeric/numeric-overlay-ui.md` for the spec this view implements.
struct NumericOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<NumericSection> = Set(NumericSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                NumericOverlayHeader(element: element)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection
                        sectionView(.content, element: element) { contentSection(element) }
                        sectionView(.typography, element: element) { typographySection(element) }
                        sectionView(.label, element: element, accessory: { labelEnabledToggle(element) }) { labelSection(element) }
                        sectionView(.unit, element: element, accessory: { unitEnabledToggle(element) }) { unitSection(element) }
                        sectionView(.icon, element: element, accessory: { iconEnabledToggle(element) }) { iconSection(element) }
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

    // MARK: - Sections

    @ViewBuilder
    private func contentSection(_ element: OverlayElement) -> some View {
        let units = OverlayUnitOption.options(for: element.type)
        if units.isEmpty {
            EmptyView()
        } else if units.count > 1 {
            InspectorDenseRow(label: "Units") {
                Menu {
                    ForEach(units) { unit in
                        Button {
                            project.setOverlayUnitOption(elementID, unitOption: unit)
                        } label: {
                            if unit == element.style.unitOption {
                                Label(unit.label, systemImage: "checkmark")
                            } else {
                                Text(unit.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: element.style.unitOption.label)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)
            }
        } else if let only = units.first {
            InspectorDenseRow(label: "Units") {
                InspectorDenseReadout(text: only.label)
            }
        }
        if element.type == .elevation {
            InspectorDenseRow(label: "Mode") {
                Menu {
                    ForEach(OverlayElevationDisplayMode.allCases) { mode in
                        Button {
                            project.setOverlayElevationDisplayMode(elementID, mode: mode)
                        } label: {
                            if mode == element.style.elevationDisplayMode {
                                Label(mode.label, systemImage: "checkmark")
                            } else {
                                Text(mode.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: element.style.elevationDisplayMode.label)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)
            }
        }
        InspectorDenseRow(label: "Format Preview") {
            InspectorDenseReadout(text: previewValue(for: element), isNumeric: true)
        }
    }

    @ViewBuilder
    private var layoutInspectorSection: some View {
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
                    get: { project.selectedOverlay(elementID)?.style.numericMinWidth ?? 0 },
                    set: { project.setOverlayNumericMinimumSize(elementID, width: $0.rounded()) }
                ),
                widthRange: 0...720,
                widthLabel: "Min Width",
                heightBinding: Binding(
                    get: { project.selectedOverlay(elementID)?.style.numericMinHeight ?? 0 },
                    set: { project.setOverlayNumericMinimumSize(elementID, height: $0.rounded()) }
                ),
                heightRange: 0...360,
                heightLabel: "Min Height"
            )
        }
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
                Text(weight.compactInspectorLabel)
                    .lineLimit(1)
            }
        }
        InspectorDenseRow(label: "Align") {
            InspectorDenseSegmented(values: OverlayTextAlignment.allCases, selection: Binding(
                get: { element.style.textAlignment },
                set: { project.setOverlayTextAlignment(elementID, alignment: $0) }
            )) { alignment in
                Image(systemName: alignment.systemImage)
            }
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.valueColor
            ) { color in
                project.setOverlayValueColor(elementID, color: color)
            }
        }
        if supportsHeartRateZoneColoring(element) {
            InspectorDenseRow(label: "Zone Color") {
                Toggle(
                    "Follow HR zones for value",
                    isOn: Binding(
                        get: { element.style.valueColorsFollowHeartRateZones },
                        set: { project.setOverlayValueColorsFollowHeartRateZones(elementID, $0) }
                    )
                )
                .toggleStyle(.checkbox)
            }
        }
        InspectorDenseSliderRow(
            label: "Alpha",
            value: Binding(
                get: { element.style.valueOpacity },
                set: { project.setOverlayValueOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.valueOpacity * 100)
        )
    }

    @ViewBuilder
    private func labelSection(_ element: OverlayElement) -> some View {
        let isEnabled = element.style.showLabel
        InspectorDenseRow(label: "Text") {
            TextField(element.type.label, text: Binding(
                get: { element.style.customLabel },
                set: { project.setOverlayCustomLabel(elementID, label: $0) }
            ), onCommit: { project.finishContinuousEdit() })
            .textFieldStyle(.plain)
            .font(NumericTokens.bodyFont)
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: "Position") {
            InspectorDenseSegmented(values: OverlayTextAttachmentPosition.allCases, selection: Binding(
                get: { element.style.labelPosition },
                set: { project.setOverlayLabelPosition(elementID, position: $0) }
            )) { position in
                Text(position.compactInspectorLabel)
                    .lineLimit(1)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: alignRowLabel(for: element.style.labelPosition)) {
            InspectorDenseSegmented(values: OverlayTextAlignment.allCases, selection: Binding(
                get: { element.style.labelTextAlignment },
                set: { project.setOverlayLabelTextAlignment(elementID, alignment: $0) }
            )) { alignment in
                Image(systemName: alignSystemImage(for: alignment, position: element.style.labelPosition))
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.labelColor
            ) { color in
                project.setOverlayLabelColor(elementID, color: color)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        if supportsHeartRateZoneColoring(element) {
            InspectorDenseRow(label: "Zone Color") {
                Toggle(
                    "Follow HR zones for label",
                    isOn: Binding(
                        get: { element.style.labelColorsFollowHeartRateZones },
                        set: { project.setOverlayLabelColorsFollowHeartRateZones(elementID, $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
            }
        }
        InspectorDenseSliderRow(
            label: "Alpha",
            value: Binding(
                get: { element.style.labelOpacity },
                set: { project.setOverlayLabelOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.labelOpacity * 100),
            isEnabled: isEnabled
        )
        fontEditorRows(
            fontName: Binding(
                get: { element.style.labelFontName },
                set: { project.setOverlayLabelFontName(elementID, fontName: $0) }
            ),
            fontSize: Binding(
                get: { element.style.labelFontSize },
                set: { project.setOverlayLabelFontSize(elementID, fontSize: $0.rounded()) }
            ),
            fontWeight: Binding(
                get: { element.style.labelFontWeight },
                set: { project.setOverlayLabelFontWeight(elementID, fontWeight: $0) }
            ),
            isEnabled: isEnabled
        )
        InspectorDenseSliderRow(
            label: "Spacing",
            value: Binding(
                get: { element.style.labelSpacing },
                set: { project.setOverlayLabelSpacing(elementID, spacing: $0.quantizedNumeric(to: 0.5)) }
            ),
            range: 0...60,
            displayText: String(format: "%.1f", element.style.labelSpacing),
            isEnabled: isEnabled
        )
    }

    @ViewBuilder
    private func unitSection(_ element: OverlayElement) -> some View {
        let isEnabled = element.style.showUnit
        InspectorDenseRow(label: "Position") {
            InspectorDenseSegmented(values: OverlayTextAttachmentPosition.allCases, selection: Binding(
                get: { element.style.unitPosition },
                set: { project.setOverlayUnitPosition(elementID, position: $0) }
            )) { position in
                Text(position.compactInspectorLabel)
                    .lineLimit(1)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        // Unit alignment is independent from label and value. Top/bottom: own
        // row horizontal align. Left/right of value: vertical align in the row
        // (minimal preset); baseline still ties unit to the value horizontally.
        InspectorDenseRow(label: alignRowLabel(for: element.style.unitPosition)) {
            InspectorDenseSegmented(values: OverlayTextAlignment.allCases, selection: Binding(
                get: { element.style.unitTextAlignment },
                set: { project.setOverlayUnitTextAlignment(elementID, alignment: $0) }
            )) { alignment in
                Image(systemName: alignSystemImage(for: alignment, position: element.style.unitPosition))
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.unitColor
            ) { color in
                project.setOverlayUnitColor(elementID, color: color)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        if supportsHeartRateZoneColoring(element) {
            InspectorDenseRow(label: "Zone Color") {
                Toggle(
                    "Follow HR zones for unit",
                    isOn: Binding(
                        get: { element.style.unitColorsFollowHeartRateZones },
                        set: { project.setOverlayUnitColorsFollowHeartRateZones(elementID, $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
            }
        }
        InspectorDenseSliderRow(
            label: "Alpha",
            value: Binding(
                get: { element.style.unitOpacity },
                set: { project.setOverlayUnitOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.unitOpacity * 100),
            isEnabled: isEnabled
        )
        fontEditorRows(
            fontName: Binding(
                get: { element.style.unitFontName },
                set: { project.setOverlayUnitFontName(elementID, fontName: $0) }
            ),
            fontSize: Binding(
                get: { element.style.unitFontSize },
                set: { project.setOverlayUnitFontSize(elementID, fontSize: $0.rounded()) }
            ),
            fontWeight: Binding(
                get: { element.style.unitFontWeight },
                set: { project.setOverlayUnitFontWeight(elementID, fontWeight: $0) }
            ),
            isEnabled: isEnabled
        )
        InspectorDenseSliderRow(
            label: "Spacing",
            value: Binding(
                get: { element.style.unitSpacing },
                set: { project.setOverlayUnitSpacing(elementID, spacing: $0.quantizedNumeric(to: 0.5)) }
            ),
            range: 0...60,
            displayText: String(format: "%.1f", element.style.unitSpacing),
            isEnabled: isEnabled
        )
    }

    @ViewBuilder
    private func iconSection(_ element: OverlayElement) -> some View {
        let isEnabled = element.style.iconEnabled
        InspectorDenseRow(label: "Symbol") {
            SFSymbolPicker(
                symbolName: Binding(
                    get: { element.style.iconSystemName },
                    set: { project.setOverlayIconSystemName(elementID, systemName: $0) }
                ),
                placeholder: element.type.defaultNumericIconSystemName,
                defaultSymbolName: element.type.defaultNumericIconSystemName,
                defaultLabel: "Metric Default",
                onSubmit: { project.finishContinuousEdit() },
                onDefault: {
                    project.setOverlayIconSystemName(elementID, systemName: element.type.defaultNumericIconSystemName)
                    project.finishContinuousEdit()
                }
            )
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: "Position") {
            InspectorDenseSegmented(values: OverlayTextAttachmentPosition.allCases, selection: Binding(
                get: { element.style.iconPosition },
                set: { project.setOverlayIconPosition(elementID, position: $0) }
            )) { position in
                Text(position.compactInspectorLabel)
                    .lineLimit(1)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: alignRowLabel(for: element.style.iconPosition)) {
            InspectorDenseSegmented(values: OverlayTextAlignment.allCases, selection: Binding(
                get: { element.style.iconTextAlignment },
                set: { project.setOverlayIconTextAlignment(elementID, alignment: $0) }
            )) { alignment in
                Image(systemName: alignSystemImage(for: alignment, position: element.style.iconPosition))
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: Binding(
                get: { element.style.iconSize },
                set: { project.setOverlayIconSize(elementID, size: $0.rounded()) }
            ),
            range: 8...96,
            displayText: "\(Int(element.style.iconSize.rounded()))",
            isEnabled: isEnabled
        )
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.iconColor
            ) { color in
                project.setOverlayIconColor(elementID, color: color)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        if supportsHeartRateZoneColoring(element) {
            InspectorDenseRow(label: "Zone Color") {
                Toggle(
                    "Follow HR zones for icon",
                    isOn: Binding(
                        get: { element.style.iconColorsFollowHeartRateZones },
                        set: { project.setOverlayIconColorsFollowHeartRateZones(elementID, $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
            }
        }
        InspectorDenseSliderRow(
            label: "Alpha",
            value: Binding(
                get: { element.style.iconOpacity },
                set: { project.setOverlayIconOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.iconOpacity * 100),
            isEnabled: isEnabled
        )
        InspectorDenseSliderRow(
            label: "Spacing",
            value: Binding(
                get: { element.style.iconSpacing },
                set: { project.setOverlayIconSpacing(elementID, spacing: $0.quantizedNumeric(to: 0.5)) }
            ),
            range: 0...60,
            displayText: String(format: "%.1f", element.style.iconSpacing),
            isEnabled: isEnabled
        )
    }

    @ViewBuilder
    private func fontEditorRows(
        fontName: Binding<String>,
        fontSize: Binding<Double>,
        fontWeight: Binding<OverlayFontWeight>,
        isEnabled: Bool
    ) -> some View {
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        fontName.wrappedValue = name
                    } label: {
                        if name == fontName.wrappedValue {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: fontName.wrappedValue)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: fontSize,
            range: 8...72,
            displayText: "\(Int(fontSize.wrappedValue.rounded()))",
            isEnabled: isEnabled
        )
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: fontWeight) { weight in
                Text(weight.compactInspectorLabel)
                    .lineLimit(1)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private func backgroundSection(_ element: OverlayElement) -> some View {
        let isEnabled = element.style.backgroundEnabled
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.backgroundColor
            ) { color in
                project.setOverlayBackgroundColor(elementID, color: color)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Opacity",
            value: Binding(
                get: { element.style.backgroundOpacity },
                set: { project.setOverlayBackgroundOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.backgroundOpacity * 100),
            isEnabled: isEnabled
        )
        InspectorDenseSliderRow(
            label: "Radius",
            value: Binding(
                get: { element.style.backgroundRadius },
                set: { project.setOverlayBackgroundRadius(elementID, radius: $0.rounded()) }
            ),
            range: 0...32,
            displayText: "\(Int(element.style.backgroundRadius.rounded()))",
            isEnabled: isEnabled
        )
        InspectorDenseRow(label: "Padding") {
            HStack(spacing: NumericTokens.space2) {
                InspectorDenseAxisField(
                    axis: "X",
                    value: Binding(
                        get: { element.style.backgroundPaddingX },
                        set: { project.setOverlayBackgroundPadding(elementID, x: $0.rounded(), y: nil) }
                    ),
                    precision: 0
                )
                .disabled(!isEnabled)
                InspectorDenseAxisField(
                    axis: "Y",
                    value: Binding(
                        get: { element.style.backgroundPaddingY },
                        set: { project.setOverlayBackgroundPadding(elementID, x: nil, y: $0.rounded()) }
                    ),
                    precision: 0
                )
                .disabled(!isEnabled)
            }
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseRow(label: "Fade Out") {
            Toggle("", isOn: Binding(
                get: { element.style.backgroundFadeOutEnabled },
                set: { project.setOverlayBackgroundFadeOutEnabled(elementID, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Fade Amount",
            value: Binding(
                get: { element.style.backgroundFadeOutAmount },
                set: { project.setOverlayBackgroundFadeOutAmount(elementID, amount: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.backgroundFadeOutAmount * 100),
            isEnabled: isEnabled && element.style.backgroundFadeOutEnabled
        )
        InspectorDenseSliderRow(
            label: "Blur",
            value: Binding(
                get: { element.style.backgroundBlurRadius },
                set: { project.setOverlayBackgroundBlurRadius(elementID, radius: $0.quantizedNumeric(to: 0.5)) }
            ),
            range: 0...40,
            displayText: String(format: "%.1f", element.style.backgroundBlurRadius),
            isEnabled: isEnabled
        )
    }

    @ViewBuilder
    private func effectsSection(_ element: OverlayElement) -> some View {
        let isEnabled = element.style.shadowEnabled
        InspectorDenseSliderRow(
            label: "Opacity",
            value: Binding(
                get: { element.style.shadowOpacity },
                set: { project.setOverlayShadowOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.shadowOpacity * 100),
            isEnabled: isEnabled
        )
        InspectorDenseSliderRow(
            label: "Radius",
            value: Binding(
                get: { element.style.shadowRadius },
                set: { project.setOverlayShadowRadius(elementID, radius: $0.rounded()) }
            ),
            range: 0...24,
            displayText: "\(Int(element.style.shadowRadius.rounded()))",
            isEnabled: isEnabled
        )
        InspectorDenseRow(label: "Offset") {
            HStack(spacing: NumericTokens.space2) {
                InspectorDenseAxisField(
                    axis: "X",
                    value: Binding(
                        get: { element.style.shadowOffsetX },
                        set: { project.setOverlayShadowOffset(elementID, x: $0.rounded(), y: nil) }
                    ),
                    precision: 0
                )
                .disabled(!isEnabled)
                InspectorDenseAxisField(
                    axis: "Y",
                    value: Binding(
                        get: { element.style.shadowOffsetY },
                        set: { project.setOverlayShadowOffset(elementID, x: nil, y: $0.rounded()) }
                    ),
                    precision: 0
                )
                .disabled(!isEnabled)
            }
            .opacity(isEnabled ? 1 : 0.5)
        }
    }

    // MARK: - Composite components

    @ViewBuilder
    private func sectionView<Body: View, Accessory: View>(
        _ section: NumericSection,
        element: OverlayElement,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
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
                accessory()
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

    @ViewBuilder
    private func backgroundEnabledToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.backgroundEnabled },
            set: { project.setOverlayBackgroundEnabled(elementID, enabled: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }

    @ViewBuilder
    private func labelEnabledToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.showLabel },
            set: { project.setOverlayShowLabel(elementID, showLabel: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }

    @ViewBuilder
    private func unitEnabledToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.showUnit },
            set: { project.setOverlayShowUnit(elementID, showUnit: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }

    @ViewBuilder
    private func iconEnabledToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.iconEnabled },
            set: { project.setOverlayIconEnabled(elementID, enabled: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }

    private func supportsHeartRateZoneColoring(_ element: OverlayElement) -> Bool {
        element.type == .heartRate || element.type == .heartRateZone
    }

    @ViewBuilder
    private func shadowEnabledToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.shadowEnabled },
            set: { project.setOverlayShadowEnabled(elementID, enabled: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
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

    private func previewValue(for element: OverlayElement) -> String {
        OverlayValueFormatter.value(
            for: element,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }

    static var fontPresets: [String] { FontLibraryManager.shared.effectiveFavorites }
    static let colorPresets: [(name: String, color: OverlayColor)] = [
        ("White", .white), ("Black", .black), ("Red", .red), ("Orange", .orange),
        ("Yellow", .yellow), ("Green", .green), ("Blue", .blue), ("Cyan", .cyan),
        ("Purple", .purple), ("Pink", .pink)
    ]
}

// MARK: - Header

struct NumericOverlayHeader: View {
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
                Image(systemName: element.type.defaultNumericIconSystemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Numeric Overlay")
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

// MARK: - Reusable Inspector dense components

enum NumericSection: String, CaseIterable {
    case content
    case layout
    case typography
    case label
    case unit
    case icon
    case background
    case effects

    var title: String {
        switch self {
        case .content: "Content"
        case .layout: "Layout"
        case .typography: "Value"
        case .label: "Label"
        case .unit: "Unit"
        case .icon: "Icon"
        case .background: "Background"
        case .effects: "Shadow"
        }
    }

    var systemImage: String {
        switch self {
        case .content: "list.bullet.rectangle"
        case .layout: "scope"
        case .typography: "textformat"
        case .label: "textformat.abc"
        case .unit: "character.textbox"
        case .icon: "star"
        case .background: "rectangle.fill"
        case .effects: "square.fill.on.square.fill"
        }
    }
}

private extension NumericOverlayDetailView {
    /// Row label for the label-alignment segmented control — flips between
    /// horizontal and vertical wording so the meaning is obvious for a
    /// stacked vs. side-attached label.
    func alignRowLabel(for position: OverlayTextAttachmentPosition) -> String {
        switch position {
        case .top, .bottom: "Align"
        case .leading, .trailing: "Anchor"
        }
    }

    func alignSystemImage(for alignment: OverlayTextAlignment, position: OverlayTextAttachmentPosition) -> String {
        switch position {
        case .top, .bottom:
            switch alignment {
            case .leading: "text.alignleft"
            case .center: "text.aligncenter"
            case .trailing: "text.alignright"
            }
        case .leading, .trailing:
            switch alignment {
            case .leading: "arrow.up.to.line"
            case .center: "minus"
            case .trailing: "arrow.down.to.line"
            }
        }
    }
}

private extension OverlayTextAttachmentPosition {
    var compactInspectorLabel: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bot"
        case .leading: "Left"
        case .trailing: "Right"
        }
    }
}

private extension OverlayFontWeight {
    var compactInspectorLabel: String {
        switch self {
        case .regular: "Reg"
        case .medium: "Med"
        case .semibold: "Semi"
        case .bold: "Bold"
        }
    }
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
