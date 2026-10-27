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
                    } else if element.type == .intervalCountdown {
                        IntervalCountdownOverlayDetailView(elementID: elementID)
                    } else if element.type == .intervalWorkSummary {
                        IntervalWorkSummaryOverlayDetailView(elementID: elementID)
                    } else if element.type == .zoneEdgeBar {
                        ZoneEdgeBarOverlayDetailView(elementID: elementID)
                    } else if element.type == .routeMap {
                        RouteMapOverlayDetailView(elementID: elementID)
                    } else if element.type == .weatherWidget {
                        WeatherWidgetOverlayDetailView(elementID: elementID)
                    } else if element.type.isDecorOverlay {
                        DecorOverlayDetailView(elementID: elementID)
                    } else {
                        MissingOverlayInspectorView()
                    }
                } else {
                    MissingOverlayInspectorView()
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

private struct MissingOverlayInspectorView: View {
    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(title: "Inspector", status: "Missing", trailingSystemImage: "slider.horizontal.3")
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
                .foregroundStyle(InspectorTheme.textPrimary)
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
    static let outerPanelPaddingX: CGFloat = 14
    static let outerPanelPaddingY: CGFloat = 14
    static let sectionGap: CGFloat = 18
    static let controlHeight: CGFloat = 34
    static let rowHeight: CGFloat = 56
    static let iconButtonSize = EditorTheme.iconButtonSize
    static let compactIconButtonSize: CGFloat = 26
    static let tileMinHeight: CGFloat = 56
    static let outerTilePaddingX: CGFloat = 10
    static let outerRowPaddingX: CGFloat = 10
    static let controlRadius = EditorTheme.controlRadius

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
