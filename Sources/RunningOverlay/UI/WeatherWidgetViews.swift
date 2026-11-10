import SwiftUI

private extension Color {
    init(_ overlayColor: OverlayColor) {
        self.init(red: overlayColor.red, green: overlayColor.green, blue: overlayColor.blue, opacity: overlayColor.alpha)
    }
}

private func weatherFont(_ style: WeatherTextStyle, scale: Double) -> Font {
    .overlayFont(family: style.fontName, size: max(1, style.fontSize * scale), overlayWeight: style.fontWeight)
}

private extension View {
    @ViewBuilder
    func weatherText(_ style: WeatherTextStyle, scale: Double) -> some View {
        self.font(weatherFont(style, scale: scale))
            .foregroundStyle(Color(style.color))
    }
}

// MARK: - Shared Wrapper

struct OverlaySharedWeatherWidgetView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        SimpleCardWeatherView(layout: layout)
            .frame(width: layout.rect.width, height: layout.rect.height)
    }
}

// MARK: - Preset Tokens

private struct WeatherWidgetCardTokens {
    var background: LinearGradient
    var strokeColor: Color
    var strokeOpacity: Double
    var divider: Color
    var shadow: Color

    static func resolve(_ layout: WeatherWidgetRenderLayout) -> WeatherWidgetCardTokens {
        let divider = layout.style.dividerEnabled
            ? Color(layout.style.dividerColor).opacity(layout.style.dividerOpacity)
            : .clear
        switch layout.style.palette {
        case .blueGlass, .presetDefault:
            return WeatherWidgetCardTokens(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.68, blue: 1.0).opacity(layout.style.cardBackgroundOpacity),
                        Color(red: 0.22, green: 0.50, blue: 0.92).opacity(layout.style.cardBackgroundOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                strokeColor: .white,
                strokeOpacity: 0.18,
                divider: divider,
                shadow: .black.opacity(0.22)
            )
        case .lightGlass:
            return WeatherWidgetCardTokens(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 1.0).opacity(layout.style.cardBackgroundOpacity),
                        Color(red: 0.82, green: 0.91, blue: 1.0).opacity(layout.style.cardBackgroundOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                strokeColor: Color(red: 0.42, green: 0.64, blue: 0.90),
                strokeOpacity: 0.26,
                divider: divider,
                shadow: .black.opacity(0.12)
            )
        case .graphite:
            return WeatherWidgetCardTokens(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.10, blue: 0.15).opacity(layout.style.cardBackgroundOpacity),
                        Color(red: 0.13, green: 0.20, blue: 0.28).opacity(layout.style.cardBackgroundOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                strokeColor: .white,
                strokeOpacity: 0.16,
                divider: divider,
                shadow: .black.opacity(0.25)
            )
        case .minimalWhite:
            return WeatherWidgetCardTokens(
                background: LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                strokeColor: .clear,
                strokeOpacity: 0,
                divider: divider,
                shadow: .black.opacity(0.45)
            )
        }
    }
}

// MARK: - Simple Card

private struct SimpleCardWeatherView: View {
    let layout: WeatherWidgetRenderLayout

