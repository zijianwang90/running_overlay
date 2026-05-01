import SwiftUI

private extension Color {
    init(_ overlayColor: OverlayColor) {
        self.init(red: overlayColor.red, green: overlayColor.green, blue: overlayColor.blue, opacity: overlayColor.alpha)
    }
}

struct WeatherWidgetOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<WeatherSection> = Set(WeatherSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        presetSection(element)
                        contentSection(element)
                        locationSection(element)
                        temperatureSection(element)
                        metricsSection(element)
                        iconSection(element)
                        appearanceSection(element)
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .padding(.bottom, NumericTokens.panelPaddingY)
                }
                Divider().overlay(NumericTokens.borderSubtle)
                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Section model

    private enum WeatherSection: String, CaseIterable {
        case layout, preset, content, location, temperature, metrics, icon, appearance

        var title: String {
            switch self {
            case .layout: "Layout"
            case .preset: "Preset"
            case .content: "Content"
            case .location: "Location"
            case .temperature: "Temperature"
            case .metrics: "Metrics"
            case .icon: "Icon"
            case .appearance: "Appearance"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .preset: "rectangle.3.group"
            case .content: "text.alignleft"
            case .location: "location"
            case .temperature: "thermometer"
            case .metrics: "chart.bar"
            case .icon: "cloud.sun"
            case .appearance: "paintpalette"
            }
        }
    }

    // MARK: - Section wrapper

    private func sectionView<Content: View>(
        _ section: WeatherSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isOpen = openSections.contains(section)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture {
                if isOpen {
                    openSections.remove(section)
                } else {
                    openSections.insert(section)
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1)
            }

            if isOpen {
                VStack(spacing: 0) { content() }
            }
        }
    }

    // MARK: - Header

    private func header(element: OverlayElement) -> some View {
        HStack(spacing: NumericTokens.space3) {
            Button {
                project.selection = .none
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .buttonStyle(.plain).help("Back")

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Weather Widget").font(.system(size: 15, weight: .semibold)).foregroundStyle(NumericTokens.textPrimary)
                    Text("Weather").font(NumericTokens.captionFont).foregroundStyle(NumericTokens.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(NumericTokens.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                }
            }
            Spacer()

            Button(role: .destructive) {
                project.deleteOverlay(element.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            .buttonStyle(.plain).help("Delete")
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) {
            Divider().overlay(NumericTokens.borderSubtle)
        }
    }

    // MARK: - Layout section

    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        sectionView(.layout, element: element) {
            OverlayLayoutInspectorRows(
                elementID: elementID,
                widthBinding: Binding(
                    get: { element.style.weatherWidget.width },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.width = v } }
                ),
                widthRange: 80...800,
                heightBinding: Binding(
                    get: { element.style.weatherWidget.height },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.height = v } }
                ),
                heightRange: 40...400
            )
        }
    }

    // MARK: - Preset section (reuse layout section header for layout)

    private func presetSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.preset, element: element) {
            InspectorDenseRow(label: "Preset") {
                Menu {
                    ForEach(WeatherWidgetPreset.allCases) { preset in
                        Button {
                            project.mutateWeatherWidgetStyle(elementID) { style in
                                let content = style
                                style = WeatherWidgetStyle.preset(preset)
                                style.manualCondition = content.manualCondition
                                style.manualTemperatureCelsius = content.manualTemperatureCelsius
                                style.manualHumidity = content.manualHumidity
                                style.manualHigh = content.manualHigh
                                style.manualLow = content.manualLow
                                style.manualWind = content.manualWind
                                style.manualFeelsLike = content.manualFeelsLike
                                style.temperatureUnit = content.temperatureUnit
                                style.locationText = content.locationText
                                style.cachedWeather = content.cachedWeather
                            }
                        } label: {
                            if preset == s.preset { Label(preset.label, systemImage: "checkmark") }
                            else { Text(preset.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: s.preset.label)
                }
            }
            InspectorDenseRow(label: "Data Source") {
                Menu {
                    ForEach(WeatherDataSource.allCases) { ds in
                        Button {
                            project.mutateWeatherWidgetStyle(elementID) { $0.dataSource = ds }
                        } label: {
                            if ds == s.dataSource { Label(ds.label, systemImage: "checkmark") }
                            else { Text(ds.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: s.dataSource.label)
                }
            }
        }
    }

    // MARK: - Content section

    private func contentSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.content, element: element) {
            InspectorDenseRow(label: "Condition") {
                Menu {
                    ForEach(WeatherCondition.allCases) { cond in
                        Button {
                            project.mutateWeatherWidgetStyle(elementID) { $0.manualCondition = cond }
                        } label: {
                            HStack {
                                Image(systemName: cond.sfSymbolName).foregroundStyle(Color(cond.iconTint))
                                if cond == s.manualCondition {
                                    Label(cond.label, systemImage: "checkmark")
                                } else { Text(cond.label) }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: s.manualCondition.sfSymbolName).foregroundStyle(Color(s.manualCondition.iconTint))
                        InspectorDenseMenuLabel(title: s.manualCondition.label)
                    }
                }
            }
        }
    }

    // MARK: - Location section

    private func locationSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.location, element: element) {
            InspectorDenseRow(label: "Location") {
                TextField("e.g. Osaka, Japan", text: Binding(
                    get: { s.locationText },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.locationText = v } }
                ))
                .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).multilineTextAlignment(.trailing).frame(maxWidth: 180)
            }
            InspectorDenseRow(label: "Show Location") {
                Toggle("", isOn: Binding(
                    get: { s.showLocation },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showLocation = v } }
                )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
            }
            InspectorDenseRow(label: "Show Weekday") {
                Toggle("", isOn: Binding(
                    get: { s.showWeekday },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showWeekday = v } }
                )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
            }
        }
    }

    // MARK: - Temperature section

    private func temperatureSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.temperature, element: element) {
            InspectorDenseRow(label: "Temperature") {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { s.manualTemperatureCelsius },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualTemperatureCelsius = v } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 56)
                    Text("°C").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                }
            }
            InspectorDenseRow(label: "Unit") {
                Menu {
                    ForEach(WeatherTemperatureUnit.allCases) { unit in
                        Button {
                            project.mutateWeatherWidgetStyle(elementID) { $0.temperatureUnit = unit }
                        } label: {
                            if unit == s.temperatureUnit { Label(unit.label, systemImage: "checkmark") }
                            else { Text(unit.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: s.temperatureUnit.shortLabel)
                }
            }
        }
    }

    // MARK: - Metrics section

    private func metricsSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.metrics, element: element) {
            InspectorDenseRow(label: "Humidity") {
                HStack(spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { s.showHumidity },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showHumidity = v } }
                    )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
                    if s.showHumidity {
                        TextField("", value: Binding(
                            get: { s.manualHumidity },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualHumidity = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 46)
                        Text("%").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                    }
                }
            }
            InspectorDenseRow(label: "High / Low") {
                HStack(spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { s.showHighLow },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showHighLow = v } }
                    )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
                    if s.showHighLow {
                        TextField("", value: Binding(
                            get: { s.manualHigh },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualHigh = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 42)
                        TextField("", value: Binding(
                            get: { s.manualLow },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualLow = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 42)
                    }
                }
            }
            InspectorDenseRow(label: "Wind") {
                HStack(spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { s.showWind },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showWind = v } }
                    )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
                    if s.showWind {
                        TextField("", value: Binding(
                            get: { s.manualWind },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualWind = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 46)
                        Text("km/h").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                    }
                }
            }
            InspectorDenseRow(label: "Feels Like") {
                HStack(spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { s.showFeelsLike },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showFeelsLike = v } }
                    )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
                    if s.showFeelsLike {
                        TextField("", value: Binding(
                            get: { s.manualFeelsLike },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualFeelsLike = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 46)
                        Text("°C").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Icon section

    private func iconSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.icon, element: element) {
            InspectorDenseRow(label: "Condition Label") {
                Toggle("", isOn: Binding(
                    get: { s.showConditionLabel },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showConditionLabel = v } }
                )).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
            }
            InspectorDenseSliderRow(
                label: "Icon Size", value: Binding(
                    get: { s.iconSize },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.iconSize = v } }
                ), range: 12...80, displayText: "\(Int(s.iconSize.rounded()))"
            )
            InspectorDenseSliderRow(
                label: "Corner Radius", value: Binding(
                    get: { s.cardCornerRadius },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.cardCornerRadius = v } }
                ), range: 0...56, displayText: "\(Int(s.cardCornerRadius.rounded()))"
            )
        }
    }

    // MARK: - Appearance section

    private func appearanceSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.appearance, element: element) {
            InspectorDenseRow(label: "Card Color") {
                InspectorDenseSwatchStrip(presets: colorPresets, selected: s.cardBackgroundColor) { color in
                    project.mutateWeatherWidgetStyle(elementID) { $0.cardBackgroundColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Card Opacity", value: Binding(
                    get: { s.cardBackgroundOpacity },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.cardBackgroundOpacity = v } }
                ), range: 0...1, displayText: String(format: "%.0f%%", s.cardBackgroundOpacity * 100)
            )
        }
    }

    private let colorPresets: [(name: String, color: OverlayColor)] = [
        ("White", .white), ("Black", .black), ("Red", .red), ("Orange", .orange),
        ("Yellow", .yellow), ("Green", .green), ("Blue", .blue), ("Cyan", .cyan),
        ("Purple", .purple), ("Pink", .pink)
    ]

    // MARK: - Footer

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset", leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done", trailingSystemImage: "checkmark",
            onLeadingTap: {
                project.mutateWeatherWidgetStyle(elementID) { style in
                    let unit = style.temperatureUnit
                    style = WeatherWidgetStyle.preset(style.preset)
                    style.temperatureUnit = unit
                }
            },
            onTrailingTap: { project.selection = .none }
        )
    }
}
