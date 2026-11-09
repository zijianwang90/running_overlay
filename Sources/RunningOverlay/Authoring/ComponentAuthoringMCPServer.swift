import Foundation

/// Authoring documents bundled with the app so an AI client gets the exact
/// protocol this build validates, without reading the repository.
enum ComponentAuthoringGuide {
    enum Topic: String, CaseIterable {
        case workflow
        case guide
        case spec
        case schema

        var resourceName: String {
            switch self {
            case .workflow: "authoring-skill"
            case .guide: "authoring-guide"
            case .spec: "authoring-spec"
            case .schema: "authoring-schema"
            }
        }

        var resourceExtension: String { self == .schema ? "json" : "md" }
    }

    struct Example {
        var name: String
        var summary: String
    }

    static let examples: [Example] = [
        Example(name: "metric-card", summary: "Content-sized card with one metric value, unit and label."),
        Example(name: "hr-pill", summary: "Heart-rate pill with a sparkline from a time series."),
        Example(name: "lap-splits", summary: "List of lap rows built with repeat."),
        Example(name: "weather-card", summary: "Host-drawn weatherWidget node with a data-source param.")
    ]

    static func text(for topic: Topic) -> String? {
        resource(named: topic.resourceName, extension: topic.resourceExtension)
    }

    static func example(named name: String) -> String? {
        guard examples.contains(where: { $0.name == name }) else { return nil }
        return resource(named: "authoring-example-\(name)", extension: "json")
    }

