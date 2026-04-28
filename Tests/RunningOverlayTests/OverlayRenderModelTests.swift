import Foundation
import Testing
@testable import RunningOverlay

struct OverlayRenderModelTests {
    @Test func scalesTextLayoutFromReferenceCanvas() {
        let element = OverlayElement(type: .heartRate, position: CGPoint(x: 0.25, y: 0.75), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1920, height: 1080),
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.textLayout(for: element, in: context)

        #expect(layout.value == "110 bpm")
        #expect(layout.fontSize == 42)
        #expect(layout.horizontalPadding == 15)
        #expect(layout.verticalPadding == 9)
    }

    @Test func distanceTimelineLayoutUsesSharedProgressAndGeometry() {
        let element = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.25), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: context)

        #expect(layout.label == "0.05 / 0.10 km")
        #expect(layout.progress == 0.5)
        #expect(layout.rect.width == 220)
        #expect(layout.rect.height == 58)
        #expect(layout.rect.midX == 640)
        #expect(layout.rect.midY == 180)
    }

    @Test func elevationChartLayoutCarriesSamplesAndProgress() {
        let element = OverlayElement(type: .elevationChart, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.elevationChartLayout(for: element, in: context)

        #expect(layout.label == "Elevation 105 m")
        #expect(layout.progress == 0.5)
        #expect(layout.samples == [100, 110])
        #expect(layout.chartHeight == 60)
    }

    @Test func runningGaugeLayoutCarriesCoreMetricsAndProgress() {
        let element = OverlayElement(type: .runningGauge, position: CGPoint(x: 0.4, y: 0.6), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.runningGaugeLayout(for: element, in: context)

        // Default style preset is `.roadRun` whose layout preset is
        // `.topTwoMiddleBottom`. Verify the canonical four regions land in
        // the right slots with expected metric values bound.
        let regions = Dictionary(uniqueKeysWithValues: layout.regions.map { ($0.config.region, $0) })
        #expect(regions[.top]?.components.value == "0.05")
        #expect(regions[.middleLeft]?.components.value == "--'--\"")
        #expect(regions[.middleRight]?.components.value == "00:05")
        #expect(regions[.bottom]?.components.value == "110")
        #expect(layout.progress == 0.5)
        #expect(layout.rect.width == 300)
        #expect(layout.rect.midX == 512)
        #expect(layout.rect.midY == 432)
        #expect(layout.style.layoutPreset == .topTwoMiddleBottom)
        #expect(layout.style.stylePreset == .roadRun)
    }

    @Test func routeMapLayoutProjectsGpsRouteAndCurrentPoint() {
        var style = OverlayStyle.default
        style.routeMapPreset = .glow
        let element = OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleRouteActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)

        #expect(layout.geometry?.points.count == 3)
        #expect(layout.projectedPoints.count == 3)
        #expect(layout.projectedCurrentPoint != nil)
        #expect(layout.progress == 0.5)
        // Default container size moved to 320 × 240 (4:3) so the user can
        // resize either axis independently. Square shape is no longer
        // forced to 1:1 — see `OverlayStyle.routeMapWidth/Height`.
        #expect(layout.rect.width == 320)
        #expect(layout.rect.height == 240)
        // Centering fix: every projected point and the current point must
        // stay inside `contentRect` (so the rendered stroke stays inside
        // the visible map box). We expand by a 1pt tolerance to absorb
        // double-precision rounding at the bounds where a point sits
        // exactly on the edge.
        let tolerance: CGFloat = 1
        let bounds = layout.contentRect.insetBy(dx: -tolerance, dy: -tolerance)
        for point in layout.projectedPoints {
            #expect(bounds.contains(point))
        }
        if let current = layout.projectedCurrentPoint {
            #expect(bounds.contains(current))
        }
    }

    @MainActor
    @Test func overlayFrameRendererWritesRunningGaugePNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let outputURL = directory.appendingPathComponent("running-gauge.png")
        let layout = OverlayLayout(elements: [
            OverlayElement(type: .runningGauge, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        ])
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: layout,
                activity: ProjectDocument.calibrationActivity(),
                elapsedTime: 1.5,
                renderGuides: false
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    @MainActor
    @Test func overlayFrameRendererWritesRouteMapPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var style = OverlayStyle.default
        style.routeMapPreset = .glow
        style.foregroundColor = .cyan
        let outputURL = directory.appendingPathComponent("route-map.png")
        let layout = OverlayLayout(elements: [
            OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        ])
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: layout,
                activity: sampleRouteActivity(),
                elapsedTime: 5,
                renderGuides: false
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    @Test func activityTimelineInterpolatesRoutePoint() throws {
        let point = try #require(sampleRouteActivity().routePoint(at: 5))

        #expect(point.elapsedTime == 5)
        #expect(abs(point.latitude - 40.7525) < 0.0001)
        #expect(abs(point.longitude - -73.9835) < 0.0001)
        #expect(point.heartRate == 120)
    }

    @MainActor
    @Test func calibrationOverlayLayoutCoversReferencePositions() {
        let layout = ProjectDocument.calibrationOverlayLayout()

        #expect(layout.elements.map(\.type) == [.distanceTimeline, .elevationChart, .heartRate, .distance, .pace, .elapsedTime])
        #expect(layout.elements.allSatisfy { element in
            element.position.x >= 0 && element.position.x <= 1 && element.position.y >= 0 && element.position.y <= 1
        })
    }

    @MainActor
    @Test func calibrationActivityProvidesRenderableData() {
        let activity = ProjectDocument.calibrationActivity()

        #expect(activity.duration == 3)
        #expect(activity.distanceMeters == 750)
        #expect(activity.heartRate(at: 1.5) == 160)
        #expect(activity.elevation(at: 1.5) == 112)
    }

    @MainActor
    @Test func overlayFrameRendererWritesCalibrationPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let outputURL = directory.appendingPathComponent("frame.png")
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 320, height: 180),
                layout: ProjectDocument.calibrationOverlayLayout(),
                activity: ProjectDocument.calibrationActivity(),
                elapsedTime: 1.5,
                renderGuides: true
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    private func sampleActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 1_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 100,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 100,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: 100,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 100,
                    heartRate: 120,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: 110,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                )
            ],
            laps: []
        )
    }

    private func sampleRouteActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 2_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 100,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: 10,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7500,
                    longitude: -73.9850
                ),
                ActivityRecord(
                    elapsedTime: 5,
                    timestamp: startDate.addingTimeInterval(5),
                    distanceMeters: 500,
                    heartRate: 120,
                    paceSecondsPerKilometer: 280,
                    elevationMeters: 14,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7525,
                    longitude: -73.9835
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 1000,
                    heartRate: 140,
                    paceSecondsPerKilometer: 260,
                    elevationMeters: 18,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7550,
                    longitude: -73.9800
                )
            ],
            laps: []
        )
    }
}
