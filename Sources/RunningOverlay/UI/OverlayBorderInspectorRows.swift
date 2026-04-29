import SwiftUI

/// Shared Border inspector used by overlay detail panels.
struct OverlayBorderInspectorModule: View {
    @EnvironmentObject private var project: ProjectDocument

    let elementID: OverlayElement.ID
    let element: OverlayElement
    @State private var isExpanded = true

    var body: some View {
        CollapsibleBorderInspectorSection(
            isExpanded: $isExpanded,
            isOn: element.style.borderEnabled,
            onSetEnabled: { project.setOverlayBorderEnabled(elementID, enabled: $0) }
        ) {
            OverlayBorderInspectorRows(
                isOn: element.style.borderEnabled,
                color: element.style.borderColor,
                opacity: element.style.borderOpacity,
                width: element.style.borderWidth,
                onSetColor: { project.setOverlayBorderColor(elementID, color: $0) },
                onSetOpacity: { project.setOverlayBorderOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) },
                onSetWidth: { project.setOverlayBorderWidth(elementID, width: $0.quantizedNumeric(to: 0.5)) }
            )
        }
    }
}

struct CollapsibleBorderInspectorSection<Content: View>: View {
    @Binding var isExpanded: Bool
    let isOn: Bool
    let onSetEnabled: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "rectangle")
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text("Border")
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(get: { isOn }, set: onSetEnabled))
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
            .onTapGesture {
                isExpanded.toggle()
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(NumericTokens.borderSubtle, lineWidth: 1))
    }
}

struct OverlayBorderInspectorRows: View {
    let isOn: Bool
    let color: OverlayColor
    let opacity: Double
    let width: Double

    let onSetColor: (OverlayColor) -> Void
    let onSetOpacity: (Double) -> Void
    let onSetWidth: (Double) -> Void

    var body: some View {
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: color, action: onSetColor)
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Opacity",
            value: Binding(get: { opacity }, set: onSetOpacity),
            range: 0...1,
            displayText: String(format: "%.0f%%", opacity * 100),
            isEnabled: isOn
        )
        InspectorDenseSliderRow(
            label: "Thickness",
            value: Binding(get: { width }, set: onSetWidth),
            range: 0.5...12,
            displayText: String(format: "%.1f", width),
            isEnabled: isOn
        )
    }
}
