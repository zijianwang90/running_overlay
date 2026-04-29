import SwiftUI

/// Shared inspector rows for the Stats Bar configuration used by both the
/// Distance Timeline and Route Map overlays.
/// Keep this surface identical across overlays so future modules can reuse it
/// without introducing per-overlay divergence.
struct StatsBarInspectorRows: View {

    // MARK: - Required config

    let isOn: Bool
    let placement: RouteMapStatsBarPlacement
    let availablePlacements: [RouteMapStatsBarPlacement]
    let layoutMode: RouteMapStatsBarLayoutMode
    let height: Double
    let heightRange: ClosedRange<Double>
    let heightLabel: String
    let backgroundOpacity: Double
    let dividerOpacity: Double
    let cornerRadius: Double
    let cornerRadiusRange: ClosedRange<Double>
    let valueTypography: TypographyConfig
    let labelTypography: TypographyConfig
    let slots: [(metric: RouteMapStatsMetric, visible: Bool)]
    let availableMetrics: [RouteMapStatsMetric]

    // MARK: - Optional unified config

    var inside: Bool? = nil
    var extraLayout: ExtraLayoutConfig? = nil

    // MARK: - Required callbacks

    let onSetPlacement: (RouteMapStatsBarPlacement) -> Void
    let onSetLayoutMode: (RouteMapStatsBarLayoutMode) -> Void
    let onSetHeight: (Double) -> Void
    let onSetBackgroundOpacity: (Double) -> Void
    let onSetDividerOpacity: (Double) -> Void
    let onSetCornerRadius: (Double) -> Void
    let onSetSlotMetric: (Int, RouteMapStatsMetric) -> Void
    let onSetSlotVisible: (Int, Bool) -> Void
    var onSetInside: ((Bool) -> Void)? = nil

    // MARK: - View

    var body: some View {
        placementRow
        if let inside, let onSetInside {
            insideRow(inside, onSet: onSetInside)
        }
        layoutRow
        heightRow
        if let extra = extraLayout {
            extraLayoutRows(extra)
        }
        backgroundOpacityRow
        dividerOpacityRow
        cornerRadiusRow
        typographyRows
        slotRows
    }

    // MARK: - Rows

