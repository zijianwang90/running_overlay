import AppKit
import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct VisualRegressionTests {
    @Test func routeMapRendererMatchesReferenceSnapshot() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-visual-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let actualURL = temporaryDirectory.appendingPathComponent("route-map.png")
        var style = OverlayStyle.default
        style.routeMapBackgroundStyle = .none
        style.glowEnabled = true
        style.foregroundColor = .cyan

        try OverlayFrameRenderer.renderPNG(
            to: actualURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: OverlayLayout(elements: [
                    OverlayElement(
                        type: .routeMap,
                        position: CGPoint(x: 0.5, y: 0.5),
                        scale: 1,
                        style: style
                    )
                ]),
                activity: syntheticRouteActivity(),
                elapsedTime: 30,
                renderGuides: false
            )
        )

        if ProcessInfo.processInfo.environment["UPDATE_VISUAL_SNAPSHOTS"] == "1" {
            let snapshotDirectory = try #require(
                ProcessInfo.processInfo.environment["VISUAL_SNAPSHOT_DIR"],
                "Snapshot updates must run through ./scripts/visual-test.sh."
            )
            let referenceURL = URL(fileURLWithPath: snapshotDirectory, isDirectory: true)
                .appendingPathComponent("route-map.png")
            try FileManager.default.createDirectory(
                at: referenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: referenceURL)
            try FileManager.default.copyItem(at: actualURL, to: referenceURL)
            return
        }

        let referenceURL = try #require(
            Bundle.module.url(
                forResource: "route-map",
                withExtension: "png",
                subdirectory: "Fixtures/VisualSnapshots"
            ),
            "Reference snapshot is missing from the test bundle."
        )
        let reference = try #require(NSImage(contentsOf: referenceURL), "Reference snapshot is missing.")
        let actual = try #require(NSImage(contentsOf: actualURL))
        let result = try compare(reference: reference, actual: actual)

        #expect(result.changedPixelRatio <= 0.03, "Changed pixel ratio: \(result.changedPixelRatio)")
        #expect(result.meanChannelDelta <= 4.0, "Mean channel delta: \(result.meanChannelDelta)")
    }

    private func compare(reference: NSImage, actual: NSImage) throws -> (changedPixelRatio: Double, meanChannelDelta: Double) {
        let referenceData = try #require(reference.tiffRepresentation)
        let actualData = try #require(actual.tiffRepresentation)
        let referenceBitmap = try #require(NSBitmapImageRep(data: referenceData))
        let actualBitmap = try #require(NSBitmapImageRep(data: actualData))
        #expect(referenceBitmap.pixelsWide == actualBitmap.pixelsWide)
        #expect(referenceBitmap.pixelsHigh == actualBitmap.pixelsHigh)

        var changedPixels = 0
        var totalDelta = 0.0
        let pixelCount = referenceBitmap.pixelsWide * referenceBitmap.pixelsHigh

        for y in 0..<referenceBitmap.pixelsHigh {
            for x in 0..<referenceBitmap.pixelsWide {
                let expected = referenceBitmap.colorAt(x: x, y: y) ?? .clear
                let observed = actualBitmap.colorAt(x: x, y: y) ?? .clear
                let deltas = [
                    abs(expected.redComponent - observed.redComponent),
                    abs(expected.greenComponent - observed.greenComponent),
                    abs(expected.blueComponent - observed.blueComponent),
                    abs(expected.alphaComponent - observed.alphaComponent),
                ]
                totalDelta += deltas.reduce(0, +) * 255
                if deltas.contains(where: { $0 * 255 > 30 }) {
                    changedPixels += 1
                }
            }
        }

        return (
            Double(changedPixels) / Double(pixelCount),
            totalDelta / Double(pixelCount * 4)
        )
    }

    private func syntheticRouteActivity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let points: [(TimeInterval, Double, Double)] = [
            (0, 40.7500, -73.9900),
            (10, 40.7520, -73.9860),
            (20, 40.7550, -73.9820),
            (30, 40.7580, -73.9840),
            (40, 40.7600, -73.9800),
            (50, 40.7620, -73.9760),
            (60, 40.7650, -73.9720),
        ]
        let records = points.map { elapsed, latitude, longitude in
            ActivityRecord(
                elapsedTime: elapsed,
                timestamp: start.addingTimeInterval(elapsed),
                distanceMeters: elapsed * 3.3,
                heartRate: 130 + Int(elapsed / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + elapsed / 10,
                cadence: 176,
                powerWatts: 250,
                calories: elapsed / 4,
                latitude: latitude,
                longitude: longitude
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }
}
