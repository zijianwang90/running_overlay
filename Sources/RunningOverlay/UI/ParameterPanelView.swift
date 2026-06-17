import SwiftUI

struct ParameterPanelView: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        Group {
            switch project.selection {
            case .timelineClip(let clipID):
                ClipDetailView(clipID: clipID)
            case .overlayElement(let elementID):
                if let element = project.selectedOverlay(elementID) {
                    if element.type.isNumericOverlay {
                        NumericOverlayDetailView(elementID: elementID)
                    } else if element.type == .distanceTimeline {
                        DistanceTimelineOverlayDetailView(elementID: elementID)
                    } else if element.type == .elevationChart {
                        ElevationChartOverlayDetailView(elementID: elementID)
                    } else if element.type == .runningGauge {
                        RunningGaugeOverlayDetailView(elementID: elementID)
                    } else if element.type == .intervalHUDBar {
                        IntervalHUDBarOverlayDetailView(elementID: elementID)
                    } else if element.type == .intervalTimeline {
                        IntervalTimelineOverlayDetailView(elementID: elementID)
                    } else if element.type == .zoneEdgeBar {
                        ZoneEdgeBarOverlayDetailView(elementID: elementID)
                    } else if element.type == .routeMap {
                        RouteMapOverlayDetailView(elementID: elementID)
                    } else if element.type == .weatherWidget {
                        WeatherWidgetOverlayDetailView(elementID: elementID)
                    } else if element.type.isDecorOverlay {
                        DecorOverlayDetailView(elementID: elementID)
                    } else {
                        OverlayDetailView(elementID: elementID)
                    }
                } else {
                    OverlayDetailView(elementID: elementID)
                }
            case .none:
                InspectorOuterView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(InspectorTheme.panelBackground)
        .foregroundStyle(InspectorTheme.textPrimary)
    }
}

private struct InspectorPanel<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
            }
        }
    }
}

struct ClipInspectorView: View {
    @EnvironmentObject private var project: ProjectDocument
    let clipID: TimelineClip.ID

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.sectionGap) {
            InspectorSection(title: "Clip Timing", systemImage: "timeline.selection") {
                if let clip = project.selectedClip(clipID) {
                    InspectorReadOnlyRow(label: "Clip", value: clip.title)
                    InspectorTextRow(label: "Camera", text: cameraBinding)

                    if project.isAutoMatchedClip(clipID) {
                        InspectorReadOnlyRow(
                            label: "Auto Matched Start",
                            value: formatSeconds(clip.startTime),
                            systemImage: nil,
                            isNumeric: true
                        )
                    } else {
                        InspectorNumberRow(
                            label: "Aligned Time",
                            value: startBinding,
                            precision: 2,
                            suffix: "s",
                            reset: resetStart
                        )
                    }

                    InspectorNumberRow(
                        label: "Offset",
                        value: offsetBinding,
                        precision: 2,
                        suffix: "s",
                        reset: resetOffset
                    )
                } else {
                    InspectorNumberRow(
                        label: "Offset",
                        value: offsetBinding,
                        precision: 2,
                        suffix: "s",
                        reset: resetOffset
                    )
                }
            }

            Button {
                project.applyOffsetToCurrentLayer(for: clipID)
            } label: {
                Label("Apply to all clips in this layer", systemImage: "square.stack.3d.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InspectorPrimaryButtonStyle())
        }
    }

    private var offsetBinding: Binding<Double> {
        Binding {
            project.selectedClip(clipID)?.alignmentOffset ?? 0
        } set: { newValue in
            project.setSelectedClipOffset(clipID, offset: newValue.quantized(to: 0.01))
        }
    }

    private var startBinding: Binding<Double> {
        Binding {
            project.selectedClip(clipID)?.effectiveStartTime ?? 0
        } set: { newValue in
            project.moveClip(clipID, toEffectiveStartTime: newValue.quantized(to: 0.01))
        }
    }

    private var cameraBinding: Binding<String> {
        Binding {
            project.selectedClip(clipID)?.cameraGroupID ?? ""
        } set: { newValue in
            project.renameTrack(containing: clipID, to: newValue)
        }
    }

    private func resetStart() {
        project.moveClip(clipID, toEffectiveStartTime: 0)
        project.finishContinuousEdit()
    }

    private func resetOffset() {
        project.setSelectedClipOffset(clipID, offset: 0)
        project.finishContinuousEdit()
    }
}

