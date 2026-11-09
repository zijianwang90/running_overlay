import CoreFoundation
import Foundation

enum OverlayJSONValue: Equatable, Sendable {
    case object([String: OverlayJSONValue])
    case array([OverlayJSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    static func decode(_ data: Data) throws -> OverlayJSONValue {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw OverlayComponentValidationError(diagnostics: [
                OverlayComponentDiagnostic(path: "$", message: "invalid JSON: \(error.localizedDescription)")
            ])
        }
        return try convert(object, path: "$")
    }

    private static func convert(_ value: Any, path: String) throws -> OverlayJSONValue {
        if value is NSNull { return .null }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .boolean(number.boolValue)
            }
            let double = number.doubleValue
            guard double.isFinite else {
                throw OverlayComponentValidationError(diagnostics: [
                    OverlayComponentDiagnostic(path: path, message: "number must be finite")
                ])
            }
            return .number(double)
        }
        if let string = value as? String { return .string(string) }
        if let array = value as? [Any] {
            return .array(try array.enumerated().map { try convert($0.element, path: "\(path)[\($0.offset)]") })
        }
        if let dictionary = value as? [String: Any] {
            var result: [String: OverlayJSONValue] = [:]
            for (key, item) in dictionary {
                result[key] = try convert(item, path: "\(path).\(key)")
            }
            return .object(result)
        }
        throw OverlayComponentValidationError(diagnostics: [
            OverlayComponentDiagnostic(path: path, message: "unsupported JSON value")
        ])
    }
}

enum OverlayComponentSignalCatalog {
    static let scalarSignals: Set<String> = [
        "activity.elapsed", "activity.remaining", "activity.distance",
        "activity.duration", "activity.totalDistance",
        "activity.heartRate", "activity.pace", "activity.avgPace",
        "activity.elevation", "activity.elevationGain", "activity.cadence",
        "activity.power", "activity.grade", "activity.temperature",
        "activity.calories", "activity.lapPace", "activity.verticalOscillation",
        "activity.groundContactTime", "activity.strideLength", "activity.verticalRatio",
        "activity.groundContactBalance", "clock.realTime", "clock.date",
        "host.canvasWidth", "host.canvasHeight", "host.scale"
    ]

    static let recordSignals: Set<String> = [
        "zone.heartRate", "zone.pace", "structure.currentLap",
        "structure.current", "structure.segment", "structure.lastWork", "structure.recovery",
        "zone.current", "zone.heartRateThreshold", "zone.paceThreshold",
        "route.current", "weather.current", "host"
    ]

    static let seriesSignals: Set<String> = [
        "activity.elapsed", "activity.remaining", "activity.distance",
        "activity.heartRate", "activity.pace", "activity.avgPace",
        "activity.elevation", "activity.elevationGain", "activity.cadence",
        "activity.power", "activity.grade", "activity.temperature",
        "activity.calories", "activity.lapPace", "activity.verticalOscillation",
        "activity.groundContactTime", "activity.strideLength", "activity.verticalRatio",
        "activity.groundContactBalance"
    ]

    static let listSignals: Set<String> = [
        "structure.laps", "structure.intervals", "zone.heartRateZones", "zone.paceZones"
    ]

    static let builtinNames: Set<String> = [
        "min", "max", "clamp", "abs", "round", "floor", "ceil", "lerp",
        "map", "sum", "avg", "count", "first", "last", "at", "coalesce",
        "exists", "format", "concat", "upper", "lower", "slice", "mix",
        "alpha", "field", "signal", "series", "metric"
    ]
}

enum OverlayComponentLoader {
    static func load(
        data: Data,
        assets: Set<String> = [],
        assetData: [String: Data] = [:]
    ) throws -> OverlayComponentPackage {
        let root = try OverlayJSONValue.decode(data)
        let parser = OverlayComponentParser(root: root, assets: assets)
        let definition = parser.parseDocument()
        let errors = parser.diagnostics.filter { $0.severity == .error }
        guard errors.isEmpty else {
            throw OverlayComponentValidationError(diagnostics: parser.diagnostics)
        }
        // Hash canonical bytes so a digest survives embedding and reformatting.
        let digest = OverlayComponentDigest.sha256(of: try root.canonicalData())
        return OverlayComponentPackage(
            definition: definition,
            digest: digest,
            assets: assets,
            assetData: assetData
        )
    }

    static func load(directory url: URL) throws -> OverlayComponentPackage {
        let manifest = url.appendingPathComponent("component.json")
        let data: Data
        do {
            data = try Data(contentsOf: manifest)
        } catch {
            throw OverlayComponentValidationError(diagnostics: [
                OverlayComponentDiagnostic(
                    path: "component.json",
                    message: "cannot read component.json: \(error.localizedDescription)"
                )
            ])
        }
        if data.count > 1024 * 1024 {
            throw OverlayComponentValidationError(diagnostics: [
                OverlayComponentDiagnostic(path: "component.json", message: "must not exceed 1 MiB")
            ])
        }
        let assetsDirectory = url.appendingPathComponent("assets")
        var assets: Set<String> = []
        var assetData: [String: Data] = [:]
        var totalAssetBytes = 0
        if FileManager.default.fileExists(atPath: assetsDirectory.path) {
            let contents = try FileManager.default.contentsOfDirectory(
                at: assetsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
            )
            for file in contents {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { continue }
                let size = values.fileSize ?? 0
                guard size <= 8 * 1024 * 1024 else {
                    throw OverlayComponentValidationError(diagnostics: [
                        OverlayComponentDiagnostic(
                            path: "assets/\(file.lastPathComponent)",
                            message: "asset exceeds 8 MiB"
                        )
                    ])
                }
                totalAssetBytes += size
                let path = "assets/\(file.lastPathComponent)"
                assets.insert(path)
                assetData[path] = try Data(contentsOf: file)
            }
        }
        if assets.count > 32 {
            throw OverlayComponentValidationError(diagnostics: [
                OverlayComponentDiagnostic(path: "assets", message: "at most 32 assets are allowed")
            ])
        }
        if totalAssetBytes > 32 * 1024 * 1024 {
            throw OverlayComponentValidationError(diagnostics: [
                OverlayComponentDiagnostic(path: "assets", message: "assets exceed 32 MiB in total")
            ])
        }
        return try load(data: data, assets: assets, assetData: assetData)
    }

    /// Loads a component ZIP archive. The archive must contain `component.json`
    /// at the root; `assets/` entries become the package's asset bytes.
    static func load(archive data: Data) throws -> OverlayComponentPackage {
        let contents = try OverlayComponentZipArchive.extract(data)
        return try load(
            data: contents.definitionData,
            assets: Set(contents.assets.keys),
            assetData: contents.assets
        )
    }

    /// Loads a package directory, ZIP archive, or a single component JSON file
    /// into a validated reference. Imported references embed the definition and
    /// asset bytes so the resulting project is self-contained.
    static func loadReference(
        at url: URL,
        source: OverlayComponentSource = .imported
    ) throws -> OverlayComponentReference {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            let package = try load(directory: url)
            let definitionData = try Data(
                contentsOf: url.appendingPathComponent("component.json")
            )
            return try OverlayComponentReference(
                definitionData: definitionData,
                source: source,
                assets: package.assetData
            )
        }
        let fileData = try Data(contentsOf: url)
        if OverlayComponentZipArchive.looksLikeZip(fileData) {
            let contents = try OverlayComponentZipArchive.extract(fileData)
            return try OverlayComponentReference(
                definitionData: contents.definitionData,
                source: source,
                assets: contents.assets
            )
        }
        return try OverlayComponentReference(
            definitionData: fileData,
            source: source
        )
    }
}

final class OverlayComponentParser {
    private let root: OverlayJSONValue
    private let assets: Set<String>
    private(set) var diagnostics: [OverlayComponentDiagnostic] = []
    private var parameterIDs: Set<String> = []
    private var nodeIDs: Set<String> = []
    /// First JSON path whose expression reads the `width`/`height` builtins,
    /// which are undefined for a content-sized component.
    private var sizeBuiltinPath: String?

    init(root: OverlayJSONValue, assets: Set<String>) {
        self.root = root
        self.assets = assets
    }

    func parseDocument() -> OverlayComponentDefinition {
        guard case .object(let object) = root else {
            error("$", "component must be a JSON object")
            return emptyDefinition()
        }
        checkUnknownKeys(
            object,
            allowed: [
                "spec", "id", "version", "name", "description", "author",
                "license", "homepage", "size", "padding", "minSize", "background", "params",
                "bindings", "nodes"
            ],
            at: "$"
        )

        let spec = string(object, "spec", at: "$") ?? ""
        if spec != "ros.component/0.1" {
            error("$.spec", "expected 'ros.component/0.1'")
        }

        let id = string(object, "id", at: "$") ?? ""
        if !matches(id, "^[a-z0-9]+(\\.[a-z0-9-]+)+$") {
            error("$.id", "must be a dot-separated lowercase namespace")
        }

        let version = string(object, "version", at: "$") ?? ""
        if !matches(version, "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$") {
            error("$.version", "must be semantic version MAJOR.MINOR.PATCH")
        }

        let name = localizedText(object["name"], at: "$.name", required: true)
            ?? OverlayComponentLocalizedText(values: ["en": id])
        let description = localizedText(object["description"], at: "$.description")

        let license = string(object, "license", at: "$") ?? ""
        if license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error("$.license", "license is required")
        }
        if let homepage = string(object, "homepage", at: "$.homepage"),
           !homepage.hasPrefix("https://") {
            error("$.homepage", "must use https")
        }

        let isContentSized: Bool
        if case .string(let sizeMode)? = object["size"] {
            if sizeMode != "content" {
                error("$.size", "size must be [width, height] or \"content\"")
            }
            isContentSized = true
        } else {
            isContentSized = false
        }
        let size = isContentSized ? .zero : parseSize(object["size"])
        let contentLayout = isContentSized ? parseContentLayout(object) : nil
        if !isContentSized {
            for key in ["padding", "minSize"] where object[key] != nil {
                error("$.\(key)", "\(key) requires \"size\": \"content\"")
            }
        }
        let background = parseBackground(object["background"], path: "$.background")
        let params = parseParams(object["params"], path: "$.params")
        let bindings = parseBindings(object["bindings"], path: "$.bindings")
        let nodes = parseNodes(object["nodes"], path: "$.nodes", depth: 0, insideRepeat: false)
        if nodes.isEmpty {
            error("$.nodes", "at least one node is required")
        }
        if isContentSized {
            for (index, node) in nodes.enumerated() where !isBoxed(node) {
                error(
                    "$.nodes[\(index)].frame",
                    "content-sized component node requires a frame unless it is text or a stack; wrap circle, line, polyline and path in a group"
                )
            }
            if let sizeBuiltinPath {
                error(sizeBuiltinPath, "width and height are unavailable when size is \"content\"")
            }
        }

