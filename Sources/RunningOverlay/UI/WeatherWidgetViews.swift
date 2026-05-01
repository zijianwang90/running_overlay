import SwiftUI

private extension Color {
    init(_ overlayColor: OverlayColor) {
        self.init(red: overlayColor.red, green: overlayColor.green, blue: overlayColor.blue, opacity: overlayColor.alpha)
    }
}

// MARK: - Shared Wrapper

struct OverlaySharedWeatherWidgetView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        Group {
            switch layout.style.preset {
            case .simpleCard: SimpleCardWeatherView(element: element, layout: layout)
            case .compactStrip: CompactStripWeatherView(element: element, layout: layout)
            case .forecastTile: ForecastTileWeatherView(element: element, layout: layout)
            case .minimalText: MinimalTextWeatherView(element: element, layout: layout)
            case .dashboardBar: DashboardBarWeatherView(element: element, layout: layout)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }
}

// MARK: - Simple Card (300×110)

private struct SimpleCardWeatherView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: layout.sfSymbolName)
                .font(.system(size: layout.iconSize))
                .foregroundStyle(Color(layout.iconTint))
                .frame(width: layout.iconSize + 8)

            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 2) {
                if layout.style.showLocation && !layout.locationText.isEmpty {
                    Text(layout.locationText)
                        .font(.system(size: layout.fontSize * 0.9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(layout.temperatureFormatted)
                        .font(.system(size: layout.fontSize * 1.7, weight: .bold))
                        .foregroundStyle(.white)
                    if layout.style.showConditionLabel {
                        Text(layout.conditionLabel)
                            .font(.system(size: layout.fontSize * 0.75))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                if layout.style.showHumidity && !layout.humidityFormatted.isEmpty {
                    Text(layout.humidityFormatted)
                        .font(.system(size: layout.fontSize * 0.7))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.style.cardCornerRadius)
            .fill(Color(layout.style.cardBackgroundColor).opacity(layout.style.cardBackgroundOpacity))
    }
}

// MARK: - Compact Strip (220×56)

private struct CompactStripWeatherView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: layout.sfSymbolName)
                .font(.system(size: layout.iconSize))
                .foregroundStyle(Color(layout.iconTint))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(layout.temperatureFormatted)
                        .font(.system(size: layout.fontSize * 1.5, weight: .bold))
                        .foregroundStyle(.white)
                    if layout.style.showConditionLabel {
                        Text(layout.conditionLabel)
                            .font(.system(size: layout.fontSize * 0.65))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                if layout.style.showLocation && !layout.locationText.isEmpty {
                    Text(layout.locationText)
                        .font(.system(size: layout.fontSize * 0.6))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.style.cardCornerRadius)
            .fill(Color(layout.style.cardBackgroundColor).opacity(layout.style.cardBackgroundOpacity))
    }
}

// MARK: - Forecast Tile (180×180)

private struct ForecastTileWeatherView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        VStack(spacing: 4) {
            if layout.style.showLocation && !layout.locationText.isEmpty {
                Text(layout.locationText)
                    .font(.system(size: layout.fontSize * 1.1, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            if layout.style.showWeekday && !layout.weekdayText.isEmpty {
                Text(layout.weekdayText)
                    .font(.system(size: layout.fontSize * 0.85))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)

            Image(systemName: layout.sfSymbolName)
                .font(.system(size: layout.iconSize))
                .foregroundStyle(Color(layout.iconTint))

            Text(layout.temperatureFormatted)
                .font(.system(size: layout.fontSize * 2.2, weight: .bold))
                .foregroundStyle(.white)

            if layout.style.showHighLow && (!layout.highFormatted.isEmpty || !layout.lowFormatted.isEmpty) {
                HStack(spacing: 10) {
                    if !layout.highFormatted.isEmpty {
                        Text("H \(layout.highFormatted)")
                            .font(.system(size: layout.fontSize * 0.7))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if !layout.lowFormatted.isEmpty {
                        Text("L \(layout.lowFormatted)")
                            .font(.system(size: layout.fontSize * 0.7))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            if layout.style.showHumidity && !layout.humidityFormatted.isEmpty {
                Text(layout.humidityFormatted)
                    .font(.system(size: layout.fontSize * 0.65))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.style.cardCornerRadius)
            .fill(Color(layout.style.cardBackgroundColor).opacity(layout.style.cardBackgroundOpacity))
    }
}

// MARK: - Minimal Text (160×92)

private struct MinimalTextWeatherView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: layout.sfSymbolName)
                    .font(.system(size: layout.iconSize))
                    .foregroundStyle(Color(layout.iconTint))
                Text(layout.temperatureFormatted)
                    .font(.system(size: layout.fontSize * 2.0, weight: .bold))
                    .foregroundStyle(.white)
            }
            if layout.style.showLocation && !layout.locationText.isEmpty {
                Text(layout.locationText)
                    .font(.system(size: layout.fontSize * 0.85))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.style.cardCornerRadius)
            .fill(Color(layout.style.cardBackgroundColor).opacity(layout.style.cardBackgroundOpacity))
    }
}

// MARK: - Dashboard Bar (460×86)

private struct DashboardBarWeatherView: View {
    let element: OverlayElement
    let layout: WeatherWidgetRenderLayout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: layout.sfSymbolName)
                .font(.system(size: layout.iconSize))
                .foregroundStyle(Color(layout.iconTint))

            VStack(alignment: .leading, spacing: 0) {
                if layout.style.showLocation && !layout.locationText.isEmpty {
                    Text(layout.locationText)
                        .font(.system(size: layout.fontSize * 1.0, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                if layout.style.showConditionLabel {
                    Text(layout.conditionLabel)
                        .font(.system(size: layout.fontSize * 0.7))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Text(layout.temperatureFormatted)
                .font(.system(size: layout.fontSize * 2.4, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if layout.style.showHumidity && !layout.humidityFormatted.isEmpty {
                    metricChip(value: layout.humidityFormatted)
                }
                if layout.style.showWind && !layout.windFormatted.isEmpty {
                    metricChip(value: layout.windFormatted)
                }
                if layout.style.showFeelsLike && !layout.feelsLikeFormatted.isEmpty {
                    metricChip(value: "Feels \(layout.feelsLikeFormatted)")
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
    }

    private func metricChip(value: String) -> some View {
        Text(value)
            .font(.system(size: layout.fontSize * 0.7, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.style.cardCornerRadius)
            .fill(Color(layout.style.cardBackgroundColor).opacity(layout.style.cardBackgroundOpacity))
    }
}