private struct ClipDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let clipID: TimelineClip.ID

    var body: some View {
        VStack(spacing: 0) {
            if let clip = project.selectedClip(clipID) {
                ClipDetailHeader(clip: clip)

                Divider()
                    .overlay(InspectorTheme.borderSubtle)

                ScrollView {
                    VStack(spacing: 0) {
                        InspectorDetailSection(title: "Clip Timing", systemImage: "video.badge.waveform") {
                            InspectorDetailRow(label: "Clip") {
                                Text(clip.title)
                                    .font(NumericTokens.bodyStrongFont)
                                    .foregroundStyle(NumericTokens.textPrimary)
                                    .lineLimit(1)
                            }

                            InspectorDetailRow(label: "Layer") {
                                TextField("Layer", text: cameraBinding)
                                    .textFieldStyle(.plain)
                                    .font(InspectorTheme.bodyStrongFont)
                                    .foregroundStyle(InspectorTheme.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }

                            if project.isAutoMatchedClip(clipID) {
                                InspectorDetailReadOnlyValueRow(
                                    label: "Auto Matched Start",
                                    value: formatSeconds(clip.startTime)
                                )
                            } else {
                                InspectorDetailNumberRow(
                                    label: "Aligned Time",
                                    value: startBinding,
                                    precision: 2,
                                    suffix: "s",
                                    reset: resetStart
                                )
                            }

                            InspectorDetailNumberRow(
                                label: "Offset",
                                value: offsetBinding,
                                precision: 2,
                                suffix: "s",
                                reset: resetOffset
                            )

                            HStack {
                                Button {
                                    project.applyOffsetToCurrentLayer(for: clipID)
                                } label: {
                                    Label("Apply to all clips in this layer", systemImage: "square.stack.3d.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(InspectorPrimaryButtonStyle())
                            }
                            .padding(.horizontal, NumericTokens.panelPaddingX)
                            .padding(.vertical, NumericTokens.space2)
                            .overlay(alignment: .bottom) {
                                Divider()
                                    .overlay(NumericTokens.borderSubtle)
                            }
                        }
                    }
                }
            } else {
                InspectorHeader(title: "Inspector", status: "Missing", trailingSystemImage: "slider.horizontal.3")
                Spacer()
            }
        }
    }

    private var offsetBinding: Binding<Double> {
        Binding {
            project.selectedClip(clipID)?.alignmentOffset ?? 0
        } set: { newValue in
            project.setSelectedClipOffset(clipID, offset: newValue.quantized(to: 0.01))
        }
    }

    private var startBinding: Binding<Double> {
        Binding {
            project.selectedClip(clipID)?.effectiveStartTime ?? 0
        } set: { newValue in
            project.moveClip(clipID, toEffectiveStartTime: newValue.quantized(to: 0.01))
        }
    }

    private var cameraBinding: Binding<String> {
        Binding {
            project.selectedClip(clipID)?.cameraGroupID ?? ""
        } set: { newValue in
            project.renameTrack(containing: clipID, to: newValue)
        }
    }

    private func resetStart() {
        project.moveClip(clipID, toEffectiveStartTime: 0)
        project.finishContinuousEdit()
    }

    private func resetOffset() {
        project.setSelectedClipOffset(clipID, offset: 0)
        project.finishContinuousEdit()
    }
}

private func formatSeconds(_ seconds: TimeInterval) -> String {
    String(format: "%.2f s", seconds)
}

private struct ClipDetailHeader: View {
    @EnvironmentObject private var project: ProjectDocument
    let clip: TimelineClip

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Button {
                project.clearSelection()
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
                Image(systemName: "video")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.textPrimary)
            }
            .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(clip.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                    .lineLimit(1)
                Text("Clip")
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
                project.deleteSelectedItem()
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
            .help("Delete Clip")
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

private struct InspectorDetailSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: InspectorTheme.space2) {
                Image(systemName: systemImage)
                    .foregroundStyle(NumericTokens.textSecondary)
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
            }
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .frame(height: NumericTokens.sectionHeaderHeight)
            .background(NumericTokens.panelBackgroundElevated)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NumericTokens.borderSubtle)
                    .frame(height: 1)
            }

            VStack(spacing: 0) {
                content
            }
        }
    }
}

private struct InspectorDetailRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textSecondary)
                .frame(width: NumericTokens.labelColumnWidth, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: NumericTokens.rowHeight)
        .background(NumericTokens.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }
}

private struct InspectorDetailNumberRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    @Binding var value: Double
    var precision: Int
    var suffix: String?
    var reset: (() -> Void)?

    var body: some View {
        InspectorDetailRow(label: label) {
            HStack(spacing: InspectorTheme.space2) {
                InspectorBufferedNumberField(
                    label: label,
                    value: $value,
                    precision: precision,
                    font: NumericTokens.numericFont,
                    textColor: NumericTokens.textPrimary,
                    onCommit: project.finishContinuousEdit
                )

                if let suffix {
                    Text(suffix)
                        .font(NumericTokens.bodyStrongFont)
                        .foregroundStyle(NumericTokens.textMuted)
                }
            }
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        }
        .onTapGesture(count: 2) {
            reset?()
        }
        .help(reset == nil ? "" : "Double-click to reset")
    }
}

private struct InspectorDetailReadOnlyValueRow: View {
    var label: String
    var value: String

    var body: some View {
        InspectorDetailRow(label: label) {
            Text(value)
                .font(NumericTokens.numericFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

private struct InspectorOuterView: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(
                title: "Inspector",
                status: overlayCountLabel,
                trailingSystemImage: "slider.horizontal.3"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: InspectorTheme.sectionGap) {
                    AddedOverlaysSection()
                }
                .padding(.horizontal, InspectorTheme.outerPanelPaddingX)
                .padding(.vertical, InspectorTheme.outerPanelPaddingY)
            }
        }
    }

