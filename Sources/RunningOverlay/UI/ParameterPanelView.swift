import SwiftUI

struct ParameterPanelView: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        Group {
            switch project.selection {
            case .timelineClip(let clipID):
                InspectorPanel {
                    InspectorHeader(
                        title: "Inspector",
                        status: "Clip",
                        trailingSystemImage: "slider.horizontal.3"
                    )
                } content: {
                    ClipInspectorView(clipID: clipID)
                        .padding(.horizontal, InspectorTheme.panelPaddingX)
                        .padding(.vertical, InspectorTheme.panelPaddingY)
                }
            case .overlayElement(let elementID):
                if let element = project.selectedOverlay(elementID) {
                    if element.type.isNumericOverlay {
                        NumericOverlayDetailView(elementID: elementID)
                    } else if element.type == .runningGauge {
                        RunningGaugeOverlayDetailView(elementID: elementID)
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

                    InspectorNumberRow(
                        label: "Start",
                        value: startBinding,
                        precision: 2,
                        suffix: "s",
                        reset: resetStart
                    )

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

private struct InspectorOuterView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var activeCategory: OverlayCategory = .metrics

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(
                title: "Inspector",
                status: overlayCountLabel,
                trailingSystemImage: "slider.horizontal.3"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: InspectorTheme.sectionGap) {
                    addOverlaySection
                    AddedElementsSection()
                }
                .padding(.horizontal, InspectorTheme.panelPaddingX)
                .padding(.vertical, InspectorTheme.panelPaddingY)
            }

            InspectorFooterHint(text: "Click an overlay to edit its style and position")
        }
    }

    private var addOverlaySection: some View {
        InspectorSection(title: "Add Overlay", subtitle: "Choose a data layer to place on the preview") {
            InspectorSegmentedControl(selection: $activeCategory, values: OverlayCategory.allCases) { category in
                Text(category.label)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: InspectorTheme.space2), GridItem(.flexible(), spacing: InspectorTheme.space2)], spacing: InspectorTheme.space2) {
                ForEach(OverlayTileInfo.tiles(for: activeCategory)) { tile in
                    OverlayAddTile(tile: tile) {
                        project.addOverlayElement(tile.type)
                    }
                }
            }
        }
    }

    private var overlayCountLabel: String {
        let count = project.overlayLayout.elements.count
        return count == 1 ? "1 overlay" : "\(count) overlays"
    }
}

