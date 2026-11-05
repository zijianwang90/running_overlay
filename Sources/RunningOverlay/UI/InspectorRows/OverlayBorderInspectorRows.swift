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
        InspectorCollapsibleSection(
            title: "Border",
            isExpanded: $isExpanded,
            isOn: Binding(get: { isOn }, set: onSetEnabled),
            content: content
        )
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