    private var overlayCountLabel: String {
        let count = project.overlayLayout.elements.count
        return count == 1 ? "1 overlay" : "\(count) overlays"
    }
}

private struct AddedOverlaysSection: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        InspectorSection(title: "Added Overlays", subtitle: "Manage overlays in your scene") {
            if project.overlayLayout.elements.isEmpty {
                HStack(spacing: InspectorTheme.space3) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .foregroundStyle(InspectorTheme.textMuted)
                    Text("No overlays added yet")
                        .font(InspectorTheme.bodyFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, InspectorTheme.space3)
                .frame(minHeight: InspectorTheme.rowHeight)
                .background(InspectorTheme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
                .overlay(InspectorRoundedBorder())
            } else {
                VStack(spacing: InspectorTheme.space2) {
                    ForEach(project.overlayLayout.elements) { element in
                        OverlayElementRow(element: element)
                    }
                }
            }
        }
    }
}

private struct OverlayElementRow: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement

    var body: some View {
        HStack(spacing: InspectorTheme.space2) {
            Button {
                project.openOverlayDetailFromList(element.id)
            } label: {
                rowBody
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 24)
                .overlay(InspectorTheme.borderSubtle)

            InspectorIconButton(
                systemImage: element.isVisible ? "eye" : "eye.slash",
                help: element.isVisible ? "Hide Overlay" : "Show Overlay",
                compact: true
            ) {
                project.setOverlayVisibility(element.id, isVisible: !element.isVisible)
            }
            InspectorIconButton(
                systemImage: element.isLocked ? "lock.fill" : "lock.open",
                help: element.isLocked ? "Unlock Overlay" : "Lock Overlay",
                compact: true
            ) {
                project.setOverlayLocked(element.id, isLocked: !element.isLocked)
            }
            InspectorIconButton(systemImage: "trash", help: "Delete", role: .destructive, compact: true) {
                project.deleteOverlay(element.id)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(InspectorTheme.textMuted)
        }
        .padding(.horizontal, InspectorTheme.outerRowPaddingX)
        .frame(minHeight: InspectorTheme.rowHeight)
        .background(InspectorTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
        .overlay(InspectorRoundedBorder())
        .opacity(element.isVisible ? 1 : 0.72)
        .contextMenu {
            Button {
                project.copyOverlayProperties(from: element.id)
            } label: {
                Label("Copy Properties", systemImage: "doc.on.doc")
            }
            Button {
                project.pasteOverlayProperties(to: element.id)
            } label: {
                Label("Paste Properties", systemImage: "doc.on.clipboard")
            }
            .disabled(!project.canPasteOverlayProperties(to: element.id))
        }
    }

    private var rowBody: some View {
        HStack(spacing: InspectorTheme.space3) {
            Image(systemName: element.type.inspectorIcon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(element.type.isFeaturedOverlay ? InspectorTheme.accentBlue : InspectorTheme.textPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(element.type.label)
                    .font(InspectorTheme.bodyStrongFont)
                    .foregroundStyle(InspectorTheme.textPrimary)
                    .lineLimit(1)
                Text(element.subtitle)
                    .font(InspectorTheme.captionFont)
                    .foregroundStyle(InspectorTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: InspectorTheme.space2)

            Text(valuePreview)
                .font(InspectorTheme.numericFont)
                .foregroundStyle(InspectorTheme.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
    }

    private var valuePreview: String {
        OverlayValueFormatter.value(
            for: element.type,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }
}

private struct InspectorBufferedNumberField: View {
    var label: String
    @Binding var value: Double
    var precision: Int
    var font: Font
    var textColor: Color
    var onCommit: () -> Void

    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField(label, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(textColor)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onAppear {
                text = formatted(value)
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused else {
                    return
                }
                text = formatted(newValue)
            }
            .onChange(of: text) { _, newText in
                guard isFocused, let parsed = parsedValue(from: newText) else {
                    return
                }
                updateValueIfNeeded(parsed)
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    text = editableText(for: value)
                } else {
                    commitText()
                }
            }
            .onSubmit {
                commitText()
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
    }

    private func commitText() {
        if let parsed = parsedValue(from: text) {
            updateValueIfNeeded(parsed)
        }
        text = formatted(value)
        onCommit()
    }

    private func parsedValue(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else {
            return nil
        }
        return Double(normalized)
    }

    private func editableText(for value: Double) -> String {
        let formattedValue = formatted(value)
        return formattedValue.hasSuffix(".00") ? String(formattedValue.dropLast(3)) : formattedValue
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.\(precision)f", value)
    }

    private func updateValueIfNeeded(_ parsed: Double) {
        guard roundedForPrecision(parsed) != roundedForPrecision(value) else {
            return
        }
        value = parsed
    }

    private func roundedForPrecision(_ value: Double) -> Double {
        let scale = pow(10, Double(precision))
        return (value * scale).rounded() / scale
    }
}

private struct OverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                OverlayDetailHeader(element: element)

                Divider()
                    .overlay(InspectorTheme.borderSubtle)

                ScrollView {
                    VStack(alignment: .leading, spacing: InspectorTheme.sectionGap) {
                        contentSection(element)
                        positionSection(element)
                        styleSection(element)
                        OverlayBackgroundInspectorModule(elementID: elementID, element: element)
                        OverlayBorderInspectorModule(elementID: elementID, element: element)
                        OverlayEffectsInspectorModule(elementID: elementID, element: element)
                    }
                    .padding(.horizontal, InspectorTheme.panelPaddingX)
                    .padding(.vertical, InspectorTheme.panelPaddingY)
                }

                Divider()
                    .overlay(InspectorTheme.borderSubtle)

                HStack(spacing: InspectorTheme.space3) {
                    Button {
                        project.selection = .none
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InspectorPrimaryButtonStyle())
                }
                .padding(.horizontal, InspectorTheme.panelPaddingX)
                .padding(.vertical, InspectorTheme.space3)
                .background(InspectorTheme.panelBackgroundElevated)
            } else {
                InspectorHeader(title: "Inspector", status: "Missing", trailingSystemImage: "slider.horizontal.3")
                Spacer()
            }
        }
    }

    private func contentSection(_ element: OverlayElement) -> some View {
        InspectorSection(title: "Content", systemImage: "list.bullet.rectangle") {
            InspectorReadOnlyRow(label: "Metric", value: element.type.label, systemImage: element.type.inspectorIcon)
            InspectorReadOnlyRow(label: "Format Preview", value: valuePreview(for: element), isNumeric: true)
        }
    }

    private func positionSection(_ element: OverlayElement) -> some View {
        InspectorSection(title: "Position & Size", systemImage: "scope") {
            HStack(spacing: InspectorTheme.space3) {
                InspectorNumberRow(label: "X", value: positionXBinding, precision: 3)
                InspectorNumberRow(label: "Y", value: positionYBinding, precision: 3)
            }

            InspectorSliderRow(
                label: "Scale",
                value: scaleBinding,
                range: 0.25...4,
                display: String(format: "%.2fx", element.scale)
            )
        }
    }

    private func styleSection(_ element: OverlayElement) -> some View {
        InspectorSection(title: "Style", systemImage: "paintpalette") {
            presetControl(for: element)

            if element.type == .routeMap {
                InspectorPickerRow(label: "Map Background", selection: routeMapBackgroundStyleBinding, values: OverlayRouteMapBackgroundStyle.allCases) { $0.compactLabel }
                InspectorSegmentedPicker(selection: routeMapColorModeBinding, values: OverlayRouteMapColorMode.allCases) { colorMode in
                    colorMode.compactLabel
                }
                InspectorSegmentedPicker(selection: routeMapShapeBinding, values: OverlayRouteMapShape.allCases) { shape in
                    shape.compactLabel
                }
                InspectorSliderRow(
                    label: "Edge Softness",
                    value: routeMapEdgeSoftnessBinding,
                    range: 0...0.45,
                    display: element.style.routeMapFadeAmount <= 0.001 ? "Solid" : String(format: "%.0f%%", element.style.routeMapFadeAmount * 100)
                )
                routeMapMarkerToggleRow(label: "Start Marker", isOn: routeMapStartMarkerVisibleBinding)
                routeMapMarkerToggleRow(label: "End Marker", isOn: routeMapEndMarkerVisibleBinding)
                routeMapMarkerToggleRow(label: "Moving Marker", isOn: routeMapRunnerMarkerVisibleBinding)
                ColorSwatchRow(label: "Start Color", presets: colorPresets, selectedColor: element.style.routeMapStartMarkerColor) { color in
                    project.setOverlayRouteMapStartMarkerColor(elementID, color: color)
                }
                ColorSwatchRow(label: "End Color", presets: routeMapEndMarkerColorPresets, selectedColor: element.style.routeMapEndMarkerColor) { color in
                    project.setOverlayRouteMapEndMarkerColor(elementID, color: color)
                }
                ColorSwatchRow(label: "Moving Color", presets: colorPresets, selectedColor: element.style.routeMapRunnerDotColor) { color in
                    project.setOverlayRouteMapRunnerDotColor(elementID, color: color)
                }
                Toggle(isOn: routeMapLegendVisibleBinding) {
                    Text("Legend")
                        .font(InspectorTheme.bodyFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                }
                .toggleStyle(.switch)
                if element.style.routeMapLegendVisible {
                    InspectorPickerRow(label: "Legend Style", selection: routeMapLegendModeBinding, values: OverlayRouteMapLegendMode.allCases) { $0.compactLabel }
                }
                if element.style.routeMapColorMode == .gradient {
                    ColorSwatchRow(label: "Gradient Start", presets: colorPresets, selectedColor: element.style.routeMapGradientStart) { color in
                        project.setOverlayRouteMapGradientStart(elementID, color: color)
                    }
                    ColorSwatchRow(label: "Gradient Mid", presets: colorPresets, selectedColor: element.style.routeMapGradientMiddle) { color in
                        project.setOverlayRouteMapGradientMiddle(elementID, color: color)
                    }
                    ColorSwatchRow(label: "Gradient End", presets: colorPresets, selectedColor: element.style.routeMapGradientEnd) { color in
                        project.setOverlayRouteMapGradientEnd(elementID, color: color)
                    }
                }
            } else {
                InspectorPickerRow(label: "Font", selection: fontNameBinding, values: fontPresets) { $0 }

                InspectorSliderRow(
                    label: "Font Size",
                    value: fontSizeBinding,
                    range: 12...96,
                    display: "\(Int(element.style.fontSize.rounded()))"
                )

                InspectorSegmentedPicker(selection: fontWeightBinding, values: OverlayFontWeight.allCases) { weight in
                    weight.shortLabel
                }
            }

            ColorSwatchRow(
                label: "Color",
                presets: colorPresets,
                selectedColor: element.style.foregroundColor
            ) { color in
                project.setOverlayForegroundColor(elementID, color: color)
            }

            InspectorSliderRow(
                label: "Background",
                value: backgroundOpacityBinding,
                range: 0...1,
                display: String(format: "%.0f%%", element.style.backgroundOpacity * 100)
            )

            InspectorSliderRow(
                label: "Shadow",
                value: shadowOpacityBinding,
                range: 0...1,
                display: String(format: "%.0f%%", element.style.shadowOpacity * 100)
            )

            InspectorSliderRow(
                label: "Shadow Radius",
                value: shadowRadiusBinding,
                range: 0...24,
                display: "\(Int(element.style.shadowRadius.rounded()))"
            )
        }
    }

    @ViewBuilder
    private func presetControl(for element: OverlayElement) -> some View {
        if element.type.supportsTextPresets {
            InspectorPickerRow(label: "Preset", selection: textPresetBinding, values: OverlayTextPreset.numericPresets) { $0.compactLabel }
        } else if element.type == .runningGauge {
            InspectorPickerRow(label: "Preset", selection: gaugePresetBinding, values: OverlayGaugePreset.allCases) { $0.compactLabel }
        } else if element.type == .routeMap {
            InspectorPickerRow(label: "Preset", selection: routeMapPresetBinding, values: OverlayRouteMapPreset.allCases) { $0.compactLabel }
        }
    }

    private func valuePreview(for element: OverlayElement) -> String {
        OverlayValueFormatter.value(
            for: element.type,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }

    private var fontPresets: [String] { FontLibraryManager.shared.effectiveFavorites }

    private let colorPresets: [(name: String, color: OverlayColor)] = [
        ("White", .white),
        ("Black", .black),
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Blue", .blue),
        ("Cyan", .cyan),
        ("Purple", .purple),
        ("Pink", .pink)
    ]

    private var routeMapEndMarkerColorPresets: [(name: String, color: OverlayColor)] {
        [("Checker", .routeMapEndCheckerboard)] + colorPresets
    }

    private var fontSizeBinding: Binding<Double> {
        Binding {
            element?.style.fontSize ?? 28
        } set: { newValue in
            project.setOverlayFontSize(elementID, fontSize: newValue.rounded())
        }
    }

    private var textPresetBinding: Binding<OverlayTextPreset> {
        Binding {
            element?.style.textPreset ?? .minimal
        } set: { newValue in
            project.setOverlayTextPreset(elementID, textPreset: newValue)
        }
    }

    private var gaugePresetBinding: Binding<OverlayGaugePreset> {
        Binding {
            element?.style.gaugePreset ?? .minimalSport
        } set: { newValue in
            project.setOverlayGaugePreset(elementID, gaugePreset: newValue)
        }
    }

    private var routeMapPresetBinding: Binding<OverlayRouteMapPreset> {
        Binding {
            element?.style.routeMapPreset ?? .minimal
        } set: { newValue in
            project.setOverlayRouteMapPreset(elementID, routeMapPreset: newValue)
        }
    }

    private var routeMapShapeBinding: Binding<OverlayRouteMapShape> {
        Binding {
            element?.style.routeMapShape ?? .square
        } set: { newValue in
            project.setOverlayRouteMapShape(elementID, shape: newValue)
        }
    }

    private func routeMapMarkerToggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
        }
        .toggleStyle(.switch)
    }

    private var routeMapColorModeBinding: Binding<OverlayRouteMapColorMode> {
        Binding {
            element?.style.routeMapColorMode ?? .solid
        } set: { newValue in
            project.setOverlayRouteMapColorMode(elementID, colorMode: newValue)
        }
    }

    private var routeMapEdgeSoftnessBinding: Binding<Double> {
        Binding {
            element?.style.routeMapFadeAmount ?? 0.22
        } set: { newValue in
            project.setOverlayRouteMapEdgeSoftness(elementID, amount: newValue.quantized(to: 0.01))
        }
    }

    private var routeMapStartMarkerVisibleBinding: Binding<Bool> {
        Binding {
            element?.style.routeMapStartMarkerStyle != .hidden
        } set: { newValue in
            project.setOverlayRouteMapStartMarkerStyle(elementID, markerStyle: newValue ? .dot : .hidden)
        }
    }

    private var routeMapRunnerMarkerVisibleBinding: Binding<Bool> {
        Binding {
            element?.style.routeMapRunnerMarkerStyle != .hidden
        } set: { newValue in
            project.setOverlayRouteMapRunnerMarkerStyle(elementID, markerStyle: newValue ? .dot : .hidden)
        }
    }

    private var routeMapEndMarkerVisibleBinding: Binding<Bool> {
        Binding {
            element?.style.routeMapEndMarkerStyle != .hidden
        } set: { newValue in
            project.setOverlayRouteMapEndMarkerStyle(elementID, markerStyle: newValue ? .dot : .hidden)
        }
    }

    private var routeMapBackgroundStyleBinding: Binding<OverlayRouteMapBackgroundStyle> {
        Binding {
            element?.style.routeMapBackgroundStyle ?? .dark
        } set: { newValue in
            project.setOverlayRouteMapBackgroundStyle(elementID, backgroundStyle: newValue)
        }
    }

    private var routeMapLegendVisibleBinding: Binding<Bool> {
        Binding {
            element?.style.routeMapLegendVisible ?? true
        } set: { newValue in
            project.setOverlayRouteMapLegendVisible(elementID, isVisible: newValue)
        }
    }

    private var routeMapLegendModeBinding: Binding<OverlayRouteMapLegendMode> {
        Binding {
            element?.style.routeMapLegendMode ?? .startFinishDistance
        } set: { newValue in
            project.setOverlayRouteMapLegendMode(elementID, legendMode: newValue)
        }
    }

    private var scaleBinding: Binding<Double> {
        Binding {
            element?.scale ?? 1
        } set: { newValue in
            project.setOverlayScale(elementID, scale: newValue.quantized(to: 0.05))
        }
    }

    private var fontNameBinding: Binding<String> {
        Binding {
            element?.style.fontName ?? FontLibraryManager.shared.defaultFamily
        } set: { newValue in
            project.setOverlayFontName(elementID, fontName: newValue)
        }
    }

    private var fontWeightBinding: Binding<OverlayFontWeight> {
        Binding {
            element?.style.fontWeight ?? .semibold
        } set: { newValue in
            project.setOverlayFontWeight(elementID, fontWeight: newValue)
        }
    }

    private var backgroundOpacityBinding: Binding<Double> {
        Binding {
            element?.style.backgroundOpacity ?? 0.22
        } set: { newValue in
            project.setOverlayBackgroundOpacity(elementID, opacity: newValue.quantized(to: 0.05))
        }
    }

    private var shadowOpacityBinding: Binding<Double> {
        Binding {
            element?.style.shadowOpacity ?? 0.35
        } set: { newValue in
            project.setOverlayShadowOpacity(elementID, opacity: newValue.quantized(to: 0.05))
        }
    }

    private var shadowRadiusBinding: Binding<Double> {
        Binding {
            element?.style.shadowRadius ?? 4
        } set: { newValue in
            project.setOverlayShadowRadius(elementID, radius: newValue.rounded())
        }
    }

    private var positionXBinding: Binding<Double> {
        Binding {
            Double(element?.position.x ?? 0.5)
        } set: { newValue in
            project.moveOverlay(elementID, to: CGPoint(x: newValue, y: element?.position.y ?? 0.5))
            project.finishContinuousEdit()
        }
    }

    private var positionYBinding: Binding<Double> {
        Binding {
            Double(element?.position.y ?? 0.5)
        } set: { newValue in
            project.moveOverlay(elementID, to: CGPoint(x: element?.position.x ?? 0.5, y: newValue))
            project.finishContinuousEdit()
        }
    }

    private var element: OverlayElement? {
        project.overlayLayout.elements.first { $0.id == elementID }
    }
}

private struct OverlayDetailHeader: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            InspectorIconButton(systemImage: "chevron.left", help: "Back") {
                project.selection = .none
            }

            ZStack {
                RoundedRectangle(cornerRadius: InspectorTheme.controlRadius)
                    .fill(InspectorTheme.controlBackground)
                Image(systemName: element.type.inspectorIcon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(element.type.isFeaturedOverlay ? InspectorTheme.accentBlue : InspectorTheme.textPrimary)
            }
            .frame(width: 46, height: 46)
            .overlay(InspectorRoundedBorder())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: InspectorTheme.space2) {
                    Text(element.type.label)
                        .font(InspectorTheme.titleFont)
                        .lineLimit(1)
                    Text("Overlay")
                        .font(InspectorTheme.captionFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                        .padding(.horizontal, InspectorTheme.space2)
                        .padding(.vertical, 3)
                        .background(InspectorTheme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(InspectorRoundedBorder(cornerRadius: 5))
                }
                Text(valuePreview)
                    .font(InspectorTheme.numericFont)
                    .foregroundStyle(InspectorTheme.textSecondary)
            }

            Spacer()

            InspectorIconButton(systemImage: "trash", help: "Delete", role: .destructive) {
                project.deleteOverlay(element.id)
            }
        }
        .padding(.horizontal, InspectorTheme.panelPaddingX)
        .padding(.vertical, InspectorTheme.space3)
        .background(InspectorTheme.panelBackgroundElevated)
    }

    private var valuePreview: String {
        OverlayValueFormatter.value(
            for: element.type,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }
}

private struct InspectorHeader: View {
    var title: String
    var status: String
    var trailingSystemImage: String

    var body: some View {
        EditorPanelHeader(title: title) {
            Text(status)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .lineLimit(1)

            InspectorIconButton(systemImage: trailingSystemImage, help: "Inspector Options", isEnabled: false) {}
        }
    }
}

private struct InspectorSection<Content: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.space3) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: InspectorTheme.space2) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(InspectorTheme.textSecondary)
                    }
                    Text(title)
                        .font(InspectorTheme.sectionTitleFont)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(InspectorTheme.bodyFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                }
            }
            content
        }
    }
}

