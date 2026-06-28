import SwiftUI

struct ZoneEdgeBarOverlayView: View {
    let element: OverlayElement
    let layout: ZoneEdgeBarRenderLayout

    private var style: ZoneEdgeBarStyle { layout.style }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if style.glowEnabled,
                   let activeIndex = layout.activeZoneIndex,
                   let activeRect = zoneRects.first(where: { $0.index == activeIndex }),
                   let activeSegment = layout.zoneSegments.first(where: { $0.index == activeIndex }) {
                    RoundedRectangle(cornerRadius: cornerRadius(for: activeRect))
                        .fill(Color(zoneEdgeBar: activeSegment.color).opacity(style.glowIntensity))
                        .blur(radius: crossAxisThickness * 1.6)
                        .frame(width: activeRect.width, height: activeRect.height)
                        .offset(x: activeRect.x, y: activeRect.y)
                }

                ForEach(zoneRects, id: \.index) { zoneRect in
                    if let segment = layout.zoneSegments.first(where: { $0.index == zoneRect.index }) {
                        let isActive = segment.index == layout.activeZoneIndex
                        RoundedRectangle(cornerRadius: cornerRadius(for: zoneRect))
                            .fill(Color(zoneEdgeBar: segment.color).opacity(isActive ? 1 : style.inactiveZoneOpacity))
                            .frame(width: zoneRect.width, height: zoneRect.height)
                            .offset(x: zoneRect.x, y: zoneRect.y)
                    }
                }

                if borderVisible {
                    RoundedRectangle(cornerRadius: min(cornerRadius, crossAxisThickness / 2))
                        .stroke(Color(zoneEdgeBar: style.borderColor).opacity(style.borderOpacity), lineWidth: max(style.borderWidth * element.scale, 0.5))
                        .frame(width: localBarRect.width, height: localBarRect.height)
                        .offset(x: localBarRect.minX, y: localBarRect.minY)
                }

                if let marker = layout.thresholdZoneMarker,
                   let zoneRect = zoneRects.first(where: { $0.index == marker.zoneIndex }) {
                    thresholdMarkerView(marker)
                        .position(markerPosition(marker, in: zoneRect))
                }

