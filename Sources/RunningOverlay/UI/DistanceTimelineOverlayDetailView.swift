import SwiftUI

struct DistanceTimelineOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<DistanceTimelineSection> = [.preset, .layout, .value, .progress]

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.preset) { presetSection(element) }
                        layoutInspectorSection(element)
                        sectionView(.value) { valueSection(element) }
                        sectionView(.label) { labelSection(element) }
                        sectionView(.progress) { progressSection(element) }
                        sectionView(.axisLabels) { axisLabelsSection(element) }
                        statsBarInspectorSection(element)
                        if element.style.distanceTimeline.preset.supportsMediaSlot {
                            sectionView(.mediaSlot) { mediaSlotSection(element) }
                        }
                        if element.style.distanceTimeline.preset.supportsElevation {
                            sectionView(.routeElevation) { routeElevationSection(element) }
                        }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Divider().overlay(NumericTokens.borderSubtle)
                footerBar
            } else {
                Spacer()
            }
        }
    }

    private func header(_ element: OverlayElement) -> some View {
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
            }
            .buttonStyle(.plain)

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumericTokens.accentBlue)
                .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text(element.style.distanceTimeline.preset.compactLabel)
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            Spacer()
            Button(role: .destructive) {
                project.deleteOverlay(element.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                    .foregroundStyle(NumericTokens.dangerRed)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) { Divider().overlay(NumericTokens.borderSubtle) }
    }

    @ViewBuilder
    private func presetSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Preset") {
            Menu {
                ForEach(DistanceTimelinePreset.allCases) { preset in
                    Button {
                        project.setOverlayDistanceTimelinePreset(elementID, preset: preset)
                    } label: {
                        if style.preset == preset {
                            Label(preset.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(preset.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: style.preset.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func valueSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Value") {
            toggle(style.showValue) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showValue = newValue }
            }
        }
        InspectorDenseRow(label: "Units") {
            InspectorDenseSegmented(values: DistanceTimelineUnitSystem.allCases, selection: Binding(
                get: { style.valueUnitSystem },
                set: { unit in project.mutateDistanceTimelineStyle(elementID) { $0.valueUnitSystem = unit } }
            )) { unit in
                Text(unit.label)
            }
        }
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        project.setOverlayFontName(elementID, fontName: name)
                    } label: {
                        Text(name)
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.fontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseSliderRow(label: "Size", value: Binding(
            get: { element.style.fontSize },
            set: { project.setOverlayFontSize(elementID, fontSize: $0.rounded()) }
        ), range: 12...72, displayText: "\(Int(element.style.fontSize))")
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { element.style.fontWeight },
                set: { project.setOverlayFontWeight(elementID, fontWeight: $0) }
            )) { weight in
                Text(weight.label)
            }
        }
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: element.style.foregroundColor) { color in
                project.setOverlayForegroundColor(elementID, color: color)
            }
        }
        InspectorDenseSliderRow(label: "Progress Gap", value: distanceBinding(\.valueProgressSpacing, of: style), range: 0...48, displayText: "\(Int(style.valueProgressSpacing))")
        InspectorDenseRow(label: "Custom Values") {
            toggle(style.customValuesEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.customValuesEnabled = newValue }
            }
        }
        if style.customValuesEnabled {
            InspectorDenseSliderRow(label: "Group Gap", value: distanceBinding(\.customValuesGroupSpacing, of: style), range: 0...80, displayText: "\(Int(style.customValuesGroupSpacing))")
            InspectorDenseSliderRow(label: "Item Gap", value: distanceBinding(\.customValueSpacing, of: style), range: 0...48, displayText: "\(Int(style.customValueSpacing))")
            InspectorDenseSliderRow(label: "Custom Size", value: distanceBinding(\.customValueFontSize, of: style), range: 8...32, displayText: "\(Int(style.customValueFontSize))")
            InspectorDenseRow(label: "Custom Color") {
                InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.customValueColor) { color in
                    project.mutateDistanceTimelineStyle(elementID) { $0.customValueColor = color }
                }
            }
            InspectorDenseSliderRow(label: "Custom Opacity", value: distanceBinding(\.customValueOpacity, of: style), range: 0...1, displayText: String(format: "%.0f%%", style.customValueOpacity * 100))
            ForEach(0..<4, id: \.self) { index in
                let custom = style.customValues[safe: index] ?? .empty
                InspectorDenseRow(label: "Custom \(index + 1)") {
                    Menu {
                        ForEach(RouteMapStatsMetric.allCases) { metric in
                            Button {
                                project.mutateDistanceTimelineStyle(elementID) { $0.setCustomValueMetric(metric, at: index) }
                            } label: {
                                if metric == custom.metric { Label(metric.label, systemImage: "checkmark") }
                                else { Text(metric.label) }
                            }
                        }
                    } label: {
                        InspectorDenseMenuLabel(title: custom.metric.label, isEnabled: custom.visible)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: NumericTokens.controlHeight)
                    Toggle("", isOn: Binding(
                        get: { custom.visible },
                        set: { newValue in project.mutateDistanceTimelineStyle(elementID) { $0.setCustomValueVisible(newValue, at: index) } }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private func labelSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Show Label") {
            toggle(style.showLabel) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showLabel = newValue }
            }
        }
        InspectorDenseRow(label: "Text") {
            TextField("Distance", text: Binding(
                get: { style.label },
                set: { value in project.mutateDistanceTimelineStyle(elementID) { $0.label = value } }
            ), onCommit: { project.finishContinuousEdit() })
            .textFieldStyle(.plain)
            .font(NumericTokens.bodyFont)
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        }
        typographyRows(
            title: "Label",
            fontName: style.labelFontName,
            fontSize: style.labelFontSize,
            fontWeight: style.labelFontWeight,
            color: style.labelColor,
            isEnabled: style.showLabel,
            onSetFontName: { value in project.mutateDistanceTimelineStyle(elementID) { $0.labelFontName = value } },
            onSetFontSize: { value in project.mutateDistanceTimelineStyle(elementID) { $0.labelFontSize = value.rounded() } },
            onSetFontWeight: { value in project.mutateDistanceTimelineStyle(elementID) { $0.labelFontWeight = value } },
            onSetColor: { value in project.mutateDistanceTimelineStyle(elementID) { $0.labelColor = value } }
        )
        InspectorDenseSliderRow(label: "Value Gap", value: distanceBinding(\.labelValueSpacing, of: style), range: 0...32, displayText: "\(Int(style.labelValueSpacing))", isEnabled: style.showLabel)
    }

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        CollapsibleLayoutInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.layout) },
                set: { newValue in
                    if newValue { openSections.insert(.layout) }
                    else { openSections.remove(.layout) }
                }
            )
        ) {
            OverlayLayoutInspectorRows(
                elementID: elementID,
                widthBinding: distanceBinding(\.width, of: style),
                widthRange: 180...640,
                heightBinding: distanceBinding(\.height, of: style),
                heightRange: 52...150
            )
        }
    }

    @ViewBuilder
    private func progressSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Fill Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.fillColor) { color in
                project.mutateDistanceTimelineStyle(elementID) { $0.fillColor = color }
            }
        }
        InspectorDenseSliderRow(label: "Track Height", value: distanceBinding(\.trackHeight, of: style), range: 2...18, displayText: "\(Int(style.trackHeight))")
        InspectorDenseSliderRow(label: "Track Opacity", value: distanceBinding(\.trackOpacity, of: style), range: 0...1, displayText: String(format: "%.0f%%", style.trackOpacity * 100))
        InspectorDenseRow(label: "Ticks") {
            toggle(style.tickMarksEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.tickMarksEnabled = newValue }
            }
        }
        InspectorDenseSliderRow(label: "Tick Density", value: Binding(
            get: { Double(style.tickDensity) },
            set: { value in project.mutateDistanceTimelineStyle(elementID) { $0.tickDensity = min(max(Int(value.rounded()), 2), 40) } }
        ), range: 2...40, displayText: "\(style.tickDensity)", isEnabled: style.tickMarksEnabled)
        InspectorDenseRow(label: "Marker") {
            toggle(style.currentMarkerEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.currentMarkerEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "Marker Style") {
            InspectorDenseSegmented(values: DistanceTimelineMarkerStyle.allCases, selection: Binding(
                get: { style.currentMarkerStyle },
                set: { markerStyle in project.mutateDistanceTimelineStyle(elementID) { $0.currentMarkerStyle = markerStyle } }
            )) { markerStyle in
                Text(markerStyle.label)
            }
        }
        .opacity(style.currentMarkerEnabled ? 1 : 0.5).disabled(!style.currentMarkerEnabled)
        InspectorDenseRow(label: "Marker Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.currentMarkerColor) { color in
                project.mutateDistanceTimelineStyle(elementID) { $0.currentMarkerColor = color }
            }
        }
        .opacity(style.currentMarkerEnabled ? 1 : 0.5).disabled(!style.currentMarkerEnabled)
        InspectorDenseSliderRow(
            label: "Marker Size",
            value: Binding(
                get: { style.currentMarkerSizeMultiplier },
                set: { value in
                    project.mutateDistanceTimelineStyle(elementID) {
                        $0.currentMarkerSizeMultiplier = min(max(value, 0.25), 4)
                    }
                }
            ),
            range: 0.25...4,
            displayText: String(format: "%.2f×", style.currentMarkerSizeMultiplier),
            isEnabled: style.currentMarkerEnabled
        )
        InspectorDenseRow(label: "Marker Label") {
            toggle(style.markerDistanceLabelEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.markerDistanceLabelEnabled = newValue }
            }
        }
        .opacity(style.currentMarkerEnabled ? 1 : 0.5).disabled(!style.currentMarkerEnabled)
        InspectorDenseRow(label: "Label Side") {
            InspectorDenseSegmented(values: DistanceTimelineAxisLabelTrackPlacement.allCases, selection: Binding(
                get: { style.markerDistanceLabelPlacement },
                set: { placement in project.mutateDistanceTimelineStyle(elementID) { $0.markerDistanceLabelPlacement = placement } }
            )) { placement in
                Text(placement.label)
            }
        }
        .opacity(style.currentMarkerEnabled && style.markerDistanceLabelEnabled ? 1 : 0.5)
        .disabled(!style.currentMarkerEnabled || !style.markerDistanceLabelEnabled)
        InspectorDenseSliderRow(
            label: "Label Offset",
            value: distanceBinding(\.markerDistanceLabelOffset, of: style),
            range: -24...64,
            displayText: "\(Int(style.markerDistanceLabelOffset))",
            isEnabled: style.currentMarkerEnabled && style.markerDistanceLabelEnabled
        )
    }

    @ViewBuilder
    private func axisLabelsSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        let axisTypographyEnabled = style.showAxisLabels || style.showDistancePoints || (style.markerDistanceLabelEnabled && style.currentMarkerEnabled)
        InspectorDenseRow(label: "Start / Finish") {
            toggle(style.showAxisLabels) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showAxisLabels = newValue }
            }
        }
        InspectorDenseRow(label: "Start / End Side") {
            InspectorDenseSegmented(values: DistanceTimelineAxisLabelTrackPlacement.allCases, selection: Binding(
                get: { style.axisEndpointLabelPlacement },
                set: { placement in project.mutateDistanceTimelineStyle(elementID) { $0.axisEndpointLabelPlacement = placement } }
            )) { placement in
                Text(placement.label)
            }
        }
        .opacity(style.showAxisLabels ? 1 : 0.5).disabled(!style.showAxisLabels)
        InspectorDenseSliderRow(
            label: "Start / End Offset",
            value: distanceBinding(\.distancePointOffset, of: style),
            range: -24...64,
            displayText: "\(Int(style.distancePointOffset))",
            isEnabled: style.showAxisLabels
        )
        InspectorDenseRow(label: "More Points") {
            toggle(style.showDistancePoints) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showDistancePoints = newValue }
            }
        }
        InspectorDenseRow(label: "Mode") {
            InspectorDenseSegmented(values: DistanceTimelineAxisLabelMode.allCases, selection: Binding(
                get: { style.axisLabelMode },
                set: { mode in project.mutateDistanceTimelineStyle(elementID) { $0.axisLabelMode = mode } }
            )) { mode in
                Text(mode.label)
            }
        }
        InspectorDenseSliderRow(label: "Density", value: Binding(
            get: { Double(style.distancePointCount) },
            set: { value in project.mutateDistanceTimelineStyle(elementID) { $0.distancePointCount = min(max(Int(value.rounded()), 0), 12) } }
        ), range: 0...12, displayText: "\(style.distancePointCount)", isEnabled: style.showDistancePoints)
        InspectorDenseRow(label: "Midpoints Side") {
            InspectorDenseSegmented(values: DistanceTimelineAxisLabelTrackPlacement.allCases, selection: Binding(
                get: { style.axisMidpointLabelPlacement },
                set: { placement in project.mutateDistanceTimelineStyle(elementID) { $0.axisMidpointLabelPlacement = placement } }
            )) { placement in
                Text(placement.label)
            }
        }
        .opacity(style.showDistancePoints ? 1 : 0.5).disabled(!style.showDistancePoints)
        InspectorDenseSliderRow(
            label: "Midpoints Offset",
            value: distanceBinding(\.midpointAxisLabelOffset, of: style),
            range: -24...64,
            displayText: "\(Int(style.midpointAxisLabelOffset))",
            isEnabled: style.showDistancePoints
        )
        typographyRows(
            title: "Axis",
            fontName: style.axisLabelFontName,
            fontSize: style.axisLabelFontSize,
            fontWeight: style.axisLabelFontWeight,
            color: style.axisLabelColor,
            isEnabled: axisTypographyEnabled,
            onSetFontName: { value in project.mutateDistanceTimelineStyle(elementID) { $0.axisLabelFontName = value } },
            onSetFontSize: { value in project.mutateDistanceTimelineStyle(elementID) { $0.axisLabelFontSize = value.rounded() } },
            onSetFontWeight: { value in project.mutateDistanceTimelineStyle(elementID) { $0.axisLabelFontWeight = value } },
            onSetColor: { value in project.mutateDistanceTimelineStyle(elementID) { $0.axisLabelColor = value } }
        )
    }

    @ViewBuilder
    private func statsBarInspectorSection(_ element: OverlayElement) -> some View {
        let config = element.style.distanceTimeline.statsBar
        CollapsibleStatsBarInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.statsBar) },
                set: { newValue in
                    if newValue { openSections.insert(.statsBar) }
                    else { openSections.remove(.statsBar) }
                }
            ),
            title: SharedStatsBarInspectorUI.sectionTitle,
            systemImage: SharedStatsBarInspectorUI.sectionSystemImage,
            isBarEnabled: config.visible,
            onSetBarEnabled: { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.visible = newValue }
            }
        ) {
            distanceTimelineStatsBarRows(element)
        }
    }

    @ViewBuilder
    private func distanceTimelineStatsBarRows(_ element: OverlayElement) -> some View {
        let config = element.style.distanceTimeline.statsBar
        OverlayStatsBarInspectorRows(
            isOn: config.visible,
            placement: config.placement,
            availablePlacements: SharedStatsBarInspectorUI.placements,
            layoutMode: config.layoutMode,
            height: config.height,
            heightRange: SharedStatsBarInspectorUI.heightRange,
            heightLabel: SharedStatsBarInspectorUI.heightLabel,
            backgroundOpacity: config.backgroundOpacity,
            dividerOpacity: config.dividerOpacity,
            cornerRadius: config.cornerRadius,
            cornerRadiusRange: SharedStatsBarInspectorUI.cornerRadiusRange,
            valueTypography: .init(
                fontName: config.valueFontName,
                fontSize: config.valueFontSize,
                fontWeight: config.valueFontWeight,
                color: config.valueColor,
                onSetFontName: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.valueFontName = value } },
                onSetFontSize: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.valueFontSize = value.rounded() } },
                onSetFontWeight: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.valueFontWeight = value } },
                onSetColor: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.valueColor = value } }
            ),
            labelTypography: .init(
                fontName: config.labelFontName,
                fontSize: config.labelFontSize,
                fontWeight: config.labelFontWeight,
                color: config.labelColor,
                onSetFontName: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.labelFontName = value } },
                onSetFontSize: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.labelFontSize = value.rounded() } },
                onSetFontWeight: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.labelFontWeight = value } },
                onSetColor: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.labelColor = value } }
            ),
            slots: config.slots.map { (metric: $0.metric, visible: $0.visible) },
            availableMetrics: SharedStatsBarInspectorUI.metrics,
            inside: config.inside,
            extraLayout: .init(
                width: config.width,
                offsetX: config.offsetX,
                offsetY: config.offsetY,
                itemSpacing: config.itemSpacing,
                onSetWidth: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.width = value.rounded() } },
                onSetOffsetX: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.offsetX = value.rounded() } },
                onSetOffsetY: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.offsetY = value.rounded() } },
                onSetItemSpacing: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.itemSpacing = value.rounded() } }
            ),
            onSetPlacement: { placement in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.placement = placement } },
            onSetLayoutMode: { mode in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.layoutMode = mode } },
            onSetHeight: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.height = value.rounded() } },
            onSetBackgroundOpacity: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.backgroundOpacity = value } },
            onSetDividerOpacity: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.dividerOpacity = value } },
            onSetCornerRadius: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.cornerRadius = value.rounded() } },
            onSetSlotMetric: { index, metric in project.mutateDistanceTimelineStyle(elementID) { $0.setStatsBarMetric(metric, at: index) } },
            onSetSlotVisible: { index, visible in project.mutateDistanceTimelineStyle(elementID) { $0.setStatsBarVisible(visible, at: index) } },
            onSetInside: { value in project.mutateDistanceTimelineStyle(elementID) { $0.statsBar.inside = value } }
        )
    }

    @ViewBuilder
    private func mediaSlotSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Enabled") {
            toggle(style.mediaSlotEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlotEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "Source") {
            Menu {
                ForEach(DistanceTimelineMediaSlotMode.allCases) { mode in
                    Button {
                        if mode.isImplemented {
                            project.mutateDistanceTimelineStyle(elementID) {
                                $0.mediaSlotMode = mode
                                $0.mediaSlot.mode = mode
                            }
                        }
                    } label: {
                        Text(mode.isImplemented ? mode.label : "\(mode.label) (future)")
                    }
                    .disabled(!mode.isImplemented)
                }
            } label: {
                InspectorDenseMenuLabel(title: style.mediaSlotMode.label)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        if style.mediaSlotMode == .staticSVG || style.mediaSlotMode == .animatedSVG {
            InspectorDenseRow(label: "Asset") {
                Button {
                    project.importDistanceTimelineIconAsset(elementID)
                } label: {
                    Label(style.mediaSlot.assetName.isEmpty ? "Import SVG" : style.mediaSlot.assetName, systemImage: "square.and.arrow.down")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                .frame(height: NumericTokens.controlHeight)
            }
        }
        InspectorDenseRow(label: "Tint") {
            InspectorDenseSegmented(values: OverlayIconTintMode.allCases, selection: Binding(
                get: { style.mediaSlot.tintMode },
                set: { mode in project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.tintMode = mode } }
            )) { mode in
                Text(mode.label)
            }
        }
        if style.mediaSlotMode == .animatedSVG {
            InspectorDenseSliderRow(
                label: "Anim Speed",
                value: Binding(
                    get: { style.mediaSlot.animationSpeed },
                    set: { newValue in project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.animationSpeed = newValue } }
                ),
                range: 0.1...4,
                displayText: String(format: "%.1fx", style.mediaSlot.animationSpeed)
            )
            InspectorDenseRow(label: "Loop") {
                toggle(style.mediaSlot.loop) { newValue in
                    project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.loop = newValue }
                }
            }
        }
        InspectorDenseSliderRow(label: "Slot Size", value: distanceBinding(\.mediaSlotSize, of: style), range: 18...64, displayText: "\(Int(style.mediaSlotSize))")
    }

    @ViewBuilder
    private func routeElevationSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Elevation") {
            toggle(style.elevationProfileVisible) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.elevationProfileVisible = newValue }
            }
        }
    }

    private func toggle(_ isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { newValue in action(newValue) }))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
    }

    private func distanceBinding(_ keyPath: WritableKeyPath<DistanceTimelineStyle, Double>, of style: DistanceTimelineStyle) -> Binding<Double> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    @ViewBuilder
    private func typographyRows(
        title: String,
        fontName: String,
        fontSize: Double,
        fontWeight: OverlayFontWeight,
        color: OverlayColor,
        isEnabled: Bool,
        onSetFontName: @escaping (String) -> Void,
        onSetFontSize: @escaping (Double) -> Void,
        onSetFontWeight: @escaping (OverlayFontWeight) -> Void,
        onSetColor: @escaping (OverlayColor) -> Void
    ) -> some View {
        InspectorDenseRow(label: "\(title) Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        onSetFontName(name)
                    } label: {
                        if name == fontName { Label(name, systemImage: "checkmark") }
                        else { Text(name) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: fontName, isEnabled: isEnabled)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        .opacity(isEnabled ? 1 : 0.5).disabled(!isEnabled)

        InspectorDenseSliderRow(
            label: "\(title) Size",
            value: Binding(
                get: { fontSize },
                set: { value in onSetFontSize(value) }
            ),
            range: 8...48,
            displayText: "\(Int(fontSize.rounded()))",
            isEnabled: isEnabled
        )

        InspectorDenseRow(label: "\(title) Weight") {
            InspectorDenseSegmented(
                values: OverlayFontWeight.allCases,
                selection: Binding(
                    get: { fontWeight },
                    set: { value in onSetFontWeight(value) }
                )
            ) { weight in
                Text(weight.label)
            }
        }
        .opacity(isEnabled ? 1 : 0.5).disabled(!isEnabled)

        InspectorDenseRow(label: "\(title) Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: color) { newColor in
                onSetColor(newColor)
            }
        }
        .opacity(isEnabled ? 1 : 0.5).disabled(!isEnabled)
    }

    @ViewBuilder
    private func sectionView<Body: View>(_ section: DistanceTimelineSection, @ViewBuilder content: () -> Body) -> some View {
        let isOpen = openSections.contains(section)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
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
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }

            if isOpen {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.mutateDistanceTimelineStyle(elementID) { $0 = .default } },
            onTrailingTap: { project.selection = .none }
        )
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }
}

