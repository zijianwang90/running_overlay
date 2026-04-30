import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct OverlayTemplateTests {
    @Test func saveOverlayTemplatePersistsLayout() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.heartRate)
        let elementID = try #require(project.overlayLayout.elements.first?.id)
        project.moveOverlay(elementID, to: CGPoint(x: 0.2, y: 0.8))
        project.setOverlayScale(elementID, scale: 1.5)
        project.setOverlayForegroundColor(elementID, color: .cyan)
        project.setOverlayTextPreset(elementID, textPreset: .sportWatch)
        project.setOverlayGaugePreset(elementID, gaugePreset: .techFuture)
        project.saveOverlayTemplate(named: "Race Layout")

        let loadedProject = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        let template = try #require(loadedProject.overlayTemplates.first)

        #expect(template.schemaVersion == 2)
        #expect(template.name == "Race Layout")
        #expect(template.referenceResolution == OverlayTemplateResolution(width: 1920, height: 1080))
        #expect(template.elements.count == 1)
        #expect(template.elements[0].type == .heartRate)
        #expect(template.elements[0].positionX == 0.2)
        #expect(template.elements[0].positionY == 0.8)
        #expect(template.elements[0].scale == 1.5)
        #expect(template.elements[0].style.foregroundColor == .cyan)
        #expect(template.elements[0].style.textPreset == .sportWatch)
        #expect(template.elements[0].style.gaugePreset == .techFuture)
    }

    @Test func overlayStyleDecodesLegacyTemplatesWithDefaultStylePresets() throws {
        let json = """
        {
          "fontName": "SF Pro",
          "fontSize": 28,
          "fontWeight": "semibold",
          "foregroundColor": { "red": 1, "green": 1, "blue": 1, "alpha": 1 },
          "backgroundOpacity": 0.22,
          "shadowOpacity": 0.35,
          "shadowRadius": 4
        }
        """

        let style = try JSONDecoder().decode(OverlayStyle.self, from: Data(json.utf8))

        #expect(style.textPreset == .minimal)
        #expect(style.gaugePreset == .minimalSport)
        #expect(style.distanceTimeline.preset == .minimal)
    }

    @Test func distanceTimelineIconSlotPersistsEmbeddedSVG() throws {
        var style = OverlayStyle.default
        style.distanceTimeline = .preset(.sport)
        style.distanceTimeline.mediaSlot.mode = .animatedSVG
        style.distanceTimeline.mediaSlot.assetName = "runner.svg"
        style.distanceTimeline.mediaSlot.svgSource = "<svg viewBox=\"0 0 24 24\"><path d=\"M2 12 L22 12\" stroke=\"currentColor\"/></svg>"

        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(OverlayStyle.self, from: data)

        #expect(decoded.distanceTimeline.mediaSlot.mode == .animatedSVG)
        #expect(decoded.distanceTimeline.mediaSlot.assetName == "runner.svg")
        #expect(decoded.distanceTimeline.mediaSlot.svgSource.contains("<path"))
    }

    @Test func applyOverlayTemplateIsUndoable() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.pace)
        let originalID = try #require(project.overlayLayout.elements.first?.id)

        let template = OverlayTemplate(
            name: "Minimal",
            elements: [
                OverlayTemplateElement(
                    type: .distance,
                    positionX: 0.1,
                    positionY: 0.2,
                    scale: 2,
                    style: .default
                )
            ]
        )
        project.overlayTemplates = [template]

        project.applyOverlayTemplate(template.id)
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .distance)
        #expect(project.overlayLayout.elements[0].id != originalID)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .pace)
        #expect(project.overlayLayout.elements[0].id == originalID)
    }

    @Test func templatePoolManagementActionsPersist() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.distance)

        project.saveCurrentOverlayTemplateWithGeneratedName()
        let saved = try #require(project.overlayTemplates.first)
        #expect(saved.name == "Template")

        project.renameOverlayTemplate(saved.id, to: "Long Run")
        #expect(project.overlayTemplates.first?.name == "Long Run")

        project.duplicateOverlayTemplate(saved.id)
        #expect(project.overlayTemplates.count == 2)
        #expect(project.overlayTemplates[0].name == "Long Run Copy")

        let loadedProject = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        #expect(loadedProject.overlayTemplates.map(\.name) == ["Long Run Copy", "Long Run"])
    }

    @Test func builtInOverlayTemplateReplacesLayoutAndIsUndoable() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.pace)
        let originalID = try #require(project.overlayLayout.elements.first?.id)
        let race = try #require(BuiltInOverlayTemplate.all.first { $0.id == "race" })

        project.applyBuiltInOverlayTemplate(race)
        #expect(project.overlayLayout.elements.map(\.type) == [.distanceTimeline, .runningGauge, .routeMap, .pace])
        #expect(project.overlayLayout.elements.first?.id != originalID)
        #expect(project.selection == .none)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .pace)
        #expect(project.overlayLayout.elements[0].id == originalID)
    }

    @Test func easyRunBuiltInTemplateLoadsBundledTemplateFile() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.elapsedTime)
        let easyRun = try #require(BuiltInOverlayTemplate.all.first { $0.id == "easyRun" })

        project.applyBuiltInOverlayTemplate(easyRun)

        #expect(project.overlayLayout.elements.map(\.type) == [.pace, .heartRate, .cadence, .routeMap, .distanceTimeline])
        #expect(project.overlayLayout.elements.first?.position.x == 0.2102358908061998)
        #expect(project.overlayLayout.elements.first?.position.y == 0.9049159976211716)
        #expect(project.overlayLayout.elements.first?.style.textPreset == .splitLabel)
    }

    private func temporaryTemplateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RunningOverlayTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("OverlayTemplates.json")
    }
}
