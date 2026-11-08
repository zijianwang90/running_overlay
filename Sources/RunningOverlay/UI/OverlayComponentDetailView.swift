import AppKit
import SwiftUI

/// Inspector detail panel for declarative overlay components.
///
/// Controls are generated from the definition's typed params. Section order
/// follows first appearance; parameters without a section fall under
/// "Parameters" (or "Advanced" when marked advanced).
struct OverlayComponentDetailView: View {
    @EnvironmentObject private var project: ProjectDocument
    let elementID: OverlayElement.ID

    @State private var collapsedSections: Set<String> = []

    var body: some View {
        if let element = project.selectedOverlay(elementID),
           let instance = element.component,
           let definition = OverlayComponentRegistry.definition(for: instance.reference) {
            ScrollView {
                VStack(spacing: NumericTokens.sectionGap) {
                    section("Layout") {
                        OverlayLayoutInspectorRows(elementID: elementID)
                    }
                    section("Component") {
                        componentInfo(element: element, instance: instance, definition: definition)
                    }
                    ForEach(sectionNames(for: definition), id: \.self) { name in
                        section(name) {
                            ForEach(definition.params.filter { sectionName(for: $0) == name }, id: \.id) { parameter in
                                if isVisible(parameter, element: element, definition: definition) {
                                    parameterControl(parameter, element: element, definition: definition)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, NumericTokens.sectionGap)
            }
        } else {
            VStack(alignment: .leading, spacing: NumericTokens.space2) {
                Text("Component unavailable")
                    .font(NumericTokens.sectionTitleFont)
                    .foregroundStyle(NumericTokens.textPrimary)
                Text("This component definition could not be resolved.")
                    .font(NumericTokens.bodyFont)
                    .foregroundStyle(NumericTokens.textSecondary)
                Spacer()
            }
            .padding(NumericTokens.panelPaddingX)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Sections

    private func section<Body: View>(
        _ title: String,
        @ViewBuilder content: () -> Body
    ) -> some View {
        let body = content()
        return InspectorCollapsibleSection(
            title: title,
            isExpanded: Binding(
                get: { !collapsedSections.contains(title) },
                set: { isOpen in
                    if isOpen { collapsedSections.remove(title) } else { collapsedSections.insert(title) }
                }
            )
        ) {
            body
        }
    }

    private func sectionName(for parameter: OverlayComponentParam) -> String {
        if let section = parameter.section {
            return section.resolve(language: OverlayComponentInstance.hostLanguage)
        }
        return parameter.isAdvanced ? "Advanced" : "Parameters"
    }

    private func sectionNames(for definition: OverlayComponentDefinition) -> [String] {
        var names: [String] = []
        for parameter in definition.params {
            let name = sectionName(for: parameter)
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    // MARK: - Component metadata

    @ViewBuilder
    private func componentInfo(
        element: OverlayElement,
        instance: OverlayComponentInstance,
        definition: OverlayComponentDefinition
    ) -> some View {
        InspectorDenseRow(label: "Name") {
            InspectorDenseReadout(text: definition.name.resolve(language: OverlayComponentInstance.hostLanguage))
        }
        InspectorDenseRow(label: "Version") {
            InspectorDenseReadout(text: definition.version, isNumeric: true)
        }
        InspectorDenseRow(label: "Source") {
            InspectorDenseReadout(text: sourceLabel(instance.reference.source))
        }
        InspectorDenseRow(label: "License") {
            InspectorDenseReadout(text: definition.license)
        }
        if let author = definition.author {
            InspectorDenseRow(label: "Author") {
                InspectorDenseReadout(text: author)
            }
        }
        if instance.reference.source == .bundled {
            InspectorDenseRow(label: "Definition") {
                Button("Duplicate to My Components") {
                    project.makeComponentEditable(element.id)
                }
                .controlSize(.small)
                .help("Embed this bundled definition so it can be customized.")
            }
        }
    }

    private func sourceLabel(_ source: OverlayComponentSource) -> String {
        switch source {
        case .bundled: "Bundled (read-only)"
        case .imported: "Imported"
        case .project: "My Components"
        }
    }

    // MARK: - Parameter values

    private func rawValue(
        _ parameter: OverlayComponentParam,
        element: OverlayElement
    ) -> OverlayJSONValue? {
        element.component?.parameters[parameter.id]
    }

    private func numberValue(_ parameter: OverlayComponentParam, element: OverlayElement) -> Double {
        if case .number(let value)? = rawValue(parameter, element: element) {
            return value
        }
        if case .number(let value) = parameter.defaultValue {
            return value
        }
        return 0
    }

    private func colorValue(_ parameter: OverlayComponentParam, element: OverlayElement) -> OverlayColor {
        if case .string(let text)? = rawValue(parameter, element: element),
           let color = OverlayComponentColorParser.parse(text) {
            return color
        }
        if case .color(let color) = parameter.defaultValue {
            return color
        }
        return .white
    }

    private func stringValue(_ parameter: OverlayComponentParam, element: OverlayElement) -> String {
        if case .string(let text)? = rawValue(parameter, element: element) {
            return text
        }
        return parameter.defaultValue.string ?? ""
    }

    // MARK: - Controls

    @ViewBuilder
    private func parameterControl(
        _ parameter: OverlayComponentParam,
        element: OverlayElement,
        definition: OverlayComponentDefinition
    ) -> some View {
        let label = parameter.label.resolve(language: OverlayComponentInstance.hostLanguage)
        switch parameter.kind {
        case .number(let minimum, let maximum, let step, let unit, let style):
            let value = numberValue(parameter, element: element)
            if style == .field {
                ComponentNumberFieldRow(
                    label: label,
                    unit: unit,
                    value: value,
                    range: minimum...maximum,
                    decimalPlaces: step.map { decimals(for: $0) } ?? 2
                ) { newValue in
                    project.setComponentParameter(
                        elementID,
                        parameterID: parameter.id,
                        value: .number(newValue)
                    )
                }
            } else {
                InspectorDenseSliderRow(
                    label: label,
                    value: Binding(
                        get: { numberValue(parameter, element: element) },
                        set: { newValue in
                            project.setComponentParameter(
                                elementID,
                                parameterID: parameter.id,
                                value: .number(newValue),
                                continuous: true
                            )
                        }
                    ),
                    range: minimum...maximum,
                    displayText: displayText(value, unit: unit, step: step)
                )
            }

        case .boolean:
            let isOn: Bool = {
                if case .boolean(let value)? = rawValue(parameter, element: element) { return value }
                if case .boolean(let value) = parameter.defaultValue { return value }
                return false
            }()
            InspectorDenseRow(label: label) {
                Toggle(label, isOn: Binding(
                    get: {
                        if case .boolean(let value)? = rawValue(parameter, element: element) { return value }
                        if case .boolean(let value) = parameter.defaultValue { return value }
                        return false
                    },
                    set: { newValue in
                        project.setComponentParameter(
                            elementID,
                            parameterID: parameter.id,
                            value: .boolean(newValue)
                        )
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel(label)
                .accessibilityValue(isOn ? "On" : "Off")
            }

        case .color:
            let color = colorValue(parameter, element: element)
            InspectorDenseRow(label: label) {
                Text(color.componentHexString)
                    .font(NumericTokens.captionFont)
                    .monospaced()
                    .foregroundStyle(NumericTokens.textSecondary)
                ColorPicker(
                    label,
                    selection: Binding(
                        get: { Color(numericOverlay: color) },
                        set: { newColor in
                            let resolved = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                            let updated = OverlayColor(
                                red: Double(resolved.redComponent),
                                green: Double(resolved.greenComponent),
                                blue: Double(resolved.blueComponent),
                                alpha: color.alpha
                            )
                            project.setComponentParameter(
                                elementID,
                                parameterID: parameter.id,
                                value: .string(updated.componentHexString)
                            )
                        }
                    ),
                    supportsOpacity: true
                )
                .labelsHidden()
                .frame(width: 44, height: NumericTokens.controlHeight)
            }

        case .enumeration(let options):
            let current = stringValue(parameter, element: element)
            InspectorDenseRow(label: label) {
                Menu {
                    ForEach(options, id: \.value) { option in
                        Button {
                            project.setComponentParameter(
                                elementID,
                                parameterID: parameter.id,
                                value: .string(option.value)
                            )
                        } label: {
                            if option.value == current {
                                Label(option.label.resolve(language: OverlayComponentInstance.hostLanguage), systemImage: "checkmark")
                            } else {
                                Text(option.label.resolve(language: OverlayComponentInstance.hostLanguage))
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(
                        title: options.first { $0.value == current }?
                            .label.resolve(language: OverlayComponentInstance.hostLanguage) ?? current
                    )
                }
                .inspectorMenuStyle()
                .frame(height: NumericTokens.controlHeight)
            }

        case .string(let maxLength):
            ComponentStringFieldRow(
                label: label,
                value: stringValue(parameter, element: element),
                maxLength: maxLength
            ) { newValue in
                project.setComponentParameter(
                    elementID,
                    parameterID: parameter.id,
                    value: .string(newValue)
                )
            }

        case .font:
            let current = stringValue(parameter, element: element).isEmpty
                ? FontLibraryManager.shared.defaultFamily
                : stringValue(parameter, element: element)
            InspectorDenseRow(label: label) {
                Menu {
                    ForEach(fontFamilies(including: current), id: \.self) { family in
                        Button {
                            project.setComponentParameter(
                                elementID,
                                parameterID: parameter.id,
                                value: .string(family)
                            )
                        } label: {
                            if family == current {
                                Label(family, systemImage: "checkmark")
                            } else {
                                Text(family)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: current)
                }
                .inspectorMenuStyle()
                .frame(height: NumericTokens.controlHeight)
            }

        case .metric(let signals, _):
            let current = stringValue(parameter, element: element).isEmpty
                ? (signals.first ?? "")
                : stringValue(parameter, element: element)
            InspectorDenseRow(label: label) {
                Menu {
                    ForEach(signals.sorted(), id: \.self) { signal in
                        Button {
                            project.setComponentParameter(
                                elementID,
                                parameterID: parameter.id,
                                value: .string(signal)
                            )
                        } label: {
                            if signal == current {
                                Label(signal, systemImage: "checkmark")
                            } else {
                                Text(signal)
                            }
                        }
                    }
                } label: {
                    InspectorDenseMenuLabel(title: current)
                }
                .inspectorMenuStyle()
                .frame(height: NumericTokens.controlHeight)
            }
        }
    }

    private func fontFamilies(including current: String) -> [String] {
        var families = InspectorPresets.fontPresets
        if !families.contains(current) { families.insert(current, at: 0) }
        return families
    }

    private func decimals(for step: Double) -> Int {
        if step >= 1 { return 0 }
        if step >= 0.1 { return 1 }
        if step >= 0.01 { return 2 }
        return 3
    }

    private func displayText(_ value: Double, unit: String?, step: Double?) -> String {
        let formatted: String
        if let step {
            formatted = value.formatted(.number.precision(.fractionLength(decimals(for: step))))
        } else {
            formatted = OverlayComponentNumberFormatter.plain(value)
        }
        guard let unit, !unit.isEmpty else { return formatted }
        return "\(formatted) \(unit)"
    }

    // MARK: - Conditions

    private func isVisible(
        _ parameter: OverlayComponentParam,
        element: OverlayElement,
        definition: OverlayComponentDefinition
    ) -> Bool {
        guard let expression = parameter.whenExpression else { return true }
        let data = OverlayComponentActivityData(
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime,
            zoneSnapshot: HeartRateZonePreferences.currentSnapshot(),
            canvasSize: CGSize(
                width: project.settings.resolution.width,
                height: project.settings.resolution.height
            ),
            elementScale: element.scale
        )
        let parameters = definition.parameterValues(
            from: element.component?.parameters ?? [:]
        )
        let context = OverlayComponentEvaluationContext(
            parameters: parameters,
            data: data,
            componentSize: definition.size
        )
        return expression.evaluate(in: context).isTruthy
    }
}

/// Number param using a typed field instead of a slider (`style: "field"`).
private struct ComponentNumberFieldRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    var unit: String?
    var value: Double
    var range: ClosedRange<Double>
    var decimalPlaces: Int
    var onCommit: (Double) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        InspectorDenseRow(label: label) {
            HStack(spacing: 4) {
                if let unit {
                    Text(unit)
                        .font(NumericTokens.captionFont)
                        .foregroundStyle(NumericTokens.textMuted)
                }
                TextField(label, text: $draft)
                    .textFieldStyle(.plain)
                    .font(NumericTokens.valueFieldFont)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .frame(width: NumericTokens.valueFieldWidth)
                    .padding(.horizontal, 6)
                    .frame(height: NumericTokens.controlHeight)
                    .background(NumericTokens.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                            .stroke(isFocused ? NumericTokens.accentBlue : NumericTokens.borderSubtle, lineWidth: isFocused ? 2 : 1)
                    )
                    .onAppear { draft = displayValue }
                    .onChange(of: displayValue) { _, newText in
                        if !isFocused { draft = newText }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    .onSubmit { commit() }
                    .onExitCommand {
                        draft = displayValue
                        isFocused = false
                    }
                    .accessibilityLabel(label)
            }
        }
    }

    private var displayValue: String {
        value.formatted(.number.precision(.fractionLength(decimalPlaces)))
    }

    private func commit() {
        let normalized = draft.replacingOccurrences(of: ",", with: ".")
        guard let parsed = Double(normalized), parsed.isFinite else {
            draft = displayValue
            return
        }
        draft = displayValue
        onCommit(min(max(parsed, range.lowerBound), range.upperBound))
        project.finishContinuousEdit()
    }
}

/// String param committed on Return or focus loss so typing is one undo point.
private struct ComponentStringFieldRow: View {
    @EnvironmentObject private var project: ProjectDocument
    var label: String
    var value: String
    var maxLength: Int
    var onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        InspectorDenseRow(label: label) {
            TextField(label, text: $draft)
                .textFieldStyle(.plain)
                .font(NumericTokens.bodyFont)
                .focused($isFocused)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .frame(height: NumericTokens.controlHeight)
                .background(NumericTokens.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: NumericTokens.controlRadius)
                        .stroke(isFocused ? NumericTokens.accentBlue : NumericTokens.borderSubtle, lineWidth: isFocused ? 2 : 1)
                )
                .onAppear { draft = value }
                .onChange(of: value) { _, newValue in
                    if !isFocused { draft = newValue }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onSubmit { commit() }
                .onExitCommand {
                    draft = value
                    isFocused = false
                }
                .accessibilityLabel(label)
        }
    }

    private func commit() {
        let trimmed = String(draft.prefix(maxLength))
        draft = trimmed
        onCommit(trimmed)
        project.finishContinuousEdit()
    }
}