    private var placementRow: some View {
        InspectorDenseRow(label: "Placement") {
            Menu {
                ForEach(availablePlacements) { p in
                    Button {
                        onSetPlacement(p)
                    } label: {
                        if p == placement { Label(p.label, systemImage: "checkmark") }
                        else { Text(p.label) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: placement.label, isEnabled: isOn)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)
    }

    private var layoutRow: some View {
        InspectorDenseRow(label: "Layout") {
            Menu {
                ForEach(RouteMapStatsBarLayoutMode.allCases) { m in
                    Button {
                        onSetLayoutMode(m)
                    } label: {
                        if m == layoutMode { Label(m.label, systemImage: "checkmark") }
                        else { Text(m.label) }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: layoutMode.label, isEnabled: isOn)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)
    }

    private func insideRow(_ value: Bool, onSet: @escaping (Bool) -> Void) -> some View {
        InspectorDenseRow(label: "Inside") {
            Toggle("", isOn: Binding(get: { value }, set: onSet))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)
    }

    private var heightRow: some View {
        InspectorDenseSliderRow(
            label: heightLabel,
            value: Binding(get: { height }, set: onSetHeight),
            range: heightRange,
            displayText: "\(Int(height.rounded()))",
            isEnabled: isOn
        )
    }

    @ViewBuilder
    private func extraLayoutRows(_ extra: ExtraLayoutConfig) -> some View {
        InspectorDenseSliderRow(
            label: "Width",
            value: Binding(get: { extra.width }, set: extra.onSetWidth),
            range: 0...640,
            displayText: extra.width < 1 ? "Auto" : "\(Int(extra.width.rounded()))",
            isEnabled: isOn
        )
        InspectorDenseRow(label: "Offset") {
            InspectorDenseAxisField(axis: "X", value: Binding(get: { extra.offsetX }, set: extra.onSetOffsetX), precision: 0)
            InspectorDenseAxisField(axis: "Y", value: Binding(get: { extra.offsetY }, set: extra.onSetOffsetY), precision: 0)
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)
        InspectorDenseSliderRow(
            label: "Item Gap",
            value: Binding(get: { extra.itemSpacing }, set: extra.onSetItemSpacing),
            range: 0...32,
            displayText: "\(Int(extra.itemSpacing.rounded()))",
            isEnabled: isOn
        )
    }

    private var backgroundOpacityRow: some View {
        InspectorDenseSliderRow(
            label: "Background",
            value: Binding(get: { backgroundOpacity }, set: onSetBackgroundOpacity),
            range: 0...1,
            displayText: String(format: "%.0f%%", backgroundOpacity * 100),
            isEnabled: isOn
        )
    }

    private var dividerOpacityRow: some View {
        InspectorDenseSliderRow(
            label: "Dividers",
            value: Binding(get: { dividerOpacity }, set: onSetDividerOpacity),
            range: 0...1,
            displayText: dividerOpacity < 0.005 ? "Off" : String(format: "%.0f%%", dividerOpacity * 100),
            isEnabled: isOn
        )
    }

    private var cornerRadiusRow: some View {
        InspectorDenseSliderRow(
            label: "Radius",
            value: Binding(get: { cornerRadius }, set: onSetCornerRadius),
            range: cornerRadiusRange,
            displayText: "\(Int(cornerRadius.rounded()))",
            isEnabled: isOn
        )
    }

    @ViewBuilder
    private var typographyRows: some View {
        typographyRows(for: "Value", config: valueTypography)
        typographyRows(for: "Label", config: labelTypography)
    }

    @ViewBuilder
    private func typographyRows(for title: String, config: TypographyConfig) -> some View {
        InspectorDenseRow(label: "\(title) Font") {
            Menu {
                ForEach(NumericOverlayDetailView.fontPresets, id: \.self) { name in
                    Button {
                        config.onSetFontName(name)
                    } label: {
                        if name == config.fontName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                InspectorDenseMenuLabel(title: config.fontName, isEnabled: isOn)
            }
            .menuStyle(.borderlessButton)
            .frame(height: NumericTokens.controlHeight)
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)

        InspectorDenseSliderRow(
            label: "\(title) Size",
            value: Binding(get: { config.fontSize }, set: config.onSetFontSize),
            range: 8...96,
            displayText: "\(Int(config.fontSize.rounded()))",
            isEnabled: isOn
        )

        InspectorDenseRow(label: "\(title) Weight") {
            InspectorDenseSegmented(
                values: OverlayFontWeight.allCases,
                selection: Binding(get: { config.fontWeight }, set: config.onSetFontWeight)
            ) { weight in
                Text(weight.label)
            }
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)

        InspectorDenseRow(label: "\(title) Color") {
            InspectorDenseSwatchStrip(presets: NumericOverlayDetailView.colorPresets, selected: config.color) { color in
                config.onSetColor(color)
            }
        }
        .opacity(isOn ? 1 : 0.5).disabled(!isOn)
    }

    @ViewBuilder
    private var slotRows: some View {
        ForEach(slots.indices, id: \.self) { index in
            let slot = slots[index]
            InspectorDenseRow(label: "Slot \(index + 1)") {
                Menu {
                    ForEach(availableMetrics) { metric in
                        Button {
                            onSetSlotMetric(index, metric)
                        } label: {
                            if metric == slot.metric { Label(metric.label, systemImage: "checkmark") }
                            else { Text(metric.label) }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: slot.metric.label, isEnabled: slot.visible)
                }
                .menuStyle(.borderlessButton)
                .frame(height: NumericTokens.controlHeight)

                Toggle("", isOn: Binding(
                    get: { slot.visible },
                    set: { onSetSlotVisible(index, $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .opacity(isOn ? 1 : 0.5).disabled(!isOn)
        }
    }
}

// MARK: - Shared Stats Bar UI constants

enum SharedStatsBarInspectorUI {
    static let sectionTitle = "Stats Bar"
    static let sectionSystemImage = "tablecells"
    static let placements = RouteMapStatsBarPlacement.distanceTimelinePlacements
    static let heightRange: ClosedRange<Double> = 32...120
    static let heightLabel = "Size"
    static let cornerRadiusRange: ClosedRange<Double> = 0...32
    static let metrics = RouteMapStatsMetric.allCases
}

extension StatsBarInspectorRows {
    struct TypographyConfig {
        var fontName: String
        var fontSize: Double
        var fontWeight: OverlayFontWeight
        var color: OverlayColor
        var onSetFontName: (String) -> Void
        var onSetFontSize: (Double) -> Void
        var onSetFontWeight: (OverlayFontWeight) -> Void
        var onSetColor: (OverlayColor) -> Void
    }

    struct ExtraLayoutConfig {
        var width: Double
        var offsetX: Double
        var offsetY: Double
        var itemSpacing: Double
        var onSetWidth: (Double) -> Void
        var onSetOffsetX: (Double) -> Void
        var onSetOffsetY: (Double) -> Void
        var onSetItemSpacing: (Double) -> Void
    }
}

extension RouteMapStatsBarPlacement {
    static let distanceTimelinePlacements: [RouteMapStatsBarPlacement] = [
        .topAttached,
        .bottomAttached,
        .leftAttached,
        .rightAttached,
    ]
}

// MARK: - Collapsible section wrapper

/// Self-contained Stats Bar inspector block:
/// title row (tap to expand) with Enabled toggle in the header, then caller-supplied rows.
/// Use this from any overlay detail view so the Stats Bar UI stays consistent and reusable.
struct CollapsibleStatsBarInspectorSection<Content: View>: View {
    @Binding var isExpanded: Bool
    let title: String
    let systemImage: String
    let isBarEnabled: Bool
    let onSetBarEnabled: (Bool) -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: NumericTokens.space2) {
            Image(systemName: systemImage)
                .frame(width: 16, alignment: .center)
                .foregroundStyle(NumericTokens.textSecondary)
            Text(title)
                .font(NumericTokens.sectionTitleFont)
                .foregroundStyle(NumericTokens.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(get: { isBarEnabled }, set: onSetBarEnabled))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onTapGesture { }
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NumericTokens.textMuted)
                .frame(width: 18, height: 18)
        }
        .frame(height: NumericTokens.sectionHeaderHeight)
        .padding(.horizontal, NumericTokens.panelPaddingX)
        .background(NumericTokens.panelBackgroundElevated)
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
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
    }
}
