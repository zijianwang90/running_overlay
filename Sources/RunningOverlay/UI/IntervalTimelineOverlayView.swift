import SwiftUI

struct IntervalTimelineOverlayView: View {
    let element: OverlayElement
    let layout: IntervalTimelineRenderLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(Color(intervalTimeline: element.style.backgroundColor).opacity(element.style.backgroundEnabled ? element.style.backgroundOpacity : 0))
                .intervalTimelineShadow(element: element)

            if element.style.borderEnabled {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Color(intervalTimeline: element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
            }

            ZStack(alignment: .topLeading) {
                ForEach(layout.segments) { segment in
                    segmentView(segment)
                }
                overflowHints
                if layout.style.markerEnabled {
                    markerView
                }
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var overflowHints: some View {
        let midY = layout.contentRect.midY - layout.rect.minY
        return ZStack(alignment: .topLeading) {
            if layout.style.overflowHintEnabled && layout.leftOverflowCount > 0 {
                ellipsis().position(x: layout.overflowEllipsisInset, y: midY)
            }
            if layout.style.overflowHintEnabled && layout.rightOverflowCount > 0 {
                ellipsis().position(x: layout.rect.width - layout.overflowEllipsisInset, y: midY)
            }
        }
    }

    private func ellipsis() -> some View {
        Text("···")
            .font(.custom(element.style.fontName, size: layout.labelFontSize * 0.95).weight(.bold))
            .foregroundStyle(Color(intervalTimeline: element.style.foregroundColor).opacity(0.50))
    }

    private func segmentView(_ segment: IntervalTimelineSegmentLayout) -> some View {
        let localRect = segment.rect.offsetBy(dx: -layout.rect.minX, dy: -layout.rect.minY)
        return ZStack {
            RoundedRectangle(cornerRadius: layout.style.segmentCornerRadius * element.scale)
                .fill(Color(intervalTimeline: segment.color).opacity(segment.opacity))
                .overlay(alignment: .leading) {
                    if segment.isCurrent && layout.style.currentProgressEnabled {
                        RoundedRectangle(cornerRadius: layout.style.segmentCornerRadius * element.scale)
                            .fill(Color.white.opacity(0.30))
                            .frame(width: localRect.width * layout.currentProgress)
                    }
                }
                .overlay {
                    if segment.isCurrent {
                        RoundedRectangle(cornerRadius: layout.style.segmentCornerRadius * element.scale)
                            .stroke(Color.white.opacity(0.74), lineWidth: 1.4 * element.scale)
                    }
                }
                .shadow(color: Color(intervalTimeline: segment.color).opacity(segment.isCurrent ? 0.45 : 0), radius: 10 * element.scale)

            VStack(spacing: 1 * element.scale) {
                if segment.isCurrent, let repText = layout.repText {
                    Text(repText)
                        .font(.custom(element.style.fontName, size: max(layout.durationFontSize * 0.82, 8)).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ForEach(Array(segment.labelLines.enumerated()), id: \.offset) { offset, line in
                    Text(line)
                        .font(.custom(
                            element.style.fontName,
                            size: offset == 0 && segment.isCurrent ? layout.labelFontSize * 1.08 : (offset == 0 ? layout.labelFontSize : layout.durationFontSize)
                        ).weight(offset == 0 ? .bold : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(offset == 0 ? 0.96 : 0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
            }
            .padding(.horizontal, 4 * element.scale)
        }
        .frame(width: localRect.width, height: localRect.height)
        .position(x: localRect.midX, y: localRect.midY)
    }

    private var markerView: some View {
        let x = layout.markerX - layout.rect.minX
        let stackHeight = layout.markerTriangleHeight + 2 * element.scale + layout.markerLabelHeight
        let y = layout.markerTopY - layout.rect.minY + stackHeight / 2
        return VStack(spacing: 2 * element.scale) {
            IntervalTimelineMarkerTriangle()
                .fill(Color(intervalTimeline: layout.style.markerColor).opacity(0.92))
                .frame(width: 10 * element.scale, height: layout.markerTriangleHeight)
            Text(layout.markerLabel)
                .font(.custom(layout.style.markerFontName.isEmpty ? element.style.fontName : layout.style.markerFontName, size: layout.style.markerFontSize * element.scale).weight(layout.style.markerFontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalTimeline: layout.style.markerColor).opacity(0.88))
                .frame(height: layout.markerLabelHeight)
                .lineLimit(1)
        }
        .position(x: x, y: y)
    }
}

private struct IntervalTimelineMarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension Color {
    init(intervalTimeline color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

private extension View {
    func intervalTimelineShadow(element: OverlayElement) -> some View {
        self
            .shadow(
                color: Color(intervalTimeline: element.style.shadowColor).opacity(element.style.shadowEnabled ? element.style.shadowOpacity : 0),
                radius: element.style.shadowRadius,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY
            )
    }
}

private extension OverlayFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