private struct InspectorSegmentedPicker<Value: Hashable, Values: RandomAccessCollection>: View where Values.Element == Value {
    @Binding var selection: Value
    var values: Values
    var title: (Value) -> String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(values), id: \.self) { value in
                Text(title(value))
                    .font(InspectorTheme.bodyStrongFont)
                    .tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .tint(InspectorTheme.accentBlue)
        .frame(height: InspectorTheme.segmentedControlHeight)
    }
}

private struct InspectorReadOnlyRow: View {
    var label: String
    var value: String
    var systemImage: String?
    var isNumeric = false

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
            Spacer()
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(InspectorTheme.textSecondary)
            }
            Text(value)
                .font(isNumeric ? InspectorTheme.numericFont : InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(minHeight: InspectorTheme.controlHeight)
        .padding(.horizontal, InspectorTheme.space3)
        .background(InspectorTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
        .overlay(InspectorRoundedBorder())
    }
}

private struct InspectorTextRow: View {
    var label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textPrimary)
                .padding(.horizontal, InspectorTheme.space3)
                .frame(height: InspectorTheme.controlHeight)
                .background(InspectorTheme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
                .overlay(InspectorRoundedBorder())
        }
    }
}

private struct InspectorNumberRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    @Binding var value: Double
    var precision: Int
    var suffix: String?
    var reset: (() -> Void)?

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
                .onTapGesture(count: 2) {
                    reset?()
                }
                .help(reset == nil ? "" : "Double-click to reset")

            InspectorBufferedNumberField(
                label: label,
                value: $value,
                precision: precision,
                font: InspectorTheme.numericFont,
                textColor: InspectorTheme.textPrimary,
                onCommit: project.finishContinuousEdit
            )

            if let suffix {
                Text(suffix)
                    .font(InspectorTheme.bodyFont)
                    .foregroundStyle(InspectorTheme.textMuted)
            }
        }
        .padding(.horizontal, InspectorTheme.space3)
        .frame(height: InspectorTheme.controlHeight)
        .background(InspectorTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
        .overlay(InspectorRoundedBorder())
    }
}

