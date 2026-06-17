import SwiftUI

struct ZoneEdgeBarOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<ZoneEdgeBarInspectorSectionKind> = Set(ZoneEdgeBarInspectorSectionKind.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)

                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: binding(for: .layout)) {
                            OverlayLayoutInspectorRows(elementID: elementID)
                        }

                        ZoneEdgeBarInspectorSection(
                            title: "Zone Bar",
                            systemImage: "rectangle.compress.vertical",
                            isExpanded: binding(for: .zoneBar)
                        ) {
                            zoneBarRows(element.style.zoneEdgeBar)
                        }

                        ZoneEdgeBarInspectorSection(
                            title: "Markers",
                            systemImage: "target",
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
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .buttonStyle(.plain)
            .help("Back")

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: "rectangle.compress.vertical")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Zone Overlay")
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle, lineWidth: 1))
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
            label: "Active Zone Width",
            value: Binding(
                get: { style.activeZoneWidthShare },
                set: { value in project.mutateZoneEdgeBarStyleContinuous(elementID) { $0.activeZoneWidthShare = value.quantizedNumeric(to: 0.05) } }
            ),
            range: 0...0.5,
            displayText: style.activeZoneWidthShare <= 0 ? "Equal" : String(format: "%.0f%%", style.activeZoneWidthShare * 100)
        )
        InspectorDenseSliderRow(
            label: "Active Zone Height",
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
        }
        toggleRow("Threshold Marker", isOn: style.thresholdMarkerEnabled) { value in
            project.mutateZoneEdgeBarStyle(elementID) { $0.thresholdMarkerEnabled = value }
        }
    }

    @ViewBuilder
    private func borderRows(_ style: ZoneEdgeBarStyle) -> some View {
        if style.borderEnabled {
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
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
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.mutateZoneEdgeBarStyle(elementID) { $0 = .default } },
            onTrailingTap: { project.selection = .none }
        )
    }
}

private enum ZoneEdgeBarInspectorSectionKind: CaseIterable {
    case layout
    case zoneBar
    case markers
}

private struct ZoneEdgeBarInspectorSection<Content: View>: View {
    var title: String
    var systemImage: String
    @Binding var isExpanded: Bool
    var headerToggle: Binding<Bool>?
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        headerToggle: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.headerToggle = headerToggle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                if let headerToggle {
                    Toggle("", isOn: headerToggle)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .frame(height: NumericTokens.sectionHeaderHeight)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}
