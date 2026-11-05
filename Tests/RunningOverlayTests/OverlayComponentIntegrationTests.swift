import Foundation
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
        #expect(OverlayComponentRegistry.definition(for: bundled) == nil)
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
            type: .heartRate,
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
              case .text(_, let text, _, let color, _, _, _, _) = textNode else {
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
              case .text(_, _, _, let color, _, _, _, _) = textNode else {
            Issue.record("expected heart-rate text node")
            return
        }
        let defaultAccent = try #require(OverlayComponentColorParser.parse("#FF4D4F"))
        #expect(abs(color.red - defaultAccent.red) < 0.001)
        #expect(abs(color.green - defaultAccent.green) < 0.001)
        #expect(abs(color.blue - defaultAccent.blue) < 0.001)
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

    // MARK: - Rendering

    #if canImport(CSkiaBridge)
    @Test func skiaRendererDrawsComponentPixels() throws {
        let element = OverlayElement(
            type: .component,
            position: CGPoint(x: 0.1, y: 0.2),
            scale: 1,
            style: .default,
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
    #endif
}