private struct InspectorPickerRow<Value: Hashable, Values: RandomAccessCollection>: View where Values.Element == Value {
    var label: String
    @Binding var selection: Value
    var values: Values
    var title: (Value) -> String

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
            Spacer()
            Picker(label, selection: $selection) {
                ForEach(Array(values), id: \.self) { value in
                    Text(title(value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 170)
        }
        .frame(minHeight: InspectorTheme.controlHeight)
    }
}

private struct InspectorSliderRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var display: String

    var body: some View {
        HStack(spacing: InspectorTheme.space3) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
                .frame(width: 86, alignment: .leading)
            Slider(
                value: $value,
                in: range,
                onEditingChanged: { editing in
                    if !editing {
                        project.finishContinuousEdit()
                    }
                }
            )
            Text(display)
                .font(InspectorTheme.numericFont)
                .foregroundStyle(InspectorTheme.textSecondary)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(minHeight: InspectorTheme.controlHeight)
    }
}

private struct ColorSwatchRow: View {
    var label: String
    var presets: [(name: String, color: OverlayColor)]
    var selectedColor: OverlayColor
    var action: (OverlayColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.space2) {
            Text(label)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: InspectorTheme.space2), count: 8), spacing: InspectorTheme.space2) {
                ForEach(presets, id: \.name) { preset in
                    ColorSwatchButton(
                        name: preset.name,
                        color: preset.color,
                        isSelected: preset.color == selectedColor
                    ) {
                        action(preset.color)
                    }
                }
            }
        }
    }

}

