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
                        sectionView(.color, element: element) { colorSection(element) }
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

    // MARK: - Sections

    @ViewBuilder
    private func contentSection(_ element: OverlayElement) -> some View {
        let units = OverlayUnitOption.options(for: element.type)
        InspectorDenseRow(label: "Style") {
            Menu {
                ForEach(OverlayTextPreset.numericPresets) { preset in
                    Button {
                        project.applyOverlayTextPreset(elementID, textPreset: preset)
                    } label: {
                        if preset == element.style.textPreset {
                            Label(preset.compactDisplayLabel, systemImage: "checkmark")
                        } else {
                            Text(preset.compactDisplayLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.textPreset.compactDisplayLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        if units.count > 1 {
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
            OverlayLayoutRows(
                elementID: elementID,
                opacityBinding: Binding(
                    get: { project.selectedOverlay(elementID)?.style.backgroundOpacity ?? 0 },
                    set: { project.setOverlayBackgroundOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
                )
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
                Text(weight.label)
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
                Text(position.label)
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
                Text(position.label)
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
                Text(weight.label)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private func colorSection(_ element: OverlayElement) -> some View {
        let accentEnabled = accentApplies(to: element.style.textPreset)
        InspectorDenseRow(label: "Accent") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.accentColor
            ) { color in
                project.setOverlayAccentColor(elementID, color: color)
            }
            .disabled(!accentEnabled)
            .opacity(accentEnabled ? 1 : 0.5)
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
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }

    private func previewValue(for element: OverlayElement) -> String {
        OverlayValueFormatter.value(
            for: element,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }

    static let fontPresets = ["SF Pro", "Avenir Next", "Helvetica Neue", "Menlo"]
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
                Image(systemName: element.type.numericIcon)
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
    case color
    case background
    case effects

    var title: String {
        switch self {
        case .content: "Content"
        case .layout: "Layout"
        case .typography: "Value"
        case .label: "Label"
        case .unit: "Unit"
        case .color: "Color"
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
        case .color: "paintpalette"
        case .background: "rectangle.fill"
        case .effects: "square.fill.on.square.fill"
        }
    }
}

private extension NumericOverlayDetailView {
    func accentApplies(to preset: OverlayTextPreset) -> Bool {
        switch preset {
        case .splitLabel, .neonGlow, .racingStripe, .editorial, .digitalWatch, .accentBar, .sportNeon:
            true
        default:
            false
        }
    }
}

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
            ForEach(presets, id: \.name) { preset in
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
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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

// MARK: - Shared layout rows

/// Shared layout rows used by all overlay detail panels.
/// Canonical row set: Position (X/Y), Scale, Width, Height, Opacity.
/// Rotation is intentionally excluded.
struct OverlayLayoutRows: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    /// Provide a binding to show a Width slider; pass nil to hide it (e.g. square components).
    var widthBinding: Binding<Double>? = nil
    var widthRange: ClosedRange<Double> = 100...720
    var widthLabel: String = "Width"

    /// Provide a binding to show a Height slider; pass nil to hide it.
    var heightBinding: Binding<Double>? = nil
    var heightRange: ClosedRange<Double> = 52...720
    var heightLabel: String = "Height"

    /// Opacity row is part of the canonical layout surface.
    var opacityBinding: Binding<Double>
    var opacityRange: ClosedRange<Double> = 0...1
    var opacityLabel: String = "Opacity"
    var opacityDisplay: (Double) -> String = { String(format: "%.0f%%", $0 * 100) }

    var body: some View {
        if let element = project.selectedOverlay(elementID) {
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
                    set: { project.setOverlayScale(elementID, scale: ($0 / 0.05).rounded() * 0.05) }
                ),
                range: 0.25...4,
                displayText: String(format: "%.2fx", element.scale)
            )
            if let w = widthBinding {
                InspectorDenseSliderRow(
                    label: widthLabel,
                    value: w,
                    range: widthRange,
                    displayText: "\(Int(w.wrappedValue))"
                )
            }
            if let h = heightBinding {
                InspectorDenseSliderRow(
                    label: heightLabel,
                    value: h,
                    range: heightRange,
                    displayText: "\(Int(h.wrappedValue))"
                )
            }
            InspectorDenseSliderRow(
                label: opacityLabel,
                value: opacityBinding,
                range: opacityRange,
                displayText: opacityDisplay(opacityBinding.wrappedValue)
            )
        }
    }
}

/// Shared collapsible section wrapper for the Layout block.
/// This keeps title/icon/disclosure behavior consistent across all detail panels.
struct CollapsibleLayoutInspectorSection<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "scope")
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text("Layout")
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
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
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }

            if isExpanded {
                VStack(spacing: 0) { content() }
            }
        }
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

extension OverlayTextPreset {
    var compactDisplayLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayElementType {
    var numericIcon: String {
        switch self {
        case .heartRate: "heart"
        case .pace: "speedometer"
        case .calories: "flame"
        case .elapsedTime: "clock"
        case .realTime: "watch.analog"
        case .distance: "ruler"
        case .elevation: "mountain.2"
        case .cadence: "figure.run"
        case .power: "bolt"
        case .distanceTimeline: "waveform.path.ecg"
        case .elevationChart: "chart.line.uptrend.xyaxis"
        case .runningGauge: "gauge"
        case .routeMap: "map"
        case .verticalOscillation: "arrow.up.and.down"
        case .groundContactTime: "timer"
        case .strideLength: "arrow.left.and.right"
        case .verticalRatio: "percent"
        case .groundContactBalance: "scale.3d"
        case .temperature: "thermometer"
        case .grade: "arrow.up.right"
        case .lapList: "list.number"
        case .lapCard: "rectangle.badge.checkmark"
        case .lapLive: "stopwatch"
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
