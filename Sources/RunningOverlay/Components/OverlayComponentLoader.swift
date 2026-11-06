import CoreFoundation
import Foundation

enum OverlayJSONValue: Equatable {
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
        "activity.heartRate", "activity.pace", "activity.avgPace",
        "activity.elevation", "activity.elevationGain", "activity.cadence",
        "activity.power", "activity.grade", "activity.temperature",
        "activity.calories", "clock.realTime", "clock.date",
        "host.canvasWidth", "host.canvasHeight", "host.scale"
    ]

    static let recordSignals: Set<String> = [
        "zone.heartRate", "zone.pace", "structure.currentLap",
        "structure.current", "route.current", "weather.current", "host"
    ]

    static let seriesSignals: Set<String> = [
        "activity.elapsed", "activity.remaining", "activity.distance",
        "activity.heartRate", "activity.pace", "activity.avgPace",
        "activity.elevation", "activity.elevationGain", "activity.cadence",
        "activity.power", "activity.grade", "activity.temperature",
        "activity.calories"
    ]

    static let listSignals: Set<String> = [
        "structure.laps", "structure.intervals"
    ]

    static let builtinNames: Set<String> = [
        "min", "max", "clamp", "abs", "round", "floor", "ceil", "lerp",
        "map", "sum", "avg", "count", "first", "last", "at", "coalesce",
        "exists", "format", "concat", "upper", "lower", "slice", "mix",
        "alpha", "signal", "series"
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
                "license", "homepage", "size", "background", "params",
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

        let size = parseSize(object["size"])
        let background = parseBackground(object["background"], path: "$.background")
        let params = parseParams(object["params"], path: "$.params")
        let bindings = parseBindings(object["bindings"], path: "$.bindings")
        let nodes = parseNodes(object["nodes"], path: "$.nodes", depth: 0, insideRepeat: false)
        if nodes.isEmpty {
            error("$.nodes", "at least one node is required")
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
        if items.count > 64 { error(path, "at most 64 params are allowed") }
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
            if !(2...16).contains(rawOptions.count) {
                error("\(path).options", "must contain 2...16 options")
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
            let kinds = ["signal", "series", "list"].filter { bindingObject[$0] != nil }
            if kinds.count != 1 {
                error(bindingPath, "binding must contain exactly one of signal, series, list")
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
                error(bindingPath, "binding must contain exactly one of signal, series, list")
            }
        }
        return result
    }

    // MARK: - Nodes

    private func parseNodes(
        _ value: OverlayJSONValue?,
        path: String,
        depth: Int,
        insideRepeat: Bool
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
            parseNode(item, at: "\(path)[\(index)]", depth: depth, insideRepeat: insideRepeat)
        }
    }

    private func parseNode(
        _ value: OverlayJSONValue,
        at path: String,
        depth: Int,
        insideRepeat: Bool
    ) -> OverlayComponentNode? {
        guard case .object(let object) = value else {
            error(path, "node must be an object")
            return nil
        }
        guard let type = string(object, "type", at: "\(path).type") else { return nil }

        let commonKeys: Set<String> = ["type", "id", "frame", "if", "opacity"]
        let typeKeys: Set<String>
        switch type {
        case "group": typeKeys = ["children", "clip", "shadow"]
        case "rect": typeKeys = ["fill", "radius", "stroke", "strokeWidth"]
        case "circle": typeKeys = ["center", "radius", "fill", "stroke", "strokeWidth"]
        case "line": typeKeys = ["from", "to", "width", "color", "cap"]
        case "polyline": typeKeys = ["points", "width", "color", "cap", "join", "dash"]
        case "path": typeKeys = ["commands", "fill", "stroke", "strokeWidth", "cap", "join", "dash"]
        case "text": typeKeys = ["text", "font", "color", "align", "verticalAlign", "maxWidth", "lineHeight"]
        case "image": typeKeys = ["asset", "fit"]
        case "gradientRect": typeKeys = ["stops", "from", "to", "radius"]
        case "sparkline": typeKeys = ["series", "stroke", "lineWidth", "fill", "smoothing"]
        case "progressBar": typeKeys = ["value", "trackColor", "fillColor", "radius"]
        case "arc": typeKeys = ["value", "startDegrees", "sweepDegrees", "radius", "width", "trackColor", "fillColor", "cap"]
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
            "rect", "text", "image", "gradientRect", "sparkline",
            "progressBar", "arc", "repeat"
        ]
        let frame = parseFrame(object["frame"], at: "\(path).frame", required: frameRequired.contains(type))
        let condition = object["if"].flatMap { expression($0, at: "\(path).if") }
        let opacity = object["opacity"].flatMap { numberSource($0, at: "\(path).opacity") }

        let kind: OverlayComponentNodeKind?
        switch type {
        case "group":
            guard let rawChildren = object["children"],
                  case .array(let childrenArray) = rawChildren else {
                error("\(path).children", "group requires children")
                return nil
            }
            let children = parseNodes(rawChildren, path: "\(path).children", depth: depth + 1, insideRepeat: insideRepeat)
            if childrenArray.isEmpty { error("\(path).children", "group requires at least one child") }
            let shadow = parseShadow(object["shadow"], at: "\(path).shadow")
            kind = .group(
                children: children,
                clip: bool(object, "clip", at: "\(path).clip") ?? false,
                shadow: shadow
            )

        case "rect":
            guard let fillValue = object["fill"] else {
                error("\(path).fill", "fill is required")
                return nil
            }
            kind = .rect(
                fill: colorSource(fillValue, at: "\(path).fill") ?? .literal(.black),
                radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") } ?? .literal(0),
                stroke: object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") },
                strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") }
            )

        case "circle":
            guard let center = object["center"].flatMap({ point($0, at: "\(path).center") }),
                  let radius = object["radius"].flatMap({ numberSource($0, at: "\(path).radius") }) else {
                error(path, "circle requires center and radius")
                return nil
            }
            kind = .circle(
                center: center,
                radius: radius,
                fill: object["fill"].flatMap { colorSource($0, at: "\(path).fill") },
                stroke: object["stroke"].flatMap { colorSource($0, at: "\(path).stroke") },
                strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") }
            )

        case "line":
            guard let from = object["from"].flatMap({ point($0, at: "\(path).from") }),
                  let to = object["to"].flatMap({ point($0, at: "\(path).to") }),
                  let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
                  let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
                error(path, "line requires from, to, width and color")
                return nil
            }
            kind = .line(
                from: from,
                to: to,
                width: width,
                color: color,
                cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt)
            )

        case "polyline":
            guard let pointsValue = object["points"],
                  let points = pointsSource(pointsValue, at: "\(path).points"),
                  let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
                  let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
                error(path, "polyline requires points, width and color")
                return nil
            }
            kind = .polyline(
                points: points,
                width: width,
                color: color,
                cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt),
                join: rawEnumValue(object, "join", at: "\(path).join", default: OverlayComponentLineJoin.miter),
                dash: parseDash(object["dash"], at: "\(path).dash")
            )

        case "path":
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
            kind = .path(
                commands: commands,
                fill: fill,
                stroke: stroke,
                strokeWidth: object["strokeWidth"].flatMap { numberSource($0, at: "\(path).strokeWidth") },
                cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt),
                join: rawEnumValue(object, "join", at: "\(path).join", default: OverlayComponentLineJoin.miter),
                dash: parseDash(object["dash"], at: "\(path).dash")
            )

        case "text":
            guard let rawText = object["text"],
                  let text = stringSource(rawText, at: "\(path).text"),
                  let font = parseFont(object["font"], at: "\(path).font"),
                  let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
                error(path, "text requires text, font and color")
                return nil
            }
            kind = .text(
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
                lineHeight: object["lineHeight"].flatMap { numberSource($0, at: "\(path).lineHeight") }
            )

        case "image":
            guard let asset = string(object, "asset", at: "\(path).asset") else {
                return nil
            }
            if !matches(asset, "^assets/[A-Za-z0-9._-]+\\.(png|jpg|jpeg)$") {
                error("\(path).asset", "invalid asset path")
            } else if !assets.contains(asset) {
                error("\(path).asset", "asset '\(asset)' is not in the package")
            }
            kind = .image(
                asset: asset,
                fit: rawEnumValue(
                    object,
                    "fit",
                    at: "\(path).fit",
                    default: OverlayComponentImageFit.contain
                )
            )

        case "gradientRect":
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
            kind = .gradientRect(
                stops: stops,
                from: from,
                to: to,
                radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") }
            )

        case "sparkline":
            guard let seriesValue = object["series"],
                  let series = expression(seriesValue, at: "\(path).series"),
                  let stroke = object["stroke"].flatMap({ colorSource($0, at: "\(path).stroke") }),
                  let lineWidth = object["lineWidth"].flatMap({ numberSource($0, at: "\(path).lineWidth") }) else {
                error(path, "sparkline requires series, stroke and lineWidth")
                return nil
            }
            kind = .sparkline(
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

        case "progressBar":
            guard let value = object["value"].flatMap({ expression($0, at: "\(path).value") }),
                  let trackColor = object["trackColor"].flatMap({ colorSource($0, at: "\(path).trackColor") }),
                  let fillColor = object["fillColor"].flatMap({ colorSource($0, at: "\(path).fillColor") }) else {
                error(path, "progressBar requires value, trackColor and fillColor")
                return nil
            }
            kind = .progressBar(
                value: value,
                trackColor: trackColor,
                fillColor: fillColor,
                radius: object["radius"].flatMap { numberSource($0, at: "\(path).radius") }
            )

        case "arc":
            guard let value = object["value"].flatMap({ expression($0, at: "\(path).value") }),
                  let start = object["startDegrees"].flatMap({ numberSource($0, at: "\(path).startDegrees") }),
                  let sweep = object["sweepDegrees"].flatMap({ numberSource($0, at: "\(path).sweepDegrees") }),
                  let radius = object["radius"].flatMap({ numberSource($0, at: "\(path).radius") }),
                  let width = object["width"].flatMap({ numberSource($0, at: "\(path).width") }),
                  let fillColor = object["fillColor"].flatMap({ colorSource($0, at: "\(path).fillColor") }) else {
                error(path, "arc requires value, angles, radius, width and fillColor")
                return nil
            }
            kind = .arc(
                value: value,
                startDegrees: start,
                sweepDegrees: sweep,
                radius: radius,
                width: width,
                trackColor: object["trackColor"].flatMap { colorSource($0, at: "\(path).trackColor") },
                fillColor: fillColor,
                cap: rawEnumValue(object, "cap", at: "\(path).cap", default: OverlayComponentLineCap.butt)
            )

        case "repeat":
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
            kind = .repeatNode(
                over: over,
                itemName: itemName,
                indexName: indexName,
                maximum: object["max"].flatMap { numberSource($0, at: "\(path).max") },
                children: children
            )

        default:
            return nil
        }

        guard let kind else { return nil }
        return OverlayComponentNode(
            id: id,
            frame: frame,
            condition: condition,
            opacity: opacity,
            kind: kind
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
        guard let family = string(object, "family", at: "\(path).family"),
              !family.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let size = object["size"].flatMap({ numberSource($0, at: "\(path).size") }) else {
            error(path, "font requires family and size")
            return nil
        }
        let weight = rawEnumValue(
            object,
            "weight",
            at: "\(path).weight",
            default: OverlayComponentFontWeight.regular
        )
        return OverlayComponentFont(family: family, size: size, weight: weight)
    }

    private func parseShadow(_ value: OverlayJSONValue?, at path: String) -> OverlayComponentShadow? {
        guard let value else { return nil }
        guard case .object(let object) = value else {
            error(path, "shadow must be an object")
            return nil
        }
        checkUnknownKeys(object, allowed: ["sigma", "dx", "dy", "color"], at: path)
        guard let sigma = object["sigma"].flatMap({ numberSource($0, at: "\(path).sigma") }),
              let dx = object["dx"].flatMap({ numberSource($0, at: "\(path).dx") }),
              let dy = object["dy"].flatMap({ numberSource($0, at: "\(path).dy") }),
              let color = object["color"].flatMap({ colorSource($0, at: "\(path).color") }) else {
            error(path, "shadow requires sigma, dx, dy and color")
            return nil
        }
        return OverlayComponentShadow(sigma: sigma, dx: dx, dy: dy, color: color)
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
            return try OverlayComponentExpression.parse(String(text.dropFirst()))
        } catch {
            self.error(path, "invalid expression: \(error)")
            return nil
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

    private func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private func error(_ path: String, _ message: String) {
        diagnostics.append(OverlayComponentDiagnostic(path: path, message: message))
    }
}
