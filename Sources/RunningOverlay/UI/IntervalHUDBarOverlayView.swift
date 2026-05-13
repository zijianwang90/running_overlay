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
            .padding(.horizontal, layout.rect.width * 0.035)
            .frame(height: mainContentHeight)

            bottomBar
                .padding(.horizontal, layout.rect.width * 0.035)
                .padding(.bottom, layout.rect.height * 0.12)
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .background(
            RoundedRectangle(cornerRadius: element.style.backgroundRadius)
                .fill(Color(intervalHUD: element.style.backgroundColor).opacity(element.style.backgroundEnabled ? element.style.backgroundOpacity : 0))
        )
        .overlay {
            if element.style.borderEnabled {
                RoundedRectangle(cornerRadius: element.style.backgroundRadius)
                    .stroke(Color(intervalHUD: element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
            }
        }
    }

    private var mainContentHeight: Double {
        layout.rect.height - (!style.bottomBarEnabled ? 0 : layout.barHeight + layout.rect.height * 0.18)
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
                .font(.custom(layout.phaseText.fontName, size: layout.phaseText.fontSize).weight(layout.phaseText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: layout.phaseColor))
                .monospacedDigit()
                .lineLimit(1)
            Text(layout.phaseDetail)
                .font(.custom(layout.phaseDetailText.fontName, size: layout.phaseDetailText.fontSize).weight(layout.phaseDetailText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor).opacity(0.88))
                .monospacedDigit()
                .lineLimit(1)
        }
        .minimumScaleFactor(0.72)
    }

    private var remainingCell: some View {
        VStack(spacing: 3) {
            Text(layout.remainingPrimaryText)
                .font(.custom(layout.primaryValueText.fontName, size: layout.primaryValueText.fontSize).weight(layout.primaryValueText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor))
                .monospacedDigit()
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(layout.remainingPrimaryLabel)
                    .font(.custom(layout.labelText.fontName, size: layout.labelText.fontSize).weight(layout.labelText.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.72))
                Text(layout.remainingSecondaryText)
                    .font(.custom(layout.metricUnitText.fontName, size: layout.metricUnitText.fontSize).weight(layout.metricUnitText.fontWeight.swiftUIFontWeight))
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
                .font(.custom(layout.labelText.fontName, size: layout.labelText.fontSize).weight(layout.labelText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.66))
                .lineLimit(1)
            Text(value)
                .font(.custom(layout.primaryValueText.fontName, size: layout.primaryValueText.fontSize * 0.86).weight(layout.primaryValueText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.foregroundColor))
                .monospacedDigit()
                .lineLimit(1)
        }
        .minimumScaleFactor(0.7)
    }

    private func metricCell(_ item: IntervalHUDBarMetricItem) -> some View {
        VStack(spacing: 4) {
            Text(item.label)
                .font(.custom(layout.labelText.fontName, size: layout.labelText.fontSize).weight(layout.labelText.fontWeight.swiftUIFontWeight))
                .foregroundStyle(Color(intervalHUD: element.style.labelColor).opacity(0.66))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.value)
                    .font(.custom(layout.metricValueText.fontName, size: layout.metricValueText.fontSize).weight(layout.metricValueText.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(intervalHUD: item.accentColor ?? element.style.foregroundColor))
                    .monospacedDigit()
                    .lineLimit(1)
                if !item.unit.isEmpty {
                    Text(item.unit)
                        .font(.custom(layout.metricUnitText.fontName, size: layout.metricUnitText.fontSize).weight(layout.metricUnitText.fontWeight.swiftUIFontWeight))
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
                    Capsule()
                        .fill(Color(intervalHUD: style.trackColor).opacity(style.trackOpacity))
                    GeometryReader { proxy in
                        Capsule()
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
                .frame(height: layout.barHeight)
            case .heartRateZones, .paceZones:
                HStack(spacing: 2) {
                    ForEach(layout.zoneSegments) { segment in
                        let isActive = segment.index == layout.activeZoneIndex
                        Rectangle()
                            .fill(Color(intervalHUD: segment.color).opacity(isActive ? 1 : 0.42))
                            .shadow(
                                color: Color(intervalHUD: segment.color).opacity(isActive && style.bottomBarGlowEnabled ? style.bottomBarGlowIntensity : 0),
                                radius: isActive ? layout.barHeight * 1.25 : 0,
                                x: 0,
                                y: 0
                            )
                    }
                }
                .frame(height: layout.barHeight)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            }
        }
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

private extension Color {
    init(intervalHUD color: OverlayColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
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
