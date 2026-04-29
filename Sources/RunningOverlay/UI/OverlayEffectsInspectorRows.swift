import SwiftUI

/// Shared Effects inspector used by overlay detail panels.
/// Effects has no section-level enable switch; each effect row controls itself.
struct OverlayEffectsInspectorModule: View {
    @EnvironmentObject private var project: ProjectDocument

    let elementID: OverlayElement.ID
    let element: OverlayElement
    @State private var isExpanded = true

    var body: some View {
        CollapsibleEffectsInspectorSection(isExpanded: $isExpanded) {
            OverlayEffectsInspectorRows(
                backgroundEnabled: element.style.backgroundEnabled,
                shadowEnabled: element.style.shadowEnabled,
                shadowColor: element.style.shadowColor,
                shadowOpacity: element.style.shadowOpacity,
                shadowRadius: element.style.shadowRadius,
                shadowThickness: element.style.shadowThickness,
                shadowOffsetX: element.style.shadowOffsetX,
                shadowOffsetY: element.style.shadowOffsetY,
                glowEnabled: element.style.glowEnabled,
                glowColor: element.style.glowColor,
                glowIntensity: element.style.glowIntensity,
                fadeOutEnabled: element.style.backgroundFadeOutEnabled,
                fadeAmount: element.style.backgroundFadeOutAmount,
                onSetShadowEnabled: { project.setOverlayShadowEnabled(elementID, enabled: $0) },
                onSetShadowColor: { project.setOverlayShadowColor(elementID, color: $0) },
                onSetShadowOpacity: { project.setOverlayShadowOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) },
                onSetShadowRadius: { project.setOverlayShadowRadius(elementID, radius: $0.rounded()) },
                onSetShadowThickness: { project.setOverlayShadowThickness(elementID, thickness: $0.quantizedNumeric(to: 0.25)) },
                onSetShadowOffsetX: { project.setOverlayShadowOffset(elementID, x: $0.rounded(), y: nil) },
                onSetShadowOffsetY: { project.setOverlayShadowOffset(elementID, x: nil, y: $0.rounded()) },
                onSetGlowEnabled: { project.setOverlayGlowEnabled(elementID, enabled: $0) },
                onSetGlowColor: { project.setOverlayGlowColor(elementID, color: $0) },
                onSetGlowIntensity: { project.setOverlayGlowIntensity(elementID, intensity: $0.quantizedNumeric(to: 0.05)) },
                onSetFadeOutEnabled: { project.setOverlayBackgroundFadeOutEnabled(elementID, enabled: $0) },
                onSetFadeAmount: { project.setOverlayBackgroundFadeOutAmount(elementID, amount: $0.quantizedNumeric(to: 0.05)) }
            )
        }
    }
}

struct CollapsibleEffectsInspectorSection<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "sparkles")
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text("Effects")
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(NumericTokens.textSecondary)
                        .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .frame(height: NumericTokens.sectionHeaderHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.16)) { isExpanded.toggle() }
            }

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(NumericTokens.borderSubtle, lineWidth: 1))
    }
}

struct OverlayEffectsInspectorRows: View {
    let backgroundEnabled: Bool
    let shadowEnabled: Bool
    let shadowColor: OverlayColor
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowThickness: Double
    let shadowOffsetX: Double
    let shadowOffsetY: Double
    let glowEnabled: Bool
    let glowColor: OverlayColor
    let glowIntensity: Double
    let fadeOutEnabled: Bool
    let fadeAmount: Double

    let onSetShadowEnabled: (Bool) -> Void
    let onSetShadowColor: (OverlayColor) -> Void
    let onSetShadowOpacity: (Double) -> Void
    let onSetShadowRadius: (Double) -> Void
    let onSetShadowThickness: (Double) -> Void
    let onSetShadowOffsetX: (Double) -> Void
    let onSetShadowOffsetY: (Double) -> Void
    let onSetGlowEnabled: (Bool) -> Void
    let onSetGlowColor: (OverlayColor) -> Void
    let onSetGlowIntensity: (Double) -> Void
    let onSetFadeOutEnabled: (Bool) -> Void
    let onSetFadeAmount: (Double) -> Void

    var body: some View {
        InspectorDenseRow(label: "Shadow") {
            Toggle("", isOn: Binding(get: { shadowEnabled }, set: onSetShadowEnabled))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        InspectorDenseRow(label: "Shadow Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: shadowColor, action: onSetShadowColor)
                .disabled(!shadowEnabled)
                .opacity(shadowEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Shadow Opacity",
            value: Binding(get: { shadowOpacity }, set: onSetShadowOpacity),
            range: 0...1,
            displayText: String(format: "%.0f%%", shadowOpacity * 100),
            isEnabled: shadowEnabled
        )
        InspectorDenseSliderRow(
            label: "Shadow Radius",
            value: Binding(get: { shadowRadius }, set: onSetShadowRadius),
            range: 0...32,
            displayText: "\(Int(shadowRadius.rounded()))",
            isEnabled: shadowEnabled
        )
        InspectorDenseSliderRow(
            label: "Shadow Thickness",
            value: Binding(get: { shadowThickness }, set: onSetShadowThickness),
            range: 1...4,
            displayText: String(format: "%.2gx", shadowThickness),
            isEnabled: shadowEnabled
        )
        InspectorDenseRow(label: "Shadow Offset") {
            InspectorDenseAxisField(axis: "X", value: Binding(get: { shadowOffsetX }, set: onSetShadowOffsetX), precision: 0)
                .disabled(!shadowEnabled)
            InspectorDenseAxisField(axis: "Y", value: Binding(get: { shadowOffsetY }, set: onSetShadowOffsetY), precision: 0)
                .disabled(!shadowEnabled)
        }
        .opacity(shadowEnabled ? 1 : 0.5)
        .disabled(!shadowEnabled)

        InspectorDenseRow(label: "Glow") {
            Toggle("", isOn: Binding(get: { glowEnabled }, set: onSetGlowEnabled))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        InspectorDenseRow(label: "Glow Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: glowColor, action: onSetGlowColor)
                .disabled(!glowEnabled)
                .opacity(glowEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Glow Intensity",
            value: Binding(get: { glowIntensity }, set: onSetGlowIntensity),
            range: 0...1,
            displayText: String(format: "%.0f%%", glowIntensity * 100),
            isEnabled: glowEnabled
        )

        InspectorDenseRow(label: "Fade Out") {
            Toggle("", isOn: Binding(get: { fadeOutEnabled }, set: onSetFadeOutEnabled))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(!backgroundEnabled)
                .opacity(backgroundEnabled ? 1 : 0.5)
        }
        InspectorDenseSliderRow(
            label: "Fade Amount",
            value: Binding(get: { fadeAmount }, set: onSetFadeAmount),
            range: 0...1,
            displayText: String(format: "%.0f%%", fadeAmount * 100),
            isEnabled: backgroundEnabled && fadeOutEnabled
        )
    }
}
