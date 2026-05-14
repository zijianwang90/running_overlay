import SwiftUI

struct IntervalTimelineOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var layoutOpen = true
    @State private var timelineOpen = true
    @State private var currentOpen = true
    @State private var railOpen = true
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
                        section("Rail", systemImage: "circle.grid.3x3.fill", isOpen: $railOpen) {
                            railRows(element.style.intervalTimeline)
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
        InspectorDenseSliderRow(
            label: "Neighbors",
            value: Binding(
                get: { Double(style.visibleNeighbors) },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.visibleNeighbors = min(max(Int(value.rounded()), 1), 8) } }
            ),
            range: 1...8,
            displayText: "\(style.visibleNeighbors)"
        )
        InspectorDenseSliderRow(
            label: "Max Full",
            value: Binding(
                get: { Double(style.maxFullSegments) },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.maxFullSegments = min(max(Int(value.rounded()), 4), 30) } }
            ),
            range: 4...30,
            displayText: "\(style.maxFullSegments)"
        )
        InspectorDenseSliderRow(
            label: "Segment Gap",
            value: timelineBinding(\.segmentGap, current: style),
            range: 0...14,
            displayText: "\(Int(style.segmentGap))"
        )
    }

    @ViewBuilder
    private func currentRows(_ style: IntervalTimelineStyle) -> some View {
        InspectorDenseSliderRow(
            label: "Emphasis",
            value: timelineBinding(\.currentSegmentHeightScale, current: style),
            range: 1...1.8,
            displayText: String(format: "%.2fx", style.currentSegmentHeightScale)
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
        InspectorDenseRow(label: "Marker Pos") {
            InspectorDenseSegmented(values: IntervalTimelineMarkerPosition.allCases, selection: Binding(
                get: { style.markerPosition },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.markerPosition = value } }
            )) { Text($0.label).tag($0) }
        }
    }

    @ViewBuilder
    private func railRows(_ style: IntervalTimelineStyle) -> some View {
        InspectorDenseRow(label: "Dots") {
            Toggle("", isOn: Binding(
                get: { style.railEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.railEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseSliderRow(
            label: "Spacing",
            value: timelineBinding(\.railSpacing, current: style),
            range: 0...18,
            displayText: "\(Int(style.railSpacing))"
        )
        InspectorDenseSliderRow(
            label: "Size",
            value: timelineBinding(\.railDotSize, current: style),
            range: 2...10,
            displayText: "\(Int(style.railDotSize))"
        )
        InspectorDenseSliderRow(
            label: "Alpha",
            value: timelineBinding(\.railOpacity, current: style),
            range: 0...1,
            displayText: String(format: "%.2f", style.railOpacity)
        )
        InspectorDenseRow(label: "Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.railColor) { color in
                project.mutateIntervalTimelineStyle(elementID) { $0.railColor = color }
            }
        }
        InspectorDenseSliderRow(
            label: "Line Width",
            value: timelineBinding(\.railLineWidth, current: style),
            range: 1...10,
            displayText: "\(Int(style.railLineWidth))"
        )
        InspectorDenseRow(label: "Line Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.railLineColor) { color in
                project.mutateIntervalTimelineStyle(elementID) { $0.railLineColor = color }
            }
        }
        .opacity(style.railEnabled ? 1 : 0.5)
    }

    @ViewBuilder
    private func labelRows(_ style: IntervalTimelineStyle) -> some View {
        InspectorDenseRow(label: "Label Mode") {
            InspectorDenseSegmented(values: IntervalTimelineLabelMode.allCases, selection: Binding(
                get: { style.primaryLabelMode },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.primaryLabelMode = value } }
            )) { Text($0.label).tag($0) }
        }
        InspectorDenseRow(label: "Duration") {
            Toggle("", isOn: Binding(
                get: { style.durationLabelsEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.durationLabelsEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Rep Counter") {
            Toggle("", isOn: Binding(
                get: { style.repCounterEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.repCounterEnabled = value } }
            ))
            .labelsHidden()
            .tint(NumericTokens.accentBlue)
        }
        InspectorDenseRow(label: "Overflow Pills") {
            Toggle("", isOn: Binding(
                get: { style.overflowPillsEnabled },
                set: { value in project.mutateIntervalTimelineStyle(elementID) { $0.overflowPillsEnabled = value } }
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
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }
}