    private static func resource(named name: String, extension fileExtension: String) -> String? {
        let bundle = Bundle.runningOverlayResources
        let url = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Authoring")
            ?? bundle.url(forResource: name, withExtension: fileExtension)
        return url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

/// A Model Context Protocol server for AI-assisted component authoring.
///
/// Started as `RunningOverlay --mcp` by an AI client (Claude Code, Codex,
/// Claude Desktop) over stdio, newline-delimited JSON-RPC 2.0. It exposes the
/// bundled authoring guides, validation, synthetic-data previews and the
/// drafts folder that the running app shows live. It never reads the user's
/// projects or activities and never reaches the network.
@MainActor
final class ComponentAuthoringMCPServer {
    typealias JSONObject = [String: Any]

    static let serverName = "running-overlay-studio"
    static let supportedProtocolVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
    static let defaultPreviewTime: TimeInterval = 150

    let store: ComponentDraftStore

    init(store: ComponentDraftStore = ComponentDraftStore()) {
        self.store = store
    }

    // MARK: - Transport

    /// Serves requests from stdin until it closes. Stdout carries protocol
    /// messages only; diagnostics go to stderr.
    static func runStdio() -> Int32 {
        let server = ComponentAuthoringMCPServer()
        while let line = readLine(strippingNewline: true) {
            guard let reply = server.handle(line: line) else { continue }
            FileHandle.standardOutput.write(Data((reply + "\n").utf8))
        }
        return 0
    }

    /// Handles one wire message. Returns the serialized response, or nil for
    /// notifications and blank lines.
    func handle(line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) else {
            return Self.serialize(Self.error(id: NSNull(), code: -32700, message: "Parse error"))
        }
        if let batch = object as? [Any] {
            let replies = batch.compactMap { ($0 as? JSONObject).flatMap(handle) }
            return replies.isEmpty ? nil : Self.serialize(replies)
        }
        guard let message = object as? JSONObject else {
            return Self.serialize(Self.error(id: NSNull(), code: -32600, message: "Invalid Request"))
        }
        return handle(message).map(Self.serialize)
    }

    /// Handles one decoded JSON-RPC message.
    func handle(_ message: JSONObject) -> JSONObject? {
        guard let method = message["method"] as? String else {
            // Responses to server-initiated requests; this server sends none.
            return nil
        }
        guard let id = message["id"] else {
            // Notifications (`notifications/initialized`, cancellations).
            return nil
        }
        let params = message["params"] as? JSONObject ?? [:]
        switch method {
        case "initialize":
            return Self.result(id: id, initializeResult(params))
        case "ping":
            return Self.result(id: id, [:])
        case "tools/list":
            return Self.result(id: id, ["tools": Self.tools])
        case "tools/call":
            guard let name = params["name"] as? String else {
                return Self.error(id: id, code: -32602, message: "Missing tool name")
            }
            let arguments = params["arguments"] as? JSONObject ?? [:]
            guard let result = callTool(name, arguments: arguments) else {
                return Self.error(id: id, code: -32602, message: "Unknown tool: \(name)")
            }
            return Self.result(id: id, result)
        default:
            return Self.error(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func initializeResult(_ params: JSONObject) -> JSONObject {
        let requested = params["protocolVersion"] as? String
        let version = requested.flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
            ?? Self.supportedProtocolVersions[1]
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return [
            "protocolVersion": version,
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": [
                "name": Self.serverName,
                "title": "Running Overlay Studio",
                "version": appVersion ?? "dev"
            ],
            "instructions": Self.instructions
        ]
    }

    static let instructions = """
    Running Overlay Studio overlay components are declarative JSON documents \
    (spec ros.component/0.1) drawn over running videos. Before authoring, call \
    get_authoring_guide (workflow, then spec for exact vocabulary) and start \
    from an example. Iterate with validate_component and render_component \
    until the preview matches the request, then save_draft. Saved drafts \
    appear live in the app under Overlay Pool > Components > Drafts, and \
    instances already placed update when the draft is saved again. Previews \
    use synthetic activity and weather data only.
    """

    // MARK: - Tools

    static let tools: [JSONObject] = [
        tool(
            "get_authoring_guide",
            title: "Get authoring guide",
            description: "Returns bundled authoring documentation. 'workflow' is the short authoring procedure; 'guide' covers layout, bindings and CLI; 'spec' is the full ros.component/0.1 specification (node, param and expression vocabulary); 'schema' is the JSON Schema.",
            properties: ["topic": [
                "type": "string",
                "enum": ComponentAuthoringGuide.Topic.allCases.map(\.rawValue),
                "description": "Defaults to workflow."
            ]],
            readOnly: true
        ),
        tool(
            "list_examples",
            title: "List example components",
            description: "Lists example components to start from.",
            properties: [:],
            readOnly: true
        ),
        tool(
            "get_example",
            title: "Get example component",
            description: "Returns the JSON of one example component.",
            properties: ["name": ["type": "string", "description": "Example name from list_examples."]],
            required: ["name"],
            readOnly: true
        ),
        tool(
            "list_metrics",
            title: "List metrics",
            description: "Lists metric ids accepted by metric(id, unit...) and metric parameters.",
            properties: [:],
            readOnly: true
        ),
        tool(
            "validate_component",
            title: "Validate component",
            description: "Validates a component document and returns its id, version and parameters, or JSON-pointer diagnostics.",
            properties: ["component": componentProperty],
            required: ["component"],
            readOnly: true
        ),
        tool(
            "render_component",
            title: "Render component preview",
            description: "Renders a component to a transparent PNG with the app's renderer, using a synthetic 12-minute interval workout (warmup 0-60 s, work 60-300 s, rest 300-360 s, work 360-600 s, rest 600-660 s, cooldown 660-720 s) and synthetic weather. Inspect the image and iterate.",
            properties: [
                "component": componentProperty,
                "params": ["type": "object", "description": "Optional parameter overrides by parameter id."],
                "elapsedSeconds": ["type": "number", "minimum": 0, "description": "Activity elapsed seconds to sample. Defaults to 150 (first work rep)."],
                "scale": ["type": "number", "minimum": 0.5, "maximum": 4, "description": "Pixels per design unit. Defaults to 2."]
            ],
            required: ["component"],
            readOnly: true
        ),
        tool(
            "save_draft",
            title: "Save draft to the app",
            description: "Validates and saves a component as a named draft in Running Overlay Studio. It appears under Overlay Pool > Components > Drafts; saving the same name again updates placed instances live. Invalid components are not saved.",
            properties: [
                "name": ["type": "string", "description": "Draft file name, e.g. heart-rate-ring. Saving the same name replaces the draft."],
                "component": componentProperty
            ],
            required: ["name", "component"],
            readOnly: false
        ),
        tool(
            "list_drafts",
            title: "List drafts",
            description: "Lists drafts in the app's drafts folder with their validation status.",
            properties: [:],
            readOnly: true
        ),
        tool(
            "get_draft",
            title: "Get draft",
            description: "Returns the JSON of a saved draft so it can be revised.",
            properties: ["name": ["type": "string"]],
            required: ["name"],
            readOnly: true
        )
    ]

    private static let componentProperty: JSONObject = [
        "description": "The component document, as a JSON object or a JSON string.",
        "type": ["object", "string"]
    ]

    private static func tool(
        _ name: String,
        title: String,
        description: String,
        properties: JSONObject,
        required: [String] = [],
        readOnly: Bool
    ) -> JSONObject {
        var schema: JSONObject = ["type": "object", "properties": properties]
        if !required.isEmpty { schema["required"] = required }
        return [
            "name": name,
            "title": title,
            "description": description,
            "inputSchema": schema,
            "annotations": [
                "readOnlyHint": readOnly,
                "destructiveHint": false,
                "idempotentHint": true,
                "openWorldHint": false
            ]
        ]
    }

    /// Runs a tool. Returns nil for an unknown tool; tool failures are
    /// reported in the result with `isError` so the model can correct them.
    func callTool(_ name: String, arguments: JSONObject) -> JSONObject? {
        do {
            switch name {
            case "get_authoring_guide":
                let topicName = arguments["topic"] as? String ?? "workflow"
                guard let topic = ComponentAuthoringGuide.Topic(rawValue: topicName),
                      let text = ComponentAuthoringGuide.text(for: topic) else {
                    return Self.failure("Unknown or missing guide topic '\(topicName)'.")
                }
                return Self.text(text)
            case "list_examples":
                return Self.text(ComponentAuthoringGuide.examples
                    .map { "- \($0.name): \($0.summary)" }
                    .joined(separator: "\n"))
            case "get_example":
                let name = arguments["name"] as? String ?? ""
                guard let json = ComponentAuthoringGuide.example(named: name) else {
                    return Self.failure("Unknown example '\(name)'. Call list_examples.")
                }
                return Self.text(json)
            case "list_metrics":
                return Self.text(OverlayMetric.allCases
                    .map { "- \($0.rawValue): \($0.displayName)" }
                    .joined(separator: "\n"))
            case "validate_component":
                let reference = try reference(from: arguments)
                return Self.text(summary(of: reference, heading: "Valid"))
            case "render_component":
                return try render(arguments)
            case "save_draft":
                let draft = try store.save(
                    name: arguments["name"] as? String ?? "",
                    data: try componentData(from: arguments)
                )
                return Self.text("""
                Saved draft '\(draft.id)' (\(draft.displayName)).
                It is listed in Running Overlay Studio under Overlay Pool > Components > Drafts. \
                Instances already placed from this component update automatically.
                """)
            case "list_drafts":
                let drafts = store.drafts()
                guard !drafts.isEmpty else { return Self.text("No drafts yet.") }
                return Self.text(drafts.map { draft in
                    switch draft.status {
                    case .valid(let reference, let displayName):
                        "- \(draft.id): \(displayName) (\(reference.id) \(reference.version))"
                    case .invalid(let diagnostics):
                        "- \(draft.id): invalid, \(diagnostics.count) error(s)"
                    }
                }.joined(separator: "\n"))
            case "get_draft":
                let name = arguments["name"] as? String ?? ""
                guard let draft = store.draft(named: name) else {
                    return Self.failure("No draft named '\(name)'. Call list_drafts.")
                }
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: draft.url.path, isDirectory: &isDirectory)
                let url = isDirectory.boolValue
                    ? draft.url.appendingPathComponent("component.json")
                    : draft.url
                return Self.text(try String(contentsOf: url, encoding: .utf8))
            default:
                return nil
            }
        } catch let error as OverlayComponentValidationError {
            return Self.failure("Invalid component:\n" + error.diagnostics
                .map { "\($0.path): \($0.severity == .error ? "error" : "warning"): \($0.message)" }
                .joined(separator: "\n"))
        } catch {
            return Self.failure(error.localizedDescription)
        }
    }

    private func render(_ arguments: JSONObject) throws -> JSONObject {
        #if canImport(CSkiaBridge)
        let reference = try reference(from: arguments)
        guard let definition = OverlayComponentRegistry.definition(for: reference) else {
            throw ComponentCLIError.unresolvedDefinition
        }
        var parameters: [String: OverlayJSONValue] = [:]
        if let raw = arguments["params"] as? JSONObject, !raw.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: raw)
            do {
                parameters = try JSONDecoder().decode([String: OverlayJSONValue].self, from: data)
            } catch {
                throw ComponentCLIError.invalidParameters(error.localizedDescription)
            }
            parameters = try ComponentCommandRunner.validatedParameters(parameters, definition: definition)
        }
        let elapsed = (arguments["elapsedSeconds"] as? NSNumber)?.doubleValue ?? Self.defaultPreviewTime
        let scale = min(max((arguments["scale"] as? NSNumber)?.doubleValue ?? 2, 0.5), 4)
        let rendered = try ComponentCommandRunner.renderPNG(
            reference: reference,
            parameters: parameters,
            activity: ComponentAuthoringFixture.workout(),
            elapsedTime: elapsed,
            weather: ComponentAuthoringFixture.weather,
            scale: scale
        )
        var lines = [
            "Rendered \(reference.id) at \(Int(elapsed)) s: \(Int(rendered.size.width))x\(Int(rendered.size.height)) px (scale \(scale))."
        ]
        lines += rendered.diagnostics.map { "warning: \($0)" }
        return [
            "content": [
                ["type": "image", "data": rendered.png.base64EncodedString(), "mimeType": "image/png"],
                ["type": "text", "text": lines.joined(separator: "\n")]
            ],
            "isError": false
        ]
        #else
        _ = arguments
        return Self.failure("Rendering needs a Skia build of Running Overlay Studio; validate_component still works.")
        #endif
    }

