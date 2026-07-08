import SwiftUI

struct IntervalWorkSummaryOverlayView: View {
    let element: OverlayElement
    let layout: IntervalWorkSummaryRenderLayout

    var body: some View {
        ZStack {
            if layout.isVisible {
                if element.style.backgroundEnabled {
                    RoundedRectangle(cornerRadius: layout.backgroundRadius, style: .continuous)
                        .fill(Color(numericOverlay: element.style.backgroundColor).opacity(element.style.backgroundOpacity))
                        .frame(width: layout.rect.width, height: layout.rect.height)
                        .intervalWorkSummaryShadow(element: element, layout: layout, isEnabled: true)
                        .overlay {
                            if element.style.borderEnabled {
                                RoundedRectangle(cornerRadius: layout.backgroundRadius, style: .continuous)
                                    .stroke(
                                        Color(numericOverlay: element.style.borderColor).opacity(element.style.borderOpacity),
                                        lineWidth: layout.borderWidth
                                    )
                            }
                        }
                }

                content
                    .padding(.horizontal, layout.backgroundPaddingX)
                    .padding(.vertical, layout.backgroundPaddingY)
                    .frame(width: layout.rect.width, height: layout.rect.height)
                    .intervalWorkSummaryGlobalGlow(element: element)
                    .intervalWorkSummaryShadow(element: element, layout: layout, isEnabled: !element.style.backgroundEnabled)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let labelStyle = layout.textItems[.componentLabel],
               labelStyle.style.isVisible,
               !layout.componentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(layout.componentLabel.uppercased())
                    .font(font(labelStyle))
                    .foregroundStyle(Color(numericOverlay: labelStyle.color))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            primaryMetric

            if !layout.secondaryItems.isEmpty {
                Spacer(minLength: 12)
                secondaryMetrics
            }

            Spacer(minLength: 0)
        }
    }

    private var primaryMetric: some View {
        VStack(spacing: 5) {
            if let valueStyle = layout.textItems[.primaryValue] {
                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text(layout.primary.value)
                        .font(font(valueStyle))
                        .foregroundStyle(Color(numericOverlay: valueStyle.color))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    if !layout.primary.unit.isEmpty {
                        Text(layout.primary.unit)
                            .font(font(valueStyle, scale: 0.34))
                            .foregroundStyle(Color(numericOverlay: valueStyle.color).opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            if let labelStyle = layout.textItems[.primaryLabel],
               labelStyle.style.isVisible,
               layout.primary.labelVisible {
                Text(layout.primary.label)
                    .font(font(labelStyle))
                    .foregroundStyle(Color(numericOverlay: labelStyle.color))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var secondaryMetrics: some View {
        HStack(spacing: 0) {
            ForEach(Array(layout.secondaryItems.enumerated()), id: \.offset) { index, item in
                secondaryMetric(item)
                    .frame(maxWidth: .infinity)
                if layout.style.dividerEnabled && index < layout.secondaryItems.count - 1 {
                    Rectangle()
                        .fill(Color(numericOverlay: layout.style.dividerColor).opacity(layout.style.dividerOpacity))
                        .frame(width: max(layout.style.dividerWidth, 0.5), height: layout.rect.height * 0.26)
                }
            }
        }
    }

    private func secondaryMetric(_ item: IntervalWorkSummaryMetricItem) -> some View {
        VStack(spacing: 4) {
            if let valueStyle = layout.textItems[.secondaryValue] {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(item.value)
                        .font(font(valueStyle))
                        .foregroundStyle(Color(numericOverlay: valueStyle.color))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    if !item.unit.isEmpty {
                        Text(item.unit)
                            .font(font(valueStyle, scale: 0.38))
                            .foregroundStyle(Color(numericOverlay: valueStyle.color).opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            if let labelStyle = layout.textItems[.secondaryLabel],
               labelStyle.style.isVisible,
               item.labelVisible {
                Text(item.label)
                    .font(font(labelStyle))
                    .foregroundStyle(Color(numericOverlay: labelStyle.color))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
    }

    private func font(_ item: IntervalWorkSummaryRenderLayout.TextItem) -> Font {
        .overlayFont(family: item.style.fontName, size: item.fontSize, overlayWeight: item.style.fontWeight)
    }

    private func font(_ item: IntervalWorkSummaryRenderLayout.TextItem, scale: Double) -> Font {
        .overlayFont(family: item.style.fontName, size: max(item.fontSize * scale, 6), overlayWeight: item.style.fontWeight)
    }
}

private extension View {
    func intervalWorkSummaryGlobalGlow(element: OverlayElement) -> some View {
        self
            .shadow(
                color: Color(numericOverlay: element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.72 : 0),
                radius: element.style.glowEnabled ? 9 + element.style.glowIntensity * 18 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color(numericOverlay: element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.35 : 0),
                radius: element.style.glowEnabled ? 18 + element.style.glowIntensity * 28 : 0,
                x: 0,
                y: 0
            )
    }

    func intervalWorkSummaryShadow(element: OverlayElement, layout: IntervalWorkSummaryRenderLayout, isEnabled: Bool) -> some View {
        self
            .shadow(
                color: Color(numericOverlay: element.style.shadowColor).opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity : 0),
                radius: layout.shadowRadius,
                x: layout.shadowOffsetX,
                y: layout.shadowOffsetY
            )
            .shadow(
                color: Color(numericOverlay: element.style.shadowColor).opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity * max(element.style.shadowThickness - 1, 0) * 0.32 : 0),
                radius: layout.shadowRadius * 1.8,
                x: layout.shadowOffsetX,
                y: layout.shadowOffsetY * 1.3
            )
    }
}