        return OverlayComponentDefinition(
            spec: spec,
            id: id,
            version: version,
            name: name,
            descriptionText: description,
            author: string(object, "author", at: "$"),
            license: license,
            homepage: string(object, "homepage", at: "$"),
            size: size,
            contentLayout: contentLayout,
            background: background,
            params: params,
            bindings: bindings,
            nodes: nodes
        )
    }

    private func emptyDefinition() -> OverlayComponentDefinition {
        OverlayComponentDefinition(
            spec: "ros.component/0.1",
            id: "",
            version: "",
            name: OverlayComponentLocalizedText(values: ["en": ""]),
            descriptionText: nil,
            author: nil,
            license: "",
            homepage: nil,
            size: .zero,
            contentLayout: nil,
            background: nil,
            params: [],
            bindings: [:],
            nodes: []
        )
    }

    // MARK: - Document fields

    private func parseSize(_ value: OverlayJSONValue?) -> OverlayComponentSize {
        guard let value else {
            error("$.size", "size is required")
            return .zero
        }
        guard case .array(let values) = value, values.count == 2 else {
            error("$.size", "size must be [width, height]")
            return .zero
        }
        let width = number(values[0], at: "$.size[0]") ?? 0
        let height = number(values[1], at: "$.size[1]") ?? 0
        if !(8...8192).contains(width) { error("$.size[0]", "must be 8...8192") }
        if !(8...8192).contains(height) { error("$.size[1]", "must be 8...8192") }
        return OverlayComponentSize(width: width, height: height)
    }

    private func parseContentLayout(_ object: [String: OverlayJSONValue]) -> OverlayComponentContentLayout {
        func pair(_ key: String) -> (OverlayComponentNumberSource, OverlayComponentNumberSource) {
            guard let value = object[key] else { return (.literal(0), .literal(0)) }
            guard case .array(let items) = value, items.count == 2 else {
                error("$.\(key)", "\(key) must be [x, y]")
                return (.literal(0), .literal(0))
            }
            return (
                numberSource(items[0], at: "$.\(key)[0]") ?? .literal(0),
                numberSource(items[1], at: "$.\(key)[1]") ?? .literal(0)
            )
        }
        let padding = pair("padding")
        let minSize = pair("minSize")
        return OverlayComponentContentLayout(
            paddingX: padding.0,
            paddingY: padding.1,
            minWidth: minSize.0,
            minHeight: minSize.1
        )
    }

    private func parseBackground(_ value: OverlayJSONValue?, path: String) -> OverlayComponentBackground? {
        guard let value else { return nil }
        guard let object = object(value, at: path, allowed: ["color", "radius"]) else {
            return nil
        }
        guard let colorValue = object["color"] else {
            error(path, "background.color is required")
            return nil
        }
        return OverlayComponentBackground(
            color: colorSource(colorValue, at: "\(path).color") ?? .literal(.black),
            radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") }
        )
    }

    private func parseParams(_ value: OverlayJSONValue?, path: String) -> [OverlayComponentParam] {
        guard let value else { return [] }
        guard case .array(let items) = value else {
            error(path, "params must be an array")
            return []
        }
        if items.count > 96 { error(path, "at most 96 params are allowed") }
        return items.enumerated().compactMap { index, item in
            parseParam(item, at: "\(path)[\(index)]")
        }
    }

    private func parseParam(_ value: OverlayJSONValue, at path: String) -> OverlayComponentParam? {
        guard case .object(let object) = value else {
            error(path, "param must be an object")
            return nil
        }
        let id = string(object, "id", at: "\(path).id") ?? ""
        if !matches(id, "^[a-z][a-zA-Z0-9_]*$") {
            error("\(path).id", "must match [a-z][a-zA-Z0-9_]*")
        } else if !parameterIDs.insert(id).inserted {
            error("\(path).id", "duplicate param id '\(id)'")
        }

        let label = localizedText(object["label"], at: "\(path).label", required: true)
            ?? OverlayComponentLocalizedText(values: ["en": id])
        let section = localizedText(object["section"], at: "\(path).section")
        let description = localizedText(object["description"], at: "\(path).description")
        let isAdvanced = bool(object, "advanced", at: "\(path).advanced") ?? false
        let whenExpression = object["when"].flatMap { expression($0, at: "\(path).when") }

        guard let type = string(object, "type", at: "\(path).type") else {
            return nil
        }

        let commonKeys: Set<String> = [
            "id", "type", "label", "section", "description", "default",
            "advanced", "when"
        ]
        let typeKeys: Set<String>
        switch type {
        case "number": typeKeys = ["min", "max", "step", "unit", "style"]
        case "enum": typeKeys = ["options"]
        case "string": typeKeys = ["maxLength"]
        case "metric": typeKeys = ["signals", "series"]
        default: typeKeys = []
        }
        checkUnknownKeys(object, allowed: commonKeys.union(typeKeys), at: path)

        let kind: OverlayComponentParamKind
        let defaultValue: OverlayComponentValue

        switch type {
        case "number":
            guard let minimum = number(object["min"], at: "\(path).min", required: true),
                  let maximum = number(object["max"], at: "\(path).max", required: true),
                  let fallback = number(object["default"], at: "\(path).default", required: true) else {
                return nil
            }
            if minimum > maximum { error(path, "min must not exceed max") }
            if !(minimum...maximum).contains(fallback) {
                error("\(path).default", "must be within min...max")
            }
            let step = number(object["step"], at: "\(path).step")
            if let step, step <= 0 { error("\(path).step", "must be positive") }
            let style = rawEnumValue(
                object,
                "style",
                at: "\(path).style",
                default: OverlayComponentParamNumberStyle.slider
            )
            kind = .number(
                minimum: minimum,
                maximum: maximum,
                step: step,
                unit: string(object, "unit", at: "\(path).unit"),
                style: style
            )
            defaultValue = .number(fallback)

        case "bool":
            guard let fallback = bool(object, "default", at: "\(path).default", required: true) else {
                return nil
            }
            kind = .boolean
            defaultValue = .boolean(fallback)

        case "color":
            guard case .string(let fallback)? = object["default"],
                  let color = OverlayComponentColorParser.parse(fallback) else {
                error("\(path).default", "must be a color literal")
                return nil
            }
            kind = .color
            defaultValue = .color(color)

        case "enum":
            guard case .array(let rawOptions)? = object["options"] else {
                error("\(path).options", "options are required")
                return nil
            }
            if !(2...32).contains(rawOptions.count) {
                error("\(path).options", "must contain 2...32 options")
            }
            var options: [OverlayComponentParamOption] = []
            var seen: Set<String> = []
            for (index, rawOption) in rawOptions.enumerated() {
                let optionPath = "\(path).options[\(index)]"
                guard case .object(let optionObject) = rawOption else {
                    error(optionPath, "option must be an object")
                    continue
                }
                checkUnknownKeys(optionObject, allowed: ["value", "label"], at: optionPath)
                guard let optionValue = string(optionObject, "value", at: "\(optionPath).value"),
                      let optionLabel = localizedText(
                        optionObject["label"], at: "\(optionPath).label", required: true
                      ) else {
                    continue
                }
                if !seen.insert(optionValue).inserted {
                    error("\(optionPath).value", "duplicate option value")
                }
                options.append(OverlayComponentParamOption(value: optionValue, label: optionLabel))
            }
            guard let fallback = string(object, "default", at: "\(path).default") else {
                return nil
            }
            if !options.contains(where: { $0.value == fallback }) {
                error("\(path).default", "must match an option value")
            }
            kind = .enumeration(options: options)
            defaultValue = .string(fallback)

        case "string":
            let maximum = number(object["maxLength"], at: "\(path).maxLength").map { Int($0) } ?? 64
            if !(1...512).contains(maximum) { error("\(path).maxLength", "must be 1...512") }
            guard let fallback = string(object, "default", at: "\(path).default", required: true) else {
                return nil
            }
            if fallback.count > maximum {
                error("\(path).default", "exceeds maxLength")
            }
            kind = .string(maxLength: maximum)
            defaultValue = .string(fallback)

        case "font":
            guard let fallback = string(object, "default", at: "\(path).default", required: true) else {
                return nil
            }
            kind = .font
            defaultValue = .string(fallback)

        case "metric":
            guard case .array(let rawSignals)? = object["signals"] else {
                error("\(path).signals", "signals are required")
                return nil
            }
            let signals = rawSignals.compactMap { item -> String? in
                guard case .string(let signal) = item else {
                    error("\(path).signals", "signals must be strings")
                    return nil
                }
                if !OverlayComponentSignalCatalog.seriesSignals.contains(signal) {
                    error("\(path).signals", "unknown or unsupported signal '\(signal)'")
                }
                return signal
            }
            guard let fallback = string(object, "default", at: "\(path).default", required: true) else {
                return nil
            }
            if !signals.contains(fallback) {
                error("\(path).default", "must be one of the declared signals")
            }
            kind = .metric(
                signals: signals,
                allowsSeries: bool(object, "series", at: "\(path).series") ?? false
            )
            defaultValue = .string(fallback)

        default:
            error("\(path).type", "unknown param type '\(type)'")
            return nil
        }

        return OverlayComponentParam(
            id: id,
            label: label,
            section: section,
            descriptionText: description,
            isAdvanced: isAdvanced,
            whenExpression: whenExpression,
            kind: kind,
            defaultValue: defaultValue
        )
    }

    private func parseBindings(_ value: OverlayJSONValue?, path: String) -> [String: OverlayComponentBinding] {
        guard let value else { return [:] }
        guard case .object(let object) = value else {
            error(path, "bindings must be an object")
            return [:]
        }
        if object.count > 64 { error(path, "at most 64 bindings are allowed") }
        var result: [String: OverlayComponentBinding] = [:]
        for (name, rawBinding) in object {
            let bindingPath = "\(path).\(name)"
            if !matches(name, "^[A-Za-z_][A-Za-z0-9_]*$") {
                error(bindingPath, "invalid binding name")
                continue
            }
            if OverlayComponentSignalCatalog.builtinNames.contains(name)
                || ["width", "height", "pi", "true", "false", "null"].contains(name) {
                error(bindingPath, "binding name shadows a builtin")
                continue
            }
            guard case .object(let bindingObject) = rawBinding else {
                error(bindingPath, "binding must be an object")
                continue
            }
            let kinds = ["signal", "series", "list", "value"].filter { bindingObject[$0] != nil }
            if kinds.count != 1 {
                error(bindingPath, "binding must contain exactly one of signal, series, list, value")
                continue
            }
            if let rawSignal = bindingObject["signal"] {
                checkUnknownKeys(bindingObject, allowed: ["signal"], at: bindingPath)
                guard case .string(let signal) = rawSignal else {
                    error("\(bindingPath).signal", "must be a string")
                    continue
                }
                if !OverlayComponentSignalCatalog.scalarSignals.contains(signal),
                   !OverlayComponentSignalCatalog.recordSignals.contains(signal) {
                    error("\(bindingPath).signal", "unknown signal '\(signal)'")
                    continue
                }
                result[name] = .signal(signal)
            } else if let rawSeries = bindingObject["series"] {
                checkUnknownKeys(bindingObject, allowed: ["series", "window", "samples"], at: bindingPath)
                guard case .string(let seriesPath) = rawSeries else {
                    error("\(bindingPath).series", "must be a string")
                    continue
                }
                if !OverlayComponentSignalCatalog.seriesSignals.contains(seriesPath) {
                    error("\(bindingPath).series", "unsupported series '\(seriesPath)'")
                    continue
                }
                let windowValue = bindingObject["window"]
                let window: OverlayComponentSeriesWindow
                if case .string("full")? = windowValue {
                    window = .full
                } else if case .array(let range)? = windowValue, range.count == 2,
                          let start = number(range[0], at: "\(bindingPath).window[0]"),
                          let end = number(range[1], at: "\(bindingPath).window[1]") {
                    window = .relative(start: start, end: end)
                } else if windowValue == nil {
                    window = .full
                } else {
                    error("\(bindingPath).window", "must be 'full' or [start, end]")
                    window = .full
                }
                let samples = number(bindingObject["samples"], at: "\(bindingPath).samples").map { Int($0) } ?? 60
                if !(2...1024).contains(samples) {
                    error("\(bindingPath).samples", "must be 2...1024")
                }
                result[name] = .series(path: seriesPath, window: window, samples: samples)
            } else if let rawValue = bindingObject["value"] {
                checkUnknownKeys(bindingObject, allowed: ["value"], at: bindingPath)
                guard let parsed = expression(rawValue, at: "\(bindingPath).value") else {
                    continue
                }
                result[name] = .value(parsed)
            } else if let rawList = bindingObject["list"] {
                checkUnknownKeys(bindingObject, allowed: ["list"], at: bindingPath)
                guard case .string(let listPath) = rawList else {
                    error("\(bindingPath).list", "must be a string")
                    continue
                }
                if !OverlayComponentSignalCatalog.listSignals.contains(listPath) {
                    error("\(bindingPath).list", "unsupported list '\(listPath)'")
                    continue
                }
                result[name] = .list(listPath)
            } else {
                error(bindingPath, "binding must contain exactly one of signal, series, list, value")
            }
        }
        return result
    }

    // MARK: - Nodes

    private func parseNodes(
        _ value: OverlayJSONValue?,
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool = false
    ) -> [OverlayComponentNode] {
        guard let value else {
            error(path, "nodes are required")
            return []
        }
        guard case .array(let items) = value else {
            error(path, "nodes must be an array")
            return []
        }
        if items.count > 512 { error(path, "at most 512 nodes are allowed") }
        if depth > 16 { error(path, "group nesting exceeds 16 levels") }
        return items.enumerated().compactMap { index, item in
            parseNode(
                item,
                at: "\(path)[\(index)]",
                depth: depth,
                insideRepeat: insideRepeat,
                insideStack: insideStack
            )
        }
    }

    private func parseNode(
        _ value: OverlayJSONValue,
        at path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool
    ) -> OverlayComponentNode? {
        guard case .object(let object) = value else {
            error(path, "node must be an object")
            return nil
        }
        guard let type = string(object, "type", at: "\(path).type") else { return nil }

        let commonKeys: Set<String> = ["type", "id", "frame", "if", "opacity", "alignSelf"]
        let typeKeys: Set<String>
        switch type {
        case "group": typeKeys = ["children", "clip", "shadow", "shadows", "shadowBounds"]
        case "stack": typeKeys = ["direction", "spacing", "crossAlign", "children"]
        case "rect": typeKeys = ["fill", "radius", "stroke", "strokeWidth"]
        case "circle": typeKeys = ["center", "radius", "fill", "stroke", "strokeWidth"]
        case "line": typeKeys = ["from", "to", "width", "color", "cap"]
        case "polyline": typeKeys = ["points", "width", "color", "cap", "join", "dash"]
        case "path": typeKeys = ["commands", "fill", "stroke", "strokeWidth", "cap", "join", "dash"]
        case "text": typeKeys = ["text", "font", "color", "align", "verticalAlign", "maxWidth", "lineHeight", "tracking"]
        case "richText": typeKeys = ["text", "font", "color", "align", "lineHeight", "tracking", "stroke", "strokeWidth", "autoFit", "gradient"]
        case "textRows": typeKeys = ["rows", "spacing", "maxWidth"]
        case "image": typeKeys = ["asset", "fit"]
        case "symbol": typeKeys = ["name", "color", "weight", "scale", "rendering"]
        case "spacer": typeKeys = ["length", "min"]
        case "columns": typeKeys = ["width", "divider", "children"]
        case "gradientRect": typeKeys = ["stops", "from", "to", "radius"]
        case "sparkline": typeKeys = ["series", "stroke", "lineWidth", "fill", "smoothing"]
        case "progressBar": typeKeys = ["value", "trackColor", "fillColor", "radius"]
        case "arc": typeKeys = ["value", "startDegrees", "sweepDegrees", "radius", "width", "trackColor", "fillColor", "cap"]
        case "segmentedBar": typeKeys = ["orientation", "segments", "activeIndex", "activeWidthShare", "activeThicknessScale", "gap", "radius", "inactiveOpacity", "glow", "border", "markers"]
        case "runningGauge": typeKeys = [
            "layoutPreset", "progress", "dialBackgroundColor", "dialBackgroundOpacity",
            "glassEffectEnabled", "outerRingEnabled", "outerRingColor", "outerRingOpacity",
            "outerRingWidthScale", "tickMarksEnabled", "tickColor", "tickOpacity",
            "majorTickOpacity", "tickCount", "majorTickEvery", "progressRingEnabled",
            "progressColor", "progressTrackColor", "progressTrackOpacity",
            "progressRingWidthScale", "progressRoundedCaps", "dividerEnabled",
            "dividerColor", "dividerOpacity", "dividerWidth", "font", "monospacedDigits",
            "primaryFontWeight", "secondaryFontWeight", "primaryTextColor",
            "secondaryTextColor", "accentColor", "regions"
        ]
        case "weatherWidget": typeKeys = [
            "dataSource", "preset", "condition", "temperatureC", "humidity", "highC", "lowC",
            "windKph", "feelsLikeC", "temperatureUnit", "useActivityTemperature",
            "locationText", "showLocation", "showWeekday", "showHumidity",
            "showHighLow", "showWind", "showFeelsLike", "showIcon",
            "showConditionLabel", "conditionLabelOverride", "humiditySuffix",
            "humidityMetricLabel", "windMetricLabel", "feelsLikeMetricLabel",
            "cardBackgroundColor", "cardBackgroundOpacity", "cardCornerRadius",
            "dividerEnabled", "dividerColor", "dividerThickness", "dividerOpacity",
            "palette", "iconSize", "slotBackgroundColor", "slotBackgroundOpacity",
            "slotSpacing", "fontFamily",
            "locationFontSize", "locationFontWeight", "locationColor",
            "conditionFontSize", "conditionFontWeight", "conditionColor",
            "temperatureFontSize", "temperatureFontWeight", "temperatureColor",
            "slotTitleFontSize", "slotTitleFontWeight", "slotTitleColor",
            "slotLabelFontSize", "slotLabelFontWeight", "slotLabelColor"
        ]
        case "routeMap": typeKeys = [
            "shape", "backgroundStyle", "cornerRadius", "backgroundOpacity",
            "startMarkerStyle", "endMarkerStyle", "runnerMarkerStyle",
            "startMarkerColor", "endMarkerColor", "runnerMarkerColor",
            "glowEnabled", "mapOpacity", "borderEnabled", "borderColor",
            "borderOpacity", "borderWidth", "foregroundColor", "fontFamily",
            "fontSize", "fontWeight", "edgeFade", "fadeAmount", "colorMode",
            "gradientStart", "gradientMiddle", "gradientEnd", "zoom",
            "showsPointsOfInterest", "width", "height"
        ]
        case "elevationChart": typeKeys = [
            "preset", "chartStyle", "smoothingEnabled", "smoothingAmount",
            "progressMode", "chartPaddingX", "chartPaddingY", "lineColor",
            "lineWidth", "lineOpacity", "fillEnabled", "fillStartColor",
            "fillEndColor", "fillOpacity", "dualAreaEnabled", "upperFillColor",
            "lowerFillColor", "currentMarkerEnabled", "markerColor",
            "markerSizeMultiplier", "markerPlayheadLineEnabled", "markerLabelEnabled",
            "gridEnabled", "axisLineEnabled", "axisLabelsEnabled", "bigNumbersEnabled",
            "bigNumberMetric", "bigNumberFontSize", "bigNumberFontFamily",
            "bigNumberFontWeight", "backgroundEnabled", "backgroundColor",
            "backgroundOpacity", "cornerRadius", "borderEnabled", "borderOpacity",
            "shadowEnabled", "shadowOpacity", "shadowRadius", "glowEnabled",
            "glowOpacity", "fontFamily", "foregroundColor", "valueFontSize",
            "width", "height"
        ]
        case "distanceTimeline": typeKeys = [
            "preset", "valueFontSize", "valueUnitSystem", "showValue", "showTotalDistance",
            "showLabel", "label", "labelFontFamily", "labelFontSize", "labelFontWeight",
            "labelColor", "labelValueSpacing", "showAxisLabels", "axisLabelMode",
            "axisLabelOffset", "axisLabelFontFamily", "axisLabelFontSize",
            "axisLabelFontWeight", "axisLabelColor", "showDistancePoints",
            "distancePointCount", "distancePointOffset", "midpointAxisLabelOffset",
            "axisEndpointLabelPlacement", "axisMidpointLabelPlacement",
            "markerDistanceLabelEnabled", "markerDistanceLabelPlacement",
            "markerDistanceLabelOffset", "currentMarkerSizeMultiplier",
            "backgroundEnabled", "backgroundColor", "backgroundOpacity", "borderEnabled",
            "borderColor", "borderOpacity", "borderWidth", "cornerRadius", "paddingX",
            "paddingY", "trackHeight", "trackOpacity", "fillColor", "tickMarksEnabled",
            "tickDensity", "currentMarkerEnabled", "currentMarkerStyle",
            "currentMarkerColor", "glowEnabled", "fadeEnabled", "fadeEdge", "fadeAmount",
            "mediaSlotEnabled", "mediaSlotMode", "mediaSystemImage", "mediaSlotSize",
            "elevationProfileVisible", "width", "height"
        ]
        case "timelineStrip": typeKeys = [
            "segments", "currentIndex", "elapsed", "mode", "emphasisFraction", "window",
            "showsWarmup", "showsRest", "showsCooldown", "segmentAreaHeight", "segmentHeight",
            "currentHeightScale", "minSegmentWidth", "gap", "radius",
            "currentBorderWidth", "completedOpacity", "futureOpacity", "colors",
            "labels", "progress", "marker", "overflow", "repText", "distanceProgress"
        ]
        case "repeat": typeKeys = ["over", "as", "index", "max", "children"]
        default:
            error("\(path).type", "unknown node type '\(type)'")
            return nil
        }
        checkUnknownKeys(object, allowed: commonKeys.union(typeKeys), at: path)

        let id = string(object, "id", at: "\(path).id")
        if let id {
            if !matches(id, "^[A-Za-z][A-Za-z0-9_-]*$") {
                error("\(path).id", "invalid node id")
            } else if !nodeIDs.insert(id).inserted {
                error("\(path).id", "duplicate node id '\(id)'")
            }
        }

        let frameRequired: Set<String> = [
            "rect", "image", "symbol", "gradientRect", "richText",
            "sparkline", "progressBar", "arc", "repeat", "segmentedBar",
            "timelineStrip", "runningGauge", "distanceTimeline", "elevationChart", "routeMap",
            "weatherWidget"
        ]
        let frame = parseFrame(object["frame"], at: "\(path).frame", required: frameRequired.contains(type))
        let condition = object["if"].flatMap { expression($0, at: "\(path).if") }
        let opacity = object["opacity"].flatMap { numberSource($0, at: "\(path).opacity") }
        var alignSelf: OverlayComponentStringSource?
        if object["alignSelf"] != nil {
            if insideStack {
                alignSelf = enumSource(
                    object,
                    "alignSelf",
                    at: "\(path).alignSelf",
                    as: OverlayComponentCrossAlignment.self
                )
            } else {
                error("\(path).alignSelf", "alignSelf is only valid on a stack child")
            }
        }

        let kind: OverlayComponentNodeKind?
        switch type {
        case "group":
            kind = parseGroupKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "stack":
            kind = parseStackKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "rect":
            kind = parseRectKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "circle":
            kind = parseCircleKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "line":
            kind = parseLineKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "polyline":
            kind = parsePolylineKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "path":
            kind = parsePathKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "text":
            kind = parseTextKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "richText":
            kind = parseRichTextKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "textRows":
            kind = parseTextRowsKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "image":
            kind = parseImageKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "spacer":
            kind = parseSpacerKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "columns":
            kind = parseColumnsKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "symbol":
            kind = parseSymbolKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "gradientRect":
            kind = parseGradientRectKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "sparkline":
            kind = parseSparklineKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "progressBar":
            kind = parseProgressBarKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "arc":
            kind = parseArcKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "repeat":
            kind = parseRepeatKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "segmentedBar":
            kind = parseSegmentedBarKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "timelineStrip":
            kind = parseTimelineStripKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "runningGauge":
            kind = parseRunningGaugeKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "distanceTimeline":
            kind = parseDistanceTimelineKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "elevationChart":
            kind = parseElevationChartKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "routeMap":
            kind = parseRouteMapKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        case "weatherWidget":
            kind = parseWeatherWidgetKind(object: object, path: path, depth: depth, insideRepeat: insideRepeat, insideStack: insideStack, frame: frame)
        default:
            return nil
        }

        guard let kind else { return nil }
        return OverlayComponentNode(
            id: id,
            frame: frame,
            condition: condition,
            opacity: opacity,
            kind: kind,
            alignSelf: alignSelf
        )
    }


    @inline(never)
    private func parseTimelineStripNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentTimelineStrip? {
            guard let segments = object["segments"].flatMap({ expression($0, at: "\(path).segments") }) else {
                error(path, "timelineStrip requires segments")
                return nil
            }
            guard let colors = parseTimelineColors(object["colors"], at: "\(path).colors") else {
                error("\(path).colors", "colors requires warmup, active, rest, cooldown and unknown")
                return nil
            }
            var labels: OverlayComponentTimelineStrip.Labels?
            if let rawLabels = object["labels"] {
                guard case .object(let labelObject) = rawLabels,
                      let font = parseFont(labelObject["font"], at: "\(path).labels.font") else {
                    error("\(path).labels", "labels requires font")
                    return nil
                }
                checkUnknownKeys(labelObject, allowed: [
                    "font", "currentWorkDistance", "currentWorkTime", "currentRestKind",
                    "currentRestDistance", "currentRestTime", "neighbor"
                ], at: "\(path).labels")
                labels = OverlayComponentTimelineStrip.Labels(
                    font: font,
                    currentWorkDistance: labelObject["currentWorkDistance"].flatMap {
                        timelineEnumSource($0, at: "\(path).labels.currentWorkDistance", allowed: ["hidden", "elapsed", "remaining"])
                    },
                    currentWorkTime: labelObject["currentWorkTime"].flatMap {
                        timelineEnumSource($0, at: "\(path).labels.currentWorkTime", allowed: ["hidden", "elapsed", "remaining"])
                    },
                    currentRestKind: labelObject["currentRestKind"].flatMap {
                        numberSource($0, at: "\(path).labels.currentRestKind")
                    },
                    currentRestDistance: labelObject["currentRestDistance"].flatMap {
                        timelineEnumSource($0, at: "\(path).labels.currentRestDistance", allowed: ["hidden", "elapsed", "remaining"])
                    },
                    currentRestTime: labelObject["currentRestTime"].flatMap {
                        timelineEnumSource($0, at: "\(path).labels.currentRestTime", allowed: ["hidden", "elapsed", "remaining"])
                    },
                    neighbor: labelObject["neighbor"].flatMap {
                        timelineEnumSource($0, at: "\(path).labels.neighbor", allowed: ["hidden", "distance", "time"])
                    }
                )
            }
            var progress: OverlayComponentTimelineStrip.Progress?
            if let rawProgress = object["progress"] {
                guard case .object(let progressObject) = rawProgress,
                      let value = progressObject["value"].flatMap({ numberSource($0, at: "\(path).progress.value") }),
                      let progressColor = progressObject["color"].flatMap({ colorSource($0, at: "\(path).progress.color") }) else {
                    error("\(path).progress", "progress requires value and color")
                    return nil
                }
                checkUnknownKeys(progressObject, allowed: ["value", "color", "opacity"], at: "\(path).progress")
                progress = OverlayComponentTimelineStrip.Progress(
                    value: value,
                    color: progressColor,
                    opacity: progressObject["opacity"].flatMap { numberSource($0, at: "\(path).progress.opacity") }
                )
            }
            var marker: OverlayComponentTimelineStrip.Marker?
            if let rawMarker = object["marker"] {
                guard case .object(let markerObject) = rawMarker,
                      let markerColor = markerObject["color"].flatMap({ colorSource($0, at: "\(path).marker.color") }),
                      let markerFont = parseFont(markerObject["font"], at: "\(path).marker.font") else {
                    error("\(path).marker", "marker requires color and font")
                    return nil
                }
                checkUnknownKeys(markerObject, allowed: [
                    "enabled", "position", "color", "label", "showsLabel", "font"
                ], at: "\(path).marker")
                marker = OverlayComponentTimelineStrip.Marker(
                    enabled: markerObject["enabled"].flatMap { numberSource($0, at: "\(path).marker.enabled") },
                    position: markerObject["position"].flatMap {
                        timelineEnumSource($0, at: "\(path).marker.position", allowed: ["progress", "center"])
                    },
                    color: markerColor,
                    label: markerObject["label"].flatMap { stringSource($0, at: "\(path).marker.label") },
                    showsLabel: markerObject["showsLabel"].flatMap { numberSource($0, at: "\(path).marker.showsLabel") },
                    font: markerFont
                )
            }
            var overflow: OverlayComponentTimelineStrip.Overflow?
            if let rawOverflow = object["overflow"] {
                guard case .object(let overflowObject) = rawOverflow,
                      let overflowColor = overflowObject["color"].flatMap({ colorSource($0, at: "\(path).overflow.color") }) else {
                    error("\(path).overflow", "overflow requires color")
                    return nil
                }
                checkUnknownKeys(overflowObject, allowed: ["enabled", "text", "color", "inset"], at: "\(path).overflow")
                overflow = OverlayComponentTimelineStrip.Overflow(
                    enabled: overflowObject["enabled"].flatMap { numberSource($0, at: "\(path).overflow.enabled") },
                    text: overflowObject["text"].flatMap { stringSource($0, at: "\(path).overflow.text") },
                    color: overflowColor,
                    inset: overflowObject["inset"].flatMap { numberSource($0, at: "\(path).overflow.inset") }
                )
            }
        return OverlayComponentTimelineStrip(
                segments: segments,
                currentIndex: object["currentIndex"].flatMap { numberSource($0, at: "\(path).currentIndex") },
                elapsed: object["elapsed"].flatMap { numberSource($0, at: "\(path).elapsed") },
                mode: object["mode"].flatMap {
                    timelineEnumSource($0, at: "\(path).mode", allowed: ["emphasized", "equal", "weighted"])
                },
                emphasisFraction: object["emphasisFraction"].flatMap { numberSource($0, at: "\(path).emphasisFraction") },
                window: object["window"].flatMap { numberSource($0, at: "\(path).window") },
                showsWarmup: object["showsWarmup"].flatMap { numberSource($0, at: "\(path).showsWarmup") },
                showsRest: object["showsRest"].flatMap { numberSource($0, at: "\(path).showsRest") },
                showsCooldown: object["showsCooldown"].flatMap { numberSource($0, at: "\(path).showsCooldown") },
                segmentAreaHeight: object["segmentAreaHeight"].flatMap { numberSource($0, at: "\(path).segmentAreaHeight") },
                segmentHeight: object["segmentHeight"].flatMap { numberSource($0, at: "\(path).segmentHeight") },
                currentHeightScale: object["currentHeightScale"].flatMap { numberSource($0, at: "\(path).currentHeightScale") },
                minSegmentWidth: object["minSegmentWidth"].flatMap { numberSource($0, at: "\(path).minSegmentWidth") },
                gap: object["gap"].flatMap { numberSource($0, at: "\(path).gap") },
                radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") },
                currentBorderWidth: object["currentBorderWidth"].flatMap { numberSource($0, at: "\(path).currentBorderWidth") },
                completedOpacity: object["completedOpacity"].flatMap { numberSource($0, at: "\(path).completedOpacity") },
                futureOpacity: object["futureOpacity"].flatMap { numberSource($0, at: "\(path).futureOpacity") },
                colors: colors,
                labels: labels,
                progress: progress,
                marker: marker,
                overflow: overflow,
                repText: object["repText"].flatMap { stringSource($0, at: "\(path).repText") },
                distanceProgress: object["distanceProgress"].flatMap { numberSource($0, at: "\(path).distanceProgress") }
            )

    }

    @inline(never)
    private func parseGroupKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawChildren = object["children"],
              case .array(let childrenArray) = rawChildren else {
            error("\(path).children", "group requires children")
            return nil
        }
        let children = parseNodes(rawChildren, path: "\(path).children", depth: depth + 1, insideRepeat: insideRepeat)
        if childrenArray.isEmpty { error("\(path).children", "group requires at least one child") }
        var shadows: [OverlayComponentShadow] = []
        if let shadow = parseShadow(object["shadow"], at: "\(path).shadow") {
            shadows.append(shadow)
        }
        if let rawShadows = object["shadows"] {
            guard case .array(let items) = rawShadows else {
                error("\(path).shadows", "shadows must be an array")
                return nil
            }
            for (index, item) in items.enumerated() {
                if let shadow = parseShadow(item, at: "\(path).shadows[\(index)]") {
                    shadows.append(shadow)
                }
            }
        }
        let shadowBounds = object["shadowBounds"].flatMap {
            parseFrame($0, at: "\(path).shadowBounds", required: true)
        }
        return .group(
            children: children,
            clip: bool(object, "clip", at: "\(path).clip") ?? false,
            shadows: shadows,
            shadowBounds: shadowBounds
        )
    }

    @inline(never)
    private func parseStackKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawChildren = object["children"],
              case .array(let childrenArray) = rawChildren else {
            error("\(path).children", "stack requires children")
            return nil
        }
        let children = parseNodes(
            rawChildren,
            path: "\(path).children",
            depth: depth + 1,
            insideRepeat: insideRepeat,
            insideStack: true
        )
        if childrenArray.isEmpty {
            error("\(path).children", "stack requires at least one child")
        }
        for (index, child) in children.enumerated() where !isBoxed(child) {
            error(
                "\(path).children[\(index)].frame",
                "stack child requires a frame unless it is text or a stack; wrap circle, line, polyline and path in a group"
            )
        }
        return .stack(
            direction: enumSource(
                object,
                "direction",
                at: "\(path).direction",
                as: OverlayComponentStackDirection.self
            ) ?? .literal(OverlayComponentStackDirection.horizontal.rawValue),
            spacing: object["spacing"].flatMap { numberSource($0, at: "\(path).spacing") }
                ?? .literal(0),
            crossAlign: enumSource(
                object,
                "crossAlign",
                at: "\(path).crossAlign",
                as: OverlayComponentCrossAlignment.self
            ) ?? .literal(OverlayComponentCrossAlignment.start.rawValue),
            children: children
        )
    }

    @inline(never)
    private func parseRectKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let fillValue = object["fill"] else {
            error("\(path).fill", "fill is required")
            return nil
        }
        return .rect(
            fill: colorSource(fillValue, at: "\(path).fill") ?? .literal(.black),
            radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") } ?? .literal(0),
            stroke: object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") },
            strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") }
        )
    }

    @inline(never)
    private func parseCircleKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let center = object["center"].flatMap({ point($0, at: "\(path).center") }),
              let radius = object["radius"].flatMap({ numberSource($0, at: "\(path).radius") }) else {
            error(path, "circle requires center and radius")
            return nil
        }
        return .circle(
            center: center,
            radius: radius,
            fill: object["fill"].flatMap { colorSource($0, at: "\(path).fill") },
            stroke: object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") },
            strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") }
        )
    }

    @inline(never)
    private func parseLineKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let from = object["from"].flatMap({ point($0, at: "\(path).from") }),
              let to = object["to"].flatMap({ point($0, at: "\(path).to") }),
              let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "line requires from, to, width and color")
            return nil
        }
        return .line(
            from: from,
            to: to,
            width: width,
            color: color,
            cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt)
        )
    }

    @inline(never)
    private func parsePolylineKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let pointsValue = object["points"],
              let points = pointsSource(pointsValue, at: "\(path).points"),
              let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "polyline requires points, width and color")
            return nil
        }
        return .polyline(
            points: points,
            width: width,
            color: color,
            cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt),
            join: rawEnumValue(object, "join", at: "\(path).join", default: OverlayComponentLineJoin.miter),
            dash: parseDash(object["dash"], at: "\(path).dash")
        )
    }

    @inline(never)
    private func parsePathKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let commandsValue = object["commands"],
              case .array(let commandItems) = commandsValue else {
            error("\(path).commands", "path requires commands")
            return nil
        }
        var commands: [OverlayComponentPathCommand] = []
        for (index, item) in commandItems.enumerated() {
            if let command = parsePathCommand(item, at: "\(path).commands[\(index)]") {
                commands.append(command)
            }
        }
        let fill = object["fill"].flatMap { colorSource($0, at: "\(path).fill") }
        let stroke = object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") }
        if fill == nil && stroke == nil {
            error(path, "path requires fill or stroke")
        }
        return .path(
            commands: commands,
            fill: fill,
            stroke: stroke,
            strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") },
            cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt),
            join: rawEnumValue(object, "join", at: "\(path).join", default: OverlayComponentLineJoin.miter),
            dash: parseDash(object["dash"], at: "\(path).dash")
        )
    }

    @inline(never)
    private func parseTextKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawText = object["text"],
              let text = stringSource(rawText, at: "\(path).text"),
              let font = parseFont(object["font"], at: "\(path).font"),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "text requires text, font and color")
            return nil
        }
        return .text(
            text: text,
            font: font,
            color: color,
            align: rawEnumValue(
                object,
                "align",
                at: "\(path).align",
                default: OverlayComponentTextAlignment.left
            ),
            verticalAlign: rawEnumValue(
                object,
                "verticalAlign",
                at: "\(path).verticalAlign",
                default: OverlayComponentVerticalAlignment.top
            ),
            maxWidth: object["maxWidth"].flatMap { numberSource($0, at: "\(path).maxWidth") },
            lineHeight: object["lineHeight"].flatMap { numberSource($0, at: "\(path).lineHeight") },
            tracking: object["tracking"].flatMap { numberSource($0, at: "\(path).tracking") }
        )
    }

    @inline(never)
    private func parseRichTextKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawText = object["text"],
              let text = stringSource(rawText, at: "\(path).text"),
              let font = parseFont(object["font"], at: "\(path).font"),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "richText requires text, font and color")
            return nil
        }
        let autoFit: OverlayComponentExpression?
        if case .boolean(let enabled)? = object["autoFit"] {
            autoFit = .literal(.boolean(enabled))
        } else {
            autoFit = object["autoFit"].flatMap { expression($0, at: "\(path).autoFit") }
        }
        return .richText(OverlayComponentRichText(
            text: text,
            font: font,
            color: color,
            align: enumSource(object, "align", at: "\(path).align", as: OverlayComponentTextAlignment.self) ?? .literal("center"),
            lineHeight: object["lineHeight"].flatMap { numberSource($0, at: "\(path).lineHeight") },
            tracking: object["tracking"].flatMap { numberSource($0, at: "\(path).tracking") },
            stroke: object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") },
            strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") },
            autoFit: autoFit,
            gradient: parseTextGradient(object["gradient"], at: "\(path).gradient")
        ))
    }

    @inline(never)
    private func parseTextRowsKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawRows = object["rows"], case .array(let rowItems) = rawRows,
              !rowItems.isEmpty else {
            error("\(path).rows", "textRows requires a non-empty rows array")
            return nil
        }
        var rows: [OverlayComponentTextRow] = []
        for (rowIndex, rowValue) in rowItems.enumerated() {
            let rowPath = "\(path).rows[\(rowIndex)]"
            guard case .object(let rowObject) = rowValue else {
                error(rowPath, "row must be an object")
                return nil
            }
            checkUnknownKeys(rowObject, allowed: ["runs", "spacing", "alignment", "if"], at: rowPath)
            guard let rawRuns = rowObject["runs"], case .array(let runItems) = rawRuns,
                  !runItems.isEmpty else {
                error("\(rowPath).runs", "row requires a non-empty runs array")
                return nil
            }
            var runs: [OverlayComponentTextRowRun] = []
            for (runIndex, runValue) in runItems.enumerated() {
                let runPath = "\(rowPath).runs[\(runIndex)]"
                guard case .object(let runObject) = runValue else {
                    error(runPath, "run must be an object")
                    return nil
                }
                checkUnknownKeys(runObject, allowed: ["text", "font", "color", "minimumScaleFactor", "verticalPadding", "opacity", "monospacedDigits", "if"], at: runPath)
                guard let rawText = runObject["text"], let text = stringSource(rawText, at: "\(runPath).text"),
                      let font = parseFont(runObject["font"], at: "\(runPath).font"),
                      let color = runObject["color"].flatMap({ colorSource($0, at: "\(runPath).color") }) else {
                    error(runPath, "run requires text, font and color")
                    return nil
                }
                runs.append(OverlayComponentTextRowRun(
                    text: text,
                    font: font,
                    color: color,
                    minimumScaleFactor: runObject["minimumScaleFactor"].flatMap { numberSource($0, at: "\(runPath).minimumScaleFactor") },
                    verticalPadding: runObject["verticalPadding"].flatMap { numberSource($0, at: "\(runPath).verticalPadding") },
                    opacity: runObject["opacity"].flatMap { numberSource($0, at: "\(runPath).opacity") },
                    monospacedDigits: bool(runObject, "monospacedDigits", at: "\(runPath).monospacedDigits") ?? false,
                    condition: runObject["if"].flatMap { expression($0, at: "\(runPath).if") }
                ))
            }
            rows.append(OverlayComponentTextRow(
                runs: runs,
                spacing: rowObject["spacing"].flatMap { numberSource($0, at: "\(rowPath).spacing") },
                alignment: rawEnumValue(rowObject, "alignment", at: "\(rowPath).alignment", default: OverlayComponentTextRowAlignment.center),
                condition: rowObject["if"].flatMap { expression($0, at: "\(rowPath).if") }
            ))
        }
        if frame == nil, object["maxWidth"] == nil {
            error("\(path).maxWidth", "auto-sized textRows requires maxWidth")
        }
        return .textRows(
            rows: rows,
            spacing: object["spacing"].flatMap { numberSource($0, at: "\(path).spacing") },
            maxWidth: object["maxWidth"].flatMap { numberSource($0, at: "\(path).maxWidth") }
        )
    }

    @inline(never)
    private func parseImageKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let asset = string(object, "asset", at: "\(path).asset") else {
            return nil
        }
        if !matches(asset, "^assets/[A-Za-z0-9._-]+\\.(png|jpg|jpeg)$") {
            error("\(path).asset", "invalid asset path")
        } else if !assets.contains(asset) {
            error("\(path).asset", "asset '\(asset)' is not in the package")
        }
        return .image(
            asset: asset,
            fit: rawEnumValue(
                object,
                "fit",
                at: "\(path).fit",
                default: OverlayComponentImageFit.contain
            )
        )
    }

    @inline(never)
    private func parseSpacerKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        if !insideStack {
            error(path, "spacer is only valid as a stack child")
        }
        if object["frame"] != nil {
            error("\(path).frame", "spacer takes a length, not a frame")
        }
        return .spacer(
            length: object["length"].flatMap { numberSource($0, at: "\(path).length") },
            minimum: object["min"].flatMap { numberSource($0, at: "\(path).min") }
        )
    }

    @inline(never)
    private func parseColumnsKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let columns = parseColumns(
            object,
            at: path,
            depth: depth,
            insideRepeat: insideRepeat
        ) else { return nil }
        return columns
    }

    @inline(never)
    private func parseSymbolKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let rawName = object["name"],
              let name = stringSource(rawName, at: "\(path).name"),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "symbol requires name and color")
            return nil
        }
        if case .literal(let literal) = name, !OverlayComponentSymbolName.isValid(literal) {
            error("\(path).name", "invalid SF Symbol name '\(literal)'")
        }
        return .symbol(
            name: name,
            color: color,
            weight: enumSource(object, "weight", at: "\(path).weight", as: OverlayComponentFontWeight.self) ?? .literal("medium"),
            scale: enumSource(object, "scale", at: "\(path).scale", as: OverlayComponentSymbolScale.self) ?? .literal("medium"),
            rendering: rawEnumValue(object, "rendering", at: "\(path).rendering", default: OverlayComponentSymbolRendering.glyph)
        )
    }

    @inline(never)
    private func parseGradientRectKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let stopsValue = object["stops"],
              case .array(let stopItems) = stopsValue,
              let from = object["from"].flatMap({ point($0, at: "\(path).from") }),
              let to = object["to"].flatMap({ point($0, at: "\(path).to") }) else {
            error(path, "gradientRect requires stops, from and to")
            return nil
        }
        var stops: [OverlayComponentGradientStop] = []
        var previousOffset = -Double.infinity
        for (index, item) in stopItems.enumerated() {
            let stopPath = "\(path).stops[\(index)]"
            guard case .object(let stopObject) = item,
                  let offset = number(stopObject["offset"], at: "\(stopPath).offset"),
                  case .string(let colorText)? = stopObject["color"],
                  let color = OverlayComponentColorParser.parse(colorText) else {
                error(stopPath, "stop requires offset and color")
                continue
            }
            if offset < previousOffset {
                error("\(stopPath).offset", "stops must be ordered by offset")
            }
            previousOffset = offset
            stops.append(OverlayComponentGradientStop(offset: offset, color: color))
        }
        if !(2...8).contains(stops.count) {
            error("\(path).stops", "must contain 2...8 stops")
        }
        return .gradientRect(
            stops: stops,
            from: from,
            to: to,
            radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") }
        )
    }

    @inline(never)
    private func parseSparklineKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let seriesValue = object["series"],
              let series = expression(seriesValue, at: "\(path).series"),
              let stroke = object["stroke"].flatMap({ colorSource($0, at: "\(path).stroke") }),
              let lineWidth = object["lineWidth"].flatMap({ numberSource($0, at: "\(path).lineWidth") }) else {
            error(path, "sparkline requires series, stroke and lineWidth")
            return nil
        }
        return .sparkline(
            series: series,
            stroke: stroke,
            lineWidth: lineWidth,
            fill: object["fill"].flatMap { colorSource($0, at: "\(path).fill") },
            smoothing: rawEnumValue(
                object,
                "smoothing",
                at: "\(path).smoothing",
                default: OverlayComponentSmoothing.none
            )
        )
    }

    @inline(never)
    private func parseProgressBarKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let value = object["value"].flatMap({ expression($0, at: "\(path).value") }),
              let trackColor = object["trackColor"].flatMap({ colorSource($0, at: "\(path).trackColor") }),
              let fillColor = object["fillColor"].flatMap({ colorSource($0, at: "\(path).fillColor") }) else {
            error(path, "progressBar requires value, trackColor and fillColor")
            return nil
        }
        return .progressBar(
            value: value,
            trackColor: trackColor,
            fillColor: fillColor,
            radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") }
        )
    }

    @inline(never)
    private func parseArcKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let value = object["value"].flatMap({ expression($0, at: "\(path).value") }),
              let start = object["startDegrees"].flatMap({ numberSource($0, at: "\(path).startDegrees") }),
              let sweep = object["sweepDegrees"].flatMap({ numberSource($0, at: "\(path).sweepDegrees") }),
              let radius = object["radius"].flatMap({ numberSource($0, at: "\(path).radius") }),
              let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
              let fillColor = object["fillColor"].flatMap({ colorSource($0, at: "\(path).fillColor") }) else {
            error(path, "arc requires value, angles, radius, width and fillColor")
            return nil
        }
        return .arc(
            value: value,
            startDegrees: start,
            sweepDegrees: sweep,
            radius: radius,
            width: width,
            trackColor: object["trackColor"].flatMap { colorSource($0, at: "\(path).trackColor") },
            fillColor: fillColor,
            cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt)
        )
    }

    @inline(never)
    private func parseRepeatKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        if insideRepeat {
            error(path, "nested repeat is not allowed")
        }
        guard let over = object["over"].flatMap({ expression($0, at: "\(path).over") }) else {
            return nil
        }
        let itemName = string(object, "as", at: "\(path).as") ?? "item"
        let indexName = string(object, "index", at: "\(path).index") ?? "index"
        for name in [itemName, indexName] {
            if !matches(name, "^[A-Za-z_][A-Za-z0-9_]*$") {
                error(path, "invalid repeat variable name '\(name)'")
            }
        }
        let children = parseNodes(
            object["children"],
            path: "\(path).children",
            depth: depth + 1,
            insideRepeat: true
        )
        return .repeatNode(
            over: over,
            itemName: itemName,
            indexName: indexName,
            maximum: object["max"].flatMap { numberSource($0, at: "\(path).max") },
            children: children
        )
    }

    @inline(never)
    private func parseSegmentedBarKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let segments = object["segments"].flatMap({ expression($0, at: "\(path).segments") }) else {
            error(path, "segmentedBar requires segments")
            return nil
        }
        var markers: [OverlayComponentSegmentedBar.Marker] = []
        if let rawMarkers = object["markers"] {
            guard case .array(let items) = rawMarkers else {
                error("\(path).markers", "markers must be an array")
                return nil
            }
            if items.count > 8 { error("\(path).markers", "at most 8 markers are allowed") }
            markers = items.enumerated().compactMap { index, item in
                parseSegmentedBarMarker(item, at: "\(path).markers[\(index)]")
            }
        }
        var glow: OverlayComponentSegmentedBar.Glow?
        if let rawGlow = object["glow"] {
            guard case .object(let glowObject) = rawGlow,
                  let opacity = glowObject["opacity"].flatMap({ numberSource($0, at: "\(path).glow.opacity") }),
                  let sigma = glowObject["sigma"].flatMap({ numberSource($0, at: "\(path).glow.sigma") }) else {
                error("\(path).glow", "glow requires opacity and sigma")
                return nil
            }
            checkUnknownKeys(glowObject, allowed: ["opacity", "sigma"], at: "\(path).glow")
            glow = OverlayComponentSegmentedBar.Glow(opacity: opacity, sigma: sigma)
        }
        var barBorder: OverlayComponentSegmentedBar.Border?
        if let rawBorder = object["border"] {
            guard case .object(let borderObject) = rawBorder,
                  let borderColor = borderObject["color"].flatMap({ colorSource($0, at: "\(path).border.color") }),
                  let borderOpacity = borderObject["opacity"].flatMap({ numberSource($0, at: "\(path).border.opacity") }),
                  let borderWidth = borderObject["width"].flatMap({ numberSource($0, at: "\(path).border.width") }) else {
                error("\(path).border", "border requires color, opacity and width")
                return nil
            }
            checkUnknownKeys(borderObject, allowed: ["color", "opacity", "width"], at: "\(path).border")
            barBorder = OverlayComponentSegmentedBar.Border(
                color: borderColor, opacity: borderOpacity, width: borderWidth
            )
        }
        return .segmentedBar(OverlayComponentSegmentedBar(
            segments: segments,
            orientation: object["orientation"].flatMap { stringSource($0, at: "\(path).orientation") },
            activeIndex: object["activeIndex"].flatMap { numberSource($0, at: "\(path).activeIndex") },
            activeWidthShare: object["activeWidthShare"].flatMap { numberSource($0, at: "\(path).activeWidthShare") },
            activeThicknessScale: object["activeThicknessScale"].flatMap { numberSource($0, at: "\(path).activeThicknessScale") },
            gap: object["gap"].flatMap { numberSource($0, at: "\(path).gap") },
            radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") },
            inactiveOpacity: object["inactiveOpacity"].flatMap { numberSource($0, at: "\(path).inactiveOpacity") },
            glow: glow,
            border: barBorder,
            markers: markers
        ))
    }

    @inline(never)
    private func parseTimelineStripKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let strip = parseTimelineStripNode(object, at: path) else { return nil }
        return .timelineStrip(strip)
    }

    @inline(never)
    private func parseRunningGaugeKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let gauge = parseRunningGaugeNode(object, at: path) else { return nil }
        return .runningGauge(gauge)
    }

    @inline(never)
    private func parseRunningGaugeNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentRunningGauge? {
        let layoutPresets: Set<String> = [
            "topBottom", "topMiddleBottom", "threeZones", "topTwoMiddleBottom",
            "topThreeMiddleBottom", "fourZones", "fiveZones"
        ]
        let regionNames: Set<String> = [
            "top", "middle", "bottom", "middleLeft", "middleCenter", "middleRight",
            "topLeft", "topRight", "bottomLeft", "bottomCenter", "bottomRight"
        ]
        guard let font = parseFont(object["font"], at: "\(path).font") else {
            error("\(path).font", "font is required")
            return nil
        }
        var regions: [OverlayComponentRunningGauge.Region]?
        if let rawRegions = object["regions"] {
            guard case .array(let items) = rawRegions else {
                error("\(path).regions", "regions must be an array")
                return nil
            }
            if items.count > 12 {
                error("\(path).regions", "at most 12 regions are allowed")
            }
            var parsed: [OverlayComponentRunningGauge.Region] = []
            for (index, item) in items.enumerated() {
                let regionPath = "\(path).regions[\(index)]"
                guard case .object(let regionObject) = item else {
                    error(regionPath, "region must be an object")
                    return nil
                }
                guard let metricValue = regionObject["metric"],
                      let metric = stringSource(metricValue, at: "\(regionPath).metric") else {
                    error("\(regionPath).metric", "region requires metric")
                    return nil
                }
                if case .literal(let literal) = metric, OverlayMetric(rawValue: literal) == nil {
                    error("\(regionPath).metric", "unknown metric '\(literal)'")
                    return nil
                }
                if let rawRegion = regionObject["region"] {
                    _ = timelineEnumSource(rawRegion, at: "\(regionPath).region", allowed: regionNames)
                }
                for key in ["valueWeight", "labelWeight"] {
                    if let rawWeight = regionObject[key] {
                        _ = timelineEnumSource(
                            rawWeight,
                            at: "\(regionPath).\(key)",
                            allowed: Set(OverlayComponentFontWeight.allCases.map(\.rawValue))
                        )
                    }
                }
                parsed.append(OverlayComponentRunningGauge.Region(
                    region: regionObject["region"].flatMap {
                        timelineEnumSource($0, at: "\(regionPath).region", allowed: regionNames)
                    },
                    metric: metric,
                    customLabel: regionObject["customLabel"].flatMap { stringSource($0, at: "\(regionPath).customLabel") },
                    showLabel: regionObject["showLabel"].flatMap { numberSource($0, at: "\(regionPath).showLabel") },
                    showUnit: regionObject["showUnit"].flatMap { numberSource($0, at: "\(regionPath).showUnit") },
                    valueFontScale: regionObject["valueFontScale"].flatMap { numberSource($0, at: "\(regionPath).valueFontScale") },
                    labelFontScale: regionObject["labelFontScale"].flatMap { numberSource($0, at: "\(regionPath).labelFontScale") },
                    unitFontScale: regionObject["unitFontScale"].flatMap { numberSource($0, at: "\(regionPath).unitFontScale") },
                    valueWeight: regionObject["valueWeight"].flatMap {
                        timelineEnumSource($0, at: "\(regionPath).valueWeight", allowed: Set(OverlayComponentFontWeight.allCases.map(\.rawValue)))
                    },
                    labelWeight: regionObject["labelWeight"].flatMap {
                        timelineEnumSource($0, at: "\(regionPath).labelWeight", allowed: Set(OverlayComponentFontWeight.allCases.map(\.rawValue)))
                    },
                    valueColor: regionObject["valueColor"].flatMap { colorSource($0, at: "\(regionPath).valueColor") },
                    labelColor: regionObject["labelColor"].flatMap { colorSource($0, at: "\(regionPath).labelColor") }
                ))
            }
            regions = parsed
        }
        func numberOrNil(_ key: String) -> OverlayComponentNumberSource? {
            object[key].flatMap { numberSource($0, at: "\(path).\(key)") }
        }
        func colorOrNil(_ key: String) -> OverlayComponentColorSource? {
            object[key].flatMap { colorSource($0, at: "\(path).\(key)") }
        }
        func weightOrNil(_ key: String) -> OverlayComponentStringSource? {
            object[key].flatMap {
                timelineEnumSource($0, at: "\(path).\(key)", allowed: Set(OverlayComponentFontWeight.allCases.map(\.rawValue)))
            }
        }
        return OverlayComponentRunningGauge(
            layoutPreset: object["layoutPreset"].flatMap {
                timelineEnumSource($0, at: "\(path).layoutPreset", allowed: layoutPresets)
            },
            progress: numberOrNil("progress"),
            dialBackgroundColor: colorOrNil("dialBackgroundColor"),
            dialBackgroundOpacity: numberOrNil("dialBackgroundOpacity"),
            glassEffectEnabled: numberOrNil("glassEffectEnabled"),
            outerRingEnabled: numberOrNil("outerRingEnabled"),
            outerRingColor: colorOrNil("outerRingColor"),
            outerRingOpacity: numberOrNil("outerRingOpacity"),
            outerRingWidthScale: numberOrNil("outerRingWidthScale"),
            tickMarksEnabled: numberOrNil("tickMarksEnabled"),
            tickColor: colorOrNil("tickColor"),
            tickOpacity: numberOrNil("tickOpacity"),
            majorTickOpacity: numberOrNil("majorTickOpacity"),
            tickCount: numberOrNil("tickCount"),
            majorTickEvery: numberOrNil("majorTickEvery"),
            progressRingEnabled: numberOrNil("progressRingEnabled"),
            progressColor: colorOrNil("progressColor"),
            progressTrackColor: colorOrNil("progressTrackColor"),
            progressTrackOpacity: numberOrNil("progressTrackOpacity"),
            progressRingWidthScale: numberOrNil("progressRingWidthScale"),
            progressRoundedCaps: numberOrNil("progressRoundedCaps"),
            dividerEnabled: numberOrNil("dividerEnabled"),
            dividerColor: colorOrNil("dividerColor"),
            dividerOpacity: numberOrNil("dividerOpacity"),
            dividerWidth: numberOrNil("dividerWidth"),
            font: font,
            monospacedDigits: numberOrNil("monospacedDigits"),
            primaryFontWeight: weightOrNil("primaryFontWeight"),
            secondaryFontWeight: weightOrNil("secondaryFontWeight"),
            primaryTextColor: colorOrNil("primaryTextColor"),
            secondaryTextColor: colorOrNil("secondaryTextColor"),
            accentColor: colorOrNil("accentColor"),
            regions: regions
        )
    }

    @inline(never)
    private func parseDistanceTimelineKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let timeline = parseDistanceTimelineNode(object, at: path) else { return nil }
        return .distanceTimeline(timeline)
    }

    @inline(never)
    private func parseDistanceTimelineNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentDistanceTimeline? {
        let presets: Set<String> = [
            "minimal", "dense", "sport", "splits", "glass", "neon", "lowerThird", "route"
        ]
        let unitSystems: Set<String> = ["metric", "imperial"]
        let axisModes: Set<String> = ["startFinish", "distance"]
        let placements: Set<String> = ["below", "above"]
        let markerStyles: Set<String> = ["dot", "pill", "triangle"]
        let fadeEdges: Set<String> = ["left", "right", "both", "vertical", "all"]
        let mediaModes: Set<String> = [
            "none", "systemIcon", "staticSVG", "animatedSVG", "image"
        ]
        let weightValues: Set<String> = Set(OverlayComponentFontWeight.allCases.map(\.rawValue))
        func numberOrNil(_ key: String) -> OverlayComponentNumberSource? {
            object[key].flatMap { numberSource($0, at: "\(path).\(key)") }
        }
        func colorOrNil(_ key: String) -> OverlayComponentColorSource? {
            object[key].flatMap { colorSource($0, at: "\(path).\(key)") }
        }
        func stringOrNil(_ key: String) -> OverlayComponentStringSource? {
            object[key].flatMap { stringSource($0, at: "\(path).\(key)") }
        }
        func enumOrNil(_ key: String, allowed: Set<String>) -> OverlayComponentStringSource? {
            object[key].flatMap {
                timelineEnumSource($0, at: "\(path).\(key)", allowed: allowed)
            }
        }
        return OverlayComponentDistanceTimeline(
            preset: enumOrNil("preset", allowed: presets),
            valueFontSize: numberOrNil("valueFontSize"),
            valueUnitSystem: enumOrNil("valueUnitSystem", allowed: unitSystems),
            showValue: numberOrNil("showValue"),
            showTotalDistance: numberOrNil("showTotalDistance"),
            showLabel: numberOrNil("showLabel"),
            label: stringOrNil("label"),
            labelFontFamily: stringOrNil("labelFontFamily"),
            labelFontSize: numberOrNil("labelFontSize"),
            labelFontWeight: enumOrNil("labelFontWeight", allowed: weightValues),
            labelColor: colorOrNil("labelColor"),
            labelValueSpacing: numberOrNil("labelValueSpacing"),
            showAxisLabels: numberOrNil("showAxisLabels"),
            axisLabelMode: enumOrNil("axisLabelMode", allowed: axisModes),
            axisLabelOffset: numberOrNil("axisLabelOffset"),
            axisLabelFontFamily: stringOrNil("axisLabelFontFamily"),
            axisLabelFontSize: numberOrNil("axisLabelFontSize"),
            axisLabelFontWeight: enumOrNil("axisLabelFontWeight", allowed: weightValues),
            axisLabelColor: colorOrNil("axisLabelColor"),
            showDistancePoints: numberOrNil("showDistancePoints"),
            distancePointCount: numberOrNil("distancePointCount"),
            distancePointOffset: numberOrNil("distancePointOffset"),
            midpointAxisLabelOffset: numberOrNil("midpointAxisLabelOffset"),
            axisEndpointLabelPlacement: enumOrNil("axisEndpointLabelPlacement", allowed: placements),
            axisMidpointLabelPlacement: enumOrNil("axisMidpointLabelPlacement", allowed: placements),
            markerDistanceLabelEnabled: numberOrNil("markerDistanceLabelEnabled"),
            markerDistanceLabelPlacement: enumOrNil("markerDistanceLabelPlacement", allowed: placements),
            markerDistanceLabelOffset: numberOrNil("markerDistanceLabelOffset"),
            currentMarkerSizeMultiplier: numberOrNil("currentMarkerSizeMultiplier"),
            backgroundEnabled: numberOrNil("backgroundEnabled"),
            backgroundColor: colorOrNil("backgroundColor"),
            backgroundOpacity: numberOrNil("backgroundOpacity"),
            borderEnabled: numberOrNil("borderEnabled"),
            borderColor: colorOrNil("borderColor"),
            borderOpacity: numberOrNil("borderOpacity"),
            borderWidth: numberOrNil("borderWidth"),
            cornerRadius: numberOrNil("cornerRadius"),
            paddingX: numberOrNil("paddingX"),
            paddingY: numberOrNil("paddingY"),
            trackHeight: numberOrNil("trackHeight"),
            trackOpacity: numberOrNil("trackOpacity"),
            fillColor: colorOrNil("fillColor"),
            tickMarksEnabled: numberOrNil("tickMarksEnabled"),
            tickDensity: numberOrNil("tickDensity"),
            currentMarkerEnabled: numberOrNil("currentMarkerEnabled"),
            currentMarkerStyle: enumOrNil("currentMarkerStyle", allowed: markerStyles),
            currentMarkerColor: colorOrNil("currentMarkerColor"),
            glowEnabled: numberOrNil("glowEnabled"),
            fadeEnabled: numberOrNil("fadeEnabled"),
            fadeEdge: enumOrNil("fadeEdge", allowed: fadeEdges),
            fadeAmount: numberOrNil("fadeAmount"),
            mediaSlotEnabled: numberOrNil("mediaSlotEnabled"),
            mediaSlotMode: enumOrNil("mediaSlotMode", allowed: mediaModes),
            mediaSystemImage: stringOrNil("mediaSystemImage"),
            mediaSlotSize: numberOrNil("mediaSlotSize"),
            elevationProfileVisible: numberOrNil("elevationProfileVisible"),
            width: numberOrNil("width"),
            height: numberOrNil("height")
        )
    }

    @inline(never)
    private func parseElevationChartKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let chart = parseElevationChartNode(object, at: path) else { return nil }
        return .elevationChart(chart)
    }

    @inline(never)
    private func parseElevationChartNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentElevationChart? {
        let presets: Set<String> = [
            "gradientArea", "dualArea", "techGlow", "minimalWhite", "bigNumbers"
        ]
        let renderStyles: Set<String> = ["area", "lineOnly"]
        let progressModes: Set<String> = ["fullProfile", "progressToCurrent"]
        let bigMetrics: Set<String> = [
            "currentElevation", "elevationGain", "maxElevation", "minElevation"
        ]
        let weightValues: Set<String> = Set(OverlayComponentFontWeight.allCases.map(\.rawValue))
        func numberOrNil(_ key: String) -> OverlayComponentNumberSource? {
            object[key].flatMap { numberSource($0, at: "\(path).\(key)") }
        }
        func colorOrNil(_ key: String) -> OverlayComponentColorSource? {
            object[key].flatMap { colorSource($0, at: "\(path).\(key)") }
        }
        func stringOrNil(_ key: String) -> OverlayComponentStringSource? {
            object[key].flatMap { stringSource($0, at: "\(path).\(key)") }
        }
        func enumOrNil(_ key: String, allowed: Set<String>) -> OverlayComponentStringSource? {
            object[key].flatMap {
                timelineEnumSource($0, at: "\(path).\(key)", allowed: allowed)
            }
        }
        return OverlayComponentElevationChart(
            preset: enumOrNil("preset", allowed: presets),
            chartStyle: enumOrNil("chartStyle", allowed: renderStyles),
            smoothingEnabled: numberOrNil("smoothingEnabled"),
            smoothingAmount: numberOrNil("smoothingAmount"),
            progressMode: enumOrNil("progressMode", allowed: progressModes),
            chartPaddingX: numberOrNil("chartPaddingX"),
            chartPaddingY: numberOrNil("chartPaddingY"),
            lineColor: colorOrNil("lineColor"),
            lineWidth: numberOrNil("lineWidth"),
            lineOpacity: numberOrNil("lineOpacity"),
            fillEnabled: numberOrNil("fillEnabled"),
            fillStartColor: colorOrNil("fillStartColor"),
            fillEndColor: colorOrNil("fillEndColor"),
            fillOpacity: numberOrNil("fillOpacity"),
            dualAreaEnabled: numberOrNil("dualAreaEnabled"),
            upperFillColor: colorOrNil("upperFillColor"),
            lowerFillColor: colorOrNil("lowerFillColor"),
            currentMarkerEnabled: numberOrNil("currentMarkerEnabled"),
            markerColor: colorOrNil("markerColor"),
            markerSizeMultiplier: numberOrNil("markerSizeMultiplier"),
            markerPlayheadLineEnabled: numberOrNil("markerPlayheadLineEnabled"),
            markerLabelEnabled: numberOrNil("markerLabelEnabled"),
            gridEnabled: numberOrNil("gridEnabled"),
            axisLineEnabled: numberOrNil("axisLineEnabled"),
            axisLabelsEnabled: numberOrNil("axisLabelsEnabled"),
            bigNumbersEnabled: numberOrNil("bigNumbersEnabled"),
            bigNumberMetric: enumOrNil("bigNumberMetric", allowed: bigMetrics),
            bigNumberFontSize: numberOrNil("bigNumberFontSize"),
            bigNumberFontFamily: stringOrNil("bigNumberFontFamily"),
            bigNumberFontWeight: enumOrNil("bigNumberFontWeight", allowed: weightValues),
            backgroundEnabled: numberOrNil("backgroundEnabled"),
            backgroundColor: colorOrNil("backgroundColor"),
            backgroundOpacity: numberOrNil("backgroundOpacity"),
            cornerRadius: numberOrNil("cornerRadius"),
            borderEnabled: numberOrNil("borderEnabled"),
            borderOpacity: numberOrNil("borderOpacity"),
            shadowEnabled: numberOrNil("shadowEnabled"),
            shadowOpacity: numberOrNil("shadowOpacity"),
            shadowRadius: numberOrNil("shadowRadius"),
            glowEnabled: numberOrNil("glowEnabled"),
            glowOpacity: numberOrNil("glowOpacity"),
            fontFamily: stringOrNil("fontFamily"),
            foregroundColor: colorOrNil("foregroundColor"),
            valueFontSize: numberOrNil("valueFontSize"),
            width: numberOrNil("width"),
            height: numberOrNil("height")
        )
    }

    @inline(never)
    private func parseRouteMapKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let map = parseRouteMapNode(object, at: path) else { return nil }
        return .routeMap(map)
    }

    @inline(never)
    private func parseRouteMapNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentRouteMap? {
        let shapes: Set<String> = ["square", "circle"]
        let backgrounds: Set<String> = ["none", "dark", "light", "terrain", "satellite"]
        let markers: Set<String> = ["hidden", "dot", "pin", "flag"]
        let edgeFades: Set<String> = ["solid", "fadeOut"]
        let colorModes: Set<String> = ["solid", "gradient"]
        let weightValues: Set<String> = Set(OverlayComponentFontWeight.allCases.map(\.rawValue))
        func numberOrNil(_ key: String) -> OverlayComponentNumberSource? {
            object[key].flatMap { numberSource($0, at: "\(path).\(key)") }
        }
        func colorOrNil(_ key: String) -> OverlayComponentColorSource? {
            object[key].flatMap { colorSource($0, at: "\(path).\(key)") }
        }
        func stringOrNil(_ key: String) -> OverlayComponentStringSource? {
            object[key].flatMap { stringSource($0, at: "\(path).\(key)") }
        }
        func enumOrNil(_ key: String, allowed: Set<String>) -> OverlayComponentStringSource? {
            object[key].flatMap {
                timelineEnumSource($0, at: "\(path).\(key)", allowed: allowed)
            }
        }
        return OverlayComponentRouteMap(
            shape: enumOrNil("shape", allowed: shapes),
            backgroundStyle: enumOrNil("backgroundStyle", allowed: backgrounds),
            cornerRadius: numberOrNil("cornerRadius"),
            backgroundOpacity: numberOrNil("backgroundOpacity"),
            startMarkerStyle: enumOrNil("startMarkerStyle", allowed: markers),
            endMarkerStyle: enumOrNil("endMarkerStyle", allowed: markers),
            runnerMarkerStyle: enumOrNil("runnerMarkerStyle", allowed: markers),
            startMarkerColor: colorOrNil("startMarkerColor"),
            endMarkerColor: colorOrNil("endMarkerColor"),
            runnerMarkerColor: colorOrNil("runnerMarkerColor"),
            glowEnabled: numberOrNil("glowEnabled"),
            mapOpacity: numberOrNil("mapOpacity"),
            borderEnabled: numberOrNil("borderEnabled"),
            borderColor: colorOrNil("borderColor"),
            borderOpacity: numberOrNil("borderOpacity"),
            borderWidth: numberOrNil("borderWidth"),
            foregroundColor: colorOrNil("foregroundColor"),
            fontFamily: stringOrNil("fontFamily"),
            fontSize: numberOrNil("fontSize"),
            fontWeight: enumOrNil("fontWeight", allowed: weightValues),
            edgeFade: enumOrNil("edgeFade", allowed: edgeFades),
            fadeAmount: numberOrNil("fadeAmount"),
            colorMode: enumOrNil("colorMode", allowed: colorModes),
            gradientStart: colorOrNil("gradientStart"),
            gradientMiddle: colorOrNil("gradientMiddle"),
            gradientEnd: colorOrNil("gradientEnd"),
            zoom: numberOrNil("zoom"),
            showsPointsOfInterest: numberOrNil("showsPointsOfInterest"),
            width: numberOrNil("width"),
            height: numberOrNil("height")
        )
    }

    @inline(never)
    private func parseWeatherWidgetKind(
        object: [String: OverlayJSONValue],
        path: String,
        depth: Int,
        insideRepeat: Bool,
        insideStack: Bool,
        frame: OverlayComponentFrame?
    ) -> OverlayComponentNodeKind? {
        guard let widget = parseWeatherWidgetNode(object, at: path) else { return nil }
        return .weatherWidget(widget)
    }

    @inline(never)
    private func parseWeatherWidgetNode(
        _ object: [String: OverlayJSONValue],
        at path: String
    ) -> OverlayComponentWeatherWidget? {
        let conditions: Set<String> = Set(WeatherCondition.allCases.map(\.rawValue))
        let units: Set<String> = ["celsius", "fahrenheit"]
        let dataSources: Set<String> = ["manual", "openMeteo", "openWeather"]
        let palettes: Set<String> = [
            "presetDefault", "blueGlass", "lightGlass", "graphite", "minimalWhite"
        ]
        let weightValues: Set<String> = Set(OverlayComponentFontWeight.allCases.map(\.rawValue))
        func numberOrNil(_ key: String) -> OverlayComponentNumberSource? {
            object[key].flatMap { numberSource($0, at: "\(path).\(key)") }
        }
        func colorOrNil(_ key: String) -> OverlayComponentColorSource? {
            object[key].flatMap { colorSource($0, at: "\(path).\(key)") }
        }
        func stringOrNil(_ key: String) -> OverlayComponentStringSource? {
            object[key].flatMap { stringSource($0, at: "\(path).\(key)") }
        }
        func enumOrNil(_ key: String, allowed: Set<String>) -> OverlayComponentStringSource? {
            object[key].flatMap {
                timelineEnumSource($0, at: "\(path).\(key)", allowed: allowed)
            }
        }
        return OverlayComponentWeatherWidget(
            dataSource: enumOrNil("dataSource", allowed: dataSources),
            condition: enumOrNil("condition", allowed: conditions),
            temperatureCelsius: numberOrNil("temperatureC"),
            humidity: numberOrNil("humidity"),
            highCelsius: numberOrNil("highC"),
            lowCelsius: numberOrNil("lowC"),
            windKph: numberOrNil("windKph"),
            feelsLikeCelsius: numberOrNil("feelsLikeC"),
            temperatureUnit: enumOrNil("temperatureUnit", allowed: units),
            useActivityTemperature: numberOrNil("useActivityTemperature"),
            locationText: stringOrNil("locationText"),
            showLocation: numberOrNil("showLocation"),
            showWeekday: numberOrNil("showWeekday"),
            showHumidity: numberOrNil("showHumidity"),
            showHighLow: numberOrNil("showHighLow"),
            showWind: numberOrNil("showWind"),
            showFeelsLike: numberOrNil("showFeelsLike"),
            showIcon: numberOrNil("showIcon"),
            showConditionLabel: numberOrNil("showConditionLabel"),
            conditionLabelOverride: stringOrNil("conditionLabelOverride"),
            humiditySuffix: stringOrNil("humiditySuffix"),
            humidityMetricLabel: stringOrNil("humidityMetricLabel"),
            windMetricLabel: stringOrNil("windMetricLabel"),
            feelsLikeMetricLabel: stringOrNil("feelsLikeMetricLabel"),
            cardBackgroundColor: colorOrNil("cardBackgroundColor"),
            cardBackgroundOpacity: numberOrNil("cardBackgroundOpacity"),
            cardCornerRadius: numberOrNil("cardCornerRadius"),
            dividerEnabled: numberOrNil("dividerEnabled"),
            dividerColor: colorOrNil("dividerColor"),
            dividerThickness: numberOrNil("dividerThickness"),
            dividerOpacity: numberOrNil("dividerOpacity"),
            palette: enumOrNil("palette", allowed: palettes),
            iconSize: numberOrNil("iconSize"),
            slotBackgroundColor: colorOrNil("slotBackgroundColor"),
            slotBackgroundOpacity: numberOrNil("slotBackgroundOpacity"),
            slotSpacing: numberOrNil("slotSpacing"),
            fontFamily: stringOrNil("fontFamily"),
            locationFontSize: numberOrNil("locationFontSize"),
            locationFontWeight: enumOrNil("locationFontWeight", allowed: weightValues),
            locationColor: colorOrNil("locationColor"),
            conditionFontSize: numberOrNil("conditionFontSize"),
            conditionFontWeight: enumOrNil("conditionFontWeight", allowed: weightValues),
            conditionColor: colorOrNil("conditionColor"),
            temperatureFontSize: numberOrNil("temperatureFontSize"),
            temperatureFontWeight: enumOrNil("temperatureFontWeight", allowed: weightValues),
            temperatureColor: colorOrNil("temperatureColor"),
            slotTitleFontSize: numberOrNil("slotTitleFontSize"),
            slotTitleFontWeight: enumOrNil("slotTitleFontWeight", allowed: weightValues),
            slotTitleColor: colorOrNil("slotTitleColor"),
            slotLabelFontSize: numberOrNil("slotLabelFontSize"),
            slotLabelFontWeight: enumOrNil("slotLabelFontWeight", allowed: weightValues),
            slotLabelColor: colorOrNil("slotLabelColor")
        )
    }

    private func parseTimelineColors(
        _ value: OverlayJSONValue?,
        at path: String
    ) -> OverlayComponentTimelineStrip.Colors? {
        guard case .object(let object)? = value else { return nil }
        checkUnknownKeys(object, allowed: [
            "warmup", "active", "rest", "cooldown", "unknown"
        ], at: path)
        guard let warmup = object["warmup"].flatMap({ colorSource($0, at: "\(path).warmup") }),
              let active = object["active"].flatMap({ colorSource($0, at: "\(path).active") }),
              let rest = object["rest"].flatMap({ colorSource($0, at: "\(path).rest") }),
              let cooldown = object["cooldown"].flatMap({ colorSource($0, at: "\(path).cooldown") }),
              let unknown = object["unknown"].flatMap({ colorSource($0, at: "\(path).unknown") }) else {
            return nil
        }
        return OverlayComponentTimelineStrip.Colors(
            warmup: warmup, active: active, rest: rest,
            cooldown: cooldown, unknown: unknown
        )
    }

    /// A string source whose literal form must be one of `allowed`; expression
    /// forms are validated at resolve time by falling back to the default.
    private func timelineEnumSource(
        _ value: OverlayJSONValue,
        at path: String,
        allowed: Set<String>
    ) -> OverlayComponentStringSource? {
        let source = stringSource(value, at: path)
        if case .literal(let literal)? = source, !allowed.contains(literal) {
            error(path, "unknown value '\(literal)'")
            return nil
        }
        return source
    }

    private func parseSegmentedBarMarker(
        _ value: OverlayJSONValue,
        at path: String
    ) -> OverlayComponentSegmentedBar.Marker? {
        guard case .object(let object) = value else {
            error(path, "marker must be an object")
            return nil
        }
        checkUnknownKeys(
            object,
            allowed: ["role", "layout", "if", "index", "fraction", "text", "color", "position", "showsValue", "scale", "font"],
            at: path
        )
        guard let text = object["text"].flatMap({ stringSource($0, at: "\(path).text") }),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }),
              let font = parseFont(object["font"], at: "\(path).font") else {
            error(path, "marker requires text, color and font")
            return nil
        }
        var position = object["position"].flatMap { stringSource($0, at: "\(path).position") }
        if case .literal(let literal)? = position,
           !["above", "below", "leading", "trailing"].contains(literal) {
            error("\(path).position", "unknown value '\(literal)'")
            position = nil
        }
        return OverlayComponentSegmentedBar.Marker(
            role: rawEnumValue(object, "role", at: "\(path).role", default: OverlayComponentSegmentedBarMarkerRole.current),
            layout: rawEnumValue(object, "layout", at: "\(path).layout", default: OverlayComponentSegmentedBarMarkerLayout.inline),
            condition: object["if"].flatMap { expression($0, at: "\(path).if") },
            index: object["index"].flatMap { numberSource($0, at: "\(path).index") },
            fraction: object["fraction"].flatMap { numberSource($0, at: "\(path).fraction") },
            text: text,
            color: color,
            position: position,
            showsValue: object["showsValue"].flatMap { numberSource($0, at: "\(path).showsValue") },
            scale: object["scale"].flatMap { numberSource($0, at: "\(path).scale") },
            font: font
        )
    }

    private func parseFrame(
        _ value: OverlayJSONValue?,
        at path: String,
        required: Bool
    ) -> OverlayComponentFrame? {
        guard let value else {
            if required { error(path, "frame is required") }
            return nil
        }
        guard case .array(let items) = value, items.count == 4 else {
            error(path, "frame must be [x, y, width, height]")
            return nil
        }
        guard let x = numberSource(items[0], at: "\(path)[0]"),
              let y = numberSource(items[1], at: "\(path)[1]"),
              let width = numberSource(items[2], at: "\(path)[2]"),
              let height = numberSource(items[3], at: "\(path)[3]") else {
            return nil
        }
        return OverlayComponentFrame(x: x, y: y, width: width, height: height)
    }


    private func parseColumns(
        _ object: [String: OverlayJSONValue],
        at path: String,
        depth: Int,
        insideRepeat: Bool
    ) -> OverlayComponentNodeKind? {
        guard let widthValue = object["width"],
              let width = numberSource(widthValue, at: "\(path).width") else {
            error("\(path).width", "columns requires width")
            return nil
        }
        guard let rawChildren = object["children"],
              case .array(let childrenArray) = rawChildren else {
            error("\(path).children", "columns requires children")
            return nil
        }
        let children = parseNodes(
            rawChildren,
            path: "\(path).children",
            depth: depth + 1,
            insideRepeat: insideRepeat
        )
        if childrenArray.isEmpty { error("\(path).children", "columns requires at least one child") }
        var divider: OverlayComponentDivider?
        if let rawDivider = object["divider"] {
            guard case .object(let dividerObject) = rawDivider else {
                error("\(path).divider", "divider must be an object")
                return nil
            }
            checkUnknownKeys(
                dividerObject,
                allowed: ["width", "color", "opacity", "height"],
                at: "\(path).divider"
            )
            guard let rawColor = dividerObject["color"],
                  let color = colorSource(rawColor, at: "\(path).divider.color"),
                  let rawHeight = dividerObject["height"],
                  let height = numberSource(rawHeight, at: "\(path).divider.height") else {
                error("\(path).divider", "divider requires color and height")
                return nil
            }
            divider = OverlayComponentDivider(
                width: dividerObject["width"].flatMap {
                    numberSource($0, at: "\(path).divider.width")
                } ?? .literal(1),
                color: color,
                opacity: dividerObject["opacity"].flatMap {
                    numberSource($0, at: "\(path).divider.opacity")
                } ?? .literal(1),
                height: height
            )
        }
        return .columns(width: width, divider: divider, children: children)
    }

    /// Whether a node has a layout box: text and stacks measure themselves,
    /// shapes with explicit geometry never do, everything else needs a frame.
    private func isBoxed(_ node: OverlayComponentNode) -> Bool {
        switch node.kind {
        case .text, .textRows, .stack, .spacer, .columns:
            true
        case .circle, .line, .polyline, .path:
            false
        default:
            node.frame != nil
        }
    }

    private func parseFont(_ value: OverlayJSONValue?, at path: String) -> OverlayComponentFont? {
        guard let value else {
            error(path, "font is required")
            return nil
        }
        guard case .object(let object) = value else {
            error(path, "font must be an object")
            return nil
        }
        checkUnknownKeys(object, allowed: ["family", "size", "weight"], at: path)
        var weight = OverlayComponentStringSource.literal(OverlayComponentFontWeight.regular.rawValue)
        if let rawWeight = object["weight"] {
            if let source = stringSource(rawWeight, at: "\(path).weight") {
                if case .literal(let literal) = source,
                   OverlayComponentFontWeight(rawValue: literal) == nil {
                    error("\(path).weight", "unknown value '\(literal)'")
                } else {
                    weight = source
                }
            }
        }
        guard let rawFamily = object["family"],
              let family = stringSource(rawFamily, at: "\(path).family"),
              let size = object["size"].flatMap({ numberSource($0, at: "\(path).size") }) else {
            error(path, "font requires family and size")
            return nil
        }
        if case .literal(let literal) = family,
           literal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error("\(path).family", "font family must not be empty")
            return nil
        }
        return OverlayComponentFont(family: family, size: size, weight: weight)
    }

    private func parseTextGradient(_ value: OverlayJSONValue?, at path: String) -> OverlayComponentTextGradient? {
        guard let value else { return nil }
        guard case .object(let object) = value else {
            error(path, "gradient must be an object")
            return nil
        }
        checkUnknownKeys(object, allowed: ["stops", "from", "to"], at: path)
        guard case .array(let rawStops)? = object["stops"], (2...8).contains(rawStops.count),
              let from = object["from"].flatMap({ point($0, at: "\(path).from") }),
              let to = object["to"].flatMap({ point($0, at: "\(path).to") }) else {
            error(path, "gradient requires 2...8 stops and from/to points")
            return nil
        }
        var stops: [OverlayComponentTextGradient.Stop] = []
        for (index, raw) in rawStops.enumerated() {
            let stopPath = "\(path).stops[\(index)]"
            guard case .object(let stop) = raw else {
                error(stopPath, "stop must be an object")
                continue
            }
            checkUnknownKeys(stop, allowed: ["offset", "color"], at: stopPath)
            guard case .number(let offset)? = stop["offset"], (0...1).contains(offset),
                  let color = stop["color"].flatMap({ colorSource($0, at: "\(stopPath).color") }) else {
                error(stopPath, "stop requires an offset in 0...1 and color")
                continue
            }
            if let previous = stops.last, offset < previous.offset {
                error("\(stopPath).offset", "stops must be ordered by offset")
            }
            stops.append(.init(offset: offset, color: color))
        }
        return OverlayComponentTextGradient(stops: stops, from: from, to: to)
    }

    private func parseShadow(_ value: OverlayJSONValue?, at path: String) -> OverlayComponentShadow? {
        guard let value else { return nil }
        guard case .object(let object) = value else {
            error(path, "shadow must be an object")
            return nil
        }
        checkUnknownKeys(object, allowed: ["sigma", "dx", "dy", "color", "opacity"], at: path)
        guard let sigma = object["sigma"].flatMap({ numberSource($0, at: "\(path).sigma") }),
              let dx = object["dx"].flatMap({ numberSource($0, at: "\(path).dx") }),
              let dy = object["dy"].flatMap({ numberSource($0, at: "\(path).dy") }),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "shadow requires sigma, dx, dy and color")
            return nil
        }
        return OverlayComponentShadow(
            sigma: sigma, dx: dx, dy: dy, color: color,
            opacity: object["opacity"].flatMap { numberSource($0, at: "\(path).opacity") }
        )
    }

    private func parsePathCommand(
        _ value: OverlayJSONValue,
        at path: String
    ) -> OverlayComponentPathCommand? {
        guard case .array(let items) = value, case .string(let command)? = items.first else {
            error(path, "command must be an array with a leading letter")
            return nil
        }
        func numbers(_ count: Int) -> [OverlayComponentNumberSource]? {
            guard items.count == count + 1 else {
                error(path, "expected \(count) numbers after '\(command)'")
                return nil
            }
            return (1...count).compactMap { numberSource(items[$0], at: "\(path)[\($0)]") }
        }
        switch command {
        case "M":
            guard let values = numbers(2), values.count == 2 else { return nil }
            return .move(values[0], values[1])
        case "L":
            guard let values = numbers(2), values.count == 2 else { return nil }
            return .line(values[0], values[1])
        case "Q":
            guard let values = numbers(4), values.count == 4 else { return nil }
            return .quad(values[0], values[1], values[2], values[3])
        case "C":
            guard let values = numbers(6), values.count == 6 else { return nil }
            return .cubic(values[0], values[1], values[2], values[3], values[4], values[5])
        case "A":
            guard let values = numbers(5), values.count == 5 else { return nil }
            return .arc(values[0], values[1], values[2], values[3], values[4])
        case "Z":
            guard items.count == 1 else {
                error(path, "'Z' takes no arguments")
                return nil
            }
            return .close
        default:
            error(path, "unknown path command '\(command)'")
            return nil
        }
    }

    private func parseDash(_ value: OverlayJSONValue?, at path: String) -> [OverlayComponentNumberSource]? {
        guard let value else { return nil }
        guard case .array(let items) = value, items.count == 2 else {
            error(path, "dash must be [length, gap]")
            return nil
        }
        let sources = items.enumerated().compactMap { index, item in
            numberSource(item, at: "\(path)[\(index)]")
        }
        return sources.count == 2 ? sources : nil
    }

    // MARK: - Value sources

    private func numberSource(_ value: OverlayJSONValue, at path: String) -> OverlayComponentNumberSource? {
        switch value {
        case .number(let number):
            guard number.isFinite, abs(number) <= 32768 else {
                error(path, "number must be finite and within ±32768")
                return nil
            }
            return .literal(number)
        case .string:
            guard let expression = expression(value, at: path) else { return nil }
            return .expression(expression)
        default:
            error(path, "expected a number or expression")
            return nil
        }
    }

    private func colorSource(_ value: OverlayJSONValue, at path: String) -> OverlayComponentColorSource? {
        switch value {
        case .string(let text):
            if text.hasPrefix("=") {
                guard let expression = expression(value, at: path) else { return nil }
                return .expression(expression)
            }
            guard let color = OverlayComponentColorParser.parse(text) else {
                error(path, "invalid color '\(text)'")
                return nil
            }
            return .literal(color)
        default:
            error(path, "expected a color or expression")
            return nil
        }
    }

    private func stringSource(_ value: OverlayJSONValue, at path: String) -> OverlayComponentStringSource? {
        guard case .string(let text) = value else {
            error(path, "expected a string or expression")
            return nil
        }
        if text.hasPrefix("=") {
            guard let expression = expression(value, at: path) else { return nil }
            return .expression(expression)
        }
        if text.count > 1024 {
            error(path, "string exceeds 1024 characters")
        }
        return .literal(text)
    }

    private func expression(_ value: OverlayJSONValue, at path: String) -> OverlayComponentExpression? {
        guard case .string(let text) = value, text.hasPrefix("=") else {
            error(path, "expression must be a string starting with '='")
            return nil
        }
        do {
            let parsed = try OverlayComponentExpression.parse(String(text.dropFirst()))
            validateMetricCalls(in: parsed, at: path)
            if sizeBuiltinPath == nil,
               !parsed.referencedIdentifiers.isDisjoint(with: ["width", "height"]) {
                sizeBuiltinPath = path
            }
            return parsed
        } catch {
            self.error(path, "invalid expression: \(error)")
            return nil
        }
    }

    /// Literal `metric(id, unit)` arguments are checked against the catalog so
    /// a typo fails validation instead of rendering nothing.
    private func validateMetricCalls(in expression: OverlayComponentExpression, at path: String) {
        switch expression {
        case .literal, .variable:
            return
        case .member(let base, _):
            validateMetricCalls(in: base, at: path)
        case .index(let base, let index):
            validateMetricCalls(in: base, at: path)
            validateMetricCalls(in: index, at: path)
        case .unary(_, let operand):
            validateMetricCalls(in: operand, at: path)
        case .binary(_, let left, let right):
            validateMetricCalls(in: left, at: path)
            validateMetricCalls(in: right, at: path)
        case .conditional(let condition, let whenTrue, let whenFalse):
            validateMetricCalls(in: condition, at: path)
            validateMetricCalls(in: whenTrue, at: path)
            validateMetricCalls(in: whenFalse, at: path)
        case .call(let name, let arguments):
            arguments.forEach { validateMetricCalls(in: $0, at: path) }
            guard name == "metric" else { return }
            var literalUnits: [String] = []
            var allUnitsLiteral = true
            for argument in arguments.dropFirst() {
                guard case .literal(.string(let unit)) = argument else {
                    allUnitsLiteral = false
                    continue
                }
                if OverlayComponentMetricCatalog.allUnits.contains(unit) {
                    literalUnits.append(unit)
                } else {
                    error(path, "unknown metric unit '\(unit)'")
                }
            }
            guard case .literal(.string(let id))? = arguments.first else { return }
            if OverlayMetric(rawValue: id) == nil {
                error(path, "unknown metric '\(id)'")
            } else if allUnitsLiteral, !literalUnits.isEmpty,
                      Set(literalUnits).isDisjoint(with: OverlayComponentMetricCatalog.units(for: id)) {
                error(path, "metric '\(id)' does not support unit '\(literalUnits.joined(separator: "', '"))'")
            }
        }
    }

    private func point(_ value: OverlayJSONValue, at path: String) -> OverlayComponentPoint? {
        guard case .array(let items) = value, items.count == 2 else {
            error(path, "point must be [x, y]")
            return nil
        }
        guard let x = numberSource(items[0], at: "\(path)[0]"),
              let y = numberSource(items[1], at: "\(path)[1]") else {
            return nil
        }
        return OverlayComponentPoint(x: x, y: y)
    }

    private func pointsSource(_ value: OverlayJSONValue, at path: String) -> OverlayComponentPointsSource? {
        switch value {
        case .array(let items):
            var points: [OverlayComponentPoint] = []
            for (index, item) in items.enumerated() {
                guard let point = point(item, at: "\(path)[\(index)]") else { return nil }
                points.append(point)
            }
            return .literal(points)
        case .string:
            guard let expression = expression(value, at: path) else { return nil }
            return .expression(expression)
        default:
            error(path, "points must be an array or expression")
            return nil
        }
    }

    // MARK: - JSON helpers

    private func object(
        _ value: OverlayJSONValue,
        at path: String,
        allowed: Set<String>
    ) -> [String: OverlayJSONValue]? {
        guard case .object(let object) = value else {
            error(path, "must be an object")
            return nil
        }
        checkUnknownKeys(object, allowed: allowed, at: path)
        return object
    }

    private func checkUnknownKeys(
        _ object: [String: OverlayJSONValue],
        allowed: Set<String>,
        at path: String
    ) {
        for key in object.keys where !allowed.contains(key) {
            error("\(path).\(key)", "unknown field")
        }
    }

    private func string(
        _ object: [String: OverlayJSONValue],
        _ key: String,
        at path: String,
        required: Bool = false
    ) -> String? {
        guard let value = object[key] else {
            if required { error(path, "is required") }
            return nil
        }
        guard case .string(let string) = value else {
            error(path, "must be a string")
            return nil
        }
        return string
    }

    private func number(
        _ value: OverlayJSONValue?,
        at path: String,
        required: Bool = false
    ) -> Double? {
        guard let value else {
            if required { error(path, "is required") }
            return nil
        }
        guard case .number(let number) = value, number.isFinite else {
            error(path, "must be a number")
            return nil
        }
        return number
    }

    private func bool(
        _ object: [String: OverlayJSONValue],
        _ key: String,
        at path: String,
        required: Bool = false
    ) -> Bool? {
        guard let value = object[key] else {
            if required { error(path, "is required") }
            return nil
        }
        guard case .boolean(let boolean) = value else {
            error(path, "must be a boolean")
            return nil
        }
        return boolean
    }

    private func localizedText(
        _ value: OverlayJSONValue?,
        at path: String,
        required: Bool = false
    ) -> OverlayComponentLocalizedText? {
        guard let value else {
            if required { error(path, "is required") }
            return nil
        }
        switch value {
        case .string(let text):
            if text.isEmpty { error(path, "must not be empty") }
            return OverlayComponentLocalizedText(values: ["en": text])
        case .object(let object):
            if !object.keys.contains("en") {
                error(path, "localized text requires 'en'")
            }
            var values: [String: String] = [:]
            for (language, item) in object {
                guard matches(language, "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$") else {
                    error("\(path).\(language)", "invalid language tag")
                    continue
                }
                guard case .string(let text) = item, !text.isEmpty else {
                    error("\(path).\(language)", "must be a non-empty string")
                    continue
                }
                values[language] = text
            }
            return OverlayComponentLocalizedText(values: values)
        default:
            error(path, "must be a string or localized object")
            return nil
        }
    }

    private func rawEnumValue<T: RawRepresentable>(
        _ object: [String: OverlayJSONValue],
        _ key: String,
        at path: String,
        default fallback: T
    ) -> T where T.RawValue == String {
        guard let value = object[key] else { return fallback }
        guard case .string(let raw) = value else {
            error(path, "must be a string")
            return fallback
        }
        guard let parsed = T(rawValue: raw) else {
            error(path, "unknown value '\(raw)'")
            return fallback
        }
        return parsed
    }

    /// An enum-valued field that also accepts an expression. Literals must
    /// name a case; expressions are checked when resolved.
    private func enumSource<T: RawRepresentable>(
        _ object: [String: OverlayJSONValue],
        _ key: String,
        at path: String,
        as type: T.Type
    ) -> OverlayComponentStringSource? where T.RawValue == String {
        guard let value = object[key] else { return nil }
        guard let source = stringSource(value, at: path) else { return nil }
        if case .literal(let literal) = source, T(rawValue: literal) == nil {
            error(path, "unknown value '\(literal)'")
            return nil
        }
        return source
    }

    private func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private func error(_ path: String, _ message: String) {
        diagnostics.append(OverlayComponentDiagnostic(path: path, message: message))
    }
}