private enum DistanceTimelineSection: String, CaseIterable {
    case preset
    case value
    case label
    case layout
    case progress
    case axisLabels
    case statsBar
    case mediaSlot
    case routeElevation

    var title: String {
        switch self {
        case .preset: "Preset"
        case .value: "Value"
        case .label: "Label"
        case .layout: "Layout"
        case .progress: "Progress"
        case .axisLabels: "Axis Labels"
        case .statsBar: "Stats Bar"
        case .mediaSlot: "Media Slot"
        case .routeElevation: "Route / Elevation"
        }
    }

    var systemImage: String {
        switch self {
        case .preset: "slider.horizontal.3"
        case .value: "number"
        case .label: "tag"
        case .layout: "scope"
        case .progress: "chart.bar.fill"
        case .axisLabels: "ruler"
        case .statsBar: "tablecells"
        case .mediaSlot: "photo"
        case .routeElevation: "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

private extension Double {
    func distanceTimelineQuantized(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension DistanceTimelineStyle {
    mutating func normalizeCustomValues() {
        customValues = Array(customValues.prefix(4)) + Array(repeating: .empty, count: max(0, 4 - customValues.count))
    }

    mutating func setCustomValueVisible(_ visible: Bool, at index: Int) {
        normalizeCustomValues()
        customValues[index].visible = visible
    }

    mutating func setCustomValueLabel(_ label: String, at index: Int) {
        normalizeCustomValues()
        customValues[index].label = label
    }

    mutating func setCustomValueMetric(_ metric: RouteMapStatsMetric, at index: Int) {
        normalizeCustomValues()
        customValues[index].metric = metric
    }

    mutating func setStatsBarMetric(_ metric: RouteMapStatsMetric, at index: Int) {
        guard statsBar.slots.indices.contains(index) else { return }
        statsBar.slots[index].metric = metric
    }

    mutating func setStatsBarVisible(_ visible: Bool, at index: Int) {
        guard statsBar.slots.indices.contains(index) else { return }
        statsBar.slots[index].visible = visible
    }
}
