import SwiftUI

struct IntervalHUDBarOverlayView: View {
    let element: OverlayElement
    let layout: IntervalHUDBarRenderLayout

    private var style: IntervalHUDBarStyle { layout.style }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    if index > 0 {
                        divider
                    }
                    cellView(cell)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, horizontalContentPadding)
            .frame(height: mainContentHeight)

            if hasVisibleBottomBar {
                Spacer()
                    .frame(height: effectiveBottomBarSpacing)
            }

            bottomBar
                .padding(.horizontal, horizontalContentPadding)
        }
        .padding(.top, verticalLayout.topPadding)
        .padding(.bottom, verticalLayout.bottomPadding)
        .intervalHUDLayeredShadow(
            element: element,
            isEnabled: !element.style.backgroundEnabled && !element.style.borderEnabled
        )
        .frame(width: layout.rect.width, height: layout.rect.height)
        .background(
            RoundedRectangle(cornerRadius: element.style.backgroundRadius)
                .fill(Color(intervalHUD: element.style.backgroundColor).opacity(element.style.backgroundEnabled ? element.style.backgroundOpacity : 0))
                .intervalHUDLayeredShadow(element: element, isEnabled: element.style.backgroundEnabled)
        )
        .overlay {
            if element.style.borderEnabled {
                RoundedRectangle(cornerRadius: element.style.backgroundRadius)
                    .stroke(Color(intervalHUD: element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
            }
        }
    }

    private var mainContentHeight: Double {
        let availableHeight = max(layout.rect.height - verticalLayout.topPadding - verticalLayout.bottomPadding, 1)
        if hasVisibleBottomBar {
            return max(availableHeight - bottomBarContentHeight - verticalLayout.spacing, 1)
        }
        return availableHeight
    }

    private var effectiveBottomBarSpacing: Double {
        verticalLayout.spacing
    }

    private var verticalLayout: IntervalHUDBarVerticalLayout {
        let desiredTopPadding = topContentPadding
        let desiredBottomPadding = bottomContentPadding
        let minimumTopPadding = max(layout.rect.height * 0.025, 2)
        let minimumBottomPadding = max(layout.rect.height * 0.025, 2)
        let requestedSpacing = hasVisibleBottomBar ? max(style.bottomBarSpacing, 0) : 0
        let minimumContentHeight = minimumMainContentHeight
        let bottomHeight = bottomBarContentHeight
        let desiredTotal = desiredTopPadding + minimumContentHeight + requestedSpacing + bottomHeight + desiredBottomPadding

        guard hasVisibleBottomBar, desiredTotal > layout.rect.height else {
            return IntervalHUDBarVerticalLayout(
                topPadding: desiredTopPadding,
                bottomPadding: desiredBottomPadding,
                spacing: requestedSpacing
            )
        }

        let availablePadding = layout.rect.height - minimumContentHeight - requestedSpacing - bottomHeight
        if availablePadding >= minimumTopPadding + minimumBottomPadding {
            let desiredPadding = max(desiredTopPadding + desiredBottomPadding, 1)
            let topShare = desiredTopPadding / desiredPadding
            let topPadding = max(minimumTopPadding, availablePadding * topShare)
            let bottomPadding = max(minimumBottomPadding, availablePadding - topPadding)
            return IntervalHUDBarVerticalLayout(
                topPadding: topPadding,
                bottomPadding: bottomPadding,
                spacing: requestedSpacing
            )
        }

        let maxSpacing = max(layout.rect.height - minimumTopPadding - minimumBottomPadding - minimumContentHeight - bottomHeight, 0)
        return IntervalHUDBarVerticalLayout(
            topPadding: minimumTopPadding,
            bottomPadding: minimumBottomPadding,
            spacing: min(requestedSpacing, maxSpacing)
        )
    }

    private var minimumMainContentHeight: Double {
        max(layout.rect.height * 0.30, min(maxTextStackHeight + 4, layout.rect.height * 0.58))
    }

    private var maxTextStackHeight: Double {
        max(
            layout.primaryValueText.fontSize + layout.labelText.fontSize + 4,
            layout.phaseText.fontSize + layout.phaseDetailText.fontSize + 3,
            layout.metricValueText.fontSize + max(layout.labelText.fontSize, layout.metricUnitText.fontSize) + 4
        )
    }

    private var horizontalContentPadding: Double {
        layout.rect.width * 0.035 + element.style.backgroundPaddingX * element.scale
    }

    private var topContentPadding: Double {
        layout.rect.height * 0.06 + element.style.backgroundPaddingY * element.scale
    }

    private var bottomContentPadding: Double {
        layout.rect.height * 0.12 + element.style.backgroundPaddingY * element.scale
    }

    private var bottomBarContentHeight: Double {
        guard hasVisibleBottomBar else { return 0 }
        return layout.barHeight
    }

    private var hasVisibleBottomBar: Bool {
        style.bottomBarEnabled && style.bottomBarMode != .none
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(intervalHUD: element.style.dividerColor).opacity(element.style.dividerEnabled ? element.style.dividerOpacity : 0))
            .frame(width: max(element.style.dividerThickness, 0.5), height: layout.rect.height * 0.48)
            .padding(.horizontal, layout.rect.width * 0.025)
    }

    private var cells: [IntervalHUDBarCell] {
        var output: [IntervalHUDBarCell] = []
        if style.showsRep {
            output.append(.rep)
        }
        if style.showsPhase {
            output.append(.phase)
        }
        if style.showsRemaining {
            output.append(.remaining)
        }
        if let zoneItem = layout.zoneItem {
            output.append(.metric(zoneItem))
        }
        output.append(contentsOf: layout.metricItems.map { .metric($0) })
        return output
    }

    @ViewBuilder
    private func cellView(_ cell: IntervalHUDBarCell) -> some View {
        switch cell {
        case .rep:
            mainCell(label: "REP", value: layout.repText)
        case .phase:
            phaseCell
        case .remaining:
            remainingCell
        case .metric(let item):
            metricCell(item)
        }
    }

    private var phaseCell: some View {
        VStack(spacing: 3) {
            Text(layout.phaseLabel)
                .font(.overlayFont(family: layout.phaseText.fontName, size: layout.phaseText.fontSize, weight: layout.phaseText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: layout.phaseColor))
                .monospacedDigit()
                .lineLimit(1)
            Text(layout.phaseDetail)
                .font(.overlayFont(family: layout.phaseDetailText.fontName, size: layout.phaseDetailText.fontSize, weight: layout.phaseDetailText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor).opacity(0.88))
                .monospacedDigit()
                .lineLimit(1)
        }
        .minimumScaleFactor(0.72)
    }

    private var remainingCell: some View {
        VStack(spacing: 3) {
            Text(layout.remainingPrimaryText)
                .font(.overlayFont(family: layout.primaryValueText.fontName, size: layout.primaryValueText.fontSize, weight: layout.primaryValueText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor))
                .monospacedDigit()
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(layout.remainingPrimaryLabel)
                    .font(.overlayFont(family: layout.labelText.fontName, size: layout.labelText.fontSize, weight: layout.labelText.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.72))
                Text(layout.remainingSecondaryText)
                    .font(.overlayFont(family: layout.metricUnitText.fontName, size: layout.metricUnitText.fontSize, weight: layout.metricUnitText.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.72))
                    .monospacedDigit()
            }
            .lineLimit(1)
        }
        .minimumScaleFactor(0.7)
    }

    private func mainCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.overlayFont(family: layout.labelText.fontName, size: layout.labelText.fontSize, weight: layout.labelText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.66))
                .lineLimit(1)
            Text(value)
                .font(.overlayFont(family: layout.primaryValueText.fontName, size: layout.primaryValueText.fontSize * 0.86, weight: layout.primaryValueText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor))
                .monospacedDigit()
                .lineLimit(1)
        }
        .minimumScaleFactor(0.7)
    }

    private func metricCell(_ item: IntervalHUDBarMetricItem) -> some View {
        VStack(spacing: 4) {
            Text(item.label)
                .font(.overlayFont(family: layout.labelText.fontName, size: layout.labelText.fontSize, weight: layout.labelText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.66))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.value)
                    .font(.overlayFont(family: layout.metricValueText.fontName, size: layout.metricValueText.fontSize, weight: layout.metricValueText.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(intervalHUD: item.accentColor ?? element.style.foregroundColor))
                    .monospacedDigit()
                    .lineLimit(1)
                if !item.unit.isEmpty {
                    Text(item.unit)
                        .font(.overlayFont(family: layout.metricUnitText.fontName, size: layout.metricUnitText.fontSize, weight: layout.metricUnitText.fontWeight.swiftUIFontWeight))
                        .foregroundStyle(Color(intervalHUD: element.style.unitColor).opacity(0.76))
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.68)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !style.bottomBarEnabled {
            EmptyView()
        } else {
            switch style.bottomBarMode {
            case .none:
                EmptyView()
            case .lapProgress:
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: bottomBarCornerRadius)
                        .fill(Color(intervalHUD: style.trackColor).opacity(style.trackOpacity))
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: bottomBarCornerRadius)
                            .fill(Color(intervalHUD: layout.phaseColor))
                            .shadow(
                                color: Color(intervalHUD: layout.phaseColor).opacity(style.bottomBarGlowEnabled ? style.bottomBarGlowIntensity : 0),
                                radius: layout.barHeight * 1.2,
                                x: 0,
                                y: 0
                            )
                            .frame(width: max(proxy.size.width * layout.progress, layout.progress > 0 ? layout.barHeight : 0))
                    }
                }
                .overlay {
                    bottomBarBorderShape
                }
                .frame(height: layout.barHeight)
            case .heartRateZones, .paceZones:
                GeometryReader { proxy in
                    let frames = OverlayRenderModel.intervalZoneSegmentFrames(
                        segmentCount: layout.zoneSegments.count,
                        activeIndex: layout.bottomBarActiveZoneIndex,
                        activeWidthShare: style.activeZoneWidthShare
                    )
                    let zoneRects = intervalZoneRects(frames: frames, width: proxy.size.width)
                    ZStack(alignment: .topLeading) {
                        if style.bottomBarGlowEnabled,
                           let activeIndex = layout.bottomBarActiveZoneIndex,
                           let activeRect = zoneRects.first(where: { $0.index == activeIndex }),
                           let activeSegment = layout.zoneSegments.first(where: { $0.index == activeIndex }) {
                            RoundedRectangle(cornerRadius: min(bottomBarCornerRadius, activeRect.height / 2))
                                .fill(Color(intervalHUD: activeSegment.color).opacity(style.bottomBarGlowIntensity))
                                .blur(radius: layout.barHeight * 1.6)
                                .frame(width: activeRect.width, height: activeRect.height)
                                .offset(
                                    x: activeRect.x,
                                    y: activeRect.y
                                )
                        }

                        ZStack(alignment: .topLeading) {
                            ForEach(zoneRects, id: \.index) { zoneRect in
                                if let segment = layout.zoneSegments.first(where: { $0.index == zoneRect.index }) {
                                    let isActive = segment.index == layout.bottomBarActiveZoneIndex
                                    RoundedRectangle(cornerRadius: segmentCornerRadius(for: zoneRect, isActive: isActive))
                                        .fill(Color(intervalHUD: segment.color).opacity(isActive ? 1 : style.inactiveZoneOpacity))
                                        .frame(width: zoneRect.width, height: zoneRect.height)
                                        .offset(x: zoneRect.x, y: zoneRect.y)
                                }
                            }
                        }
                        .frame(width: proxy.size.width, height: layout.barHeight, alignment: .topLeading)
                        .overlay {
                            bottomBarBorderShape
                        }

                        if let marker = layout.thresholdZoneMarker,
                           let markerRect = zoneRects.first(where: { $0.index == marker.zoneIndex }) {
                            zoneMarkerView(marker)
                                .position(
                                    x: markerRect.x + markerRect.width * marker.fractionInZone,
                                    y: zoneMarkerY(for: marker)
                                )
                        }

                        if let marker = layout.zoneMarker,
                           let markerRect = zoneRects.first(where: { $0.index == marker.zoneIndex }) {
                            zoneMarkerView(marker)
                                .position(
                                    x: markerRect.x + markerRect.width * marker.fractionInZone,
                                    y: zoneMarkerY(for: marker)
                                )
                        }
                    }
                    .frame(width: proxy.size.width, height: layout.barHeight, alignment: .topLeading)
                }
                .frame(height: layout.barHeight)
            }
        }
    }

    private func zoneMarkerY(for marker: IntervalHUDBarZoneMarker) -> Double {
        if marker.role == .threshold {
            let lineHeight = thresholdMarkerLineHeight
            let labelHeight = zoneMarkerValueFontSize(marker) + 4
            let markerHeight = lineHeight + 2 + labelHeight
            return layout.barHeight / 2 - lineHeight / 2 + markerHeight / 2
        }
        let arrowHeight = zoneMarkerArrowHeight(marker)
        let showsValue = marker.role == .threshold || style.zoneMarkerShowsValue
        let valueHeight = showsValue ? max(zoneMarkerValueFontSize(marker), 9) + 6 : 0
        let markerHeight = arrowHeight + valueHeight + (showsValue ? 2 : 0)
        if style.zoneMarkerPosition == .above {
            return -zoneMarkerGap - markerHeight / 2
        }
        return layout.barHeight + zoneMarkerGap + markerHeight / 2
    }

    private var bottomBarCornerRadius: Double {
        min(max(style.bottomBarCornerRadius * element.scale, 0), layout.barHeight)
    }

    @ViewBuilder
    private var bottomBarBorderShape: some View {
        if style.bottomBarBorderEnabled && style.bottomBarBorderWidth > 0 && style.bottomBarBorderOpacity > 0 {
            RoundedRectangle(cornerRadius: bottomBarCornerRadius)
                .stroke(
                    Color(intervalHUD: style.bottomBarBorderColor).opacity(style.bottomBarBorderOpacity),
                    lineWidth: max(style.bottomBarBorderWidth * element.scale, 0)
                )
        }
    }

    private func segmentCornerRadius(for rect: IntervalHUDBarZoneRect, isActive: Bool) -> Double {
        min(bottomBarCornerRadius, rect.height / 2, rect.width / 2)
    }

    private func intervalZoneRects(frames: [IntervalHUDBarZoneSegmentFrame], width: Double) -> [IntervalHUDBarZoneRect] {
        let segmentCount = min(frames.count, layout.zoneSegments.count)
        guard segmentCount > 0 else { return [] }
        let requestedGap = max(style.zoneSegmentGap * element.scale, 0)
        let maxGap = segmentCount > 1 ? max(width / Double(segmentCount - 1) * 0.18, 0) : 0
        let gap = min(requestedGap, maxGap)
        let usableWidth = max(width - gap * Double(max(segmentCount - 1, 0)), 1)
        return (0..<segmentCount).map { position in
            let frame = frames[position]
            let segment = layout.zoneSegments[position]
            let isActive = segment.index == layout.bottomBarActiveZoneIndex
            let height = isActive ? layout.barHeight * max(style.activeZoneHeightScale, 1) : layout.barHeight
            let positionOffset = Double(position) * gap
            return IntervalHUDBarZoneRect(
                index: segment.index,
                x: usableWidth * frame.start + positionOffset,
                y: (layout.barHeight - height) / 2,
                width: max(usableWidth * frame.width, 0),
                height: height
            )
        }
    }

    private var zoneMarkerGap: Double {
        switch style.zoneMarkerPosition {
        case .above:
            max(layout.barHeight * 0.35, 3)
        case .below:
            max(layout.barHeight * 0.55, 4)
        }
    }

    @ViewBuilder
    private func zoneMarkerView(_ marker: IntervalHUDBarZoneMarker) -> some View {
        if marker.role == .threshold {
            thresholdZoneMarkerView(marker)
        } else {
            VStack(spacing: 2) {
                if style.zoneMarkerPosition == .above {
                    if style.zoneMarkerShowsValue {
                        zoneMarkerValue(marker)
                    }
                    IntervalHUDBarZoneMarkerTriangle(direction: .down)
                        .fill(Color(intervalHUD: marker.color))
                        .frame(width: zoneMarkerArrowWidth(marker), height: zoneMarkerArrowHeight(marker))
                } else {
                    IntervalHUDBarZoneMarkerTriangle(direction: .up)
                        .fill(Color(intervalHUD: marker.color))
                        .frame(width: zoneMarkerArrowWidth(marker), height: zoneMarkerArrowHeight(marker))
                    if style.zoneMarkerShowsValue {
                        zoneMarkerValue(marker)
                    }
                }
            }
            .fixedSize()
        }
    }

    private func thresholdZoneMarkerView(_ marker: IntervalHUDBarZoneMarker) -> some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(Color(intervalHUD: marker.color).opacity(0.78))
                .frame(width: max(1.2 * element.scale, 1), height: thresholdMarkerLineHeight)
            Text(marker.valueText)
                .font(.overlayFont(family: layout.metricUnitText.fontName, size: zoneMarkerValueFontSize(marker), weight: layout.metricUnitText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: marker.color).opacity(0.78))
                .lineLimit(1)
        }
        .fixedSize()
    }

    private func zoneMarkerValue(_ marker: IntervalHUDBarZoneMarker) -> some View {
        Text(marker.valueText)
            .font(.overlayFont(family: layout.metricUnitText.fontName, size: zoneMarkerValueFontSize(marker), weight: layout.metricUnitText.fontWeight.swiftUIFontWeight))
            .foregroundStyle(Color(intervalHUD: marker.color))
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func zoneMarkerArrowWidth(_ marker: IntervalHUDBarZoneMarker) -> Double {
        marker.role == .threshold ? max(layout.barHeight * 0.95, 9) : max(layout.barHeight * 1.35, 12)
    }

    private func zoneMarkerArrowHeight(_ marker: IntervalHUDBarZoneMarker) -> Double {
        marker.role == .threshold ? max(layout.barHeight * 0.62, 6) : max(layout.barHeight * 0.9, 8)
    }

    private func zoneMarkerValueFontSize(_ marker: IntervalHUDBarZoneMarker) -> Double {
        marker.role == .threshold ? max(layout.metricUnitText.fontSize * 0.72, 7) : max(layout.metricUnitText.fontSize, 9)
    }

    private var thresholdMarkerLineHeight: Double {
        max(layout.barHeight * 1.35, 10)
    }
}

