import SwiftUI

/// Dense Inspector detail panel for the Route Map overlay.
/// Mirrors the design language of `NumericOverlayDetailView`:
/// `InspectorDenseRow` rows, collapsible sections, and the same tokens
/// (`NumericTokens`) so the right Inspector feels consistent across overlay types.
struct RouteMapOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<RouteMapSection> = Set(RouteMapSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                RouteMapOverlayHeader(element: element, subtitle: subtitle(for: element))

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.preset) { presetSection(element) }
                        layoutInspectorSection(element)
                        sectionView(.container) { containerSection(element) }
                        sectionView(.backgroundMap, accessory: { showMapToggle(element) }) { backgroundMapSection(element) }
                        sectionView(.routeLine) { routeLineSection(element) }
                        sectionView(.markers) { markersSection(element) }
                        routeMapStatsBarInspectorSection(element)
                        sectionView(.effects) { effectsSection(element) }
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

    // MARK: - Sections

    @ViewBuilder
    private func presetSection(_ element: OverlayElement) -> some View {
        // The Route Style preset describes the polyline appearance only.
        // Container shape / edge controls live in the Container section
        // below; map visibility lives in the Background Map section. The
        // legacy "Container Preset" row was removed because it duplicated
        // those individual controls.
        InspectorDenseRow(label: "Route Style") {
            Menu {
                ForEach(OverlayRouteMapPreset.allCases) { preset in
                    Button {
                        project.setOverlayRouteMapPreset(elementID, routeMapPreset: preset)
                    } label: {
                        if preset == element.style.routeMapPreset {
                            Label(preset.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(preset.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.routeMapPreset.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
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
                widthBinding: Binding(
                    get: { element.style.routeMapWidth },
                    set: { project.setOverlayRouteMapWidth(elementID, width: $0.quantizedRouteMap(to: 4)) }
                ),
                widthRange: 120...720,
                heightBinding: Binding(
                    get: { element.style.routeMapHeight },
                    set: { project.setOverlayRouteMapHeight(elementID, height: $0.quantizedRouteMap(to: 4)) }
                ),
                heightRange: 120...720
            )
        }
    }

    @ViewBuilder
    private func containerSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Shape") {
            InspectorDenseSegmented(values: OverlayRouteMapShape.allCases, selection: Binding(
                get: { element.style.routeMapShape },
                set: { project.setOverlayRouteMapShape(elementID, shape: $0) }
            )) { shape in
                Text(shape.compactLabel)
            }
        }

        // Square containers expose independent Width / Height sliders so the
        // user can match the wider 4:3 (or any) aspect they want. Circle
        // containers collapse to a single Size control because the renderer
        // takes the shorter edge as the diameter.
        if element.style.routeMapShape == .circle {
            InspectorDenseSliderRow(
                label: "Size",
                value: Binding(
                    get: { min(element.style.routeMapWidth, element.style.routeMapHeight) },
                    set: { newValue in
                        let v = newValue.quantizedRouteMap(to: 4)
                        project.setOverlayRouteMapWidth(elementID, width: v)
                        project.setOverlayRouteMapHeight(elementID, height: v)
                    }
                ),
                range: 120...600,
                displayText: "\(Int(min(element.style.routeMapWidth, element.style.routeMapHeight).rounded())) pt"
            )
        } else {
            InspectorDenseSliderRow(
                label: "Width",
                value: Binding(
                    get: { element.style.routeMapWidth },
                    set: { project.setOverlayRouteMapWidth(elementID, width: $0.quantizedRouteMap(to: 4)) }
                ),
                range: 120...720,
                displayText: "\(Int(element.style.routeMapWidth.rounded())) pt"
            )
            InspectorDenseSliderRow(
                label: "Height",
                value: Binding(
                    get: { element.style.routeMapHeight },
                    set: { project.setOverlayRouteMapHeight(elementID, height: $0.quantizedRouteMap(to: 4)) }
                ),
                range: 120...720,
                displayText: "\(Int(element.style.routeMapHeight.rounded())) pt"
            )
            InspectorDenseSliderRow(
                label: "Corner Radius",
                value: Binding(
                    get: { element.style.routeMapCornerRadius },
                    set: { project.setOverlayRouteMapCornerRadius(elementID, radius: $0.quantizedRouteMap(to: 2)) }
                ),
                range: 0...80,
                displayText: element.style.routeMapCornerRadius < 1
                    ? "Sharp"
                    : "\(Int(element.style.routeMapCornerRadius.rounded())) pt"
            )
        }

        InspectorDenseRow(label: "Edge Mode") {
            InspectorDenseSegmented(values: OverlayRouteMapEdgeFade.allCases, selection: Binding(
                get: { element.style.routeMapEdgeFade },
                set: { project.setOverlayRouteMapEdgeFade(elementID, edgeFade: $0) }
            )) { mode in
                Text(mode.compactLabel)
            }
        }

        InspectorDenseRow(label: "Border") {
            Toggle("", isOn: Binding(
                get: { element.style.routeMapBorderVisible },
                set: { project.setOverlayRouteMapBorderVisible(elementID, isVisible: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }

        let softnessEnabled = element.style.routeMapEdgeFade == .fadeOut
        InspectorDenseSliderRow(
            label: "Edge Softness",
            value: Binding(
                get: { element.style.routeMapFadeAmount },
                set: { project.setOverlayRouteMapEdgeSoftness(elementID, amount: $0.quantizedRouteMap(to: 0.01)) }
            ),
            // Allow up to 85% softness so the box can dissolve into the
            // background like the design mockup. The mask renderer caps at
            // the same value internally.
            range: 0...0.85,
            displayText: element.style.routeMapFadeAmount <= 0.001
                ? "Solid"
                : String(format: "%.0f%%", element.style.routeMapFadeAmount * 100),
            isEnabled: softnessEnabled
        )
    }

    @ViewBuilder
    private func backgroundMapSection(_ element: OverlayElement) -> some View {
        // The Map Style picker only exposes the four "show map" choices.
        // Whether the map is rendered at all is controlled by the section
        // header toggle (`showMapToggle`). When the user toggles Show Map
        // off we set `routeMapBackgroundStyle = .none` and disable the
        // dependent rows.
        let mapEnabled = element.style.routeMapBackgroundStyle != .none
        InspectorDenseRow(label: "Map Style") {
            Menu {
                ForEach(OverlayRouteMapBackgroundStyle.visibleCases) { style in
                    Button {
                        project.setOverlayRouteMapBackgroundStyle(elementID, backgroundStyle: style)
                    } label: {
                        if style == element.style.routeMapBackgroundStyle {
                            Label(style.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(style.compactLabel)
                        }
                    }
                }
            } label: {
                let title = mapEnabled
                    ? element.style.routeMapBackgroundStyle.compactLabel
                    : OverlayRouteMapBackgroundStyle.dark.compactLabel
                InspectorDenseMenuLabel(title: title, isEnabled: mapEnabled)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        .opacity(mapEnabled ? 1 : 0.5)
        .disabled(!mapEnabled)

        InspectorDenseSliderRow(
            label: "Map Opacity",
            value: Binding(
                get: { element.style.routeMapMapOpacity },
                set: { project.setOverlayRouteMapMapOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.01)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.routeMapMapOpacity * 100),
            isEnabled: mapEnabled
        )
    }

    @ViewBuilder
    private func showMapToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.routeMapBackgroundStyle != .none },
            set: { project.setOverlayRouteMapShowMap(elementID, showMap: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
        .help("Show or hide the map background")
    }

    @ViewBuilder
    private func routeLineSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Color Mode") {
            InspectorDenseSegmented(values: OverlayRouteMapColorMode.allCases, selection: Binding(
                get: { element.style.routeMapColorMode },
                set: { project.setOverlayRouteMapColorMode(elementID, colorMode: $0) }
            )) { mode in
                Text(mode.compactLabel)
            }
        }

        if element.style.routeMapColorMode == .solid {
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: element.style.foregroundColor
                ) { color in
                    project.setOverlayForegroundColor(elementID, color: color)
                }
            }
        } else {
            InspectorDenseRow(label: "Gradient Start") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: element.style.routeMapGradientStart
                ) { color in
                    project.setOverlayRouteMapGradientStart(elementID, color: color)
                }
            }
            InspectorDenseRow(label: "Gradient Mid") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: element.style.routeMapGradientMiddle
                ) { color in
                    project.setOverlayRouteMapGradientMiddle(elementID, color: color)
                }
            }
            InspectorDenseRow(label: "Gradient End") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: element.style.routeMapGradientEnd
                ) { color in
                    project.setOverlayRouteMapGradientEnd(elementID, color: color)
                }
            }
        }
    }

    @ViewBuilder
    private func markersSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "All Markers") {
            InspectorDenseSegmented(values: OverlayRouteMapMarkerStyle.allCases, selection: Binding(
                get: { element.style.routeMapMarkerStyle },
                set: { project.setOverlayRouteMapMarkerStyle(elementID, markerStyle: $0) }
            )) { marker in
                Text(marker.compactLabel)
            }
        }
        InspectorDenseRow(label: "Start") {
            Menu {
                ForEach(OverlayRouteMapMarkerStyle.allCases) { marker in
                    Button {
                        project.setOverlayRouteMapStartMarkerStyle(elementID, markerStyle: marker)
                    } label: {
                        if marker == element.style.routeMapStartMarkerStyle {
                            Label(marker.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(marker.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.routeMapStartMarkerStyle.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseRow(label: "End") {
            Menu {
                ForEach(OverlayRouteMapMarkerStyle.allCases) { marker in
                    Button {
                        project.setOverlayRouteMapEndMarkerStyle(elementID, markerStyle: marker)
                    } label: {
                        if marker == element.style.routeMapEndMarkerStyle {
                            Label(marker.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(marker.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.routeMapEndMarkerStyle.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseRow(label: "Position Color") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: element.style.routeMapRunnerDotColor
            ) { color in
                project.setOverlayRouteMapRunnerDotColor(elementID, color: color)
            }
        }
    }

    @ViewBuilder
    private func routeMapStatsBarInspectorSection(_ element: OverlayElement) -> some View {
        let config = element.style.routeMapStatsBar
        CollapsibleStatsBarInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.legend) },
                set: { newValue in
                    if newValue { openSections.insert(.legend) }
                    else { openSections.remove(.legend) }
                }
            ),
            title: SharedStatsBarInspectorUI.sectionTitle,
            systemImage: SharedStatsBarInspectorUI.sectionSystemImage,
            isBarEnabled: config.visible,
            onSetBarEnabled: { project.setOverlayRouteMapStatsBarVisible(elementID, isVisible: $0) }
        ) {
            routeMapStatsBarRows(element)
        }
    }

    @ViewBuilder
    private func routeMapStatsBarRows(_ element: OverlayElement) -> some View {
        let config = element.style.routeMapStatsBar
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
                onSetFontName: { project.setOverlayRouteMapStatsBarValueFontName(elementID, fontName: $0) },
                onSetFontSize: { project.setOverlayRouteMapStatsBarValueFontSize(elementID, fontSize: $0.quantizedRouteMap(to: 1)) },
                onSetFontWeight: { project.setOverlayRouteMapStatsBarValueFontWeight(elementID, fontWeight: $0) },
                onSetColor: { project.setOverlayRouteMapStatsBarValueColor(elementID, color: $0) }
            ),
            labelTypography: .init(
                fontName: config.labelFontName,
                fontSize: config.labelFontSize,
                fontWeight: config.labelFontWeight,
                color: config.labelColor,
                onSetFontName: { project.setOverlayRouteMapStatsBarLabelFontName(elementID, fontName: $0) },
                onSetFontSize: { project.setOverlayRouteMapStatsBarLabelFontSize(elementID, fontSize: $0.quantizedRouteMap(to: 1)) },
                onSetFontWeight: { project.setOverlayRouteMapStatsBarLabelFontWeight(elementID, fontWeight: $0) },
                onSetColor: { project.setOverlayRouteMapStatsBarLabelColor(elementID, color: $0) }
            ),
            slots: config.slots.map { (metric: $0.metric, visible: $0.visible) },
            availableMetrics: SharedStatsBarInspectorUI.metrics,
            inside: config.inside,
            extraLayout: .init(
                width: config.width,
                offsetX: config.offsetX,
                offsetY: config.offsetY,
                itemSpacing: config.itemSpacing,
                onSetWidth: { project.setOverlayRouteMapStatsBarWidth(elementID, width: $0.quantizedRouteMap(to: 1)) },
                onSetOffsetX: { project.setOverlayRouteMapStatsBarOffsetX(elementID, offsetX: $0.quantizedRouteMap(to: 1)) },
                onSetOffsetY: { project.setOverlayRouteMapStatsBarOffsetY(elementID, offsetY: $0.quantizedRouteMap(to: 1)) },
                onSetItemSpacing: { project.setOverlayRouteMapStatsBarItemSpacing(elementID, spacing: $0.quantizedRouteMap(to: 1)) }
            ),
            onSetPlacement: { project.setOverlayRouteMapStatsBarPlacement(elementID, placement: $0) },
            onSetLayoutMode: { project.setOverlayRouteMapStatsBarLayoutMode(elementID, layoutMode: $0) },
            onSetHeight: { project.setOverlayRouteMapStatsBarHeight(elementID, height: $0.quantizedRouteMap(to: 2)) },
            onSetBackgroundOpacity: { project.setOverlayRouteMapStatsBarBackgroundOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.05)) },
            onSetDividerOpacity: { project.setOverlayRouteMapStatsBarDividerOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.01)) },
            onSetCornerRadius: { project.setOverlayRouteMapStatsBarCornerRadius(elementID, radius: $0.quantizedRouteMap(to: 1)) },
            onSetSlotMetric: { project.setOverlayRouteMapStatsBarSlotMetric(elementID, slotIndex: $0, metric: $1) },
            onSetSlotVisible: { project.setOverlayRouteMapStatsBarSlotVisible(elementID, slotIndex: $0, isVisible: $1) },
            onSetInside: { project.setOverlayRouteMapStatsBarInside(elementID, isInside: $0) }
        )
    }

    @ViewBuilder
    private func effectsSection(_ element: OverlayElement) -> some View {
        InspectorDenseSliderRow(
            label: "Shadow Opacity",
            value: Binding(
                get: { element.style.shadowOpacity },
                set: { project.setOverlayShadowOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.shadowOpacity * 100)
        )
        InspectorDenseSliderRow(
            label: "Shadow Radius",
            value: Binding(
                get: { element.style.shadowRadius },
                set: { project.setOverlayShadowRadius(elementID, radius: $0.rounded()) }
            ),
            range: 0...24,
            displayText: "\(Int(element.style.shadowRadius.rounded()))"
        )
    }

    // MARK: - Composition

    @ViewBuilder
    private func sectionView<Body: View, Accessory: View>(
        _ section: RouteMapSection,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Body
    ) -> some View {
        let isOpen = openSections.contains(section)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                accessory()
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
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isOpen {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.resetOverlayStyle(elementID) },
            onTrailingTap: { project.selection = .none }
        )
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }

    private func subtitle(for element: OverlayElement) -> String {
        distanceText(for: element)
    }

    private func distanceText(for element: OverlayElement) -> String {
        let meters = project.activity.distanceMeters
        guard meters > 0 else { return "—" }
        return String(format: "%.2f km", meters / 1000)
    }
}