    private func componentData(from arguments: JSONObject) throws -> Data {
        switch arguments["component"] {
        case let text as String:
            return Data(text.utf8)
        case let object as JSONObject:
            return try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
        default:
            throw ComponentAuthoringMCPError.missingComponent
        }
    }

    private func reference(from arguments: JSONObject) throws -> OverlayComponentReference {
        try OverlayComponentReference(definitionData: try componentData(from: arguments), source: .imported)
    }

    private func summary(of reference: OverlayComponentReference, heading: String) -> String {
        guard let definition = OverlayComponentRegistry.definition(for: reference) else {
            return "\(heading): \(reference.id) \(reference.version)"
        }
        let language = OverlayComponentInstance.hostLanguage
        var lines = [
            "\(heading): \(reference.id) \(reference.version)",
            "Name: \(definition.name.resolve(language: language))"
        ]
        let parameters = definition.params.map {
            "\($0.id) (\($0.label.resolve(language: language)))"
        }
        lines.append(parameters.isEmpty ? "Parameters: none" : "Parameters: " + parameters.joined(separator: ", "))
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON-RPC helpers

    private static func text(_ text: String) -> JSONObject {
        ["content": [["type": "text", "text": text]], "isError": false]
    }

    private static func failure(_ text: String) -> JSONObject {
        ["content": [["type": "text", "text": text]], "isError": true]
    }

    private static func result(id: Any, _ result: JSONObject) -> JSONObject {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private static func error(id: Any, code: Int, message: String) -> JSONObject {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    private static func serialize(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.withoutEscapingSlashes]))
            ?? Data(#"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"#.utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

enum ComponentAuthoringMCPError: LocalizedError {
    case missingComponent

    var errorDescription: String? {
        switch self {
        case .missingComponent:
            "Pass the component document as 'component' (a JSON object or string)."
        }
    }
}
