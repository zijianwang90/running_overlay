import SwiftUI

struct ZoneEdgeBarOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<ZoneEdgeBarInspectorSectionKind> = Set(ZoneEdgeBarInspectorSectionKind.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: binding(for: .layout)) {
                            OverlayLayoutInspectorRows(elementID: elementID)
                        }

                        ZoneEdgeBarInspectorSection(
                            title: "Zone Bar",
                            isExpanded: binding(for: .zoneBar)
                        ) {
                            zoneBarRows(element.style.zoneEdgeBar)
                        }

                        ZoneEdgeBarInspectorSection(
                            title: "Markers",
                            isExpanded: binding(for: .markers)
                        ) {
                            markerRows(element.style.zoneEdgeBar)
                        }

                        OverlayEffectsInspectorModule(
                            elementID: elementID,
                            element: element,
                            showsGlowControls: false,
                            showsFadeOutControls: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

            } else {
                Spacer()
            }
        }
    }

    private func binding(for section: ZoneEdgeBarInspectorSectionKind) -> Binding<Bool> {
        Binding(
            get: { openSections.contains(section) },
            set: { isOpen in
                if isOpen {
                    openSections.insert(section)
                } else {
                    openSections.remove(section)
                }
            }
        )
    }

    @ViewBuilder
    private func zoneBarRows(_ style: ZoneEdgeBarStyle) -> some View {
        InspectorDenseRow(label: "Metric") {
            InspectorDenseSegmented(values: ZoneEdgeBarMetric.allCases, selection: Binding(
                get: { style.metric },
                set: { value in project.mutateZoneEdgeBarStyle(elementID) { $0.metric = value } }
            )) { metric in
                Text(metric.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        InspectorDenseRow(label: "Placement") {
            InspectorDenseSegmented(values: ZoneEdgeBarPlacement.allCases, selection: Binding(
                get: { style.placement },
                set: { value in project.mutateZoneEdgeBarStyle(elementID) { $0.placement = value } }
            )) { placement in
                Text(placement.label)
            }
        }
        if style.placement == .edge {
            InspectorDenseRow(label: "Edge") {
                InspectorDenseSegmented(values: ZoneEdgeBarEdge.allCases, selection: Binding(
                    get: { style.edge },
                    set: { value in project.mutateZoneEdgeBarStyle(elementID) { $0.edge = value } }
                )) { edge in
                    Text(edge.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            InspectorDenseSliderRow(
                label: edgePositionLabel(for: style.edge),
                value: Binding(
                    get: { style.edgeInset },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.edgeInset = value.rounded() } }
                ),
                range: -120...120,
                displayText: "\(Int(style.edgeInset.rounded()))"
            )
        } else {
            InspectorDenseRow(label: "Orientation") {
                InspectorDenseSegmented(values: ZoneEdgeBarOrientation.allCases, selection: Binding(
                    get: { style.orientation },
                    set: { value in project.mutateZoneEdgeBarStyle(elementID) { $0.orientation = value } }
                )) { orientation in
                    Text(orientation.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        InspectorDenseSliderRow(
            label: "Length",
            value: Binding(
                get: { style.length },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.length = value.rounded() } }
            ),
            range: 160...1280,
            displayText: "\(Int(style.length.rounded()))"
        )
        InspectorDenseSliderRow(
            label: "Thickness",
            value: Binding(
                get: { style.thickness },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.thickness = value.quantizedNumeric(to: 0.5) } }
            ),
            range: 4...36,
            displayText: String(format: "%.1f", style.thickness)
        )
        InspectorDenseSliderRow(
            label: "Active Width",
            value: Binding(
                get: { style.activeZoneWidthShare },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.activeZoneWidthShare = value.quantizedNumeric(to: 0.05) } }
            ),
            range: 0...0.5,
            displayText: style.activeZoneWidthShare <= 0 ? "Equal" : String(format: "%.0f%%", style.activeZoneWidthShare * 100)
        )
        InspectorDenseSliderRow(
            label: "Active Height",
            value: Binding(
                get: { style.activeZoneHeightScale },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.activeZoneHeightScale = value.quantizedNumeric(to: 0.05) } }
            ),
            range: 1...2,
            displayText: String(format: "%.2gx", style.activeZoneHeightScale)
        )
        InspectorDenseSliderRow(
            label: "Zone Gap",
            value: Binding(
                get: { style.zoneSegmentGap },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.zoneSegmentGap = value.quantizedNumeric(to: 0.5) } }
            ),
            range: 0...12,
            displayText: String(format: "%.1f", style.zoneSegmentGap)
        )
        InspectorDenseSliderRow(
            label: "Inactive Opacity",
            value: Binding(
                get: { style.inactiveZoneOpacity },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.inactiveZoneOpacity = value.quantizedNumeric(to: 0.05) } }
            ),
            range: 0.2...1,
            displayText: String(format: "%.0f%%", style.inactiveZoneOpacity * 100)
        )
        InspectorDenseSliderRow(
            label: "Corner Radius",
            value: Binding(
                get: { style.cornerRadius },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.cornerRadius = value.quantizedNumeric(to: 0.5) } }
            ),
            range: 0...18,
            displayText: String(format: "%.1f", style.cornerRadius)
        )
        toggleRow("Border", isOn: style.borderEnabled) { value in
            project.mutateZoneEdgeBarStyle(elementID) { $0.borderEnabled = value }
        }
        borderRows(style)
        toggleRow("Glow", isOn: style.glowEnabled) { value in
            project.mutateZoneEdgeBarStyle(elementID) { $0.glowEnabled = value }
        }
        if style.glowEnabled {
            InspectorDenseSliderRow(
                label: "Glow Intensity",
                value: Binding(
                    get: { style.glowIntensity },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.glowIntensity = value.quantizedNumeric(to: 0.05) } }
                ),
                range: 0...1,
                displayText: String(format: "%.0f%%", style.glowIntensity * 100)
            )
        }
    }

    @ViewBuilder
    private func markerRows(_ style: ZoneEdgeBarStyle) -> some View {
        toggleRow("Current Marker", isOn: style.markerEnabled) { value in
            project.mutateZoneEdgeBarStyle(elementID) { $0.markerEnabled = value }
        }
        if style.markerEnabled {
            toggleRow("Marker Value", isOn: style.markerShowsValue) { value in
                project.mutateZoneEdgeBarStyle(elementID) { $0.markerShowsValue = value }
            }
            InspectorDenseSliderRow(
                label: "Arrow Size",
                value: Binding(
                    get: { style.markerSizeScale },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.markerSizeScale = value.quantizedNumeric(to: 0.05) } }
                ),
                range: 0.5...2,
                displayText: String(format: "%.2gx", style.markerSizeScale)
            )
        }
        toggleRow("Threshold Marker", isOn: style.thresholdMarkerEnabled) { value in
            project.mutateZoneEdgeBarStyle(elementID) { $0.thresholdMarkerEnabled = value }
        }
        if style.thresholdMarkerEnabled {
            InspectorDenseSliderRow(
                label: "Threshold Size",
                value: Binding(
                    get: { style.thresholdMarkerSizeScale },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.thresholdMarkerSizeScale = value.quantizedNumeric(to: 0.05) } }
                ),
                range: 0.5...2,
                displayText: String(format: "%.2gx", style.thresholdMarkerSizeScale)
            )
        }
    }

    @ViewBuilder
    private func borderRows(_ style: ZoneEdgeBarStyle) -> some View {
        if style.borderEnabled {
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: InspectorPresets.colorPresets,
                    selected: style.borderColor
                ) { color in
                    project.mutateZoneEdgeBarStyle(elementID) { $0.borderColor = color }
                }
            }
            InspectorDenseSliderRow(
                label: "Width",
                value: Binding(
                    get: { style.borderWidth },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.borderWidth = value.quantizedNumeric(to: 0.5) } }
                ),
                range: 0.5...8,
                displayText: String(format: "%.1f", style.borderWidth)
            )
            InspectorDenseSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { style.borderOpacity },
                    set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.borderOpacity = value.quantizedNumeric(to: 0.05) } }
                ),
                range: 0...1,
                displayText: String(format: "%.0f%%", style.borderOpacity * 100)
            )
        }
    }

    private func edgePositionLabel(for edge: ZoneEdgeBarEdge) -> String {
        switch edge {
        case .top, .bottom:
            return "Vertical Position"
        case .left, .right:
            return "Horizontal Position"
        }
    }

    private func toggleRow(_ label: String, isOn: Bool, onSet: @escaping (Bool) -> Void) -> some View {
        InspectorDenseRow(label: label) {
            Toggle("", isOn: Binding(get: { isOn }, set: onSet))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .labelsHidden()
        }
    }

}

private enum ZoneEdgeBarInspectorSectionKind: CaseIterable {
    case layout
    case zoneBar
    case markers
}

private struct ZoneEdgeBarInspectorSection<Content: View>: View {
    var title: String
    @Binding var isExpanded: Bool
    var headerToggle: Binding<Bool>?
    @ViewBuilder var content: Content

    init(
        title: String,
        isExpanded: Binding<Bool>,
        headerToggle: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.headerToggle = headerToggle
        self.content = content()
    }

    var body: some View {
        let body = content
        InspectorCollapsibleSection(title: title, isExpanded: $isExpanded, isOn: headerToggle) { body }
    }
}