private struct ColorSwatchButton: View {
    var name: String
    var color: OverlayColor
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.isRouteMapEndCheckerboard ? Color.clear : Color(color))
                .frame(width: 22, height: 22)
                .overlay {
                    if color.isRouteMapEndCheckerboard {
                        RouteMapCheckerboardSwatch(cornerRadius: 11)
                            .clipShape(Circle())
                    }
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? InspectorTheme.accentBlue : InspectorTheme.borderStrong, lineWidth: isSelected ? 3 : 1)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(color == .white || color == .yellow ? Color.black : Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

private struct InspectorIconButton: View {
    var systemImage: String
    var help: String
    var role: ButtonRole?
    var isEnabled = true
    var compact = false
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(
                    width: compact ? InspectorTheme.compactIconButtonSize : InspectorTheme.iconButtonSize,
                    height: compact ? InspectorTheme.compactIconButtonSize : InspectorTheme.iconButtonSize
                )
                .background(InspectorTheme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
                .overlay(InspectorRoundedBorder())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private var foreground: Color {
        if !isEnabled {
            return InspectorTheme.textMuted.opacity(0.45)
        }
        return role == .destructive ? InspectorTheme.dangerRed : InspectorTheme.textPrimary
    }
}

private struct InspectorRoundedBorder: View {
    var cornerRadius = InspectorTheme.controlRadius
    var color = InspectorTheme.borderSubtle

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color, lineWidth: 1)
    }
}

