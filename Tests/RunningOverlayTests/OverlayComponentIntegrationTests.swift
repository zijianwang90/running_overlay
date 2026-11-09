import AppKit
import Foundation
import ImageIO
import Testing
@testable import RunningOverlay

struct OverlayComponentIntegrationTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures/Components"
            )
        )
        return try Data(contentsOf: url)
    }

    private func reference(_ name: String = "hr-pill") throws -> OverlayComponentReference {
        try OverlayComponentReference(definitionData: fixtureData(name), source: .imported)
    }

    private func makeTimeline() -> ActivityTimeline {
        let records = (0...6).map { index -> ActivityRecord in
            let time = Double(index) * 100
            return ActivityRecord(
                elapsedTime: time,
                timestamp: start.addingTimeInterval(time),
                distanceMeters: time * 5,
                heartRate: 100 + index * 20,
                paceSecondsPerKilometer: 300,
                elevationMeters: 100 + Double(index),
                cadence: 170,
                powerWatts: 240,
                calories: time * 0.1,
                latitude: 37.0 + Double(index) * 0.001,
                longitude: -122.0 + Double(index) * 0.001,
                temperatureCelsius: 18,
                gradePercent: 0.5
            )
        }
        let laps: [LapRecord] = (1...3).map { index in
            let startTime: Double = Double(index - 1) * 200
            let endTime: Double = Double(index) * 200
            let startDistance: Double = Double(index - 1) * 1000
            let pace: Double = 300 - Double(index) * 10
            let heartRate: Int = 120 + index * 15
            let maxHeartRate: Int = 140 + index * 15
            return LapRecord(
                lapIndex: index,
                startElapsedTime: startTime,
                endElapsedTime: endTime,
                startDistanceMeters: startDistance,
                totalDistanceMeters: 1000,
                totalElapsedTime: 200,
                avgPaceSecondsPerKm: pace,
                avgHeartRate: heartRate,
                maxHeartRate: maxHeartRate,
                avgCadenceSPM: 170,
                avgPowerWatts: 240,
                totalAscent: 5,
                kind: .active
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 600,
            distanceMeters: 3000,
            records: records,
            laps: laps
        )
    }

    // MARK: - Persistence

    @Test func importedReferenceEmbedsDefinitionAndCanonicalDigest() throws {
        let data = try fixtureData("hr-pill")
        let imported = try OverlayComponentReference(definitionData: data, source: .imported)

        #expect(imported.id == "studio.builtin.heart-rate-pill")
        #expect(imported.version == "1.0.0")
        #expect(imported.definition != nil)
        #expect(imported.digest.hasPrefix("sha256:"))

        // Formatting-only differences do not change identity.
        let object = try JSONSerialization.jsonObject(with: data)
        let pretty = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        let reformatted = try OverlayComponentReference(definitionData: pretty, source: .imported)
        #expect(reformatted.digest == imported.digest)
        #expect(reformatted.definition == imported.definition)
    }

    @Test func bundledReferenceDoesNotEmbedDefinition() throws {
        let bundled = try OverlayComponentReference(
            definitionData: try fixtureData("hr-pill"),
            source: .bundled
        )

        #expect(bundled.definition == nil)
        #expect(OverlayComponentRegistry.definition(for: bundled) != nil)
    }

    @Test func templateRoundTripPreservesComponentElement() throws {
        let instance = OverlayComponentInstance(
            reference: try reference(),
            parameters: [
                "accent": .string("#FF4D4F"),
                "radius": .number(20),
                "showTrend": .boolean(false)
            ]
        )
        let element = OverlayElement(
            type: .component,
            position: CGPoint(x: 0.12, y: 0.7),
            scale: 1.5,
            opacity: 0.9,
            style: .default,
            component: instance
        )
        let template = OverlayTemplate(
            name: "Component",
            layout: OverlayLayout(elements: [element])
        )

        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(OverlayTemplate.self, from: data)

        #expect(decoded.elements.count == 1)
        #expect(decoded.elements[0].type == .component)
        #expect(decoded.elements[0].componentReference == instance.reference)
        #expect(decoded.elements[0].componentParameters == instance.parameters)
        #expect(decoded.elements[0].overlayElement.component == instance)
    }

    @Test func nativeElementsStillEncodeWithoutComponentKeys() throws {
        let element = OverlayElement(
            type: .decorSolidColor,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: .default
        )
        let data = try JSONEncoder().encode(OverlayTemplateElement(element: element))
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["component"] == nil)
        #expect(object["params"] == nil)

        let decoded = try JSONDecoder().decode(OverlayTemplateElement.self, from: data)
        #expect(decoded.componentReference == nil)
        #expect(decoded.componentParameters.isEmpty)
    }

    @Test func componentTypeWithoutReferenceFailsToDecode() throws {
        let json = """
        {
          "type": "component",
          "positionX": 0.1,
          "positionY": 0.1,
          "scale": 1,
          "style": \(String(data: try JSONEncoder().encode(OverlayStyle.default), encoding: .utf8) ?? "{}")
        }
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(OverlayTemplateElement.self, from: Data(json.utf8))
        }
    }

    // MARK: - Resolution

    @Test func registryResolvesPersistedParameters() throws {
        let instance = OverlayComponentInstance(
            reference: try reference(),
            parameters: ["accent": .string("#FF0000")]
        )
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 150,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1920, height: 1080),
            elementScale: 1.5
        )
        let resolved = try #require(OverlayComponentRegistry.resolve(instance: instance, data: data))

        #expect(resolved.size == OverlayComponentSize(width: 240, height: 72))
        #expect(resolved.diagnostics.isEmpty)
        guard case .rect(_, let fill, _, _, _) = resolved.nodes.first else {
            Issue.record("expected leading background rect")
            return
        }
        #expect(fill.alpha < 1)

        guard let textNode = resolved.nodes.dropFirst().first,
              case .text(_, let text, _, let color, _, _, _, _, _, _) = textNode else {
            Issue.record("expected heart-rate text node")
            return
        }
        #expect(text == "130")
        #expect(color == OverlayColor(red: 1, green: 0, blue: 0, alpha: 1))
    }

    @Test func digestMismatchStillRendersEmbeddedDefinition() throws {
        var reference = try reference()
        reference.digest = "sha256:0000"
        let instance = OverlayComponentInstance(reference: reference)
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 0,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )
        let resolved = try #require(OverlayComponentRegistry.resolve(instance: instance, data: data))

        #expect(resolved.nodes.isEmpty == false)
        #expect(resolved.diagnostics.first?.contains("does not match") == true)
    }

    @Test func invalidParametersFallBackToDefaults() throws {
        let instance = OverlayComponentInstance(
            reference: try reference(),
            parameters: [
                "radius": .string("not a number"),
                "unknown": .number(1)
            ]
        )
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 0,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )
        let resolved = try #require(OverlayComponentRegistry.resolve(instance: instance, data: data))

        // Persisted values that do not match the declared parameter type are
        // dropped before resolution, so the declared defaults render.
        #expect(resolved.diagnostics.isEmpty)
        guard let textNode = resolved.nodes.dropFirst().first,
              case .text(_, _, _, let color, _, _, _, _, _, _) = textNode else {
            Issue.record("expected heart-rate text node")
            return
        }
        let defaultAccent = try #require(OverlayComponentColorParser.parse("#FF4D4F"))
        #expect(abs(color.red - defaultAccent.red) < 0.001)
        #expect(abs(color.green - defaultAccent.green) < 0.001)
        #expect(abs(color.blue - defaultAccent.blue) < 0.001)
    }

    // MARK: - Bundled library

    @Test func bundledExamplesResolveByDigest() throws {
        let item = try #require(
            OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" }
        )
        let reference = try OverlayComponentLibrary.reference(for: item)

        #expect(reference.source == .bundled)
        #expect(reference.definition == nil)
        #expect(reference.digest.hasPrefix("sha256:"))

        let definition = try #require(OverlayComponentRegistry.definition(for: reference))
        #expect(definition.id == item.id)
        #expect(definition.name.resolve() == "Heart Rate Pill")

        // A stale digest must not resolve to a different bundled build.
        var stale = reference
        stale.digest = "sha256:0000"
        #expect(OverlayComponentRegistry.definition(for: stale) == nil)
    }

    @MainActor
    @Test func addingBundledComponentFromLibraryUsesDisplayName() throws {
        let project = ProjectDocument()
        let item = try #require(
            OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" }
        )

        let id = try #require(project.addComponentFromLibrary(item))
        let element = try #require(project.selectedOverlay(id))

        #expect(element.type == .component)
        #expect(element.component?.reference.source == .bundled)
        #expect(element.component?.reference.definition == nil)
        #expect(element.displayLabel == "Heart Rate Pill")
        #expect(project.selection == .overlayElement(id))
    }

    @MainActor
    @Test func duplicatingBundledComponentEmbedsDefinition() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))
        let originalDigest = project.selectedOverlay(id)?.component?.reference.digest

        project.makeComponentEditable(id)

        let reference = try #require(project.selectedOverlay(id)?.component?.reference)
        #expect(reference.source == .project)
        #expect(reference.definition != nil)
        #expect(reference.digest == originalDigest)

        project.undo()
        #expect(project.selectedOverlay(id)?.component?.reference.source == .bundled)
    }

    // MARK: - Parameter editing

    @MainActor
    @Test func numberParametersClampAndQuantizeWithOneUndoPoint() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))
        // hr-pill radius: 0...36, step 1.
        project.setComponentParameter(id, parameterID: "radius", value: .number(100))
        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == .number(36))

        project.setComponentParameter(id, parameterID: "radius", value: .number(12.6))
        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == .number(13))

        project.undo()
        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == .number(36))
        project.undo()
        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == nil)
    }

    @MainActor
    @Test func continuousParameterEditsShareOneUndoTransaction() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))

        project.setComponentParameter(id, parameterID: "radius", value: .number(10), continuous: true)
        project.setComponentParameter(id, parameterID: "radius", value: .number(20), continuous: true)
        project.finishContinuousEdit()

        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == .number(20))
        project.undo()
        #expect(project.selectedOverlay(id)?.component?.parameters["radius"] == nil)
    }

    @MainActor
    @Test func invalidParameterValuesAreIgnored() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))

        project.setComponentParameter(id, parameterID: "showTrend", value: .number(1))
        project.setComponentParameter(id, parameterID: "unknown", value: .number(1))
        project.setComponentParameter(id, parameterID: "accent", value: .string("not-a-color"))

        let parameters = project.selectedOverlay(id)?.component?.parameters ?? [:]
        #expect(parameters.isEmpty)

        // Only the add is on the undo stack, so one undo removes the element
        // instead of reverting an ignored parameter write.
        project.undo()
        #expect(project.selectedOverlay(id) == nil)
    }

    @MainActor
    @Test func colorParametersStoreCanonicalHex() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))

        project.setComponentParameter(id, parameterID: "accent", value: .string("#ff0000"))

        #expect(
            project.selectedOverlay(id)?.component?.parameters["accent"]
                == .string(OverlayColor(red: 1, green: 0, blue: 0, alpha: 1).componentHexString)
        )
    }

    @MainActor
    @Test func booleanParametersPersistAsBool() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))

        project.setComponentParameter(id, parameterID: "showTrend", value: .boolean(false))

        #expect(project.selectedOverlay(id)?.component?.parameters["showTrend"] == .boolean(false))
    }

    @MainActor
    @Test func stringParametersAreTruncatedToMaxLength() throws {
        let project = ProjectDocument()
        let item = try #require(
            OverlayComponentLibraryItem.all.first { $0.id == "studio.examples.lap-splits" }
        )
        let id = try #require(project.addComponentFromLibrary(item))

        let long = String(repeating: "A", count: 40)
        project.setComponentParameter(id, parameterID: "title", value: .string(long))

        #expect(
            project.selectedOverlay(id)?.component?.parameters["title"]
                == .string(String(long.prefix(32)))
        )
    }

    // MARK: - Project mutation

    @MainActor
    @Test func addingComponentElementIsOneUndoPoint() throws {
        let project = ProjectDocument()
        let reference = try reference()

        project.addComponentElement(
            reference: reference,
            parameters: ["accent": .string("#00FF00")]
        )

        #expect(project.overlayLayout.elements.count == 1)
        let element = project.overlayLayout.elements[0]
        #expect(element.type == .component)
        #expect(element.component?.reference == reference)
        #expect(element.component?.parameters == ["accent": .string("#00FF00")])
        #expect(project.selection == .overlayElement(element.id))

        project.undo()
        #expect(project.overlayLayout.elements.isEmpty)

        project.redo()
        #expect(project.overlayLayout.elements.count == 1)
    }


    // MARK: - Package import

    private struct TempPackage {
        var root: URL

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func makePackage(
        nodes: String,
        assets: [String: Data] = [:]
    ) throws -> TempPackage {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocomponent-\(UUID().uuidString)", isDirectory: true)
        let assetsDirectory = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(
            at: assetsDirectory,
            withIntermediateDirectories: true
        )
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.image",
          "version": "1.0.0",
          "name": "Image Card",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [\(nodes)]
        }
        """
        try Data(json.utf8).write(to: root.appendingPathComponent("component.json"))
        for (name, data) in assets {
            try data.write(to: assetsDirectory.appendingPathComponent(name))
        }
        return TempPackage(root: root)
    }

    private func makePNG(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        size: Int = 4
    ) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: size * 4,
            bitsPerPixel: 32
        ))
        let base = try #require(bitmap.bitmapData)
        for index in 0..<(size * size) {
            base[index * 4] = red
            base[index * 4 + 1] = green
            base[index * 4 + 2] = blue
            base[index * 4 + 3] = 255
        }
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    @Test func directoryPackageEmbedsAssetBytes() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/card.png", "fit": "fill" }"#,
            assets: ["card.png": try makePNG(red: 220, green: 40, blue: 60)]
        )
        defer { package.cleanUp() }

        let reference = try OverlayComponentLoader.loadReference(at: package.root)
        #expect(reference.id == "community.test.image")
        #expect(reference.source == .imported)
        #expect(reference.definition != nil)
        let asset = try #require(reference.assets?["assets/card.png"])
        #expect(!asset.isEmpty)
        #expect(OverlayComponentRegistry.definition(for: reference) != nil)
    }

    @Test func directoryPackageRejectsMissingAsset() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/missing.png" }"#
        )
        defer { package.cleanUp() }

        do {
            _ = try OverlayComponentLoader.loadReference(at: package.root)
            Issue.record("Expected a validation error")
        } catch let error as OverlayComponentValidationError {
            #expect(error.errors.contains { $0.path == "$.nodes[0].asset" })
        }
    }

    @MainActor
    @Test func importedPackageRoundTripsThroughProjectFile() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/card.png", "fit": "fill" }"#,
            assets: ["card.png": try makePNG(red: 10, green: 200, blue: 90)]
        )
        defer { package.cleanUp() }

        let project = ProjectDocument()
        _ = try project.importComponentPackage(at: package.root)
        #expect(project.overlayLayout.elements.count == 1)

        let fileURL = package.root.deletingLastPathComponent()
            .appendingPathComponent("import-test-\(UUID().uuidString).roproj")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try project.writeProject(to: fileURL)

        let reopened = ProjectDocument()
        _ = try reopened.loadProject(from: fileURL)
        let element = try #require(reopened.overlayLayout.elements.first)
        #expect(element.type == .component)
        let reference = try #require(element.component?.reference)
        #expect(reference.source == .imported)
        #expect(reference.assets?["assets/card.png"] != nil)
        #expect(OverlayComponentRegistry.definition(for: reference) != nil)
    }

    @MainActor
    @Test func projectComponentCatalogDeduplicatesByDigest() throws {
        let project = ProjectDocument()
        let reference = try self.reference()
        project.addComponentElement(reference: reference)
        project.addComponentElement(reference: reference)

        let entries = project.projectComponentEntries
        #expect(entries.count == 1)
        #expect(entries.first?.instanceCount == 2)
        #expect(entries.first?.displayName == "Heart Rate Pill")
    }

    @MainActor
    @Test func bundledComponentsStayOutOfProjectCatalog() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        _ = try #require(project.addComponentFromLibrary(item))
        #expect(project.projectComponentEntries.isEmpty)
    }

    @MainActor
    @Test func removingProjectComponentRemovesAllInstancesInOneUndo() throws {
        let project = ProjectDocument()
        let reference = try self.reference()
        project.addComponentElement(reference: reference)
        project.addComponentElement(reference: reference)
        let entry = try #require(project.projectComponentEntries.first)

        project.removeProjectComponent(entry)
        #expect(project.overlayLayout.elements.isEmpty)

        project.undo()
        #expect(project.overlayLayout.elements.count == 2)
    }

    @MainActor
    @Test func exportedProjectComponentReloadsWithSameDigestAndAssets() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/card.png", "fit": "fill" }"#,
            assets: ["card.png": try makePNG(red: 5, green: 6, blue: 7)]
        )
        defer { package.cleanUp() }

        let project = ProjectDocument()
        _ = try project.importComponentPackage(at: package.root)
        let entry = try #require(project.projectComponentEntries.first)

        let exportURL = package.root.deletingLastPathComponent()
            .appendingPathComponent("export-\(UUID().uuidString).rocomponent", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try OverlayComponentPackageWriter.write(entry.reference, to: exportURL)

        let reloaded = try OverlayComponentLoader.loadReference(at: exportURL)
        #expect(reloaded.digest == entry.reference.digest)
        #expect(reloaded.id == entry.reference.id)
        #expect(reloaded.assets?["assets/card.png"] == entry.reference.assets?["assets/card.png"])
    }

    @MainActor
    @Test func duplicatingComponentOverlayKeepsItsPayload() throws {
        let project = ProjectDocument()
        let item = try #require(OverlayComponentLibraryItem.all.first { $0.id == "studio.builtin.heart-rate-pill" })
        let id = try #require(project.addComponentFromLibrary(item))
        project.setComponentParameter(id, parameterID: "radius", value: .number(12))
        let original = try #require(project.overlayLayout.elements.first { $0.id == id })

        project.duplicateOverlay(id)

        let copy = try #require(project.overlayLayout.elements.last)
        #expect(copy.id != id)
        #expect(copy.component == original.component)
        #expect(project.overlayLayout.elements.count == 2)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
    }

    @Test func componentCLIParsesValidateAndRenderArguments() throws {
        let validate = try ComponentCLICommand.parse(arguments: [
            "RunningOverlay", "--component-validate", "Packages/Card"
        ])
        guard case let .validate(command)? = validate else {
            Issue.record("Expected a validate command")
            return
        }
        #expect(command.packageURL.path.hasSuffix("Packages/Card"))

        let render = try ComponentCLICommand.parse(arguments: [
            "RunningOverlay", "--component-render", "Packages/Card",
            "--component-output", "out.png", "--component-scale", "3"
        ])
        guard case let .render(renderCommand)? = render else {
            Issue.record("Expected a render command")
            return
        }
        #expect(renderCommand.outputURL.path.hasSuffix("out.png"))
        #expect(renderCommand.scale == 3)

        #expect(throws: ComponentCLIError.self) {
            _ = try ComponentCLICommand.parse(arguments: [
                "RunningOverlay", "--component-render", "Packages/Card"
            ])
        }
    }

    /// Every Overlay Pool visual/decor tile creates a bundled component, not a
    /// native element. Native types still decode for projects saved earlier.
    @Test func poolTilesCreateBundledComponents() throws {
        let items = OverlayComponentLibraryItem.all
        #expect(!OverlayTileInfo.all.isEmpty)
        for tile in OverlayTileInfo.all {
            let matches = items.filter { $0.id == tile.componentID }
            #expect(matches.count == 1, "\(tile.type) maps to \(tile.componentID)")
            let item = try #require(matches.first)
            _ = try OverlayComponentLibrary.reference(for: item)
        }
    }

    /// The preview resolves every component each frame. A bundled lookup that
    /// re-reads and re-parses the resource makes timeline and element drags
    /// unusable, so pin the cache.
    @Test func bundledDefinitionsAreCached() throws {
        let item = try #require(OverlayComponentLibraryItem.decor.first)
        let reference = try OverlayComponentLibrary.reference(for: item)
        // Warm the cache; other suites may load definitions concurrently, so
        // only this reference's own load count must stay flat.
        _ = OverlayComponentRegistry.definition(for: reference)
        #if DEBUG
        let afterWarm = OverlayComponentRegistry.bundledLoadCount(for: reference)
        _ = OverlayComponentRegistry.definition(for: reference)
        #expect(OverlayComponentRegistry.bundledLoadCount(for: reference) == afterWarm)
        #endif
    }

    // MARK: - Rendering

    #if canImport(CSkiaBridge)
    @Test func skiaRendererDrawsComponentPixels() throws {
        // Element-level shadow/glow is host styling applied around the whole
        // component; disable it here so the samples isolate the definition's
        // background and text.
        var style = OverlayStyle.default
        style.shadowEnabled = false
        style.glowEnabled = false
        let element = OverlayElement(
            type: .component,
            position: CGPoint(x: 0.1, y: 0.2),
            scale: 1,
            style: style,
            component: OverlayComponentInstance(reference: try reference())
        )
        #expect(SkiaEasyRunRenderer.supports(element))

        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 150
        ))

        var visibleSamples = 0
        for y in stride(from: 0, to: Int(size.height), by: 8) {
            for x in stride(from: 0, to: Int(size.width), by: 8) {
                if pixels[y * rowBytes + x * 4 + 3] > 0 {
                    visibleSamples += 1
                }
            }
        }
        #expect(visibleSamples > 0)

        // The instance is top-leading anchored at (0.1, 0.2) and scaled 1:1 at
        // 1280×720, so its rect is (128, 144, 240, 72). The interior sample is
        // the declared background #0B1220CC; outside the rect stays clear.
        let interior = pixel(pixels, rowBytes: rowBytes, x: 188, y: 210)
        #expect(abs(interior.a - 204) <= 3)
        #expect(abs(interior.b - 25) <= 6)
        #expect(abs(interior.g - 14) <= 6)
        #expect(abs(interior.r - 9) <= 6)

        let outside = pixel(pixels, rowBytes: rowBytes, x: 120, y: 140)
        #expect(outside.a == 0)

        // The heart-rate text resolves `accent` (#FF4D4F). Premultiplied
        // samples from those glyphs are strongly red and distinctly not the
        // dark navy background.
        var accentSamples = 0
        for y in stride(from: 144, to: 216, by: 2) {
            for x in stride(from: 128, to: 368, by: 2) {
                let sample = pixel(pixels, rowBytes: rowBytes, x: x, y: y)
                if sample.r > 120, sample.g < 120, sample.a > 100 {
                    accentSamples += 1
                }
            }
        }
        #expect(accentSamples > 0)
    }

    private func pixel(
        _ pixels: UnsafePointer<UInt8>,
        rowBytes: Int,
        x: Int,
        y: Int
    ) -> (b: Int, g: Int, r: Int, a: Int) {
        let offset = y * rowBytes + x * 4
        return (
            Int(pixels[offset]),
            Int(pixels[offset + 1]),
            Int(pixels[offset + 2]),
            Int(pixels[offset + 3])
        )
    }

    @Test func stackAutoSizedTextHonorsNodeOpacity() throws {
        let package = try makePackage(
            nodes: #"""
            {
              "type": "stack",
              "children": [
                {
                  "type": "text", "text": "A",
                  "font": { "family": "Helvetica Neue", "size": 28, "weight": "semibold" },
                  "color": "#FFFFFF", "opacity": 0.5
                }
              ]
            }
            """#
        )
        defer { package.cleanUp() }

        var style = OverlayStyle.default
        style.shadowEnabled = false
        style.glowEnabled = false
        let element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: style,
            component: OverlayComponentInstance(
                reference: try OverlayComponentLoader.loadReference(at: package.root)
            )
        )
        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        var maximumAlpha = 0
        for y in 0..<100 {
            for x in 0..<100 {
                maximumAlpha = max(maximumAlpha, Int(pixels[y * rowBytes + x * 4 + 3]))
            }
        }
        // The opacity layer must cover the auto-sized text; a zero-size layer
        // would clip it away entirely.
        #expect(maximumAlpha > 100)
        #expect(maximumAlpha < 200)
    }

    @Test func skiaRendererDrawsRepeatBasedComponent() throws {
        let instance = OverlayComponentInstance(
            reference: try reference("lap-splits")
        )
        let element = OverlayElement(
            type: .component,
            position: CGPoint(x: 0.05, y: 0.1),
            scale: 1,
            style: .default,
            component: instance
        )
        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 150
        ))

        var visibleSamples = 0
        for y in stride(from: 0, to: Int(size.height), by: 8) {
            for x in stride(from: 0, to: Int(size.width), by: 8) {
                if pixels[y * rowBytes + x * 4 + 3] > 0 {
                    visibleSamples += 1
                }
            }
        }
        #expect(visibleSamples > 0)
    }


    @Test func skiaRendererDrawsImageAssets() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/card.png", "fit": "fill" }"#,
            assets: ["card.png": try makePNG(red: 230, green: 40, blue: 50)]
        )
        defer { package.cleanUp() }

        let reference = try OverlayComponentLoader.loadReference(at: package.root)
        let element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: .default,
            component: OverlayComponentInstance(reference: reference)
        )
        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        let inside = pixel(pixels, rowBytes: rowBytes, x: 50, y: 50)
        #expect(inside.a > 240)
        #expect(inside.r > 200)
        #expect(inside.g < 80)

        let outside = pixel(pixels, rowBytes: rowBytes, x: 150, y: 50)
        #expect(outside.a == 0)
    }

    @MainActor
    @Test func componentRenderCommandWritesPNG() throws {
        let package = try makePackage(
            nodes: #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/card.png", "fit": "fill" }"#,
            assets: ["card.png": try makePNG(red: 20, green: 180, blue: 240)]
        )
        defer { package.cleanUp() }
        let output = package.root.deletingLastPathComponent()
            .appendingPathComponent("component-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output) }

        let url = try ComponentCommandRunner.renderComponent(
            ComponentRenderCommand(
                packageURL: package.root,
                outputURL: output,
                scale: 2
            )
        )
        #expect(url == output)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 200)
        #expect(image.height == 200)
    }

    @Test func unresolvedComponentDrawsNothingWithoutFailing() throws {
        let reference = OverlayComponentReference(
            id: "studio.missing",
            version: "1.0.0",
            digest: "sha256:0",
            source: .bundled
        )
        let element = OverlayElement(
            type: .component,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: .default,
            component: OverlayComponentInstance(reference: reference)
        )

        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        var visible = false
        for y in stride(from: 0, to: Int(size.height), by: 8) {
            for x in stride(from: 0, to: Int(size.width), by: 8) where pixels[y * rowBytes + x * 4 + 3] > 0 {
                visible = true
                break
            }
        }
        #expect(visible == false)
    }

    private func contentSizedReference() throws -> OverlayComponentReference {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.content-sized",
          "version": "1.0.0",
          "name": "Content Sized",
          "license": "MIT",
          "size": "content",
          "padding": ["=pad", 6],
          "minSize": [0, "=minHeight"],
          "params": [
            { "id": "label", "type": "string", "label": "Label", "default": "1" },
            { "id": "pad", "type": "number", "label": "Pad", "min": 0, "max": 40, "default": 0 },
            { "id": "minHeight", "type": "number", "label": "Min Height", "min": 0, "max": 400, "default": 0 }
          ],
          "background": { "color": "#FF0000FF" },
          "nodes": [
            {
              "type": "text", "text": "=label",
              "font": { "family": "Helvetica Neue", "size": 28, "weight": "semibold" },
              "color": "#FFFFFF"
            }
          ]
        }
        """
        return try OverlayComponentReference(definitionData: Data(json.utf8), source: .imported)
    }

    private func contentSizedElement(
        _ reference: OverlayComponentReference,
        parameters: [String: OverlayJSONValue]
    ) -> OverlayElement {
        var style = OverlayStyle.default
        style.shadowEnabled = false
        style.glowEnabled = false
        return OverlayElement(
            type: .component,
            position: CGPoint(x: 0.1, y: 0.1),
            scale: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference, parameters: parameters)
        )
    }

    @Test func contentSizedFrameFollowsValuePaddingAndMinimumSize() throws {
        let reference = try contentSizedReference()
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1280, height: 720),
            activity: makeTimeline(),
            elapsedTime: 0
        )
        func frame(_ parameters: [String: OverlayJSONValue]) throws -> CGRect {
            try #require(OverlayComponentSkiaRenderer.frame(
                for: contentSizedElement(reference, parameters: parameters),
                renderContext: context
            ))
        }

        let narrow = try frame(["label": .string("1")])
        let wide = try frame(["label": .string("1111")])
        #expect(narrow.origin == CGPoint(x: 128, y: 72))
        #expect(wide.width > narrow.width * 2)
        #expect(abs(wide.height - narrow.height) < 0.001)

        let padded = try frame(["label": .string("1"), "pad": .number(10)])
        #expect(abs(padded.width - narrow.width - 20) < 0.001)

        let tall = try frame(["label": .string("1"), "minHeight": .number(200)])
        #expect(abs(tall.height - (200 + 12)) < 0.001)

        // The preview hit/selection frame uses the same measurement.
        let element = contentSizedElement(reference, parameters: ["label": .string("1111")])
        #expect(PreviewElementGeometry.frame(for: element, in: context) == wide)
    }

    @Test func contentSizedBackgroundFillsMeasuredBounds() throws {
        let reference = try contentSizedReference()
        let element = contentSizedElement(
            reference,
            parameters: ["label": .string("88"), "pad": .number(10)]
        )
        let size = CGSize(width: 1280, height: 720)
        let context = OverlayRenderContext(canvasSize: size, activity: makeTimeline(), elapsedTime: 0)
        let bounds = try #require(OverlayComponentSkiaRenderer.frame(for: element, renderContext: context))
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        let midY = Int(bounds.midY)
        let insideRight = pixel(pixels, rowBytes: rowBytes, x: Int(bounds.maxX.rounded(.down)) - 1, y: midY)
        #expect(insideRight.a == 255)
        #expect(insideRight.r == 255)
        let outsideRight = pixel(pixels, rowBytes: rowBytes, x: Int(bounds.maxX.rounded(.up)) + 1, y: midY)
        #expect(outsideRight.a == 0)
        let insideBottom = pixel(pixels, rowBytes: rowBytes, x: Int(bounds.midX), y: Int(bounds.maxY.rounded(.down)) - 1)
        #expect(insideBottom.a == 255)
    }

    @Test func skiaRendererDrawsSymbolNode() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.symbol",
          "version": "1.0.0",
          "name": "Symbol",
          "license": "MIT",
          "size": [60, 60],
          "nodes": [
            { "type": "symbol", "name": "heart.fill", "frame": [10, 10, 40, 40], "color": "#FF0000" }
          ]
        }
        """
        let reference = try OverlayComponentReference(definitionData: Data(json.utf8), source: .imported)
        var style = OverlayStyle.default
        style.shadowEnabled = false
        style.glowEnabled = false
        let element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference)
        )
        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        var redInside = 0
        var paintedOutside = 0
        for y in 0..<70 {
            for x in 0..<70 {
                let sample = pixel(pixels, rowBytes: rowBytes, x: x, y: y)
                let inGlyphBox = (10..<50).contains(x) && (10..<50).contains(y)
                if inGlyphBox, sample.a > 200, sample.r > 200, sample.g < 40 {
                    redInside += 1
                } else if !inGlyphBox, sample.a > 0 {
                    paintedOutside += 1
                }
            }
        }
        #expect(redInside > 400)
        #expect(paintedOutside == 0)
    }

    @MainActor
    @Test func componentRenderCommandCropsContentSizedComponent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocomponent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.content-cli",
          "version": "1.0.0",
          "name": "Content CLI",
          "license": "MIT",
          "size": "content",
          "minSize": [50, 30],
          "nodes": [
            { "type": "rect", "frame": [0, 0, 40, 20], "fill": "#FFFFFF" }
          ]
        }
        """
        try Data(json.utf8).write(to: root.appendingPathComponent("component.json"))
        let output = root.appendingPathComponent("out.png")

        let url = try ComponentCommandRunner.renderComponent(
            ComponentRenderCommand(packageURL: root, outputURL: output, scale: 2)
        )
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 100)
        #expect(image.height == 60)
    }

    /// A stretched row takes the vertical stack's width and its flexible
    /// spacer pushes the last child to the trailing edge, also when the row
    /// carries a node opacity layer.
    @Test(arguments: [false, true])
    func flexibleSpacerDistributesStretchedRowWidth(withOpacity: Bool) throws {
        let opacity = withOpacity ? #", "opacity": 0.5"# : ""
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.flex",
          "version": "1.0.0",
          "name": "Flex",
          "license": "MIT",
          "size": [300, 100],
          "nodes": [
            {
              "type": "stack", "direction": "vertical",
              "children": [
                { "type": "rect", "frame": [0, 0, 200, 10], "fill": "#00FF00" },
                {
                  "type": "stack", "direction": "horizontal", "alignSelf": "stretch"\(opacity),
                  "children": [
                    { "type": "rect", "frame": [0, 0, 10, 10], "fill": "#FF0000" },
                    { "type": "spacer" },
                    { "type": "spacer", "length": 4 },
                    { "type": "rect", "frame": [0, 0, 10, 10], "fill": "#0000FF" }
                  ]
                }
              ]
            }
          ]
        }
        """
        let reference = try OverlayComponentReference(definitionData: Data(json.utf8), source: .imported)
        var style = OverlayStyle.default
        style.shadowEnabled = false
        style.glowEnabled = false
        let element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference)
        )
        let size = CGSize(width: 1280, height: 720)
        let renderer = try #require(SkiaEasyRunRenderer(size: size))
        let (pixels, rowBytes) = try #require(renderer.render(
            layout: OverlayLayout(elements: [element]),
            activity: makeTimeline(),
            elapsedTime: 0
        ))

        let left = pixel(pixels, rowBytes: rowBytes, x: 5, y: 15)
        #expect(left.r > 100 && left.b < 20)
        let right = pixel(pixels, rowBytes: rowBytes, x: 195, y: 15)
        #expect(right.b > 100 && right.r < 20)
        let gap = pixel(pixels, rowBytes: rowBytes, x: 187, y: 15)
        #expect(gap.a == 0)
        let beyond = pixel(pixels, rowBytes: rowBytes, x: 205, y: 15)
        #expect(beyond.a == 0)
    }

    @MainActor
    @Test func addingNumericPresetSeedsItsMetric() throws {
        let project = ProjectDocument()
        let item = try #require(
            OverlayComponentLibraryItem.numericPresets.first { $0.id == "studio.numeric#pace" }
        )
        let id = try #require(project.addComponentFromLibrary(item))
        let element = try #require(project.overlayLayout.elements.first { $0.id == id })
        #expect(element.component?.parameters["metricId"] == .string("pace"))
        #expect(element.component?.reference.source == .bundled)
        #expect(element.component?.reference.id == "studio.numeric")
    }
    #endif
}
