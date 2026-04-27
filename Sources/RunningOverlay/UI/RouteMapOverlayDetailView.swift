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
                Divider().overlay(NumericTokens.borderSubtle)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.preset) { presetSection(element) }
                        sectionView(.layout) { layoutSection(element) }
                        sectionView(.container) { containerSection(element) }
                        sectionView(.backgroundMap, accessory: { showMapToggle(element) }) { backgroundMapSection(element) }
                        sectionView(.routeLine) { routeLineSection(element) }
                        sectionView(.markers) { markersSection(element) }
                        sectionView(.legend, accessory: { statsBarVisibleToggle(element) }) { statsBarSection(element) }
                        sectionView(.effects) { effectsSection(element) }
                    }
                    .padding(.horizontal, NumericTokens.panelPaddingX)
                    .padding(.vertical, NumericTokens.panelPaddingY)
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
    private func layoutSection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Anchor") {
            InspectorAnchorGrid(position: element.position) { anchor in
                project.setOverlayPosition(elementID, position: anchor)
                project.finishContinuousEdit()
            }
        }
        InspectorDenseRow(label: "Position") {
            HStack(spacing: NumericTokens.space2) {
                InspectorDenseAxisField(
                    axis: "X",
                    value: Binding(
                        get: { Double(element.position.x) },
                        set: {
                            project.setOverlayPosition(elementID, position: CGPoint(x: $0, y: element.position.y))
                            project.finishContinuousEdit()
                        }
                    ),
                    precision: 3
                )
                InspectorDenseAxisField(
                    axis: "Y",
                    value: Binding(
                        get: { Double(element.position.y) },
                        set: {
                            project.setOverlayPosition(elementID, position: CGPoint(x: element.position.x, y: $0))
                            project.finishContinuousEdit()
                        }
                    ),
                    precision: 3
                )
            }
        }
        InspectorDenseSliderRow(
            label: "Scale",
            value: Binding(
                get: { element.scale },
                set: { project.setOverlayScale(elementID, scale: $0.quantizedRouteMap(to: 0.05)) }
            ),
            range: 0.25...4,
            displayText: String(format: "%.2fx", element.scale)
        )
        InspectorDenseSliderRow(
            label: "Rotation",
            value: Binding(
                get: { element.style.rotationDegrees },
                set: { project.setOverlayRotation(elementID, degrees: $0.rounded()) }
            ),
            range: -180...180,
            displayText: "\(Int(element.style.rotationDegrees))°"
        )
        InspectorDenseSliderRow(
            label: "Opacity",
            value: Binding(
                get: { element.style.backgroundOpacity },
                set: { project.setOverlayBackgroundOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", element.style.backgroundOpacity * 100)
        )
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
            .controlSize(.small)
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
        .controlSize(.small)
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
    }

    @ViewBuilder
    private func statsBarSection(_ element: OverlayElement) -> some View {
        let config = element.style.routeMapStatsBar
        let isEnabled = config.visible

        InspectorDenseSliderRow(
            label: "Background",
            value: Binding(
                get: { config.backgroundOpacity },
                set: { project.setOverlayRouteMapStatsBarBackgroundOpacity(elementID, opacity: $0.quantizedRouteMap(to: 0.05)) }
            ),
            range: 0...1,
            displayText: String(format: "%.0f%%", config.backgroundOpacity * 100)
        )
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)

        ForEach(config.slots.indices, id: \.self) { index in
            let slot = config.slots[index]
            InspectorDenseRow(label: "Slot \(index + 1)") {
                Menu {
                    ForEach(RouteMapStatsMetric.allCases) { metric in
                        Button {
                            project.setOverlayRouteMapStatsBarSlotMetric(elementID, slotIndex: index, metric: metric)
                        } label: {
                            if metric == slot.metric {
                                Label(metric.label, systemImage: "checkmark")
                            } else {
                                Text(metric.label)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: slot.metric.label, isEnabled: slot.visible)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)

                Toggle("", isOn: Binding(
                    get: { slot.visible },
                    set: { project.setOverlayRouteMapStatsBarSlotVisible(elementID, slotIndex: index, isVisible: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .opacity(isEnabled ? 1 : 0.5)
            .disabled(!isEnabled)
        }
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
        VStack(alignment: .leading, spacing: NumericTokens.rowGap) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                accessory()
                Button {
                    if isOpen {
                        openSections.remove(section)
                    } else {
                        openSections.insert(section)
                    }
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumericTokens.textMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)

            if isOpen {
                VStack(spacing: NumericTokens.rowGap) {
                    content()
                }
            }
        }
        .padding(.bottom, NumericTokens.space2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func statsBarVisibleToggle(_ element: OverlayElement) -> some View {
        Toggle("", isOn: Binding(
            get: { element.style.routeMapStatsBar.visible },
            set: { project.setOverlayRouteMapStatsBarVisible(elementID, isVisible: $0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
    }

    private var footerBar: some View {
        HStack(spacing: NumericTokens.space2) {
            Button {
                project.resetOverlayStyle(elementID)
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Button {
                project.selection = .none
            } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorPrimaryButtonStyle())
        }
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
