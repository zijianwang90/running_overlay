import SwiftUI

/// Inspector detail view for the three Decor element subtypes
/// (`decorSolidColor`, `decorIcon`, `decorText`). Solid Color (Phase B) and
/// Icon (Phase D) are implemented; Text remains a placeholder until Phase F.
struct DecorOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<DecorSection> = Set(DecorSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        switch element.type {
                        case .decorSolidColor:
                            solidColorBody(element: element)
                        case .decorIcon:
                            iconBody(element: element)
                        case .decorText:
                            textBody(element: element)
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: Solid Color (Phase B)

    @ViewBuilder
    private func solidColorBody(element: OverlayElement) -> some View {
        layoutInspectorSection(element)
        sectionView(.shape, element: element) { shapeSection(element) }
        sectionView(.fill, element: element) { fillSection(element) }
        OverlayBorderInspectorModule(elementID: elementID, element: element)
        OverlayEffectsInspectorModule(elementID: elementID, element: element)
    }

    @ViewBuilder
    private func shapeSection(_ element: OverlayElement) -> some View {
        let s = element.style.decor
        InspectorDenseRow(label: "Shape") {
            InspectorDenseSegmented(
                values: DecorShape.allCases,
                selection: Binding(
                    get: { s.shape },
                    set: { project.setDecorShape(elementID, shape: $0) }
                ),
                label: { shape in
                    Image(systemName: shape.systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
            )
        }
        if s.shape == .roundedRectangle {
            InspectorDenseSliderRow(
                label: "Corner Radius",
                value: Binding(
                    get: { s.cornerRadius },
                    set: { project.setDecorCornerRadius(elementID, radius: $0) }
                ),
                range: 0...256,
                displayText: "\(Int(s.cornerRadius.rounded()))"
            )
        }
    }

    @ViewBuilder
    private func fillSection(_ element: OverlayElement) -> some View {
        let s = element.style.decor
        InspectorDenseRow(label: "Fill") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: s.fillColor
            ) { color in
                project.setDecorFillColor(elementID, color: color)
            }
        }
    }

    // MARK: Icon (Phase D)

    @ViewBuilder
    private func iconBody(element: OverlayElement) -> some View {
        layoutInspectorSection(element)
        sectionView(.iconSource, element: element) { iconSourceSection(element) }
        sectionView(.iconTint, element: element) { iconTintSection(element) }
        OverlayBorderInspectorModule(elementID: elementID, element: element)
        OverlayEffectsInspectorModule(elementID: elementID, element: element)
    }

    @ViewBuilder
    private func iconSourceSection(_ element: OverlayElement) -> some View {
        let r = DecorIconResolved(from: element.style.decor)

        // Source type picker
        InspectorDenseRow(label: "Source") {
            InspectorDenseSegmented(
                values: IconSourceType.allCases,
                selection: Binding(
                    get: { iconSourceType(for: r.asset) },
                    set: { newSource in
                        switch newSource {
                        case .sfSymbol:
                            project.setDecorIconAsset(elementID, asset: .sfSymbol(name: "star.fill", weight: .medium, scale: .large))
                        case .bundledSVG:
                            project.setDecorIconAsset(elementID, asset: .bundledSVG(name: ""))
                        case .upload:
                        project.importUserAsset(kind: .svg, allowedContentTypes: [.svg])
                        if let lastAsset = project.userAssets.last {
                            project.setDecorIconAsset(elementID, asset: .userStaticSVG(assetID: lastAsset.id))
                        }
                    }
                }
                ),
                label: { source in
                    HStack(spacing: 4) {
                        Image(systemName: source.systemImage)
                            .font(.system(size: 10))
                        Text(source.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            )
        }

        switch r.asset {
        case .sfSymbol, .none:
            InspectorDenseRow(label: "Symbol") {
                SFSymbolPicker(
                    symbolName: Binding(
                        get: { r.asset.symbolName ?? "star.fill" },
                        set: { newName in
                            project.setDecorIconAsset(elementID, asset: .sfSymbol(
                                name: newName,
                                weight: r.asset.symbolWeight ?? .medium,
                                scale: r.asset.symbolScale ?? .large
                            ))
                        }
                    ),
                    placeholder: "star.fill",
                    defaultSymbolName: "star.fill",
                    onSubmit: { project.finishContinuousEdit() },
                    onDefault: {
                        project.setDecorIconAsset(elementID, asset: .sfSymbol(
                            name: "star.fill",
                            weight: r.asset.symbolWeight ?? .medium,
                            scale: r.asset.symbolScale ?? .large
                        ))
                        project.finishContinuousEdit()
                    }
                )
            }

            // Weight picker
            InspectorDenseRow(label: "Weight") {
                InspectorDenseSegmented(
                    values: SymbolWeight.allCases,
                    selection: Binding(
                        get: { r.asset.symbolWeight ?? .medium },
                        set: { newWeight in
                            project.setDecorIconAsset(elementID, asset: .sfSymbol(
                                name: r.asset.symbolName ?? "star.fill",
                                weight: newWeight,
                                scale: r.asset.symbolScale ?? .large
                            ))
                        }
                    ),
                    label: { weight in
                        Text(weight.label.prefix(1))
                            .font(.system(size: 10, weight: .medium))
                    }
                )
            }

            // Scale picker
            InspectorDenseRow(label: "Scale") {
                InspectorDenseSegmented(
                    values: SymbolScale.allCases,
                    selection: Binding(
                        get: { r.asset.symbolScale ?? .large },
                        set: { newScale in
                            project.setDecorIconAsset(elementID, asset: .sfSymbol(
                                name: r.asset.symbolName ?? "star.fill",
                                weight: r.asset.symbolWeight ?? .medium,
                                scale: newScale
                            ))
                        }
                    ),
                    label: { scale in Text(scale.label).font(.system(size: 10, weight: .medium)) }
                )
            }

        case .bundledSVG, .bundledImage:
            // Bundled SVG name display
            let name = r.asset.bundledSVGName ?? ""
            if name.isEmpty {
                InspectorDenseRow(label: "SVG") { Text("None selected — add .svg files to Resources/Icons/").font(NumericTokens.captionFont).foregroundStyle(NumericTokens.textSecondary) }
            } else {
                InspectorDenseRow(label: "SVG") { Text("\(name).svg").font(NumericTokens.captionFont).foregroundStyle(NumericTokens.textPrimary) }
            }

            // "Preserve SVG Colors" toggle
            InspectorDenseRow(label: "Preserve Colors") {
                Toggle("", isOn: Binding(
                    get: { r.preserveSVGColors },
                    set: { project.setDecorIconPreserveSVGColors(elementID, enabled: $0) }
                ))
                .toggleStyle(.switch)
            }

        case .userStaticSVG:
            InspectorDenseRow(label: "Asset") { Text("User upload — Phase E").font(NumericTokens.captionFont).foregroundStyle(NumericTokens.textSecondary) }
        }
    }

    @ViewBuilder
    private func iconTintSection(_ element: OverlayElement) -> some View {
        let r = DecorIconResolved(from: element.style.decor)

        // Content mode
        InspectorDenseRow(label: "Content Mode") {
            InspectorDenseSegmented(
                values: IconContentMode.allCases,
                selection: Binding(
                    get: { r.contentMode },
                    set: { project.setDecorIconContentMode(elementID, mode: $0) }
                ),
                label: { mode in Text(mode.label).font(.system(size: 10, weight: .medium)) }
            )
        }

        // Tint color swatch
        InspectorDenseRow(label: "Tint") {
            InspectorDenseSwatchStrip(
                presets: NumericOverlayDetailView.colorPresets,
                selected: r.tint
            ) { color in
                project.setDecorIconTint(elementID, color: color)
            }
        }
    }

    // MARK: Layout (shared)

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let s = element.style.decor
        let widthRange: ClosedRange<Double> = 8...4096
        let heightRange: ClosedRange<Double> = 8...4096
        let showSize = element.type == .decorSolidColor || element.type == .decorIcon

        CollapsibleLayoutInspectorSection(
            isExpanded: Binding(
                get: { openSections.contains(.layout) },
                set: { newValue in
                    if newValue { openSections.insert(.layout) } else { openSections.remove(.layout) }
                }
            )
        ) {
            OverlayLayoutInspectorRows(
                elementID: elementID,
                widthBinding: showSize ? Binding(
                    get: { s.width },
                    set: { project.setDecorSize(elementID, width: $0) }
                ) : nil,
                widthRange: widthRange,
                heightBinding: showSize ? Binding(
                    get: { s.height },
                    set: { project.setDecorSize(elementID, height: $0) }
                ) : nil,
                heightRange: heightRange
            )
        }
    }

    // MARK: Text (Phase F)

    @ViewBuilder
    private func textBody(element: OverlayElement) -> some View {
        layoutInspectorSection(element)
        sectionView(.textContent, element: element) { textContentSection(element) }
        sectionView(.textFont, element: element) { textFontSection(element) }
        sectionView(.textAppearance, element: element) { textAppearanceSection(element) }
        sectionView(.textFill, element: element) { textFillSection(element) }
        OverlayBorderInspectorModule(elementID: elementID, element: element)
        OverlayEffectsInspectorModule(elementID: elementID, element: element)
    }

    @ViewBuilder
    private func textContentSection(_ element: OverlayElement) -> some View {
        let r = DecorTextResolved(from: element.style.decor)
        VStack(spacing: NumericTokens.rowGap) {
            TextEditor(text: Binding(
                get: { r.content },
                set: { project.setDecorTextContent(elementID, content: $0) }
            ))
            .font(NumericTokens.bodyFont)
            .frame(minHeight: 60)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(NumericTokens.borderSubtle))
        }
    }

    @ViewBuilder
    private func textFontSection(_ element: OverlayElement) -> some View {
        let r = DecorTextResolved(from: element.style.decor)
        let fontIdx = switch r.font {
        case .system(let family): family == PresetFontName.digitalWatch ? 1 : 0
        case .bundled: 1
        case .userAsset: 2
        }
        InspectorDenseRow(label: "Font") {
            Picker("", selection: Binding<Int>(
                get: { fontIdx },
                set: { (idx: Int) in
                    switch idx {
                    case 0: project.setDecorTextFont(elementID, font: .system(family: FontLibraryManager.shared.defaultFamily))
                    case 1:
                        project.setDecorTextFont(
                            elementID,
                            font: .system(family: PresetFontName.digitalWatch)
                        )
                    default: break
                    }
                }
            )) {
                Text("System").tag(0)
                Text("Digital").tag(1)
                Text("Upload").tag(2).disabled(true)
            }
            .pickerStyle(.segmented)
        }
        if case .system(let selectedFamily) = r.font,
           selectedFamily != PresetFontName.digitalWatch {
            let families = FontLibraryManager.shared.effectiveFavorites
            InspectorDenseRow(label: "Family") {
                Picker("", selection: Binding(
                    get: {
                        if case .system(let f) = r.font { return f }
                        return FontLibraryManager.shared.defaultFamily
                    },
                    set: { project.setDecorTextFont(elementID, font: .system(family: $0)) }
                )) {
                    ForEach(families, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                .frame(maxWidth: 200)
            }
        }
        if case .bundled = r.font {
            InspectorDenseRow(label: "Legacy Font") {
                Button("Use Menlo Digital") {
                    project.setDecorTextFont(
                        elementID,
                        font: .system(family: PresetFontName.digitalWatch)
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        InspectorDenseSliderRow(
            label: "Size",
            value: Binding(
                get: { r.size },
                set: { project.setDecorTextSize(elementID, size: $0) }
            ),
            range: 4...256,
            displayText: "\(Int(r.size.rounded()))"
        )
    }

    @ViewBuilder
    private func textAppearanceSection(_ element: OverlayElement) -> some View {
        let r = DecorTextResolved(from: element.style.decor)
        InspectorDenseRow(label: "Alignment") {
            InspectorDenseSegmented(
                values: DecorTextAlignment.allCases,
                selection: Binding(
                    get: { r.alignment },
                    set: { project.setDecorTextAlignment(elementID, alignment: $0) }
                ),
                label: { a in Text(a.label).font(.system(size: 10, weight: .medium)) }
            )
        }
        InspectorDenseSliderRow(
            label: "Line Height",
            value: Binding(
                get: { r.lineHeight },
                set: { project.setDecorTextLineHeight(elementID, lineHeight: $0) }
            ),
            range: 0.5...4,
            displayText: String(format: "%.1fx", r.lineHeight)
        )
        InspectorDenseSliderRow(
            label: "Letter Spacing",
            value: Binding(
                get: { r.letterSpacing },
                set: { project.setDecorTextLetterSpacing(elementID, spacing: $0) }
            ),
            range: -10...40,
            displayText: "\(Int(r.letterSpacing.rounded()))"
        )
        InspectorDenseRow(label: "Auto Fit") {
            Toggle("", isOn: Binding(
                get: { r.autoFit },
                set: { project.setDecorTextAutoFit(elementID, enabled: $0) }
            ))
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func textFillSection(_ element: OverlayElement) -> some View {
        let r = DecorTextResolved(from: element.style.decor)
        if case .solid(let solidColor) = r.fillMode {
            InspectorDenseRow(label: "Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: solidColor
                ) { color in
                    project.setDecorTextFillMode(elementID, fillMode: .solid(color: color))
                }
            }
        }
        InspectorDenseSliderRow(
            label: "Stroke Width",
            value: Binding(
                get: { r.strokeWidth },
                set: { project.setDecorTextStrokeWidth(elementID, width: $0) }
            ),
            range: 0...30,
            displayText: "\(Int(r.strokeWidth.rounded()))"
        )
        if r.strokeWidth > 0 {
            InspectorDenseRow(label: "Stroke Color") {
                InspectorDenseSwatchStrip(
                    presets: NumericOverlayDetailView.colorPresets,
                    selected: r.strokeColor
                ) { color in
                    project.setDecorTextStrokeColor(elementID, color: color)
                }
            }
        }
    }

    @ViewBuilder
    private func placeholderBody(element: OverlayElement) -> some View {
        VStack(alignment: .leading, spacing: NumericTokens.sectionGap) {
            Text(element.type.label)
                .font(NumericTokens.sectionTitleFont)
                .foregroundStyle(NumericTokens.textPrimary)
            Text("Inspector for this decor type lands in Phase F.")
                .font(NumericTokens.bodyFont)
                .foregroundStyle(NumericTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Header / Footer / Section shell

    private func header(element: OverlayElement) -> some View {
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

            ZStack {
                RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                    .fill(NumericTokens.controlBackground)
                    .frame(width: NumericTokens.iconButtonSize, height: NumericTokens.iconButtonSize)
                Image(systemName: headerSymbol(for: element.type))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NumericTokens.accentBlue)
            }
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            HStack(spacing: 8) {
                Text(element.type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("Decor")
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
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(NumericTokens.panelBackgroundElevated)
        .overlay(alignment: .bottom) {
            Divider().overlay(NumericTokens.borderSubtle)
        }
    }

    private func headerSymbol(for type: OverlayElementType) -> String {
        switch type {
        case .decorSolidColor: "square.fill"
        case .decorIcon: "star"
        case .decorText: "textformat"
        default: "square"
        }
    }

    private var footerBar: some View {
        InspectorDetailFooterBar(
            leadingTitle: "Reset",
            leadingSystemImage: "arrow.counterclockwise",
            trailingTitle: "Done",
            trailingSystemImage: "checkmark",
            onLeadingTap: { project.resetOverlayStyle(elementID) },
            onTrailingTap: { project.selection = .none }
        )
    }

    private enum DecorSection: String, CaseIterable {
        case layout, shape, fill, iconSource, iconTint, textContent, textFont, textAppearance, textFill

        var title: String {
            switch self {
            case .layout: "Layout"
            case .shape: "Shape"
            case .fill: "Fill"
            case .iconSource: "Icon"
            case .iconTint: "Color & Fit"
            case .textContent: "Content"
            case .textFont: "Font & Size"
            case .textAppearance: "Appearance"
            case .textFill: "Fill & Stroke"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .shape: "square.on.square"
            case .fill: "paintpalette"
            case .iconSource: "star"
            case .iconTint: "paintbrush"
            case .textContent: "text.quote"
            case .textFont: "character.square"
            case .textAppearance: "text.alignleft"
            case .textFill: "paintbrush.pointed"
            }
        }
    }

    private func sectionView<Content: View>(
        _ section: DecorSection,
        element: OverlayElement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isOpen = openSections.contains(section)
        return VStack(alignment: .leading, spacing: NumericTokens.rowGap) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: section.systemImage)
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(NumericTokens.textSecondary)
                Text(section.title)
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Spacer()
                Button {
                    if isOpen { openSections.remove(section) } else { openSections.insert(section) }
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumericTokens.textMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .frame(height: NumericTokens.sectionHeaderHeight)
            .padding(.horizontal, NumericTokens.panelPaddingX)
            .background(NumericTokens.panelBackgroundElevated)
            .overlay(alignment: .bottom) { Rectangle().fill(NumericTokens.borderSubtle).frame(height: 1) }

            if isOpen {
                VStack(spacing: 0) { content() }
            }
        }
    }

    // MARK: Helpers

    private enum IconSourceType: String, CaseIterable, Identifiable {
        case sfSymbol, bundledSVG, upload

        var id: String { rawValue }
        var label: String {
            switch self {
            case .sfSymbol: "SF Symbol"
            case .bundledSVG: "Bundled"
            case .upload: "Upload"
            }
        }
        var systemImage: String {
            switch self {
            case .sfSymbol: "square.grid.3x3"
            case .bundledSVG: "shippingbox"
            case .upload: "square.and.arrow.up"
            }
        }
    }

    private func iconSourceType(for asset: IconAsset) -> IconSourceType {
        switch asset {
        case .sfSymbol: .sfSymbol
        case .bundledSVG: .bundledSVG
        case .bundledImage: .bundledSVG
        case .userStaticSVG: .upload
        case .none: .sfSymbol
        }
    }

}

private extension IconAsset {
    var symbolName: String? {
        if case .sfSymbol(let name, _, _) = self { return name }
        return nil
    }
    var symbolWeight: SymbolWeight? {
        if case .sfSymbol(_, let w, _) = self { return w }
        return nil
    }
    var symbolScale: SymbolScale? {
        if case .sfSymbol(_, _, let s) = self { return s }
        return nil
    }
    var bundledSVGName: String? {
        if case .bundledSVG(let name) = self { return name }
        return nil
    }
}
