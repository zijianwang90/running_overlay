import SwiftUI

struct IntervalTimelineOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var layoutOpen = true
    @State private var timelineOpen = true
    @State private var currentOpen = true
    @State private var labelsOpen = true

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        CollapsibleLayoutInspectorSection(isExpanded: $layoutOpen) {
                            OverlayLayoutInspectorRows(
                                elementID: elementID,
                                widthBinding: timelineBinding(\.width, current: element.style.intervalTimeline),
                                widthRange: 320...1100,
                                heightBinding: timelineBinding(\.height, current: element.style.intervalTimeline),
                                heightRange: 56...180
                            )
                        }
                        section("Timeline", systemImage: "timeline.selection", isOpen: $timelineOpen) {
                            timelineRows(element.style.intervalTimeline)
                        }
                        section("Current", systemImage: "location.fill", isOpen: $currentOpen) {
                            currentRows(element.style.intervalTimeline)
                        }
                        section("Labels", systemImage: "textformat", isOpen: $labelsOpen) {
                            labelRows(element.style.intervalTimeline)
                        }
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
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
            }
            .buttonStyle(.plain)

            Image(systemName: "timeline.selection")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumericTokens.accentBlue)
                .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("Interval Timeline")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Charts")
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
        .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
    }

    private func section<Content: View>(_ title: String, systemImage: String, isOpen: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
                    .frame(width: 18, height: 18)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture { isOpen.wrappedValue.toggle() }
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
            if isOpen.wrappedValue {
                VStack(spacing: 0) { content() }
            }
        }
    }

    @ViewBuilder
    private func timelineRows(_ style: IntervalTimelineStyle) -> some View {
        InspectorDenseRow(label: "Mode") {
            InspectorDenseSegmented(values: IntervalTimelineMode.allCases, selection: Binding(
                get: { style.mode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.mode = value } }
            )) { Text($0.label).tag($0) }
        }
        if style.mode == .fullSchedule {
            InspectorDenseRow(label: "Layout") {
                InspectorDenseSegmented(values: IntervalTimelineFullSegmentLayoutMode.allCases, selection: Binding(
                    get: { style.fullSegmentLayoutMode },
                    set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.fullSegmentLayoutMode = value } }
                )) { Text($0.label).tag($0) }
            }
        }
        InspectorDenseSliderRow(
            label: "Neighbors",
            value: Binding(
                get: { Double(style.visibleNeighbors) },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.visibleNeighbors = min(max(Int(value.rounded()), 1), 8) } }
            ),
            range: 1...8,
            displayText: "\(style.visibleNeighbors)"
        )
        InspectorDenseRow(label: "Rest") {
            Toggle("", isOn: Binding(
                get: { style.showsRestSegments },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.showsRestSegments = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "WU") {
            Toggle("", isOn: Binding(
                get: { style.showsWarmupSegments },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.showsWarmupSegments = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "CD") {
            Toggle("", isOn: Binding(
                get: { style.showsCooldownSegments },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.showsCooldownSegments = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseSliderRow(
            label: "Segment Gap",
            value: timelineBinding(\.segmentGap, current: style),
            range: 0...14,
            displayText: "\(Int(style.segmentGap))"
        )
        InspectorDenseSliderRow(
            label: "Radius",
            value: timelineBinding(\.segmentCornerRadius, current: style),
            range: 0...20,
            displayText: "\(Int(style.segmentCornerRadius))"
        )
    }

    @ViewBuilder
    private func currentRows(_ style: IntervalTimelineStyle) -> some View {
        let usesFullEqualWidth = style.mode == .fullSchedule && style.fullSegmentLayoutMode == .equal
        InspectorDenseSliderRow(
            label: "Emphasis",
            value: timelineBinding(\.currentSegmentHeightScale, current: style),
            range: 1...1.8,
            displayText: String(format: "%.2fx", style.currentSegmentHeightScale)
        )
        InspectorDenseSliderRow(
            label: "Width",
            value: usesFullEqualWidth ? timelineBinding(\.fullEqualCurrentSegmentWidthFraction, current: style) : timelineBinding(\.currentSegmentWidthFraction, current: style),
            range: usesFullEqualWidth ? 0...0.65 : 0.15...0.5,
            displayText: usesFullEqualWidth && style.fullEqualCurrentSegmentWidthFraction <= 0.005
                ? "Equal"
                : String(format: "%.0f%%", (usesFullEqualWidth ? style.fullEqualCurrentSegmentWidthFraction : style.currentSegmentWidthFraction) * 100)
        )
        InspectorDenseRow(label: "Progress") {
            Toggle("", isOn: Binding(
                get: { style.currentProgressEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentProgressEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Marker") {
            Toggle("", isOn: Binding(
                get: { style.markerEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Marker Text") {
            Toggle("", isOn: Binding(
                get: { style.markerLabelEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerLabelEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        .opacity(style.markerEnabled ? 1 : 0.5)
        .disabled(!style.markerEnabled)
        InspectorDenseRow(label: "Text") {
            TextField("NOW", text: Binding(
                get: { style.markerLabel },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerLabel = String(value.prefix(24)) } }
            ))
            .textFieldStyle(.plain)
            .font(NumericTokens.bodyFont)
            .foregroundStyle(NumericTokens.textPrimary)
            .multilineTextAlignment(.trailing)
        }
        .opacity(style.markerEnabled && style.markerLabelEnabled ? 1 : 0.5)
        .disabled(!style.markerEnabled || !style.markerLabelEnabled)
        InspectorDenseRow(label: "Marker Pos") {
            InspectorDenseSegmented(values: IntervalTimelineMarkerPosition.allCases, selection: Binding(
                get: { style.markerPosition },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerPosition = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseSliderRow(
            label: "Marker Size",
            value: timelineBinding(\.markerFontSize, current: style),
            range: 8...22,
            displayText: "\(Int(style.markerFontSize))"
        )
        InspectorDenseRow(label: "Marker Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { style.markerFontWeight },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerFontWeight = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Marker Font") {
            Menu {
                Button {
                    project.mutateIntervalTimelineStyle(elementID) { $0.markerFontName = "" }
                } label: {
                    if style.markerFontName.isEmpty {
                        Label("Default", systemImage: "checkmark")
                    } else {
                        Text("Default")
                    }
                }
                Divider()
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        project.mutateIntervalTimelineStyle(elementID) { $0.markerFontName = name }
                    } label: {
                        if name == style.markerFontName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: style.markerFontName.isEmpty ? "Default" : style.markerFontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseRow(label: "Marker Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.markerColor) { color in
                project.mutateIntervalTimelineStyle(elementID) { $0.markerColor = color }
            }
        }
    }

    @ViewBuilder
    private func labelRows(_ style: IntervalTimelineStyle) -> some View {
        InspectorDenseRow(label: "Work Dist") {
            InspectorDenseSegmented(values: IntervalTimelineCurrentLabelMetricMode.allCases, selection: Binding(
                get: { style.currentWorkDistanceLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentWorkDistanceLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Work Time") {
            InspectorDenseSegmented(values: IntervalTimelineCurrentLabelMetricMode.allCases, selection: Binding(
                get: { style.currentWorkTimeLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentWorkTimeLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Rest Kind") {
            Toggle("", isOn: Binding(
                get: { style.currentRestKindLabelEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentRestKindLabelEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Rest Dist") {
            InspectorDenseSegmented(values: IntervalTimelineCurrentLabelMetricMode.allCases, selection: Binding(
                get: { style.currentRestDistanceLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentRestDistanceLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Rest Time") {
            InspectorDenseSegmented(values: IntervalTimelineCurrentLabelMetricMode.allCases, selection: Binding(
                get: { style.currentRestTimeLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.currentRestTimeLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Neighbor") {
            InspectorDenseSegmented(values: IntervalTimelineNeighborLabelMode.allCases, selection: Binding(
                get: { style.neighborLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.neighborLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Rep Counter") {
            Toggle("", isOn: Binding(
                get: { style.repCounterEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.repCounterEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Overflow Hint") {
            Toggle("", isOn: Binding(
                get: { style.overflowHintEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.overflowHintEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
    }

    private func timelineBinding(_ keyPath: WritableKeyPath<IntervalTimelineStyle, Double>, current style: IntervalTimelineStyle) -> Binding<Double> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { value in project.mutateIntervalTimelineStyleContinuous(elementID) { $0[keyPath: keyPath] = value } }
        )
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.mutateIntervalTimelineStyle(elementID) { $0 = .default } },
            onTrailingTap: { project.selection = .none }
        )
    }
}
