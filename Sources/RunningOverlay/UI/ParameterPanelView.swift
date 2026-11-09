import SwiftUI

struct ParameterPanelView: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        Group {
            switch project.selection {
            case .timelineClip(let clipID):
                ClipDetailView(clipID: clipID)
            case .timelineClips:
                InspectorOuterView()
            case .overlayElement(let elementID):
                VStack(spacing: 0) {
                    if let element = project.selectedOverlay(elementID) {
                        OverlayDetailHeader(element: element)
                    }
                    overlayDetail(elementID)
                        .inspectorRevealsExpandedSections()
                }
            case .none:
                InspectorOuterView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(InspectorTheme.panelBackground)
        .foregroundStyle(InspectorTheme.textPrimary)
    }

    @ViewBuilder
    private func overlayDetail(_ elementID: OverlayElement.ID) -> some View {
        if let element = project.selectedOverlay(elementID) {
            if element.type == .distanceTimeline {
                DistanceTimelineOverlayDetailView(elementID: elementID)
            } else if element.type == .elevationChart {
                ElevationChartOverlayDetailView(elementID: elementID)
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
            } else if element.type == .component {
                OverlayComponentDetailView(elementID: elementID)
            } else {
                MissingOverlayInspectorView()
            }
        } else {
            MissingOverlayInspectorView()
        }
    }
}

/// "3 of 6" beside the overlay pop-up, so the list position stays visible
/// while the pop-up shows only the overlay name.
enum OverlaySwitcherTitle {
    static func position(index: Int, count: Int) -> String {
        "\(index + 1) of \(count)"
    }
}

/// Header for every overlay detail panel. The Inspector follows the editor
/// selection, so there is no Back or Done: clicking empty canvas or pressing
/// Escape returns to the overlay list. The pop-up switches overlays, the
/// arrows step through unlocked overlays, and the action menu holds Reset
/// Style plus the same commands as the overlay's context menu.
private struct OverlayDetailHeader: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement

    var body: some View {
        let elements = project.overlayLayout.elements
        let currentIndex = elements.firstIndex { $0.id == element.id }
        let canStep = elements.filter { !$0.isLocked }.count > 1

        HStack(spacing: 4) {
            Picker("Overlay", selection: Binding(
                get: { element.id },
                set: { project.openOverlayDetailFromList($0) }
            )) {
                ForEach(elements) { item in
                    Label(item.displayLabel, systemImage: item.isLocked ? "lock.fill" : item.type.inspectorIcon)
                        .tag(item.id)
                        .disabled(item.isLocked && item.id != element.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("Switch Overlay")

            if let currentIndex {
                Text(OverlaySwitcherTitle.position(index: currentIndex, count: elements.count))
                    .font(NumericTokens.captionFont)
                    .monospacedDigit()
                    .foregroundStyle(NumericTokens.textMuted)
                    .lineLimit(1)
                    .padding(.leading, 2)
            }

            Spacer(minLength: NumericTokens.space2)

            InspectorIconButton(systemImage: "chevron.up", help: "Previous Overlay", isEnabled: canStep) {
                project.selectAdjacentOverlay(-1)
            }
            InspectorIconButton(systemImage: "chevron.down", help: "Next Overlay", isEnabled: canStep) {
                project.selectAdjacentOverlay(1)
            }

            Menu {
                Button("Reset Style") {
                    project.resetOverlayInspectorStyle(element.id)
                }
                Divider()
                OverlayElementContextMenu(element: element)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More Actions")
            .accessibilityLabel("More Actions")
        }
        .padding(.leading, NumericTokens.panelPaddingX - 4)
        .padding(.trailing, NumericTokens.panelPaddingX)
        .frame(height: NumericTokens.detailHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NumericTokens.borderSubtle)
                .frame(height: 1)
        }
    }
}

private struct MissingOverlayInspectorView: View {
    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(title: "Inspector", status: "Missing")
            Spacer()
        }
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
                InspectorHeader(title: "Inspector", status: "Missing")
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
        HStack(spacing: NumericTokens.space2) {
            Image(systemName: "video")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NumericTokens.textSecondary)
            Text(clip.title)
                .font(NumericTokens.bodyStrongFont)
                .foregroundStyle(NumericTokens.textPrimary)
                .lineLimit(1)
            Spacer()
            InspectorIconButton(systemImage: "trash", help: "Delete Clip") {
                project.deleteSelectedItem()
            }
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: NumericTokens.detailHeaderHeight)
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
            InspectorHeader(title: "Inspector", status: overlayCountLabel)

            if project.overlayLayout.elements.isEmpty {
                VStack(spacing: InspectorTheme.space2) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(InspectorTheme.textMuted)
                    Text("No Overlays")
                        .font(InspectorTheme.bodyStrongFont)
                        .foregroundStyle(InspectorTheme.textPrimary)
                    Text("Drag an overlay from the Overlay Pool onto the preview to add it.")
                        .font(InspectorTheme.captionFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(InspectorTheme.space3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AddedOverlaysList()
            }
        }
    }

    private var overlayCountLabel: String {
        let count = project.overlayLayout.elements.count
        return count == 1 ? "1 overlay" : "\(count) overlays"
    }
}