private struct InspectorTileButtonStyle: ButtonStyle {
    var isAccent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? InspectorTheme.controlBackgroundPressed : (isAccent ? InspectorTheme.accentBlueSoft.opacity(0.55) : InspectorTheme.controlBackground))
            .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
            .overlay(InspectorRoundedBorder(color: isAccent ? InspectorTheme.borderStrong : InspectorTheme.borderSubtle))
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct InspectorRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? InspectorTheme.controlBackgroundPressed : InspectorTheme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
            .overlay(InspectorRoundedBorder())
    }
}

private struct InspectorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InspectorTheme.bodyStrongFont)
            .foregroundStyle(Color.white)
            .padding(.horizontal, InspectorTheme.space3)
            .frame(height: InspectorTheme.controlHeight)
            .background(configuration.isPressed ? InspectorTheme.accentBlue.opacity(0.72) : InspectorTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
    }
}

private enum InspectorTheme {
    static let panelBackground = EditorTheme.panelBackground
    static let panelBackgroundElevated = EditorTheme.panelHeader
    static let controlBackground = EditorTheme.surfaceControl
    static let controlBackgroundPressed = EditorTheme.surfacePressed
    static let borderSubtle = EditorTheme.borderSubtle
    static let borderStrong = EditorTheme.borderStrong
    static let textPrimary = EditorTheme.textPrimary
    static let textSecondary = EditorTheme.textSecondary
    static let textMuted = EditorTheme.textMuted
    static let accentBlue = EditorTheme.accentBlue
    static let accentBlueSoft = EditorTheme.accentBlueSoft
    static let dangerRed = EditorTheme.dangerRed

