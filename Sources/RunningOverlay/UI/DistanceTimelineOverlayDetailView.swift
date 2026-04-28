import SwiftUI

struct DistanceTimelineOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<DistanceTimelineSection> = [.preset, .content, .layout, .progress]

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        sectionView(.preset) { presetSection(element) }
                        sectionView(.content) { contentSection(element) }
                        sectionView(.layout) { layoutSection(element) }
                        sectionView(.progress) { progressSection(element) }
                        if element.style.distanceTimeline.preset.supportsMediaSlot {
                            sectionView(.mediaSlot) { mediaSlotSection(element) }
                        }
                        if element.style.distanceTimeline.preset.supportsElevation {
                            sectionView(.routeElevation) { routeElevationSection(element) }
                        }
                        sectionView(.backgroundBorder) { backgroundBorderSection(element) }
                        sectionView(.typography) { typographySection(element) }
                        sectionView(.effects) { effectsSection(element) }
                    }
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

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumericTokens.accentBlue)
                .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text(element.style.distanceTimeline.preset.compactLabel)
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
        .overlay(alignment: .bottom) { Divider().overlay(NumericTokens.borderSubtle) }
    }

    @ViewBuilder
    private func presetSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Preset") {
            Menu {
                ForEach(DistanceTimelinePreset.allCases) { preset in
                    Button {
                        project.setOverlayDistanceTimelinePreset(elementID, preset: preset)
                    } label: {
                        if style.preset == preset {
                            Label(preset.compactLabel, systemImage: "checkmark")
                        } else {
                            Text(preset.compactLabel)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: style.preset.compactLabel)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
    }

    @ViewBuilder
    private func contentSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Show Label") {
            toggle(style.showLabel) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showLabel = newValue }
            }
        }
        InspectorDenseRow(label: "Label") {
            TextField("Distance", text: Binding(
                get: { style.label },
                set: { value in project.mutateDistanceTimelineStyle(elementID) { $0.label = value } }
            ), onCommit: { project.finishContinuousEdit() })
            .textFieldStyle(.plain)
            .font(NumericTokens.bodyFont)
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
        }
        InspectorDenseRow(label: "Percent") {
            toggle(style.showPercent) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showPercent = newValue }
            }
        }
        InspectorDenseRow(label: "Start / Finish") {
            toggle(style.showStartFinishLabels) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.showStartFinishLabels = newValue }
            }
        }
    }

    @ViewBuilder
    private func layoutSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Anchor") {
            InspectorAnchorGrid(position: element.position) { anchor in
                project.setOverlayPosition(elementID, position: anchor)
                project.finishContinuousEdit()
            }
        }
        InspectorDenseRow(label: "Position") {
            HStack(spacing: NumericTokens.space2) {
                InspectorDenseAxisField(axis: "X", value: Binding(
                    get: { Double(element.position.x) },
                    set: {
                        project.setOverlayPosition(elementID, position: CGPoint(x: $0, y: element.position.y))
                        project.finishContinuousEdit()
                    }
                ), precision: 3)
                InspectorDenseAxisField(axis: "Y", value: Binding(
                    get: { Double(element.position.y) },
                    set: {
                        project.setOverlayPosition(elementID, position: CGPoint(x: element.position.x, y: $0))
                        project.finishContinuousEdit()
                    }
                ), precision: 3)
            }
        }
        InspectorDenseSliderRow(label: "Scale", value: Binding(
            get: { element.scale },
            set: { project.setOverlayScale(elementID, scale: $0.distanceTimelineQuantized(to: 0.05)) }
        ), range: 0.25...4, displayText: String(format: "%.2fx", element.scale))
        InspectorDenseSliderRow(label: "Width", value: distanceBinding(\.width, of: style), range: 180...640, displayText: "\(Int(style.width))")
        InspectorDenseSliderRow(label: "Height", value: distanceBinding(\.height, of: style), range: 52...150, displayText: "\(Int(style.height))")
        InspectorDenseRow(label: "Padding") {
            InspectorDenseAxisField(axis: "X", value: distanceBinding(\.paddingX, of: style), precision: 0)
            InspectorDenseAxisField(axis: "Y", value: distanceBinding(\.paddingY, of: style), precision: 0)
        }
    }

    @ViewBuilder
    private func progressSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Fill Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.fillColor) { color in
                project.mutateDistanceTimelineStyle(elementID) { $0.fillColor = color }
            }
        }
        InspectorDenseSliderRow(label: "Track Height", value: distanceBinding(\.trackHeight, of: style), range: 2...18, displayText: "\(Int(style.trackHeight))")
        InspectorDenseSliderRow(label: "Track Opacity", value: distanceBinding(\.trackOpacity, of: style), range: 0...1, displayText: String(format: "%.0f%%", style.trackOpacity * 100))
        InspectorDenseRow(label: "Ticks") {
            toggle(style.tickMarksEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.tickMarksEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "Marker") {
            toggle(style.currentMarkerEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.currentMarkerEnabled = newValue }
            }
        }
    }

    @ViewBuilder
    private func mediaSlotSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Enabled") {
            toggle(style.mediaSlotEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlotEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "Source") {
            Menu {
                ForEach(DistanceTimelineMediaSlotMode.allCases) { mode in
                    Button {
                        if mode.isImplemented {
                            project.mutateDistanceTimelineStyle(elementID) {
                                $0.mediaSlotMode = mode
                                $0.mediaSlot.mode = mode
                            }
                        }
                    } label: {
                        Text(mode.isImplemented ? mode.label : "\(mode.label) (future)")
                    }
                    .disabled(!mode.isImplemented)
                }
            } label: {
                InspectorDenseMenuLabel(title: style.mediaSlotMode.label)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        if style.mediaSlotMode == .staticSVG || style.mediaSlotMode == .animatedSVG {
            InspectorDenseRow(label: "Asset") {
                Button {
                    project.importDistanceTimelineIconAsset(elementID)
                } label: {
                    Label(style.mediaSlot.assetName.isEmpty ? "Import SVG" : style.mediaSlot.assetName, systemImage: "square.and.arrow.down")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                .frame(height: NumericTokens.controlHeight)
            }
        }
        InspectorDenseRow(label: "Tint") {
            InspectorDenseSegmented(values: OverlayIconTintMode.allCases, selection: Binding(
                get: { style.mediaSlot.tintMode },
                set: { mode in project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.tintMode = mode } }
            )) { mode in
                Text(mode.label)
            }
        }
        if style.mediaSlotMode == .animatedSVG {
            InspectorDenseSliderRow(
                label: "Anim Speed",
                value: Binding(
                    get: { style.mediaSlot.animationSpeed },
                    set: { newValue in project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.animationSpeed = newValue } }
                ),
                range: 0.1...4,
                displayText: String(format: "%.1fx", style.mediaSlot.animationSpeed)
            )
            InspectorDenseRow(label: "Loop") {
                toggle(style.mediaSlot.loop) { newValue in
                    project.mutateDistanceTimelineStyle(elementID) { $0.mediaSlot.loop = newValue }
                }
            }
        }
        InspectorDenseSliderRow(label: "Slot Size", value: distanceBinding(\.mediaSlotSize, of: style), range: 18...64, displayText: "\(Int(style.mediaSlotSize))")
    }

    @ViewBuilder
    private func routeElevationSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Elevation") {
            toggle(style.elevationProfileVisible) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.elevationProfileVisible = newValue }
            }
        }
    }

    @ViewBuilder
    private func backgroundBorderSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Background") {
            toggle(style.backgroundEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.backgroundEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "BG Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: style.backgroundColor) { color in
                project.mutateDistanceTimelineStyle(elementID) { $0.backgroundColor = color }
            }
        }
        InspectorDenseSliderRow(label: "BG Opacity", value: distanceBinding(\.backgroundOpacity, of: style), range: 0...1, displayText: String(format: "%.0f%%", style.backgroundOpacity * 100))
        InspectorDenseSliderRow(label: "Radius", value: distanceBinding(\.cornerRadius, of: style), range: 0...32, displayText: "\(Int(style.cornerRadius))")
        InspectorDenseRow(label: "Border") {
            toggle(style.borderEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.borderEnabled = newValue }
            }
        }
        InspectorDenseSliderRow(label: "Border Width", value: distanceBinding(\.borderWidth, of: style), range: 0.5...6, displayText: String(format: "%.1f", style.borderWidth), isEnabled: style.borderEnabled)
        InspectorDenseSliderRow(label: "Border Opacity", value: distanceBinding(\.borderOpacity, of: style), range: 0...1, displayText: String(format: "%.0f%%", style.borderOpacity * 100), isEnabled: style.borderEnabled)
    }

    @ViewBuilder
    private func typographySection(_ element: OverlayElement) -> some View {
        InspectorDenseRow(label: "Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        project.setOverlayFontName(elementID, fontName: name)
                    } label: {
                        Text(name)
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: element.style.fontName)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        InspectorDenseSliderRow(label: "Value Size", value: Binding(
            get: { element.style.fontSize },
            set: { project.setOverlayFontSize(elementID, fontSize: $0.rounded()) }
        ), range: 12...72, displayText: "\(Int(element.style.fontSize))")
        InspectorDenseRow(label: "Weight") {
            InspectorDenseSegmented(values: OverlayFontWeight.allCases, selection: Binding(
                get: { element.style.fontWeight },
                set: { project.setOverlayFontWeight(elementID, fontWeight: $0) }
            )) { weight in
                Text(weight.label)
            }
        }
        InspectorDenseRow(label: "Text Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: element.style.foregroundColor) { color in
                project.setOverlayForegroundColor(elementID, color: color)
            }
        }
    }

    @ViewBuilder
    private func effectsSection(_ element: OverlayElement) -> some View {
        let style = element.style.distanceTimeline
        InspectorDenseRow(label: "Glow") {
            toggle(style.glowEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.glowEnabled = newValue }
            }
        }
        InspectorDenseRow(label: "Fade Out") {
            toggle(style.fadeEnabled) { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0.fadeEnabled = newValue }
            }
        }
        InspectorDenseSliderRow(label: "Fade Amount", value: distanceBinding(\.fadeAmount, of: style), range: 0...0.6, displayText: String(format: "%.0f%%", style.fadeAmount * 100), isEnabled: style.fadeEnabled)
    }

    private func toggle(_ isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { newValue in action(newValue) }))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
    }

    private func distanceBinding(_ keyPath: WritableKeyPath<DistanceTimelineStyle, Double>, of style: DistanceTimelineStyle) -> Binding<Double> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { newValue in
                project.mutateDistanceTimelineStyle(elementID) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    @ViewBuilder
    private func sectionView<Body: View>(_ section: DistanceTimelineSection, @ViewBuilder content: () -> Body) -> some View {
        let isOpen = openSections.contains(section)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumericTokens.textMuted)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .contentShape(Rectangle())
            .onTapGesture {
                if isOpen {
                    openSections.remove(section)
                } else {
                    openSections.insert(section)
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }

            if isOpen {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.mutateDistanceTimelineStyle(elementID) { $0 = .default } },
            onTrailingTap: { project.selection = .none }
        )
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.space3)
        .background(NumericTokens.panelBackgroundElevated)
    }
}

private enum DistanceTimelineSection: String, CaseIterable {
    case preset
    case content
    case layout
    case progress
    case mediaSlot
    case routeElevation
    case backgroundBorder
    case typography
    case effects

    var title: String {
        switch self {
        case .preset: "Preset"
        case .content: "Content"
        case .layout: "Layout"
        case .progress: "Progress"
        case .mediaSlot: "Media Slot"
        case .routeElevation: "Route / Elevation"
        case .backgroundBorder: "Background & Border"
        case .typography: "Typography"
        case .effects: "Effects"
        }
    }

    var systemImage: String {
        switch self {
        case .preset: "slider.horizontal.3"
        case .content: "text.alignleft"
        case .layout: "scope"
        case .progress: "chart.bar.fill"
        case .mediaSlot: "photo"
        case .routeElevation: "point.topleft.down.curvedto.point.bottomright.up"
        case .backgroundBorder: "rectangle"
        case .typography: "textformat"
        case .effects: "sparkles"
        }
    }
}

private extension Double {
    func distanceTimelineQuantized(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
