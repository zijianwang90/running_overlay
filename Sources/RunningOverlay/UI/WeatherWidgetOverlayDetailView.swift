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
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        presetSection(element)
                        locationSection(element)
                        weatherSection(element)
                        appearanceSection(element)
                        typographySection(element)
                    }
                    .padding(.bottom, NumericTokens.panelPaddingY)
                }
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Section model

    private enum WeatherSection: String, CaseIterable {
        case layout, preset, location, weather, appearance, typography

        var title: String {
            switch self {
            case .layout: "Layout"
            case .preset: "Preset"
            case .appearance: "Appearance"
            case .typography: "Typography"
            case .location: "Location"
            case .weather: "Weather"
            }
        }
    }

    // MARK: - Section wrapper

    private func sectionView<Content: View>(
        _ section: WeatherSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let body = content()
        return InspectorCollapsibleSection(title: section.title, isExpanded: sectionExpansion(section)) { body }
    }

    private func sectionExpansion(_ section: WeatherSection) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { isOpen in
                if isOpen { openSections.insert(section) } else { openSections.remove(section) }
            }
        )
    }

    // MARK: - Header

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
                        Button { project.applyWeatherWidgetPreset(elementID, preset: preset) } label: {
                            if preset == s.preset { Label(preset.label, systemImage: "checkmark") }
                            else { Text(preset.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: s.preset.label)
                }
                .inspectorMenuStyle()
                .frame(height: NumericTokens.controlHeight)
            }
        }
    }

    // MARK: - Weather section

    private func weatherSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        let usesAPI = s.dataSource.isAPI
        let metricSlots = s.normalizedMetricSlots()
        let hasFITTemperature = project.activity.hasTemperatureData
        let hasOpenWeatherKey = !project.openWeatherAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return sectionView(.weather, element: element) {
            InspectorDenseRow(label: "Data Source") {
                Menu {
                    ForEach(WeatherDataSource.inspectorCases) { ds in
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
                .inspectorMenuStyle()
            }

            if hasFITTemperature {
                InspectorDenseRow(label: "From Activity") {
                    Toggle("", isOn: Binding(
                        get: { s.useFITTemperature },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.useFITTemperature = v } }
                    ))
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .labelsHidden()
                    .help("Use the temperature recorded in the activity")
                    .tint(NumericTokens.accentBlue)
                }
            }

            if usesAPI {
                InspectorDenseRow(label: "Condition") {
                    Text("From \(s.dataSource.label)")
                        .font(NumericTokens.bodyFont)
                        .foregroundStyle(NumericTokens.textSecondary)
                }
                if s.dataSource == .openWeather, !hasOpenWeatherKey {
                    InspectorDenseRow(label: "API Key") {
                        Text("Set in Project Settings")
                            .font(NumericTokens.bodyFont)
                            .foregroundStyle(EditorTheme.warningYellow)
                    }
                }
            } else {
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
                        .inspectorMenuStyle()
                    }
                }
                InspectorDenseRow(label: "Label Override") {
                    TextField("Auto", text: Binding(
                        get: { s.conditionLabelOverride },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.conditionLabelOverride = v } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(NumericTokens.bodyFont)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                }
                InspectorDenseRow(label: "Temperature") {
                    HStack(spacing: 4) {
                        TextField("", value: Binding(
                            get: { s.manualTemperatureCelsius },
                            set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualTemperatureCelsius = v } }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(NumericTokens.bodyFont)
                        .frame(width: 56)
                        Text("°C").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                    }
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
                .inspectorMenuStyle()
            }

            if s.preset.metricSlotCount == 0 {
                InspectorDenseRow(label: "Metric Slots") {
                    Text("None for this style")
                        .font(NumericTokens.bodyFont)
                        .foregroundStyle(NumericTokens.textSecondary)
                }
            } else {
                ForEach(0..<s.preset.metricSlotCount, id: \.self) { index in
                    metricSlotRow(index: index, selected: metricSlots[index])
                }
            }

            if !usesAPI {
                ForEach(manualMetricInputs(for: metricSlots), id: \.self) { metric in
                    manualMetricInputRow(metric, style: s)
                }
            }

            InspectorDenseRow(label: "Show Icon") {
                Toggle("", isOn: Binding(
                    get: { s.showIcon },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showIcon = v } }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }

            InspectorDenseRow(label: "Condition Label") {
                Toggle("", isOn: Binding(
                    get: { s.showConditionLabel },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showConditionLabel = v } }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }
        }
    }

    private func metricSlotRow(index: Int, selected: WeatherMetricSlotValue) -> some View {
        InspectorDenseRow(label: "Slot \(index + 1)") {
            Menu {
                ForEach(WeatherMetricSlotValue.allCases) { metric in
                    Button {
                        project.mutateWeatherWidgetStyle(elementID) { style in
                            var slots = style.normalizedMetricSlots()
                            guard slots.indices.contains(index) else { return }
                            slots[index] = metric
                            style.metricSlots = WeatherWidgetStyle.normalizedMetricSlots(slots, for: style.preset)
                        }
                    } label: {
                        if metric == selected { Label(metric.label, systemImage: "checkmark") }
                        else { Text(metric.label) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: selected.label)
            }
            .inspectorMenuStyle()
        }
    }

    private func manualMetricInputs(for slots: [WeatherMetricSlotValue]) -> [WeatherMetricSlotValue] {
        WeatherMetricSlotValue.allCases.filter { $0 != .none && slots.contains($0) }
    }

    @ViewBuilder
    private func manualMetricInputRow(_ metric: WeatherMetricSlotValue, style s: WeatherWidgetStyle) -> some View {
        switch metric {
        case .none:
            EmptyView()
        case .humidity:
            InspectorDenseRow(label: "Humidity") {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { s.manualHumidity },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualHumidity = v } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 46)
                    Text("%").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                }
            }
        case .highLow:
            InspectorDenseRow(label: "High / Low") {
                HStack(spacing: 4) {
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
        case .wind:
            InspectorDenseRow(label: "Wind") {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { s.manualWind },
                        set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.manualWind = v } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder).font(NumericTokens.bodyFont).frame(width: 46)
                    Text("km/h").font(NumericTokens.bodyFont).foregroundStyle(NumericTokens.textSecondary)
                }
            }
        case .feelsLike:
            InspectorDenseRow(label: "Feels Like") {
                HStack(spacing: 4) {
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

    // MARK: - Location section

    private func locationSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        let hasActivityLocation = project.activity.routePoints.first != nil
        let hasOpenWeatherKey = !project.openWeatherAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let canFetchSelectedAPI = s.dataSource != .openWeather || hasOpenWeatherKey
        return sectionView(.location, element: element) {
            InspectorDenseRow(label: "API Fetch") {
                Button {
                    project.fetchWeatherForActivityLocation(elementID)
                } label: {
                    Image(systemName: "figure.run")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(!hasActivityLocation || !canFetchSelectedAPI)
                .help(fetchHelpText(base: "Fetch weather by the activity's GPS start position", dataSource: s.dataSource, hasOpenWeatherKey: hasOpenWeatherKey))
                .accessibilityLabel("Fetch weather")
            }
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
                )).toggleStyle(.checkbox).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
            }
            InspectorDenseRow(label: "Show Weekday") {
                Toggle("", isOn: Binding(
                    get: { s.showWeekday },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.showWeekday = v } }
                )).toggleStyle(.checkbox).controlSize(.mini).labelsHidden().tint(NumericTokens.accentBlue)
            }
        }
    }

    private func fetchHelpText(base: String, dataSource: WeatherDataSource, hasOpenWeatherKey: Bool) -> String {
        if dataSource == .openWeather, !hasOpenWeatherKey {
            return "Add an OpenWeather API key in Project Settings first."
        }
        return base
    }

    // MARK: - Appearance section

    private func appearanceSection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.appearance, element: element) {
            InspectorDenseRow(label: "Palette") {
                Menu {
                    ForEach(WeatherWidgetPalette.allCases) { palette in
                        Button {
                            project.mutateWeatherWidgetStyle(elementID) { $0.palette = palette }
                        } label: {
                            if palette == s.palette { Label(palette.label, systemImage: "checkmark") }
                            else { Text(palette.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: s.palette.label)
                }
                .inspectorMenuStyle()
            }
            InspectorDenseSliderRow(
                label: "Card Opacity", value: Binding(
                    get: { s.cardBackgroundOpacity },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.cardBackgroundOpacity = v } }
                ), range: 0...1, displayText: String(format: "%.0f%%", s.cardBackgroundOpacity * 100)
            )
            InspectorDenseSliderRow(
                label: "Corner Radius", value: Binding(
                    get: { s.cardCornerRadius },
                    set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.cardCornerRadius = v } }
                ), range: 0...56, displayText: "\(Int(s.cardCornerRadius.rounded()))"
            )
            InspectorDenseRow(label: "Show Divider") {
                Toggle("", isOn: Binding(
                    get: { s.dividerEnabled },
                    set: { v in project.mutateWeatherWidgetStyle(elementID) { $0.dividerEnabled = v } }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .labelsHidden()
                .tint(NumericTokens.accentBlue)
            }
            if s.dividerEnabled {
                InspectorDenseRow(label: "Divider Color") {
                    InspectorDenseSwatchStrip(presets: colorPresets, selected: s.dividerColor) { color in
                        project.mutateWeatherWidgetStyle(elementID) { $0.dividerColor = color }
                    }
                }
                InspectorDenseSliderRow(
                    label: "Divider Width", value: Binding(
                        get: { s.dividerThickness },
                        set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.dividerThickness = v } }
                    ), range: 0.5...6, displayText: String(format: "%.1f", s.dividerThickness)
                )
                InspectorDenseSliderRow(
                    label: "Divider Opacity", value: Binding(
                        get: { s.dividerOpacity },
                        set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.dividerOpacity = v } }
                    ), range: 0...1, displayText: String(format: "%.0f%%", s.dividerOpacity * 100)
                )
            }
            if s.preset == .dashboardBar {
                InspectorDenseRow(label: "Slot Color") {
                    InspectorDenseSwatchStrip(presets: colorPresets, selected: s.slotBackgroundColor) { color in
                        project.mutateWeatherWidgetStyle(elementID) { $0.slotBackgroundColor = color }
                    }
                }
                InspectorDenseSliderRow(
                    label: "Slot Opacity", value: Binding(
                        get: { s.slotBackgroundOpacity },
                        set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.slotBackgroundOpacity = v } }
                    ), range: 0...1, displayText: String(format: "%.0f%%", s.slotBackgroundOpacity * 100)
                )
                InspectorDenseSliderRow(
                    label: "Slot Spacing", value: Binding(
                        get: { s.slotSpacing },
                        set: { v in project.mutateWeatherWidgetStyleContinuous(elementID) { $0.slotSpacing = v } }
                    ), range: 0...40, displayText: String(format: "%.0f", s.slotSpacing)
                )
            }
        }
    }

    // MARK: - Typography section

    private func typographySection(_ element: OverlayElement) -> some View {
        let s = element.style.weatherWidget
        return sectionView(.typography, element: element) {
            textStyleRows(
                title: "Location",
                style: s.locationTextStyle,
                writer: { mut in project.mutateWeatherWidgetStyle(elementID) { mut(&$0.locationTextStyle) } },
                writerContinuous: { mut in project.mutateWeatherWidgetStyleContinuous(elementID) { mut(&$0.locationTextStyle) } }
            )
            textStyleRows(
                title: "Condition",
                style: s.conditionTextStyle,
                writer: { mut in project.mutateWeatherWidgetStyle(elementID) { mut(&$0.conditionTextStyle) } },
                writerContinuous: { mut in project.mutateWeatherWidgetStyleContinuous(elementID) { mut(&$0.conditionTextStyle) } }
            )
            textStyleRows(
                title: "Temperature",
                style: s.temperatureTextStyle,
                writer: { mut in project.mutateWeatherWidgetStyle(elementID) { mut(&$0.temperatureTextStyle) } },
                writerContinuous: { mut in project.mutateWeatherWidgetStyleContinuous(elementID) { mut(&$0.temperatureTextStyle) } }
            )
            textStyleRows(
                title: "Slot Title",
                style: s.slotTitleTextStyle,
                writer: { mut in project.mutateWeatherWidgetStyle(elementID) { mut(&$0.slotTitleTextStyle) } },
                writerContinuous: { mut in project.mutateWeatherWidgetStyleContinuous(elementID) { mut(&$0.slotTitleTextStyle) } }
            )
            textStyleRows(
                title: "Slot Label",
                style: s.slotLabelTextStyle,
                writer: { mut in project.mutateWeatherWidgetStyle(elementID) { mut(&$0.slotLabelTextStyle) } },
                writerContinuous: { mut in project.mutateWeatherWidgetStyleContinuous(elementID) { mut(&$0.slotLabelTextStyle) } }
            )
        }
    }

    @ViewBuilder
    private func textStyleRows(
        title: String,
        style: WeatherTextStyle,
        writer: @escaping ((inout WeatherTextStyle) -> Void) -> Void,
        writerContinuous: @escaping ((inout WeatherTextStyle) -> Void) -> Void
    ) -> some View {
        InspectorDenseRow(label: title) {
            Text("")
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textSecondary)
        }
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(InspectorPresets.fontPresets, id: \.self) { name in
                    Button {
                        writer { $0.fontName = name }
                    } label: {
                        if name == style.fontName { Label(name, systemImage: "checkmark") }
                        else { Text(name) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: style.fontName)
            }
            .inspectorMenuStyle()
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: Binding(
                get: { style.fontSize },
                set: { v in writerContinuous { $0.fontSize = v.rounded() } }
            ),
            range: 6...96,
            displayText: "\(Int(style.fontSize.rounded()))"
        )
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { style.fontWeight },
                set: { v in writer { $0.fontWeight = v } }
            )) { weight in
                Text(weatherWeightLabel(weight)).lineLimit(1)
            }
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(presets: colorPresets, selected: style.color) { color in
                writer { $0.color = OverlayColor(red: color.red, green: color.green, blue: color.blue, alpha: style.color.alpha) }
            }
        }
        InspectorDenseSliderRow(
            label: "Alpha",
            value: Binding(
                get: { style.color.alpha },
                set: { v in writerContinuous { $0.color.alpha = v } }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", style.color.alpha * 100)
        )
    }

    private func weatherWeightLabel(_ weight: OverlayFontWeight) -> String {
        switch weight {
        case .regular: "Reg"
        case .medium: "Med"
        case .semibold: "Semi"
        case .bold: "Bold"
        }
    }

    private let colorPresets: [(name: String, color: OverlayColor)] = [
        ("White", .white), ("Black", .black), ("Red", .red), ("Orange", .orange),
        ("Yellow", .yellow), ("Green", .green), ("Blue", .blue), ("Cyan", .cyan),
        ("Purple", .purple), ("Pink", .pink)
    ]

    // MARK: - Footer

}