    static let space1 = EditorTheme.space1
    static let space2 = EditorTheme.space2
    static let space3 = EditorTheme.space3
    static let panelPaddingX: CGFloat = 18
    static let panelPaddingY: CGFloat = 16
    static let outerPanelPaddingX: CGFloat = 14
    static let outerPanelPaddingY: CGFloat = 14
    static let sectionGap: CGFloat = 18
    static let controlHeight: CGFloat = 34
    static let rowHeight: CGFloat = 56
    static let iconButtonSize = EditorTheme.iconButtonSize
    static let compactIconButtonSize: CGFloat = 26
    static let tileMinHeight: CGFloat = 56
    static let segmentedControlHeight: CGFloat = 24
    static let outerTilePaddingX: CGFloat = 10
    static let outerRowPaddingX: CGFloat = 10
    static let controlRadius = EditorTheme.controlRadius

    static let titleFont = EditorTheme.panelTitleFont
    static let sectionTitleFont = EditorTheme.sectionTitleFont
    static let bodyFont = EditorTheme.bodyFont
    static let bodyStrongFont = EditorTheme.bodyStrongFont
    static let captionFont = EditorTheme.captionFont
    static let numericFont = EditorTheme.numericFont
}

private extension OverlayElement {
    var subtitle: String {
        let components = OverlayValueFormatter.components(for: type, activity: .empty, elapsedTime: 0)
        return "\(components.label) • \(type.kindLabel)"
    }
}

private extension OverlayElementType {
    var inspectorIcon: String {
        OverlayTileInfo.all.first { $0.type == self }?.systemImage ?? "square.stack.3d.up"
    }

    var kindLabel: String {
        switch self {
        case .distanceTimeline, .elevationChart:
            "Chart"
        case .runningGauge:
            "Gauge"
        case .routeMap:
            "Map"
        default:
            "Text"
        }
    }

    var isFeaturedOverlay: Bool {
        self == .runningGauge || self == .routeMap
    }
}

private extension OverlayFontWeight {
    var shortLabel: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        }
    }
}

private extension OverlayTextPreset {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayGaugePreset {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapPreset {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapContainerPreset {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapShape {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapEdgeFade {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapColorMode {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapMarkerStyle {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapBackgroundStyle {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

extension OverlayRouteMapLegendMode {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension Color {
    init(_ overlayColor: OverlayColor) {
        self.init(
            red: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            opacity: overlayColor.alpha
        )
    }
}

private extension Double {
    func quantized(to step: Double) -> Double {
        guard step > 0 else {
            return self
        }
        return (self / step).rounded() * step
    }
}