// MARK: - Header

struct RouteMapOverlayHeader: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement
    let subtitle: String

    var body: some View {
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
            .buttonStyle(.plain)
            .help("Back")

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "map")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Route Map")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NumericTokens.textPrimary)
                    Text("Overlay")
                        .font(NumericTokens.captionFont)
                        .foregroundStyle(NumericTokens.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NumericTokens.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle, lineWidth: 1))
                }
                Text(subtitle)
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textMuted)
                    .lineLimit(1)
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
            .help("Delete")
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(NumericTokens.borderSubtle)
        }
    }
}

// MARK: - Section enum

enum RouteMapSection: String, CaseIterable {
    case preset
    case layout
    case container
    case backgroundMap
    case routeLine
    case markers
    case legend
    case effects

    var title: String {
        switch self {
        case .preset: "Preset"
        case .layout: "Layout"
        case .container: "Container"
        case .backgroundMap: "Background Map"
        case .routeLine: "Route Line"
        case .markers: "Markers"
        case .legend: "Stats Bar"
        case .effects: "Effects"
        }
    }

    var systemImage: String {
        switch self {
        case .preset: "wand.and.stars"
        case .layout: "scope"
        case .container: "rectangle.dashed"
        case .backgroundMap: "map"
        case .routeLine: "scribble.variable"
        case .markers: "mappin.and.ellipse"
        case .legend: "list.dash"
        case .effects: "sparkles"
        }
    }
}

private extension Double {
    func quantizedRouteMap(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
