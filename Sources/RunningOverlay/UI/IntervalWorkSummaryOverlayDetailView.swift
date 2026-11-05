import SwiftUI

struct IntervalWorkSummaryOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var layoutOpen = true
    @State private var timingOpen = true
    @State private var contentOpen = true
    @State private var textOpen = true

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: $layoutOpen) {
                            OverlayLayoutInspectorRows(
                                elementID: elementID,
                                widthBinding: styleBinding(\.width, current: element.style.intervalWorkSummary),
                                widthRange: 240...900,
                                heightBinding: styleBinding(\.height, current: element.style.intervalWorkSummary),
                                heightRange: 140...520
                            )
                        }
                        section("Timing", isOpen: $timingOpen) {
                            timingRows(element.style.intervalWorkSummary)
                        }
                        section("Content", isOpen: $contentOpen) {
                            contentRows(element.style.intervalWorkSummary)
                        }
                        section("Text", isOpen: $textOpen) {
                            textRows(element.style.intervalWorkSummary)
                        }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                Spacer()
            }
        }
    }

    private func section<Content: View>(_ title: String, isOpen: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        let body = content()
        return InspectorCollapsibleSection(title: title, isExpanded: isOpen) { body }
    }

    @ViewBuilder
    private func timingRows(_ style: IntervalWorkSummaryStyle) -> some View {
        InspectorDenseSliderRow(
            label: "Duration",
            value: styleBinding(\.displayDuration, current: style),
            range: 1...20,
            displayText: String(format: "%.1fs", style.displayDuration)
        )
        InspectorDenseRow(label: "Units") {
            InspectorDenseSegmented(values: IntervalWorkSummaryUnitSystem.allCases, selection: styleBinding(\.unitSystem, current: style)) {
                Text($0.label).tag($0)
            }
        }
    }

    @ViewBuilder
    private func contentRows(_ style: IntervalWorkSummaryStyle) -> some View {
        InspectorDenseRow(label: "Label") {
            TextField("WORK SUMMARY", text: styleBinding(\.componentLabel, current: style))
                .textFieldStyle(.plain)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        InspectorDenseRow(label: "Label Align") {
            InspectorDenseSegmented(values: OverlayTextAlignment.allCases, selection: labelAlignmentBinding(current: style)) {
                Text($0.label).tag($0)
            }
        }
        InspectorDenseRow(label: "Accent") {
            InspectorDenseSegmented(values: IntervalCountdownColorMode.allCases, selection: styleBinding(\.accentColorMode, current: style)) {
                Text($0.label).tag($0)
            }
        }
        if style.accentColorMode == .customColor {
            InspectorDenseRow(label: "Accent Color") {
                InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.accentCustomColor) { color in
                    project.mutateIntervalWorkSummaryStyle(elementID) { $0.accentCustomColor = color }
                }
            }
        }
        InspectorDenseRow(label: "Primary") {
            metricMenu(selected: style.primaryMetric) { metric in
                project.mutateIntervalWorkSummaryStyle(elementID) { $0.primaryMetric = metric }
            }
        }
        InspectorDenseRow(label: "Primary Label") {
            miniToggle(styleBinding(\.primaryLabelVisible, current: style))
        }
        ForEach(0..<3, id: \.self) { index in
            slotRows(index: index, style: style)
        }
        InspectorDenseRow(label: "Dividers") {
            miniToggle(styleBinding(\.dividerEnabled, current: style))
        }
        InspectorDenseSliderRow(
            label: "Divider Opacity",
            value: styleBinding(\.dividerOpacity, current: style),
            range: 0...1,
            displayText: String(format: "%.0f%%", style.dividerOpacity * 100),
            isEnabled: style.dividerEnabled
        )
    }

    @ViewBuilder
    private func slotRows(index: Int, style: IntervalWorkSummaryStyle) -> some View {
        let slot = style.normalizedSecondarySlots[index]
        InspectorDenseRow(label: "Metric \(index + 1)") {
            miniToggle(slotVisibleBinding(index, current: style))
            metricMenu(selected: slot.metric) { metric in
                updateSlot(index) { $0.metric = metric }
            }
        }
        InspectorDenseRow(label: "Label \(index + 1)") {
            TextField(slot.metric.shortLabel, text: slotCustomLabelBinding(index, current: style))
                .textFieldStyle(.plain)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .disabled(!slot.isVisible)
        InspectorDenseRow(label: "Show Label \(index + 1)") {
            miniToggle(slotLabelVisibleBinding(index, current: style))
        }
        .disabled(!slot.isVisible)
    }

    @ViewBuilder
    private func textRows(_ style: IntervalWorkSummaryStyle) -> some View {
        ForEach(IntervalWorkSummaryTextRole.allCases) { role in
            textRoleGroup(role, style: style.textStyle(for: role))
        }
    }

    private func textRoleGroup(_ role: IntervalWorkSummaryTextRole, style: IntervalWorkSummaryTextStyle) -> some View {
        VStack(spacing: 0) {
            textGroupHeader(
                role.label,
                visibility: role.isHideable ? textVisibilityBinding(role, current: currentStyle) : nil
            )
            textRoleRows(role, style: style)
        }
    }

    @ViewBuilder
    private func textRoleRows(_ role: IntervalWorkSummaryTextRole, style: IntervalWorkSummaryTextStyle) -> some View {
        InspectorDenseRow(label: "Font") {
            fontMenu(selected: style.fontName) { fontName in
                updateTextStyle(role) { $0.fontName = fontName }
            }
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: textBinding(role, \.fontSize, current: style),
            range: 8...120,
            displayText: "\(Int(style.fontSize.rounded()))"
        )
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: textBinding(role, \.fontWeight, current: style)) {
                Text($0.label).tag($0)
            }
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSegmented(values: IntervalCountdownColorMode.allCases, selection: textBinding(role, \.colorMode, current: style)) {
                Text($0.label).tag($0)
            }
        }
        if style.colorMode == .customColor {
            InspectorDenseRow(label: "Custom") {
                InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.customColor) { color in
                    updateTextStyle(role) { $0.customColor = color }
                }
            }
        }
    }

    private func textGroupHeader(_ title: String, visibility: Binding<Bool>?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NumericTokens.textPrimary)
            Spacer()
            if let visibility {
                miniToggle(visibility)
            }
        }
        .frame(height: 32)
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .background(NumericTokens.panelBackground)
        .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
    }

    private var currentStyle: IntervalWorkSummaryStyle {
        project.selectedOverlay(elementID)?.style.intervalWorkSummary ?? .default
    }

    private func miniToggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding)
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
    }

    private func metricMenu(selected: IntervalWorkSummaryMetric, action: @escaping (IntervalWorkSummaryMetric) -> Void) -> some View {
        Menu {
            ForEach(IntervalWorkSummaryMetric.allCases) { metric in
                Button {
                    action(metric)
                } label: {
                    if metric == selected {
                        Label(metric.label, systemImage: "checkmark")
                    } else {
                        Text(metric.label)
                    }
                }
            }
        } label: {
            InspectorDenseMenuLabel(title: selected.label)
        }
        .inspectorMenuStyle()
        .frame(height: NumericTokens.controlHeight)
    }

    private func fontMenu(selected: String, action: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                Button {
                    action(name)
                } label: {
                    if name == selected {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            InspectorDenseMenuLabel(title: selected.isEmpty ? "Default" : selected)
        }
        .inspectorMenuStyle()
        .frame(height: NumericTokens.controlHeight)
    }

    private func styleBinding<Value>(_ keyPath: WritableKeyPath<IntervalWorkSummaryStyle, Value>, current: IntervalWorkSummaryStyle) -> Binding<Value> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { value in project.mutateIntervalWorkSummaryStyleContinuous(elementID) { $0[keyPath: keyPath] = value } }
        )
    }

    private func labelAlignmentBinding(current: IntervalWorkSummaryStyle) -> Binding<OverlayTextAlignment> {
        Binding(
            get: { current.resolvedComponentLabelAlignment },
            set: { value in project.mutateIntervalWorkSummaryStyleContinuous(elementID) { $0.componentLabelAlignment = value } }
        )
    }

    private func slotVisibleBinding(_ index: Int, current: IntervalWorkSummaryStyle) -> Binding<Bool> {
        Binding(
            get: { current.normalizedSecondarySlots[index].isVisible },
            set: { visible in updateSlot(index) { $0.isVisible = visible } }
        )
    }

    private func slotLabelVisibleBinding(_ index: Int, current: IntervalWorkSummaryStyle) -> Binding<Bool> {
        Binding(
            get: { current.normalizedSecondarySlots[index].labelVisible },
            set: { visible in updateSlot(index) { $0.labelVisible = visible } }
        )
    }

    private func slotCustomLabelBinding(_ index: Int, current: IntervalWorkSummaryStyle) -> Binding<String> {
        Binding(
            get: { current.normalizedSecondarySlots[index].customLabel },
            set: { label in updateSlot(index) { $0.customLabel = String(label.prefix(24)) } }
        )
    }

    private func updateSlot(_ index: Int, mutate: @escaping (inout IntervalWorkSummarySlot) -> Void) {
        project.mutateIntervalWorkSummaryStyleContinuous(elementID) { style in
            var slots = style.normalizedSecondarySlots
            guard slots.indices.contains(index) else { return }
            mutate(&slots[index])
            style.secondarySlots = Array(slots.prefix(3))
        }
    }

    private func textVisibilityBinding(_ role: IntervalWorkSummaryTextRole, current: IntervalWorkSummaryStyle) -> Binding<Bool> {
        Binding(
            get: { current.textStyle(for: role).isVisible },
            set: { visible in
                guard role.isHideable else { return }
                updateTextStyle(role) { $0.isVisible = visible }
            }
        )
    }

    private func textBinding<Value>(
        _ role: IntervalWorkSummaryTextRole,
        _ keyPath: WritableKeyPath<IntervalWorkSummaryTextStyle, Value>,
        current: IntervalWorkSummaryTextStyle
    ) -> Binding<Value> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { value in updateTextStyle(role) { $0[keyPath: keyPath] = value } }
        )
    }

    private func updateTextStyle(_ role: IntervalWorkSummaryTextRole, mutate: @escaping (inout IntervalWorkSummaryTextStyle) -> Void) {
        project.mutateIntervalWorkSummaryStyleContinuous(elementID) { style in
            var textStyle = style.textStyle(for: role)
            mutate(&textStyle)
            style.setTextStyle(textStyle, for: role)
        }
    }
}
