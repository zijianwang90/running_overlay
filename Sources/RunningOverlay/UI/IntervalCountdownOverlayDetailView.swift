import SwiftUI

struct IntervalCountdownOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var layoutOpen = true
    @State private var countdownOpen = true
    @State private var progressOpen = true
    @State private var textOpen = true

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: $layoutOpen) {
                            OverlayLayoutInspectorRows(
                                elementID: elementID,
                                widthBinding: styleBinding(\.size, current: element.style.intervalCountdown),
                                widthRange: 160...720,
                                heightBinding: styleBinding(\.size, current: element.style.intervalCountdown),
                                heightRange: 160...720
                            )
                        }
                        section("Countdown", systemImage: "timer", isOpen: $countdownOpen) {
                            visibilityRows(element.style.intervalCountdown)
                        }
                        section("Progress Ring", systemImage: "circle.dashed", isOpen: $progressOpen) {
                            progressRows(element.style.intervalCountdown)
                        }
                        section("Text", systemImage: "textformat", isOpen: $textOpen) {
                            textRows(element.style.intervalCountdown)
                        }
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
            }
            .buttonStyle(.plain)

            Image(systemName: "timer.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumericTokens.accentBlue)
                .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("Interval Countdown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Charts")
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
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
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
    }

    private func section<Content: View>(_ title: String, systemImage: String, isOpen: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture { isOpen.wrappedValue.toggle() }
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
            if isOpen.wrappedValue {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    @ViewBuilder
    private func visibilityRows(_ style: IntervalCountdownStyle) -> some View {
        ForEach(IntervalCountdownTextRole.allCases.filter(\.isHideable)) { role in
            InspectorDenseRow(label: role.label) {
                miniToggle(textVisibilityBinding(role, current: style))
            }
        }
    }

    @ViewBuilder
    private func progressRows(_ style: IntervalCountdownStyle) -> some View {
        InspectorDenseSliderRow(
            label: "Ring Width",
            value: styleBinding(\.ringWidth, current: style),
            range: 4...48,
            displayText: String(format: "%.1f", style.ringWidth)
        )
        InspectorDenseSliderRow(
            label: "Track Opacity",
            value: styleBinding(\.trackOpacity, current: style),
            range: 0...1,
            displayText: String(format: "%.0f%%", style.trackOpacity * 100)
        )
        InspectorDenseRow(label: "Fill Color") {
            InspectorDenseSegmented(values: IntervalCountdownColorMode.allCases, selection: styleBinding(\.fillColorMode, current: style)) {
                Text($0.label).tag($0)
            }
        }
        if style.fillColorMode == .customColor {
            InspectorDenseRow(label: "Custom Fill") {
                InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.fillCustomColor) { color in
                    project.mutateIntervalCountdownStyle(elementID) { $0.fillCustomColor = color }
                }
            }
        }
        InspectorDenseRow(label: "Rounded Ends") {
            miniToggle(styleBinding(\.roundedLineCap, current: style))
        }
        InspectorDenseRow(label: "Ring Glow") {
            miniToggle(styleBinding(\.ringGlowEnabled, current: style))
        }
        InspectorDenseSliderRow(
            label: "Glow Intensity",
            value: styleBinding(\.ringGlowIntensity, current: style),
            range: 0...1,
            displayText: String(format: "%.0f%%", style.ringGlowIntensity * 100),
            isEnabled: style.ringGlowEnabled
        )
    }

    @ViewBuilder
    private func textRows(_ style: IntervalCountdownStyle) -> some View {
        ForEach(IntervalCountdownTextRole.allCases) { role in
            textRoleRows(role, style: style.textStyle(for: role))
        }
    }

    @ViewBuilder
    private func textRoleRows(_ role: IntervalCountdownTextRole, style: IntervalCountdownTextStyle) -> some View {
        if role.isHideable {
            InspectorDenseRow(label: "\(role.label) Visible") {
                miniToggle(textVisibilityBinding(role, current: currentStyle))
            }
        }
        InspectorDenseRow(label: "\(role.label) Font") {
            fontMenu(selected: style.fontName) { fontName in
                updateTextStyle(role) { $0.fontName = fontName }
            }
        }
        InspectorDenseSliderRow(
            label: "\(role.label) Size",
            value: textBinding(role, \.fontSize, current: style),
            range: 8...120,
            displayText: "\(Int(style.fontSize.rounded()))"
        )
        InspectorDenseRow(label: "\(role.label) Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: textBinding(role, \.fontWeight, current: style)) {
                Text($0.label).tag($0)
            }
        }
        InspectorDenseRow(label: "\(role.label) Color") {
            InspectorDenseSegmented(values: IntervalCountdownColorMode.allCases, selection: textBinding(role, \.colorMode, current: style)) {
                Text($0.label).tag($0)
            }
        }
        if style.colorMode == .customColor {
            InspectorDenseRow(label: "\(role.label) Custom") {
                InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.customColor) { color in
                    updateTextStyle(role) { $0.customColor = color }
                }
            }
        }
    }

    private var currentStyle: IntervalCountdownStyle {
        project.selectedOverlay(elementID)?.style.intervalCountdown ?? .default
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

    private func miniToggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
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
        .menuStyle(.borderlessButton)
        .frame(height: NumericTokens.controlHeight)
    }

    private func styleBinding<Value>(_ keyPath: WritableKeyPath<IntervalCountdownStyle, Value>, current: IntervalCountdownStyle) -> Binding<Value> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { value in project.mutateIntervalCountdownStyleContinuous(elementID) { $0[keyPath: keyPath] = value } }
        )
    }

    private func textVisibilityBinding(_ role: IntervalCountdownTextRole, current: IntervalCountdownStyle) -> Binding<Bool> {
        Binding(
            get: { current.textStyle(for: role).isVisible },
            set: { visible in
                guard role.isHideable else { return }
                updateTextStyle(role) { $0.isVisible = visible }
            }
        )
    }

    private func textBinding<Value>(
        _ role: IntervalCountdownTextRole,
        _ keyPath: WritableKeyPath<IntervalCountdownTextStyle, Value>,
        current: IntervalCountdownTextStyle
    ) -> Binding<Value> {
        Binding(
            get: { current[keyPath: keyPath] },
            set: { value in
                updateTextStyle(role) { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func updateTextStyle(_ role: IntervalCountdownTextRole, mutate: @escaping (inout IntervalCountdownTextStyle) -> Void) {
        project.mutateIntervalCountdownStyleContinuous(elementID) { style in
            var textStyle = style.textStyle(for: role)
            mutate(&textStyle)
            style.setTextStyle(textStyle, for: role)
        }
    }
}