    private var tokens: WeatherWidgetCardTokens { .resolve(layout) }
    private var scale: Double { layout.rect.width / layout.style.width }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: scaled(7)) {
                if layout.style.showConditionLabel {
                    Text(layout.conditionLabel)
                        .weatherText(layout.style.conditionTextStyle, scale: scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if layout.style.showIcon {
                    WeatherConditionIconView(condition: layout.condition, size: scaled(58))
                        .frame(width: scaled(82), height: scaled(54), alignment: .center)
                        .padding(.leading, scaled(4))
                }
            }
            .frame(width: layout.rect.width * 0.40, height: layout.rect.height, alignment: .leading)
            .padding(.leading, scaled(18))

            if layout.style.dividerEnabled {
                Rectangle()
                    .fill(tokens.divider)
                    .frame(width: dividerThickness)
                    .padding(.vertical, scaled(18))
            }

            VStack(alignment: .leading, spacing: scaled(3)) {
                if layout.style.showLocation {
                    Text(layout.locationText)
                        .weatherText(layout.style.locationTextStyle, scale: scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                if layout.style.showWeekday, !layout.weekdayText.isEmpty {
                    Text(layout.weekdayText)
                        .weatherText(layout.style.slotTitleTextStyle, scale: scale)
                }

                Text(layout.temperatureFormatted)
                    .weatherText(layout.style.temperatureTextStyle, scale: scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let metric = layout.metricSlots.first {
                    Text(inlineMetricText(metric))
                        .weatherText(layout.style.slotLabelTextStyle, scale: scale)
                }
            }
            .padding(.leading, scaled(16))
            .padding(.trailing, scaled(18))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .weatherCardBackground(layout: layout, tokens: tokens)
    }

    private func scaled(_ value: Double) -> Double {
        value * scale
    }

    private var dividerThickness: Double {
        max(1, scaled(layout.style.dividerThickness))
    }

    private func inlineMetricText(_ metric: WeatherMetricSlotRender) -> String {
        metric.kind == .feelsLike ? "\(metric.label) \(metric.value)" : metric.value
    }
}

// MARK: - Weather Icons

private struct WeatherConditionIconView: View {
    let condition: WeatherCondition
    let size: Double

    var body: some View {
        IconView(
            asset: .bundledImage(name: condition.bundledImageName),
            rect: CGRect(origin: .zero, size: CGSize(width: size, height: size)),
            preserveSVGColors: true
        )
        .frame(width: size, height: size)
    }
}

private struct SunIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.74, blue: 0.20).opacity(0.88))
                        .frame(width: s * 0.07, height: s * 0.18)
                        .offset(y: -s * 0.34)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.88, blue: 0.32), Color(red: 1.0, green: 0.55, blue: 0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: s * 0.46, height: s * 0.46)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct MoonIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.82, blue: 1.0), Color(red: 0.40, green: 0.52, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: s * 0.54, height: s * 0.54)
                Circle()
                    .fill(Color(red: 0.07, green: 0.10, blue: 0.18))
                    .frame(width: s * 0.48, height: s * 0.48)
                    .offset(x: s * 0.16, y: -s * 0.08)
                Circle().fill(.white.opacity(0.85)).frame(width: s * 0.07, height: s * 0.07).offset(x: -s * 0.23, y: -s * 0.26)
                Circle().fill(.white.opacity(0.68)).frame(width: s * 0.05, height: s * 0.05).offset(x: s * 0.22, y: s * 0.18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct CloudIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            cloudShape(size: s)
                .fill(LinearGradient(colors: [Color(red: 0.50, green: 0.84, blue: 0.98), Color(red: 0.20, green: 0.58, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct PartlyCloudyIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.76, blue: 0.20))
                    .frame(width: s * 0.44, height: s * 0.44)
                    .offset(x: -s * 0.18, y: -s * 0.18)
                cloudShape(size: s)
                    .fill(LinearGradient(colors: [Color(red: 0.58, green: 0.86, blue: 0.98), Color(red: 0.28, green: 0.62, blue: 0.90)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .offset(x: s * 0.03, y: s * 0.08)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct RainIcon: View {
    var heavy: Bool

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                cloudShape(size: s)
                    .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.78, blue: 0.98), Color(red: 0.18, green: 0.48, blue: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .offset(y: -s * 0.10)
                ForEach(0..<(heavy ? 4 : 3), id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.25, green: 0.68, blue: 1.0))
                        .frame(width: s * 0.085, height: s * (heavy ? 0.28 : 0.22))
                        .rotationEffect(.degrees(18))
                        .offset(x: s * (Double(index) - Double(heavy ? 1.5 : 1.0)) * 0.17, y: s * 0.30)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct ThunderIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                cloudShape(size: s)
                    .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.74, blue: 0.94), Color(red: 0.20, green: 0.42, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .offset(y: -s * 0.12)
                LightningShape()
                    .fill(Color(red: 1.0, green: 0.76, blue: 0.16))
                    .frame(width: s * 0.28, height: s * 0.44)
                    .offset(x: s * 0.04, y: s * 0.25)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct SnowIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                cloudShape(size: s)
                    .fill(LinearGradient(colors: [Color(red: 0.68, green: 0.90, blue: 1.0), Color(red: 0.42, green: 0.72, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .offset(y: -s * 0.12)
                ForEach(0..<3, id: \.self) { index in
                    SnowflakeShape()
                        .stroke(Color(red: 0.78, green: 0.96, blue: 1.0), lineWidth: max(1.2, s * 0.035))
                        .frame(width: s * 0.16, height: s * 0.16)
                        .offset(x: s * (Double(index) - 1) * 0.20, y: s * 0.31)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct FogIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            VStack(spacing: s * 0.08) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.58, green: 0.70, blue: 0.78).opacity(index == 0 || index == 3 ? 0.62 : 0.92))
                        .frame(width: s * (index.isMultiple(of: 2) ? 0.74 : 0.58), height: s * 0.095)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct WindIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    WindLineShape()
                        .stroke(Color(red: 0.44, green: 0.74, blue: 0.78).opacity(index == 1 ? 1 : 0.72), style: StrokeStyle(lineWidth: max(2, s * 0.075), lineCap: .round, lineJoin: .round))
                        .frame(width: s * 0.82, height: s * 0.24)
                        .offset(y: s * (Double(index) - 1) * 0.19)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private func cloudShape(size s: Double) -> some Shape {
    WeatherCloudShape()
}

private struct WeatherCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.addEllipse(in: CGRect(x: w * 0.16, y: h * 0.38, width: w * 0.30, height: h * 0.27))
        path.addEllipse(in: CGRect(x: w * 0.31, y: h * 0.25, width: w * 0.35, height: h * 0.38))
        path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.36, width: w * 0.29, height: h * 0.28))
        path.addRoundedRect(in: CGRect(x: w * 0.19, y: h * 0.48, width: w * 0.60, height: h * 0.22), cornerSize: CGSize(width: h * 0.11, height: h * 0.11))
        return path
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.60, y: rect.midY * 0.86))
        path.closeSubpath()
        return path
    }
}

private struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for angle in stride(from: 0.0, to: 180.0, by: 60.0) {
            let a = Angle(degrees: angle).radians
            let dx = cos(a) * r
            let dy = sin(a) * r
            path.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
            path.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
        }
        return path
    }
}

private struct WindLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY),
            control2: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.maxY)
        )
        return path
    }
}

private extension View {
    func weatherCardBackground(layout: WeatherWidgetRenderLayout, tokens: WeatherWidgetCardTokens) -> some View {
        background {
            RoundedRectangle(cornerRadius: scaledCornerRadius(layout), style: .continuous)
                .fill(tokens.background)
                .overlay {
                    RoundedRectangle(cornerRadius: scaledCornerRadius(layout), style: .continuous)
                        .stroke(tokens.strokeColor.opacity(tokens.strokeOpacity), lineWidth: max(1, layout.rect.width / layout.style.width))
                }
                .shadow(color: tokens.shadow, radius: max(4, layout.rect.width * 0.025), x: 0, y: max(2, layout.rect.height * 0.04))
        }
    }

    private func scaledCornerRadius(_ layout: WeatherWidgetRenderLayout) -> Double {
        layout.style.cardCornerRadius * layout.rect.width / layout.style.width
    }
}
