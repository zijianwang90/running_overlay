import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Hit and selection geometry used by the Skia preview, where overlay elements
/// are pixels rather than SwiftUI views. The frames must come from the same
/// `OverlayRenderModel` layouts that preview and export render.
struct PreviewElementGeometryTests {
    private let canvas = CGSize(width: 1280, height: 720)

    @Test func numericOverlayIsTopLeadingAnchored() {
        let element = element(.heartRate, at: CGPoint(x: 0.25, y: 0.4))
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(abs(frame.minX - 320) < 0.5)
        #expect(abs(frame.minY - 288) < 0.5)
        #expect(frame.width > 0)
        #expect(frame.height > 0)
    }

    @Test func numericOverlayHitRectGrowsWithValueLength() {
        var shortValue = element(.customNumeric, at: CGPoint(x: 0.1, y: 0.1))
        shortValue.style.customNumericField = .latitude
        shortValue.style.customNumericFormat = .coordinate
        shortValue.style.customNumericPrecision = 2

        var longValue = shortValue
        longValue.style.customNumericPrecision = 6

        let shortFrame = PreviewElementGeometry.frame(for: shortValue, in: context)
        let longFrame = PreviewElementGeometry.frame(for: longValue, in: context)

        #expect(longFrame.width > shortFrame.width)
    }

    @Test func distanceTimelineUsesRenderModelRect() {
        let element = element(.distanceTimeline, at: CGPoint(x: 0.5, y: 0.3))
        let expected = OverlayRenderModel.distanceTimelineLayout(for: element, in: context).rect
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(frame == expected)
    }

    @Test func routeMapUsesRenderModelRect() {
        let element = element(.routeMap, at: CGPoint(x: 0.8, y: 0.2))
        let expected = OverlayRenderModel.routeMapLayout(for: element, in: context).rect
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(frame == expected)
    }

    @Test func zoneEdgeBarUsesRenderModelRect() {
        let element = element(.zoneEdgeBar, at: CGPoint(x: 0.5, y: 0.5))
        let expected = OverlayRenderModel.zoneEdgeBarLayout(for: element, in: context).rect
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(frame == expected)
    }

    @Test func decorElementIsCenteredOnPosition() {
        let element = element(.decorSolidColor, at: CGPoint(x: 0.5, y: 0.25))
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(abs(frame.midX - 640) < 0.5)
        #expect(abs(frame.midY - 180) < 0.5)
        #expect(frame.width > 0)
        #expect(frame.height > 0)
    }

    @Test func everyElementTypeProducesAFiniteNonEmptyFrame() {
        for type in OverlayElementType.allCases {
            let frame = PreviewElementGeometry.frame(
                for: element(type, at: CGPoint(x: 0.5, y: 0.5)),
                in: context
            )
            #expect(frame.origin.x.isFinite, "\(type.rawValue) origin")
            #expect(frame.origin.y.isFinite, "\(type.rawValue) origin")
            #expect(frame.width > 0, "\(type.rawValue) width")
            #expect(frame.height > 0, "\(type.rawValue) height")
        }
    }

    private var context: OverlayRenderContext {
        OverlayRenderContext(
            canvasSize: canvas,
            activity: Self.activity,
            elapsedTime: 10
        )
    }

    private func element(
        _ type: OverlayElementType,
        at position: CGPoint
    ) -> OverlayElement {
        OverlayElement(type: type, position: position, scale: 1, style: .default)
    }

    private static let activity: ActivityTimeline = {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 60, by: 1).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.3,
                heartRate: 130 + Int(t / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + t / 10,
                cadence: 176,
                powerWatts: 250,
                calories: t / 4,
                latitude: 40.75 + 0.0006 * sin(t / 8),
                longitude: -73.99 + 0.0008 * cos(t / 8)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }()
}
