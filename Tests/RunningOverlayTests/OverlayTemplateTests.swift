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

        #expect(template.schemaVersion == 1)
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

    private func temporaryTemplateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RunningOverlayTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("OverlayTemplates.json")
    }
}
