import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import RunningOverlay

/// Hit and selection geometry used by the Skia preview, where overlay elements
/// are pixels rather than SwiftUI views. The frames must come from the same
/// `OverlayRenderModel` layouts that preview and export render.
struct PreviewElementGeometryTests {
    private let canvas = CGSize(width: 1280, height: 720)

    /// Numeric readings are `studio.numeric` components, which keep the
    /// top-leading anchor native numeric overlays used.
    @Test func numericComponentIsTopLeadingAnchored() throws {
        let element = try #require(OverlayComponentLibrary.numericElement(
            .heartRate,
            position: CGPoint(x: 0.25, y: 0.4),
            scale: 1
        ))
        let frame = PreviewElementGeometry.frame(for: element, in: context)

        #expect(abs(frame.minX - 320) < 0.5)
        #expect(abs(frame.minY - 288) < 0.5)
        #expect(frame.width > 0)
        #expect(frame.height > 0)
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

    @Test func canvasTapUsesTheSameFramesForSupportedAndFallbackModules() {
        let supportedID = UUID()
        let fallbackID = UUID()
        let frames: [OverlayElement.ID: CGRect] = [
            supportedID: CGRect(x: 100, y: 100, width: 120, height: 40),
            fallbackID: CGRect(x: 400, y: 300, width: 200, height: 80),
        ]
        let visible: Set<OverlayElement.ID> = [supportedID, fallbackID]

        // Inside either module's frame the canvas must keep the selection,
        // including modules currently drawn by the SwiftUI fallback.
        #expect(PreviewCanvasHitTesting.isOverlayHit(
            at: CGPoint(x: 160, y: 120),
            frames: frames,
            visibleElementIDs: visible
        ))
        #expect(PreviewCanvasHitTesting.isOverlayHit(
            at: CGPoint(x: 500, y: 340),
            frames: frames,
            visibleElementIDs: visible
        ))
        // The 4pt tolerance applies at the edge.
        #expect(PreviewCanvasHitTesting.isOverlayHit(
            at: CGPoint(x: 97, y: 97),
            frames: frames,
            visibleElementIDs: visible
        ))
        // Empty canvas clears the selection.
        #expect(!PreviewCanvasHitTesting.isOverlayHit(
            at: CGPoint(x: 300, y: 200),
            frames: frames,
            visibleElementIDs: visible
        ))
        // Hidden elements do not absorb taps.
        #expect(!PreviewCanvasHitTesting.isOverlayHit(
            at: CGPoint(x: 160, y: 120),
            frames: frames,
            visibleElementIDs: [fallbackID]
        ))
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
        let records: [ActivityRecord] = stride(from: 0.0, through: 60, by: 1)
            .map { (t: Double) -> ActivityRecord in
                // The values are separated because an older toolchain cannot
                // type-check one large literal in reasonable time.
                let distanceMeters: Double = t * 3.3
                let heartRate: Int = 130 + Int(t / 3)
                let elevationMeters: Double = 20 + t / 10
                let calories: Double = t / 4
                let latitude: Double = 40.75 + 0.0006 * sin(t / 8)
                let longitude: Double = -73.99 + 0.0008 * cos(t / 8)
                return ActivityRecord(
                    elapsedTime: t,
                    timestamp: start.addingTimeInterval(t),
                    distanceMeters: distanceMeters,
                    heartRate: heartRate,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: elevationMeters,
                    cadence: 176,
                    powerWatts: 250,
                    calories: calories,
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
    }()
}