/// The overlay list is a standard selectable `List`: clicking a row (or
/// moving to it with the arrow keys) selects that overlay, and the Inspector
/// follows the selection into its detail panel. Row actions stay out of the
/// way until the pointer is over the row, except for the hidden and locked
/// indicators, which always show because they describe the overlay's state.
private struct AddedOverlaysList: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        List(selection: Binding<OverlayElement.ID?>(
            get: { nil },
            set: { elementID in
                if let elementID { project.openOverlayDetailFromList(elementID) }
            }
        )) {
            Section("Added Overlays") {
                ForEach(project.overlayLayout.elements) { element in
                    OverlayElementRow(element: element)
                        .tag(element.id)
                        .contextMenu {
                            OverlayElementContextMenu(element: element)
                        }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, InspectorTheme.listRowHeight)
    }
}

private struct OverlayElementRow: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: InspectorTheme.space2) {
            Image(systemName: element.type.inspectorIcon)
                .font(.system(size: 13))
                .foregroundStyle(InspectorTheme.textSecondary)
                .frame(width: 18)

            Text(element.displayLabel)
                .font(InspectorTheme.bodyFont)
                .foregroundStyle(InspectorTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: InspectorTheme.space2)

            Text(valuePreview)
                .font(InspectorTheme.captionFont)
                .monospacedDigit()
                .foregroundStyle(InspectorTheme.textSecondary)
                .lineLimit(1)

            // Both buttons always take part in layout and only fade in, so
            // hovering never resizes the row. The fixed height lets the 24 pt
            // hit targets overhang the text line instead of growing the row.
            HStack(spacing: 0) {
                InspectorIconButton(
                    systemImage: element.isVisible ? "eye" : "eye.slash",
                    help: element.isVisible ? "Hide Overlay" : "Show Overlay"
                ) {
                    project.setOverlayVisibility(element.id, isVisible: !element.isVisible)
                }
                .rowAccessory(isShown: isHovered || !element.isVisible)
                InspectorIconButton(
                    systemImage: element.isLocked ? "lock.fill" : "lock.open",
                    help: element.isLocked ? "Unlock Overlay" : "Lock Overlay"
                ) {
                    project.setOverlayLocked(element.id, isLocked: !element.isLocked)
                }
                .rowAccessory(isShown: isHovered || element.isLocked)
            }
            .frame(width: NumericTokens.iconButtonSize * 2, height: InspectorTheme.rowAccessoryHeight, alignment: .trailing)
        }
        .opacity(element.isVisible ? 1 : 0.55)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var valuePreview: String {
        OverlayValueFormatter.value(
            for: element.type,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime
        )
    }
}

private extension View {
    func rowAccessory(isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0).allowsHitTesting(isShown)
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

private struct InspectorHeader: View {
    var title: String
    var status: String

    var body: some View {
        EditorPanelHeader(title: title) {
            Text(status)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .lineLimit(1)
        }
    }
}

private struct InspectorIconButton: View {
    var systemImage: String
    var help: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(InspectorIconButtonStyle())
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
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
    static let controlBackground = EditorTheme.surfaceControl
    static let borderSubtle = EditorTheme.borderSubtle
    static let textPrimary = EditorTheme.textPrimary
    static let textSecondary = EditorTheme.textSecondary
    static let textMuted = EditorTheme.textMuted
    static let accentBlue = EditorTheme.accentBlue
    static let dangerRed = EditorTheme.dangerRed

    static let space1 = EditorTheme.space1
    static let space2 = EditorTheme.space2
    static let space3 = EditorTheme.space3
    static let controlHeight: CGFloat = 28
    static let listRowHeight: CGFloat = 28
    /// Layout height of the row eye/lock group; the buttons overhang it.
    static let rowAccessoryHeight: CGFloat = 18
    static let controlRadius = EditorTheme.controlRadius

    static let sectionTitleFont = EditorTheme.sectionTitleFont
    static let bodyFont = EditorTheme.bodyFont
    static let bodyStrongFont = EditorTheme.bodyStrongFont
    static let captionFont = EditorTheme.captionFont
    static let numericFont = EditorTheme.numericFont
}

extension OverlayElementType {
    /// The pool tile catalog is keyed by display name during the migration to
    /// declarative components; legacy native types reuse its icons.
    var inspectorIcon: String {
        OverlayTileInfo.all.first { $0.label == label }?.systemImage ?? "square.stack.3d.up"
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

private extension Double {
    func quantized(to step: Double) -> Double {
        guard step > 0 else {
            return self
        }
        return (self / step).rounded() * step
    }
}