private struct IntervalHUDBarZoneMarkerTriangle: Shape {
    enum Direction {
        case up
        case down
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
        }
        path.closeSubpath()
        return path
    }
}

private enum IntervalHUDBarCell: Identifiable {
    case rep
    case phase
    case remaining
    case metric(IntervalHUDBarMetricItem)

    var id: String {
        switch self {
        case .rep:
            "rep"
        case .phase:
            "phase"
        case .remaining:
            "remaining"
        case .metric(let item):
            item.id.uuidString
        }
    }
}

private struct IntervalHUDBarVerticalLayout {
    var topPadding: Double
    var bottomPadding: Double
    var spacing: Double
}

private struct IntervalHUDBarZoneRect {
    var index: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

private extension Color {
    init(intervalHUD color: OverlayColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

private extension View {
    func intervalHUDLayeredShadow(element: OverlayElement, isEnabled: Bool) -> some View {
        self
            .shadow(
                color: Color(intervalHUD: element.style.shadowColor)
                    .opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity : 0),
                radius: element.style.shadowRadius,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY
            )
            .shadow(
                color: Color(intervalHUD: element.style.shadowColor)
                    .opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity * max(element.style.shadowThickness - 1, 0) * 0.32 : 0),
                radius: element.style.shadowRadius * 0.72,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY
            )
            .shadow(
                color: Color(intervalHUD: element.style.shadowColor)
                    .opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity * max(element.style.shadowThickness - 2, 0) * 0.22 : 0),
                radius: element.style.shadowRadius * 0.48,
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