private struct AddedElementsSection: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        InspectorSection(title: "Added Elements", subtitle: "Manage overlays in your scene") {
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
                project.selectOverlay(element.id)
            } label: {
                rowBody
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 28)
                .overlay(InspectorTheme.borderSubtle)

            InspectorIconButton(systemImage: "eye", help: "Visibility unavailable", isEnabled: false) {}
            InspectorIconButton(systemImage: "lock", help: "Lock unavailable", isEnabled: false) {}
            InspectorIconButton(systemImage: "trash", help: "Delete", role: .destructive) {
                project.deleteOverlay(element.id)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(InspectorTheme.textMuted)
        }
        .padding(.horizontal, InspectorTheme.space3)
        .frame(minHeight: InspectorTheme.rowHeight)
        .background(InspectorTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
        .overlay(InspectorRoundedBorder())
    }

    private var rowBody: some View {
        HStack(spacing: InspectorTheme.space3) {
            Image(systemName: element.type.inspectorIcon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(element.type.isFeaturedOverlay ? InspectorTheme.accentBlue : InspectorTheme.textPrimary)
                .frame(width: 30)

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
                InspectorSegmentedControl(selection: routeMapColorModeBinding, values: OverlayRouteMapColorMode.allCases) { colorMode in
                    Text(colorMode.compactLabel)
                }
                InspectorSegmentedControl(selection: routeMapShapeBinding, values: OverlayRouteMapShape.allCases) { shape in
                    Text(shape.compactLabel)
                }
                InspectorSegmentedControl(selection: routeMapEdgeFadeBinding, values: OverlayRouteMapEdgeFade.allCases) { edgeFade in
                    Text(edgeFade.compactLabel)
                }
                InspectorSegmentedControl(selection: routeMapMarkerStyleBinding, values: OverlayRouteMapMarkerStyle.allCases) { markerStyle in
                    Text(markerStyle.compactLabel)
                }
                InspectorPickerRow(label: "Start Marker", selection: routeMapStartMarkerStyleBinding, values: OverlayRouteMapMarkerStyle.allCases) { $0.compactLabel }
                InspectorPickerRow(label: "End Marker", selection: routeMapEndMarkerStyleBinding, values: OverlayRouteMapMarkerStyle.allCases) { $0.compactLabel }
                Toggle(isOn: routeMapLegendVisibleBinding) {
                    Text("Legend")
                        .font(InspectorTheme.bodyFont)
                        .foregroundStyle(InspectorTheme.textSecondary)
                }
                .toggleStyle(.switch)
                if element.style.routeMapLegendVisible {
                    InspectorPickerRow(label: "Legend Style", selection: routeMapLegendModeBinding, values: OverlayRouteMapLegendMode.allCases) { $0.compactLabel }
                }
                if element.style.routeMapEdgeFade == .fadeOut {
                    InspectorSliderRow(
                        label: "Fade Amount",
                        value: routeMapFadeAmountBinding,
                        range: 0.05...0.45,
                        display: String(format: "%.0f%%", element.style.routeMapFadeAmount * 100)
                    )
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
            }

            InspectorPickerRow(label: "Font", selection: fontNameBinding, values: fontPresets) { $0 }

            InspectorSliderRow(
                label: "Font Size",
                value: fontSizeBinding,
                range: 12...96,
                display: "\(Int(element.style.fontSize.rounded()))"
            )

            InspectorSegmentedControl(selection: fontWeightBinding, values: OverlayFontWeight.allCases) { weight in
                Text(weight.shortLabel)
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

    private let fontPresets = [
        "SF Pro",
        "Avenir Next",
        "Helvetica Neue",
        "Menlo"
    ]

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

    private var routeMapColorModeBinding: Binding<OverlayRouteMapColorMode> {
        Binding {
            element?.style.routeMapColorMode ?? .solid
        } set: { newValue in
            project.setOverlayRouteMapColorMode(elementID, colorMode: newValue)
        }
    }

    private var routeMapEdgeFadeBinding: Binding<OverlayRouteMapEdgeFade> {
        Binding {
            element?.style.routeMapEdgeFade ?? .solid
        } set: { newValue in
            project.setOverlayRouteMapEdgeFade(elementID, edgeFade: newValue)
        }
    }

    private var routeMapFadeAmountBinding: Binding<Double> {
        Binding {
            element?.style.routeMapFadeAmount ?? 0.22
        } set: { newValue in
            project.setOverlayRouteMapFadeAmount(elementID, amount: newValue.quantized(to: 0.01))
        }
    }

    private var routeMapMarkerStyleBinding: Binding<OverlayRouteMapMarkerStyle> {
        Binding {
            element?.style.routeMapMarkerStyle ?? .dot
        } set: { newValue in
            project.setOverlayRouteMapMarkerStyle(elementID, markerStyle: newValue)
        }
    }

    private var routeMapStartMarkerStyleBinding: Binding<OverlayRouteMapMarkerStyle> {
        Binding {
            element?.style.routeMapStartMarkerStyle ?? .dot
        } set: { newValue in
            project.setOverlayRouteMapStartMarkerStyle(elementID, markerStyle: newValue)
        }
    }

    private var routeMapEndMarkerStyleBinding: Binding<OverlayRouteMapMarkerStyle> {
        Binding {
            element?.style.routeMapEndMarkerStyle ?? .dot
        } set: { newValue in
            project.setOverlayRouteMapEndMarkerStyle(elementID, markerStyle: newValue)
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
            element?.style.fontName ?? "SF Pro"
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

private struct InspectorSegmentedControl<Value: Hashable & Identifiable, Label: View>: View {
    @Binding var selection: Value
    var values: [Value]
    @ViewBuilder var label: (Value) -> Label

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values) { value in
                Button {
                    selection = value
                } label: {
                    label(value)
                        .font(InspectorTheme.bodyStrongFont)
                        .foregroundStyle(selection == value ? InspectorTheme.accentBlue : InspectorTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: InspectorTheme.controlHeight)
                        .background(selection == value ? InspectorTheme.accentBlueSoft : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

                if value.id != values.last?.id {
                    Divider()
                        .overlay(InspectorTheme.borderSubtle)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.controlRadius))
        .overlay(InspectorRoundedBorder())
    }
}

private struct OverlayAddTile: View {
    let tile: OverlayTileInfo
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorTheme.space3) {
                Image(systemName: tile.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tile.isAccent ? InspectorTheme.accentBlue : InspectorTheme.textPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.label)
                        .font(InspectorTheme.bodyStrongFont)
                        .foregroundStyle(tile.isAccent ? InspectorTheme.accentBlue : InspectorTheme.textPrimary)
                        .lineLimit(1)
                    Text(tile.hint)
                        .font(InspectorTheme.captionFont)
                        .foregroundStyle(InspectorTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: InspectorTheme.space1)

                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(InspectorTheme.textPrimary)
            }
            .padding(.horizontal, InspectorTheme.space3)
            .frame(minHeight: InspectorTheme.tileMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(InspectorTileButtonStyle(isAccent: tile.isAccent))
        .help("Add \(tile.label)")
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

            TextField(label, value: $value, format: .number.precision(.fractionLength(precision)))
                .textFieldStyle(.plain)
                .font(InspectorTheme.numericFont)
                .foregroundStyle(InspectorTheme.textPrimary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    project.finishContinuousEdit()
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }

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
                .fill(Color(color))
                .frame(width: 22, height: 22)
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
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: InspectorTheme.iconButtonSize, height: InspectorTheme.iconButtonSize)
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

private struct InspectorFooterHint: View {
    var text: String

    var body: some View {
        HStack(spacing: InspectorTheme.space2) {
            Image(systemName: "info.circle")
            Text(text)
        }
        .font(InspectorTheme.captionFont)
        .foregroundStyle(InspectorTheme.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, InspectorTheme.space3)
        .background(InspectorTheme.panelBackgroundElevated)
        .overlay(alignment: .top) {
            Divider()
                .overlay(InspectorTheme.borderSubtle)
        }
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
    static let sectionGap: CGFloat = 22
    static let controlHeight: CGFloat = 34
    static let rowHeight = EditorTheme.compactRowHeight
    static let iconButtonSize = EditorTheme.iconButtonSize
    static let tileMinHeight: CGFloat = 68
    static let controlRadius = EditorTheme.controlRadius

    static let titleFont = EditorTheme.panelTitleFont
    static let sectionTitleFont = EditorTheme.sectionTitleFont
    static let bodyFont = EditorTheme.bodyFont
    static let bodyStrongFont = EditorTheme.bodyStrongFont
    static let captionFont = EditorTheme.captionFont
    static let numericFont = EditorTheme.numericFont
}

private enum OverlayCategory: String, CaseIterable, Identifiable {
    case metrics
    case charts
    case route

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metrics: "Metrics"
        case .charts: "Charts"
        case .route: "Route"
        }
    }
}

private struct OverlayTileInfo: Identifiable {
    var type: OverlayElementType
    var hint: String
    var systemImage: String
    var category: OverlayCategory
    var isAccent = false

    var id: OverlayElementType { type }
    var label: String { type.label }

    static let all: [OverlayTileInfo] = [
        OverlayTileInfo(type: .heartRate, hint: "bpm", systemImage: "heart", category: .metrics),
        OverlayTileInfo(type: .pace, hint: "min/km", systemImage: "timer", category: .metrics),
        OverlayTileInfo(type: .calories, hint: "kcal", systemImage: "flame", category: .metrics),
        OverlayTileInfo(type: .elapsedTime, hint: "duration", systemImage: "clock", category: .metrics),
        OverlayTileInfo(type: .realTime, hint: "clock time", systemImage: "watch.analog", category: .metrics),
        OverlayTileInfo(type: .distance, hint: "km / mi", systemImage: "ruler", category: .metrics),
        OverlayTileInfo(type: .distanceTimeline, hint: "progress", systemImage: "waveform.path.ecg", category: .charts),
        OverlayTileInfo(type: .elevation, hint: "altitude", systemImage: "mountain.2", category: .metrics),
        OverlayTileInfo(type: .elevationChart, hint: "profile", systemImage: "chart.line.uptrend.xyaxis", category: .charts),
        OverlayTileInfo(type: .cadence, hint: "spm", systemImage: "figure.run", category: .metrics),
        OverlayTileInfo(type: .power, hint: "watts", systemImage: "bolt", category: .metrics),
        OverlayTileInfo(type: .runningGauge, hint: "live gauge", systemImage: "gauge", category: .charts, isAccent: true),
        OverlayTileInfo(type: .routeMap, hint: "GPS path", systemImage: "map", category: .route, isAccent: true)
    ]

    static func tiles(for category: OverlayCategory) -> [OverlayTileInfo] {
        all.filter { $0.category == category }
    }
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

private extension OverlayRouteMapPreset {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapShape {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapEdgeFade {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapColorMode {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapMarkerStyle {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapBackgroundStyle {
    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }
}

private extension OverlayRouteMapLegendMode {
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
