import Foundation
import Testing
@testable import RunningOverlay

/// Drafts folder, live reload and the `--mcp` authoring server.
@MainActor
@Suite(.serialized, .skiaSerialized)
struct ComponentAIAuthoringTests {
    private static func metricCard(version: String = "1.0.0") throws -> String {
        let json = try #require(ComponentAuthoringGuide.example(named: "metric-card"))
        return json.replacingOccurrences(of: "\"version\": \"1.0.0\"", with: "\"version\": \"\(version)\"")
    }

    private static func temporaryStore() throws -> ComponentDraftStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("component-drafts-\(UUID().uuidString)", isDirectory: true)
        let store = ComponentDraftStore(directory: directory)
        try store.ensureDirectory()
        return store
    }

    private static func removing(_ store: ComponentDraftStore) {
        try? FileManager.default.removeItem(at: store.directory)
    }

    // MARK: - Draft store

    @Test func slugKeepsLettersDigitsAndSingleHyphens() {
        #expect(ComponentDraftStore.slug("  HR Ring / v2!! ") == "hr-ring-v2")
        #expect(ComponentDraftStore.slug("---") == "")
        #expect(ComponentDraftStore.slug("心率") == "")
    }

    @Test func savesValidDraftsAndRejectsInvalidOrReservedOnes() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }

        let draft = try store.save(name: "Metric Card", data: Data(try Self.metricCard().utf8))
        #expect(draft.id == "metric-card")
        #expect(draft.reference?.id == "examples.metric-card")
        #expect(store.drafts().map(\.id) == ["metric-card"])

        #expect(throws: OverlayComponentValidationError.self) {
            try store.save(name: "broken", data: Data(#"{"spec":"ros.component/0.1"}"#.utf8))
        }
        let reserved = try Self.metricCard().replacingOccurrences(
            of: "\"examples.metric-card\"", with: "\"studio.metric-card\""
        )
        #expect(throws: ComponentDraftError.reservedID("studio.metric-card")) {
            try store.save(name: "reserved", data: Data(reserved.utf8))
        }
        #expect(throws: ComponentDraftError.invalidName("!!")) {
            try store.save(name: "!!", data: Data(try Self.metricCard().utf8))
        }
        #expect(store.drafts().count == 1)
    }

    @Test func listsHandWrittenInvalidDraftsWithDiagnostics() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        try Data(#"{"spec":"ros.component/0.1"}"#.utf8)
            .write(to: store.directory.appendingPathComponent("broken.json"))
        try Data("ignored".utf8).write(to: store.directory.appendingPathComponent("notes.txt"))

        let drafts = store.drafts()
        #expect(drafts.map(\.id) == ["broken"])
        guard case let .invalid(diagnostics) = drafts.first?.status else {
            Issue.record("Expected an invalid draft")
            return
        }
        #expect(!diagnostics.isEmpty)
    }

    @Test func pastedRepliesSaveTheFencedComponent() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        let reply = "Here is your card:\n```json\n\(try Self.metricCard())\n```\nEnjoy!"

        let draft = try store.saveDraft(fromPastedText: reply)
        #expect(draft.id == "metric-card")
        #expect(throws: ComponentDraftError.noComponentJSON) {
            try store.saveDraft(fromPastedText: "no json here")
        }
    }

    @Test func deleteRefusesFilesOutsideTheDraftsFolder() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        let outside = ComponentDraft(
            id: "elsewhere",
            url: FileManager.default.temporaryDirectory.appendingPathComponent("elsewhere.json"),
            modified: Date(),
            status: .invalid([])
        )
        #expect(throws: ComponentDraftError.outsideDraftsFolder) {
            try store.delete(outside)
        }
    }

    // MARK: - Live reload

    @Test func changedDraftReloadsPlacedInstancesAsOneUndoPoint() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        let first = try store.save(name: "card", data: Data(try Self.metricCard().utf8))
        let project = ProjectDocument()
        let library = ComponentDraftLibrary(store: store)
        library.start(project: project, interval: 3600)
        defer { library.stop() }
        #expect(library.drafts.map(\.id) == ["card"])

        let elementID = try #require(project.addComponentFromDraft(first))
        project.setComponentParameter(elementID, parameterID: "title", value: .string("Pulse"))

        let second = try store.save(name: "card", data: Data(try Self.metricCard(version: "1.1.0").utf8))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: second.url.path
        )
        library.refresh()

        let reloaded = try #require(project.overlayLayout.elements.first { $0.id == elementID }?.component)
        #expect(reloaded.reference.version == "1.1.0")
        #expect(reloaded.parameters["title"] == .string("Pulse"))

        project.undo()
        let restored = try #require(project.overlayLayout.elements.first { $0.id == elementID }?.component)
        #expect(restored.reference.version == "1.0.0")
        #expect(restored.parameters["title"] == .string("Pulse"))
    }

    @Test func firstScanDoesNotRewriteExistingInstances() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        let project = ProjectDocument()
        let original = try OverlayComponentReference(
            definitionData: Data(try Self.metricCard().utf8),
            source: .imported
        )
        let elementID = project.addComponentElement(reference: original)
        try store.save(name: "card", data: Data(try Self.metricCard(version: "2.0.0").utf8))

        let library = ComponentDraftLibrary(store: store)
        library.start(project: project, interval: 3600)
        defer { library.stop() }
        let component = try #require(project.overlayLayout.elements.first { $0.id == elementID }?.component)
        #expect(component.reference.version == "1.0.0")
    }

    @Test func reloadLeavesBundledAndOtherComponentsAlone() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.numeric#pace" })
        let bundledID = try #require(project.addComponentFromLibrary(item))
        let bundledDigest = project.overlayLayout.elements.first { $0.id == bundledID }?.component?.reference.digest
        let reference = try OverlayComponentReference(
            definitionData: Data(try Self.metricCard(version: "3.0.0").utf8),
            source: .imported
        )
        project.reloadComponentDefinition(reference, displayName: "Metric Card")
        #expect(project.overlayLayout.elements.first { $0.id == bundledID }?.component?.reference.digest == bundledDigest)
        #expect(project.statusMessage != "Reloaded Metric Card from draft.")
    }

    // MARK: - MCP server

    private func call(
        _ server: ComponentAuthoringMCPServer,
        _ method: String,
        id: Int = 1,
        params: [String: Any] = [:]
    ) throws -> [String: Any] {
        let request: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        let line = String(decoding: try JSONSerialization.data(withJSONObject: request), as: UTF8.self)
        let reply = try #require(server.handle(line: line))
        return try #require(try JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any])
    }

    private func tool(
        _ server: ComponentAuthoringMCPServer,
        _ name: String,
        _ arguments: [String: Any]
    ) throws -> (isError: Bool, content: [[String: Any]]) {
        let reply = try call(server, "tools/call", params: ["name": name, "arguments": arguments])
        let result = try #require(reply["result"] as? [String: Any])
        return (
            result["isError"] as? Bool ?? false,
            try #require(result["content"] as? [[String: Any]])
        )
    }

    @Test func initializeNegotiatesProtocolAndListsTools() throws {
        let server = ComponentAuthoringMCPServer(store: try Self.temporaryStore())
        defer { Self.removing(server.store) }

        let known = try call(server, "initialize", params: ["protocolVersion": "2025-06-18"])
        let result = try #require(known["result"] as? [String: Any])
        #expect(result["protocolVersion"] as? String == "2025-06-18")
        #expect((result["serverInfo"] as? [String: Any])?["name"] as? String == "running-overlay-studio")

        let future = try call(server, "initialize", params: ["protocolVersion": "2099-01-01"])
        #expect((future["result"] as? [String: Any])?["protocolVersion"] as? String == "2025-06-18")

        let list = try call(server, "tools/list")
        let names = ((list["result"] as? [String: Any])?["tools"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String }
        #expect(names == [
            "get_authoring_guide", "list_examples", "get_example", "list_metrics",
            "validate_component", "render_component", "save_draft", "list_drafts", "get_draft"
        ])
    }

    @Test func notificationsAndUnknownMethodsFollowJSONRPC() throws {
        let server = ComponentAuthoringMCPServer(store: try Self.temporaryStore())
        defer { Self.removing(server.store) }
        #expect(server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        #expect(server.handle(line: "   ") == nil)

        let parse = try #require(server.handle(line: "{not json"))
        #expect(parse.contains("-32700"))

        let unknown = try call(server, "resources/list")
        #expect((unknown["error"] as? [String: Any])?["code"] as? Int == -32601)

        let badTool = try call(server, "tools/call", params: ["name": "nope"])
        #expect((badTool["error"] as? [String: Any])?["code"] as? Int == -32602)
    }

    @Test func guidesExamplesAndValidationTools() throws {
        let server = ComponentAuthoringMCPServer(store: try Self.temporaryStore())
        defer { Self.removing(server.store) }

        for topic in ComponentAuthoringGuide.Topic.allCases {
            let guide = try tool(server, "get_authoring_guide", ["topic": topic.rawValue])
            #expect(!guide.isError)
            #expect(((guide.content.first?["text"] as? String)?.count ?? 0) > 500)
        }
        let example = try tool(server, "get_example", ["name": "lap-splits"])
        #expect((example.content.first?["text"] as? String)?.contains("ros.component/0.1") == true)
        #expect(try tool(server, "get_example", ["name": "../authoring-spec"]).isError)

        let valid = try tool(server, "validate_component", ["component": try Self.metricCard()])
        #expect(!valid.isError)
        #expect((valid.content.first?["text"] as? String)?.contains("examples.metric-card") == true)

        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(try Self.metricCard().utf8)) as? [String: Any]
        )
        #expect(try tool(server, "validate_component", ["component": object]).isError == false)

        let invalid = try tool(server, "validate_component", ["component": #"{"spec":"ros.component/0.1"}"#])
        #expect(invalid.isError)
        #expect((invalid.content.first?["text"] as? String)?.contains("Invalid component") == true)
        #expect(try tool(server, "validate_component", [:]).isError)
    }

    @Test func draftToolsWriteIntoTheSharedFolder() throws {
        let store = try Self.temporaryStore()
        defer { Self.removing(store) }
        let server = ComponentAuthoringMCPServer(store: store)

        let saved = try tool(server, "save_draft", ["name": "HR Card", "component": try Self.metricCard()])
        #expect(!saved.isError)
        #expect(store.drafts().map(\.id) == ["hr-card"])

        let rejected = try tool(server, "save_draft", [
            "name": "broken", "component": #"{"spec":"ros.component/0.1"}"#
        ])
        #expect(rejected.isError)
        #expect(store.drafts().count == 1)

        let listed = try tool(server, "list_drafts", [:])
        #expect((listed.content.first?["text"] as? String)?.contains("hr-card") == true)
        let fetched = try tool(server, "get_draft", ["name": "hr-card"])
        #expect((fetched.content.first?["text"] as? String)?.contains("examples.metric-card") == true)
        #expect(try tool(server, "get_draft", ["name": "missing"]).isError)
    }

    #if canImport(CSkiaBridge)
    @Test func renderReturnsAPNGFromSyntheticData() throws {
        let server = ComponentAuthoringMCPServer(store: try Self.temporaryStore())
        defer { Self.removing(server.store) }
        let rendered = try tool(server, "render_component", [
            "component": try Self.metricCard(),
            "params": ["title": "Pulse"],
            "elapsedSeconds": 200,
            "scale": 1
        ])
        #expect(!rendered.isError)
        let image = try #require(rendered.content.first { $0["type"] as? String == "image" })
        #expect(image["mimeType"] as? String == "image/png")
        let encoded = try #require(image["data"] as? String)
        let data = try #require(Data(base64Encoded: encoded))
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))

        let badParams = try tool(server, "render_component", [
            "component": try Self.metricCard(), "params": ["nope": 1]
        ])
        #expect(badParams.isError)
    }
    #endif

    // MARK: - Bundled guides and app guidance

    /// The MCP server must hand AI clients the protocol this build validates,
    /// so bundled copies must match the canonical documents.
    @Test func bundledGuidesMatchCanonicalDocs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let canonical: [(ComponentAuthoringGuide.Topic, String)] = [
            (.workflow, "docs/overlay-components/skills/overlay-component-authoring/SKILL.md"),
            (.guide, "docs/overlay-components/authoring.md"),
            (.spec, "docs/overlay-components/spec-v0.1.md"),
            (.schema, "docs/overlay-components/schema/ros-component-0.1.schema.json")
        ]
        for (topic, path) in canonical {
            let expected = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(ComponentAuthoringGuide.text(for: topic) == expected, "\(path) drifted from its bundled copy")
        }
        for example in ComponentAuthoringGuide.examples {
            let expected = try String(
                contentsOf: root.appendingPathComponent(
                    "docs/overlay-components/examples/\(example.name).rocomponent.json"
                ),
                encoding: .utf8
            )
            #expect(ComponentAuthoringGuide.example(named: example.name) == expected)
            #expect(throws: Never.self) {
                _ = try OverlayComponentReference(definitionData: Data(expected.utf8), source: .imported)
            }
        }
    }

    @Test func connectCommandsTargetTheRunningExecutable() throws {
        let path = "/Applications/Running Overlay Studio.app/Contents/MacOS/RunningOverlay"
        #expect(ComponentAIClient.claudeCode.connectCommand(executablePath: path)
            == "claude mcp add running-overlay -- \"\(path)\" --mcp")
        #expect(ComponentAIClient.codex.connectCommand(executablePath: path)
            == "codex mcp add running-overlay -- \"\(path)\" --mcp")
        #expect(ComponentAIClient.other.connectCommand(executablePath: path) == nil)

        let desktop = try #require(ComponentAIClient.claudeDesktop.connectCommand(executablePath: path))
        let config = try #require(try JSONSerialization.jsonObject(with: Data(desktop.utf8)) as? [String: Any])
        let server = (config["mcpServers"] as? [String: Any])?["running-overlay"] as? [String: Any]
        #expect(server?["command"] as? String == path)
        #expect(server?["args"] as? [String] == ["--mcp"])

        let prompt = ComponentAIClient.authoringPrompt()
        #expect(prompt.contains("ros.component/0.1"))
        #expect(prompt.contains("# Specification"))
    }

    @Test func syntheticFixtureCoversTheAdvertisedSchedule() {
        let activity = ComponentAuthoringFixture.workout()
        #expect(activity.duration == 720)
        #expect(activity.laps.map(\.kind) == [.warmup, .active, .rest, .active, .rest, .cooldown])
        #expect(activity.laps.map(\.startElapsedTime) == [0, 60, 300, 360, 600, 660])
        #expect(!activity.routePoints.isEmpty)
    }
}
