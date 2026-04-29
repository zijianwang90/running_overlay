import SwiftUI

/// Shared Background inspector used by overlay detail panels.
/// The section owns the header, on/off switch, and disclosure state so callers
/// can add the complete module without duplicating Numeric-style chrome.
struct OverlayBackgroundInspectorModule: View {
    @EnvironmentObject private var project: ProjectDocument

    let elementID: OverlayElement.ID
    let element: OverlayElement
    @State private var isExpanded = true

    var body: some View {
        CollapsibleBackgroundInspectorSection(
            isExpanded: $isExpanded,
            isOn: element.style.backgroundEnabled,
            onSetEnabled: { project.setOverlayBackgroundEnabled(elementID, enabled: $0) }
        ) {
            OverlayBackgroundInspectorRows(
                isOn: element.style.backgroundEnabled,
                color: element.style.backgroundColor,
                opacity: element.style.backgroundOpacity,
                radius: element.style.backgroundRadius,
                paddingX: element.style.backgroundPaddingX,
                paddingY: element.style.backgroundPaddingY,
                blur: element.style.backgroundBlurRadius,
                onSetColor: { project.setOverlayBackgroundColor(elementID, color: $0) },
                onSetOpacity: { project.setOverlayBackgroundOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) },
                onSetRadius: { project.setOverlayBackgroundRadius(elementID, radius: $0.rounded()) },
                onSetPaddingX: { project.setOverlayBackgroundPadding(elementID, x: $0.rounded(), y: nil) },
                onSetPaddingY: { project.setOverlayBackgroundPadding(elementID, x: nil, y: $0.rounded()) },
                onSetBlur: { project.setOverlayBackgroundBlurRadius(elementID, radius: $0.quantizedNumeric(to: 0.5)) }
            )
        }
    }
}

struct CollapsibleBackgroundInspectorSection<Content: View>: View {
    @Binding var isExpanded: Bool
    let isOn: Bool
    let onSetEnabled: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "rectangle.fill")
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text("Background")
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

struct OverlayBackgroundInspectorRows: View {
    let isOn: Bool
    let color: OverlayColor
    let opacity: Double
    let radius: Double
    let paddingX: Double
    let paddingY: Double
    let blur: Double

    let onSetColor: (OverlayColor) -> Void
    let onSetOpacity: (Double) -> Void
    let onSetRadius: (Double) -> Void
    let onSetPaddingX: (Double) -> Void
    let onSetPaddingY: (Double) -> Void
    let onSetBlur: (Double) -> Void

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
            label: "Radius",
            value: Binding(get: { radius }, set: onSetRadius),
            range: 0...64,
            displayText: "\(Int(radius.rounded()))",
            isEnabled: isOn
        )
        InspectorDenseRow(label: "Padding") {
            InspectorDenseAxisField(axis: "X", value: Binding(get: { paddingX }, set: onSetPaddingX), precision: 0)
                .disabled(!isOn)
            InspectorDenseAxisField(axis: "Y", value: Binding(get: { paddingY }, set: onSetPaddingY), precision: 0)
                .disabled(!isOn)
        }
        .opacity(isOn ? 1 : 0.5)
        .disabled(!isOn)
        InspectorDenseSliderRow(
            label: "Blur",
            value: Binding(get: { blur }, set: onSetBlur),
            range: 0...40,
            displayText: String(format: "%.1f", blur),
            isEnabled: isOn
        )
    }
}
