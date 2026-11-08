import SwiftUI

/// Dense Inspector detail panel for the Route Map overlay.
/// Uses the shared `InspectorDense*` design language:
/// `InspectorDenseRow` rows, collapsible sections, and the same tokens
/// (`NumericTokens`) so the right Inspector feels consistent across overlay types.
struct RouteMapOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<RouteMapSection> = Set(RouteMapSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        layoutInspectorSection(element)
                        sectionView(.container) { containerSection(element) }
                        sectionView(.backgroundMap, isOn: showMapBinding(element)) { backgroundMapSection(element) }
                        sectionView(.routeLine) { routeLineSection(element) }
                        sectionView(.markers) { markersSection(element) }
                        routeMapStatsBarInspectorSection(element)
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

            } else {
                Spacer()
            }
        }
    }

    // MARK: - Sections

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
        }
    }

    @ViewBuilder
    private func backgroundMapSection(_ element: OverlayElement) -> some View {
        // The Map Style picker only exposes the four "show map" choices.
        // Whether the map is rendered at all is controlled by the section
        // header checkbox (`showMapBinding`). When the user turns the map
        // off we set `routeMapBackgroundStyle = .none`, and the section
        // disables every dependent row, including Map POIs.
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
            .inspectorMenuStyle()
            .frame(height: NumericTokens.controlHeight)
        }
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
        InspectorDenseSliderRow(
            label: "Map Zoom",
            value: Binding(
                get: { element.style.routeMapZoom },
                set: { project.setOverlayRouteMapZoom(elementID, zoom: $0.quantizedRouteMap(to: 0.05)) }
            ),
            range: 0.5...3,
            displayText: String(format: "%.2gx", element.style.routeMapZoom),
            isEnabled: mapEnabled
        )
        InspectorDenseRow(label: "Map POIs") {
            Toggle("", isOn: Binding(
                get: { element.style.routeMapShowsPointsOfInterest },
                set: { project.setOverlayRouteMapShowsPointsOfInterest(elementID, isVisible: $0) }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .labelsHidden()
            .disabled(!mapEnabled)
        }
    }

    private func showMapBinding(_ element: OverlayElement) -> Binding<Bool> {
        Binding(
            get: { element.style.routeMapBackgroundStyle != .none },
            set: { project.setOverlayRouteMapShowMap(elementID, showMap: $0) }
        )
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
                    presets: InspectorPresets.colorPresets,
                    selected: element.style.foregroundColor
                ) { color in
                    project.setOverlayForegroundColor(elementID, color: color)
                }
            }
        } else {
            InspectorDenseRow(label: "Gradient Start") {
                InspectorDenseSwatchStrip(
                    presets: InspectorPresets.colorPresets,
                    selected: element.style.routeMapGradientStart
                ) { color in
                    project.setOverlayRouteMapGradientStart(elementID, color: color)
                }
            }
            InspectorDenseRow(label: "Gradient Mid") {
                InspectorDenseSwatchStrip(
                    presets: InspectorPresets.colorPresets,
                    selected: element.style.routeMapGradientMiddle
                ) { color in
                    project.setOverlayRouteMapGradientMiddle(elementID, color: color)
                }
            }
            InspectorDenseRow(label: "Gradient End") {
                InspectorDenseSwatchStrip(
                    presets: InspectorPresets.colorPresets,
                    selected: element.style.routeMapGradientEnd
                ) { color in
                    project.setOverlayRouteMapGradientEnd(elementID, color: color)
                }
            }
        }

        InspectorDenseRow(label: "Glow") {
            Toggle("", isOn: Binding(
                get: { element.style.glowEnabled },
                set: { project.setOverlayGlowEnabled(elementID, enabled: $0) }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func markersSection(_ element: OverlayElement) -> some View {
        markerVisibilityRow(label: "Start", isVisible: element.style.routeMapStartMarkerStyle != .hidden) { isVisible in
            project.setOverlayRouteMapStartMarkerStyle(elementID, markerStyle: isVisible ? .dot : .hidden)
        }
        markerColorRow(label: "Start Color", selected: element.style.routeMapStartMarkerColor) { color in
            project.setOverlayRouteMapStartMarkerColor(elementID, color: color)
        }
        markerVisibilityRow(label: "End", isVisible: element.style.routeMapEndMarkerStyle != .hidden) { isVisible in
            project.setOverlayRouteMapEndMarkerStyle(elementID, markerStyle: isVisible ? .dot : .hidden)
        }
        markerColorRow(label: "End Color", presets: endMarkerColorPresets, selected: element.style.routeMapEndMarkerColor) { color in
            project.setOverlayRouteMapEndMarkerColor(elementID, color: color)
        }
        markerVisibilityRow(label: "Moving", isVisible: element.style.routeMapRunnerMarkerStyle != .hidden) { isVisible in
            project.setOverlayRouteMapRunnerMarkerStyle(elementID, markerStyle: isVisible ? .dot : .hidden)
        }
        markerColorRow(label: "Moving Color", selected: element.style.routeMapRunnerDotColor) { color in
            project.setOverlayRouteMapRunnerDotColor(elementID, color: color)
        }
    }

    @ViewBuilder
    private func markerVisibilityRow(
        label: String,
        isVisible: Bool,
        onSet: @escaping (Bool) -> Void
    ) -> some View {
        InspectorDenseRow(label: label) {
            Toggle("", isOn: Binding(get: { isVisible }, set: { newValue in
                onSet(newValue)
            }))
                .toggleStyle(.checkbox)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func markerColorRow(
        label: String,
        presets: [(name: String, color: OverlayColor)] = InspectorPresets.colorPresets,
        selected: OverlayColor,
        onSelect: @escaping (OverlayColor) -> Void
    ) -> some View {
        InspectorDenseRow(label: label) {
            InspectorDenseSwatchStrip(
                presets: presets,
                selected: selected,
                action: onSelect
            )
        }
    }

    private var endMarkerColorPresets: [(name: String, color: OverlayColor)] {
        [("Checker", .routeMapEndCheckerboard)] + InspectorPresets.colorPresets
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

    // MARK: - Composition

    private func sectionView<Body: View>(
        _ section: RouteMapSection,
        isOn: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Body
    ) -> some View {
        let body = content()
        return InspectorCollapsibleSection(title: section.title, isExpanded: sectionExpansion(section), isOn: isOn) { body }
    }

    private func sectionExpansion(_ section: RouteMapSection) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { isOpen in
                if isOpen { openSections.insert(section) } else { openSections.remove(section) }
            }
        )
    }
}

// MARK: - Header

// MARK: - Section enum

enum RouteMapSection: String, CaseIterable {
    case layout
    case container
    case backgroundMap
    case routeLine
    case markers
    case legend

    var title: String {
        switch self {
        case .layout: "Layout"
        case .container: "Container"
        case .backgroundMap: "Background Map"
        case .routeLine: "Route Line"
        case .markers: "Markers"
        case .legend: "Stats Bar"
        }
    }
}

private extension Double {
    func quantizedRouteMap(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
