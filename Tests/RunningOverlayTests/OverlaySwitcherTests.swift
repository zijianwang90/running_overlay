import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct OverlaySwitcherTests {
    @Test func adjacentSelectionWrapsAndSkipsLockedOverlays() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        project.addOverlayElement(.pace)
        project.addOverlayElement(.distance)
        let ids = project.overlayLayout.elements.map(\.id)
        project.setOverlayLocked(ids[1], isLocked: true)
        project.selection = .overlayElement(ids[0])

        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[2]))

        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[0]))

        project.selectAdjacentOverlay(-1)
        #expect(project.selection == .overlayElement(ids[2]))
    }

    @Test func adjacentSelectionStartsFromTheEndsWithoutAnOverlaySelection() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        project.addOverlayElement(.pace)
        let ids = project.overlayLayout.elements.map(\.id)

        project.selection = .none
        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[0]))

        project.selection = .none
        project.selectAdjacentOverlay(-1)
        #expect(project.selection == .overlayElement(ids[1]))
    }

    @Test func adjacentSelectionDoesNothingWhenEveryOverlayIsLocked() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        let id = project.overlayLayout.elements[0].id
        project.setOverlayLocked(id, isLocked: true)
        project.selection = .none

        project.selectAdjacentOverlay(1)

        #expect(project.selection == .none)
    }

    @Test func positionReadsOneBasedIndexOfTotal() {
        #expect(OverlaySwitcherTitle.position(index: 3, count: 14) == "4 of 14")
    }

    @Test func resetInspectorStyleRestoresChartDefaultsInOneUndoStep() {
        let project = ProjectDocument()
        project.addOverlayElement(.distanceTimeline)
        let id = project.overlayLayout.elements[0].id
        project.mutateDistanceTimelineStyle(id) { $0.showValue = !DistanceTimelineStyle.default.showValue }
        let edited = project.overlayLayout.elements[0].style.distanceTimeline

        project.resetOverlayInspectorStyle(id)
        #expect(project.overlayLayout.elements[0].style.distanceTimeline == .default)

        project.undo()
        #expect(project.overlayLayout.elements[0].style.distanceTimeline == edited)
    }

    @Test func resetInspectorStyleKeepsWeatherTemperatureUnit() {
        let project = ProjectDocument()
        project.addOverlayElement(.weatherWidget)
        let id = project.overlayLayout.elements[0].id
        let unit: WeatherTemperatureUnit = project.overlayLayout.elements[0].style.weatherWidget.temperatureUnit == .celsius ? .fahrenheit : .celsius
        project.mutateWeatherWidgetStyle(id) {
            $0.temperatureUnit = unit
            $0.locationText = "Edited"
        }

        project.resetOverlayInspectorStyle(id)

        let style = project.overlayLayout.elements[0].style.weatherWidget
        #expect(style.temperatureUnit == unit)
        #expect(style.locationText != "Edited")
    }
}

struct InspectorNumericInputTests {
    @Test func parsesPlainNumbersAndClampsToRange() {
        #expect(InspectorNumericInput.value(from: "42", displayText: "10", range: 0...100) == 42)
        #expect(InspectorNumericInput.value(from: "250 px", displayText: "10 px", range: 0...100) == 100)
        #expect(InspectorNumericInput.value(from: "-5", displayText: "10", range: 0...100) == 0)
        #expect(InspectorNumericInput.value(from: "1,5", displayText: "1.0", range: 0...4) == 1.5)
    }

    @Test func treatsPercentReadoutsAsUnitInterval() {
        #expect(InspectorNumericInput.value(from: "40", displayText: "75%", range: 0...1) == 0.4)
        #expect(InspectorNumericInput.value(from: "40%", displayText: "0.75", range: 0...1) == 0.4)
        #expect(InspectorNumericInput.value(from: "30", displayText: "Off", range: 0...1) == 0.3)
    }

    @Test func rejectsTextWithoutANumber() {
        #expect(InspectorNumericInput.value(from: "abc", displayText: "10", range: 0...100) == nil)
        #expect(InspectorNumericInput.value(from: "", displayText: "10", range: 0...100) == nil)
    }
}
