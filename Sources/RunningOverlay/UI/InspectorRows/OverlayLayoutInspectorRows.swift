import SwiftUI

/// Shared layout rows used by all overlay detail panels.
/// Canonical row set: Position (X/Y), Scale, Width, Height, Opacity.
/// Rotation is intentionally excluded.
struct OverlayLayoutInspectorRows: View {
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

    /// Opacity row is part of the canonical layout surface and applies to the whole element.
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
                value: Binding(
                    get: { element.opacity },
                    set: { project.setOverlayOpacity(elementID, opacity: $0.quantizedNumeric(to: 0.05)) }
                ),
                range: opacityRange,
                displayText: opacityDisplay(element.opacity)
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