                if let marker = layout.zoneMarker,
                   let zoneRect = zoneRects.first(where: { $0.index == marker.zoneIndex }) {
                    currentMarkerView(marker)
                        .position(markerPosition(marker, in: zoneRect))
                }
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .zoneEdgeBarShadow(element: element)
    }

    private var localBarRect: CGRect {
        layout.barRect.offsetBy(dx: -layout.rect.minX, dy: -layout.rect.minY)
    }

    private var crossAxisThickness: Double {
        layout.orientation == .horizontal ? localBarRect.height : localBarRect.width
    }

    private var cornerRadius: Double {
        min(max(style.cornerRadius * element.scale, 0), crossAxisThickness / 2)
    }

    private var borderVisible: Bool {
        style.borderEnabled && style.borderOpacity > 0 && style.borderWidth > 0
    }

    private var zoneRects: [ZoneEdgeBarZoneRect] {
        let frames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: layout.zoneSegments.count,
            activeIndex: layout.activeZoneIndex,
            activeWidthShare: style.activeZoneWidthShare
        )
        return zoneRects(frames: frames)
    }

    private func zoneRects(frames: [IntervalHUDBarZoneSegmentFrame]) -> [ZoneEdgeBarZoneRect] {
        let segmentCount = min(frames.count, layout.zoneSegments.count)
        guard segmentCount > 0 else { return [] }
        let length = layout.orientation == .horizontal ? localBarRect.width : localBarRect.height
        let requestedGap = max(style.zoneSegmentGap * element.scale, 0)
        let maxGap = segmentCount > 1 ? max(length / Double(segmentCount - 1) * 0.18, 0) : 0
        let gap = min(requestedGap, maxGap)
        let usableLength = max(length - gap * Double(max(segmentCount - 1, 0)), 1)

        return (0..<segmentCount).map { position in
            let frame = frames[position]
            let segment = layout.zoneSegments[position]
            let isActive = segment.index == layout.activeZoneIndex
            let activeThickness = crossAxisThickness * max(style.activeZoneHeightScale, 1)
            let thickness = isActive ? activeThickness : crossAxisThickness
            let positionOffset = Double(position) * gap
            let segmentLength = max(usableLength * frame.width, 0)

            if layout.orientation == .horizontal {
                return ZoneEdgeBarZoneRect(
                    index: segment.index,
                    x: localBarRect.minX + usableLength * frame.start + positionOffset,
                    y: localBarRect.midY - thickness / 2,
                    width: segmentLength,
                    height: thickness
                )
            }

            return ZoneEdgeBarZoneRect(
                index: segment.index,
                x: localBarRect.midX - thickness / 2,
                y: localBarRect.maxY - usableLength * (frame.start + frame.width) - positionOffset,
                width: thickness,
                height: segmentLength
            )
        }
    }

    private func cornerRadius(for rect: ZoneEdgeBarZoneRect) -> Double {
        min(cornerRadius, rect.width / 2, rect.height / 2)
    }

    private func markerPosition(_ marker: IntervalHUDBarZoneMarker, in rect: ZoneEdgeBarZoneRect) -> CGPoint {
        if layout.orientation == .horizontal {
            let x = rect.x + rect.width * marker.fractionInZone
            switch layout.markerSide {
            case .above:
                return CGPoint(x: x, y: marker.role == .threshold ? localBarRect.midY : localBarRect.minY - currentMarkerHeight(marker) / 2 - markerGap)
            case .below:
                return CGPoint(x: x, y: marker.role == .threshold ? localBarRect.midY : localBarRect.maxY + currentMarkerHeight(marker) / 2 + markerGap)
            case .leading, .trailing:
                return CGPoint(x: x, y: localBarRect.midY)
            }
        }

        let y = rect.y + rect.height - rect.height * marker.fractionInZone
        switch layout.markerSide {
        case .leading:
            return CGPoint(x: marker.role == .threshold ? localBarRect.midX : localBarRect.minX - currentMarkerWidth(marker) / 2 - markerGap, y: y)
        case .trailing:
            return CGPoint(x: marker.role == .threshold ? localBarRect.midX : localBarRect.maxX + currentMarkerWidth(marker) / 2 + markerGap, y: y)
        case .above, .below:
            return CGPoint(x: localBarRect.midX, y: y)
        }
    }

    @ViewBuilder
    private func currentMarkerView(_ marker: IntervalHUDBarZoneMarker) -> some View {
        if layout.orientation == .horizontal {
            VStack(spacing: 2) {
                if layout.markerSide == .above && style.markerShowsValue {
                    markerValue(marker)
                }
                ZoneEdgeBarTriangle(direction: layout.markerSide == .above ? .down : .up)
                    .fill(Color(zoneEdgeBar: marker.color))
                    .frame(width: max(crossAxisThickness * 1.35, 12), height: max(crossAxisThickness * 0.9, 8))
                if layout.markerSide == .below && style.markerShowsValue {
                    markerValue(marker)
                }
            }
            .fixedSize()
        } else {
            HStack(spacing: 2) {
                if layout.markerSide == .leading && style.markerShowsValue {
                    markerValue(marker)
                }
                ZoneEdgeBarTriangle(direction: layout.markerSide == .leading ? .right : .left)
                    .fill(Color(zoneEdgeBar: marker.color))
                    .frame(width: max(crossAxisThickness * 0.9, 8), height: max(crossAxisThickness * 1.35, 12))
                if layout.markerSide == .trailing && style.markerShowsValue {
                    markerValue(marker)
                }
            }
            .fixedSize()
        }
    }

    private func thresholdMarkerView(_ marker: IntervalHUDBarZoneMarker) -> some View {
        Group {
            if layout.orientation == .horizontal {
                VStack(spacing: 2) {
                    if layout.markerSide == .above {
                        markerText(marker, scale: 0.72)
                    }
                    thresholdLine(marker)
                        .frame(width: max(1.2 * element.scale, 1), height: thresholdLineLength)
                    if layout.markerSide != .above {
                        markerText(marker, scale: 0.72)
                    }
                }
                .offset(y: horizontalThresholdOffset)
            } else {
                HStack(spacing: 2) {
                    if layout.markerSide == .leading {
                        markerText(marker, scale: 0.72)
                    }
                    thresholdLine(marker)
                        .frame(width: thresholdLineLength, height: max(1.2 * element.scale, 1))
                    if layout.markerSide != .leading {
                        markerText(marker, scale: 0.72)
                    }
                }
                .offset(x: verticalThresholdOffset)
            }
        }
        .fixedSize()
    }

    private func thresholdLine(_ marker: IntervalHUDBarZoneMarker) -> some View {
        Capsule()
            .fill(Color(zoneEdgeBar: marker.color).opacity(0.78))
    }

    private func markerValue(_ marker: IntervalHUDBarZoneMarker) -> some View {
        markerText(marker, scale: 1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func markerText(_ marker: IntervalHUDBarZoneMarker, scale: Double) -> some View {
        Text(marker.valueText)
            .font(.overlayFont(family: layout.markerText.fontName, size: max(layout.markerText.fontSize * scale, 7), weight: layout.markerText.fontWeight.zoneEdgeBarSwiftUIFontWeight))
            .foregroundStyle(Color(zoneEdgeBar: marker.color).opacity(marker.role == .threshold ? 0.78 : 1))
            .monospacedDigit()
            .lineLimit(1)
    }

    private var markerGap: Double {
        max(crossAxisThickness * 0.35, 3)
    }

    private var thresholdLineLength: Double {
        max(crossAxisThickness * 1.35, 10)
    }

    private var thresholdMarkerHeight: Double {
        thresholdLineLength + max(layout.markerText.fontSize * 0.72, 7) + 6
    }

    private var thresholdLabelAndSpacing: Double {
        thresholdMarkerHeight - thresholdLineLength
    }

    private var horizontalThresholdOffset: Double {
        layout.markerSide == .above ? -thresholdLabelAndSpacing / 2 : thresholdLabelAndSpacing / 2
    }

    private var verticalThresholdOffset: Double {
        layout.markerSide == .leading ? -thresholdLabelAndSpacing / 2 : thresholdLabelAndSpacing / 2
    }

    private func currentMarkerHeight(_ marker: IntervalHUDBarZoneMarker) -> Double {
        max(crossAxisThickness * 0.9, 8) + (style.markerShowsValue ? max(layout.markerText.fontSize, 9) + 8 : 0)
    }

    private func currentMarkerWidth(_ marker: IntervalHUDBarZoneMarker) -> Double {
        max(crossAxisThickness * 0.9, 8) + (style.markerShowsValue ? 84 : 0)
    }
}

private struct ZoneEdgeBarZoneRect {
    var index: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

private struct ZoneEdgeBarTriangle: Shape {
    enum Direction {
        case up
        case down
        case left
        case right
    }

    var direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private extension Color {
    init(zoneEdgeBar color: OverlayColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

private extension View {
    func zoneEdgeBarShadow(element: OverlayElement) -> some View {
        self
            .shadow(
                color: Color(zoneEdgeBar: element.style.shadowColor)
                    .opacity(element.style.shadowEnabled ? element.style.shadowOpacity : 0),
                radius: element.style.shadowRadius,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY
            )
    }
}

private extension OverlayFontWeight {
    var zoneEdgeBarSwiftUIFontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
