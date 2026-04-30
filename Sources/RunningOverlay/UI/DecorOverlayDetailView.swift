import SwiftUI

/// Inspector detail view for the three Decor element subtypes
/// (`decorSolidColor`, `decorIcon`, `decorText`). Phase B implements the
/// Solid Color sections; Icon/Text remain placeholders until Phases D/F.
struct DecorOverlayDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var openSections: Set<DecorSection> = Set(DecorSection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            if let element = project.selectedOverlay(elementID) {
                header(element: element)
                Divider().overlay(NumericTokens.borderSubtle)
                ScrollView {
                    VStack(spacing: NumericTokens.sectionGap) {
                        switch element.type {
                        case .decorSolidColor:
                            solidColorBody(element: element)
                        case .decorIcon, .decorText:
                            placeholderBody(element: element)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, NumericTokens.panelPaddingX)
                    .padding(.vertical, NumericTokens.panelPaddingY)
                }
                Divider().overlay(NumericTokens.borderSubtle)
                footerBar
            } else {
                Spacer()
            }
        }
    }

    // MARK: Solid Color

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

    // MARK: Layout (shared)

    @ViewBuilder
    private func layoutInspectorSection(_ element: OverlayElement) -> some View {
        let s = element.style.decor
        let widthRange: ClosedRange<Double> = 8...4096
        let heightRange: ClosedRange<Double> = 8...4096
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
                widthBinding: element.type == .decorSolidColor ? Binding(
                    get: { s.width },
                    set: { project.setDecorSize(elementID, width: $0) }
                ) : nil,
                widthRange: widthRange,
                heightBinding: element.type == .decorSolidColor ? Binding(
                    get: { s.height },
                    set: { project.setDecorSize(elementID, height: $0) }
                ) : nil,
                heightRange: heightRange,
                opacityBinding: Binding(
                    get: { element.style.backgroundOpacity },
                    set: { project.setOverlayBackgroundOpacity(elementID, opacity: $0) }
                )
            )
        }
    }

    // MARK: Placeholders for Icon/Text

    @ViewBuilder
    private func placeholderBody(element: OverlayElement) -> some View {
        VStack(alignment: .leading, spacing: NumericTokens.sectionGap) {
            Text(element.type.label)
                .font(NumericTokens.sectionTitleFont)
                .foregroundStyle(NumericTokens.textPrimary)
            Text("Inspector for this decor type lands in a future phase.")
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

            VStack(alignment: .leading, spacing: 2) {
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
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.panelPaddingY)
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
        HStack {
            Button {
                project.deleteOverlay(elementID)
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(NumericTokens.captionFont)
                    .foregroundStyle(NumericTokens.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .padding(.vertical, NumericTokens.panelPaddingY * 0.75)
    }

    private enum DecorSection: String, CaseIterable {
        case layout, shape, fill

        var title: String {
            switch self {
            case .layout: "Layout"
            case .shape: "Shape"
            case .fill: "Fill"
            }
        }

        var systemImage: String {
            switch self {
            case .layout: "scope"
            case .shape: "square.on.square"
            case .fill: "paintpalette"
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
                    .padding(.horizontal, NumericTokens.panelPaddingX)
                    .padding(.vertical, NumericTokens.panelPaddingY * 0.5)
            }
        }
    }
}
