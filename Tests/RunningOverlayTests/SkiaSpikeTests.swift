#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

@Suite(.serialized, .skiaSerialized) struct SkiaSpikeTests {
    @Test func easyRunNumericTextMatchesSwiftUIBaseline() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        // MapKit snapshots need the network; both renderers draw the same grid when the
        // provider is off, so the comparison stays deterministic.
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        let activity = Self.activity()
        let size = CGSize(width: 1920, height: 1080)
        let skia = try #require(SkiaEasyRunRenderer(size: size))
        let frames = 120

        // Baseline: the shipping SwiftUI renderer, rasterized without PNG encoding.
        let swiftStart = ContinuousClock.now
        var lastImage: CGImage?
        for i in 0..<frames {
            lastImage = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: layout,
                activity: activity,
                elapsedTime: Double(i) * 0.5,
                size: size
            )
        }
        let swiftUIMs = Self.ms(ContinuousClock.now - swiftStart) / Double(frames)
        let image = try #require(lastImage)

        let skiaStart = ContinuousClock.now
        for i in 0..<frames {
            _ = skia.render(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
        }
        let skiaMs = Self.ms(ContinuousClock.now - skiaStart) / Double(frames)

        let (skPixels, skRow) = try #require(skia.render(
            layout: layout,
            activity: activity,
            elapsedTime: Double(frames - 1) * 0.5
        ))
        let cgPixels = try #require(SwiftUIOverlayVideoExporter.rasterizeCanvas(
            draws: [(image, CGRect(origin: .zero, size: size))],
            canvasSize: size
        ))
        let cgRow = Int(size.width) * 4
        var changed = 0
        var delta = 0
        var perElement = [Int](repeating: 0, count: layout.elements.count)
        var diffBox = CGRect.null
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(cgPixels[y * cgRow + x * 4 + channel])
                            - Int(skPixels[y * skRow + x * 4 + channel])
                    )
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                    let nx = Double(x) / size.width
                    let ny = Double(y) / size.height
                    var best = 0
                    var bestDistance = Double.greatestFiniteMagnitude
                    for (index, element) in layout.elements.enumerated() {
                        let dx = nx - element.position.x
                        let dy = ny - element.position.y
                        let distance = dx * dx + dy * dy
                        if distance < bestDistance {
                            bestDistance = distance
                            best = index
                        }
                    }
                    perElement[best] += 1
                }
                delta += pixelDelta
            }
        }
        let perElementSummary = layout.elements.enumerated()
            .map { "\($0.element.type.rawValue)=\(perElement[$0.offset])" }
            .joined(separator: " ")
        // Debug artifacts for visual comparison.
        let swiftUIRep = NSBitmapImageRep(cgImage: image)
        if let png = swiftUIRep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/skia-spike-swiftui.png"))
        }
        if let provider = CGDataProvider(data: Data(bytes: skPixels, count: skRow * 1080) as CFData),
           let skiaImage = CGImage(
               width: 1920, height: 1080, bitsPerComponent: 8, bitsPerPixel: 32,
               bytesPerRow: skRow, space: CGColorSpaceCreateDeviceRGB(),
               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                   | CGBitmapInfo.byteOrder32Little.rawValue),
               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
           ) {
            let skiaRep = NSBitmapImageRep(cgImage: skiaImage)
            if let png = skiaRep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/skia-spike-skia.png"))
            }
        }

        print(
            "SKIA-SPIKE elements=\(layout.elements.count) "
                + "swiftui=\(String(format: "%.3f", swiftUIMs))ms/frame "
                + "skia=\(String(format: "%.3f", skiaMs))ms/frame "
                + "changedPixels=\(changed) "
                + "meanDelta=\(Double(delta) / (1920 * 1080 * 4)) "
                + "diffBox=\(diffBox) "
                + "perElement=[\(perElementSummary)]"
        )
        #expect(skiaMs > 0)
    }

    @Test func timeDistanceTimeline() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter { $0.type == .distanceTimeline }
        let activity = Self.activity()
        let size = CGSize(width: 1920, height: 1080)
        let skia = try #require(SkiaEasyRunRenderer(size: size))
        let frames = 30

        var plain = layout
        if var element = plain.elements.first {
            element.style.shadowEnabled = false
            element.style.glowEnabled = false
            plain.elements = [element]
        }

        for (name, candidate) in [("full", layout), ("plain", plain)] {
            let start = ContinuousClock.now
            for i in 0..<frames {
                _ = skia.render(layout: candidate, activity: activity, elapsedTime: Double(i) * 0.5)
            }
            let ms = Self.ms(ContinuousClock.now - start) / Double(frames)
            print("SKIA-DT-\(name)=\(String(format: "%.3f", ms))ms/frame")
        }
    }

    @Test func distanceTimelinePlainDiff() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter { $0.type == .distanceTimeline }
        guard var element = layout.elements.first else { return }
        element.style.shadowEnabled = false
        element.style.glowEnabled = false
        element.style.distanceTimeline.glowEnabled = false
        layout.elements = [element]
        let activity = Self.activity()
        let size = CGSize(width: 1920, height: 1080)
        let skia = try #require(SkiaEasyRunRenderer(size: size))
        let image = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
            overlayLayout: layout, activity: activity, elapsedTime: 59.5, size: size
        )
        let (skPixels, skRow) = try #require(
            skia.render(layout: layout, activity: activity, elapsedTime: 59.5)
        )
        let cgPixels = try #require(SwiftUIOverlayVideoExporter.rasterizeCanvas(
            draws: [(image, CGRect(origin: .zero, size: size))], canvasSize: size
        ))
        let cgRow = Int(size.width) * 4
        var changed = 0
        var delta = 0
        var diffBox = CGRect.null
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(cgPixels[y * cgRow + x * 4 + channel])
                            - Int(skPixels[y * skRow + x * 4 + channel])
                    )
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
                delta += pixelDelta
            }
        }
        print("SKIA-DT-PLAIN changedPixels=\(changed) meanDelta=\(Double(delta) / (1920 * 1080 * 4)) diffBox=\(diffBox)")
        let swiftUIRep = NSBitmapImageRep(cgImage: image)
        if let png = swiftUIRep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/dt-plain-swiftui.png"))
        }
        if let provider = CGDataProvider(data: Data(bytes: skPixels, count: skRow * 1080) as CFData),
           let skiaImage = CGImage(
               width: 1920, height: 1080, bitsPerComponent: 8, bitsPerPixel: 32,
               bytesPerRow: skRow, space: CGColorSpaceCreateDeviceRGB(),
               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                   | CGBitmapInfo.byteOrder32Little.rawValue),
               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
           ),
           let png = NSBitmapImageRep(cgImage: skiaImage).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/dt-plain-skia.png"))
        }
    }

    @Test func timeEachModule() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        let activity = Self.activity()
        let size = CGSize(width: 1920, height: 1080)
        let skia = try #require(SkiaEasyRunRenderer(size: size))
        let frames = 60

        for element in layout.elements {
            var single = layout
            single.elements = [element]
            let skiaStart = ContinuousClock.now
            for i in 0..<frames {
                _ = skia.render(layout: single, activity: activity, elapsedTime: Double(i) * 0.5)
            }
            let skiaMs = Self.ms(ContinuousClock.now - skiaStart) / Double(frames)

            let swiftStart = ContinuousClock.now
            for i in 0..<frames {
                _ = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                    overlayLayout: single,
                    activity: activity,
                    elapsedTime: Double(i) * 0.5,
                    size: size
                )
            }
            let swiftMs = Self.ms(ContinuousClock.now - swiftStart) / Double(frames)
            print(
                "MODULE \(element.type.rawValue) skia=\(String(format: "%.3f", skiaMs))ms "
                    + "swiftui=\(String(format: "%.3f", swiftMs))ms"
            )
        }

        let skiaStart = ContinuousClock.now
        for i in 0..<frames {
            _ = skia.render(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
        }
        let skiaAll = Self.ms(ContinuousClock.now - skiaStart) / Double(frames)
        let swiftStart = ContinuousClock.now
        for i in 0..<frames {
            _ = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: layout, activity: activity,
                elapsedTime: Double(i) * 0.5, size: size
            )
        }
        let swiftAll = Self.ms(ContinuousClock.now - swiftStart) / Double(frames)
        print(
            "MODULE all skia=\(String(format: "%.3f", skiaAll))ms "
                + "swiftui=\(String(format: "%.3f", swiftAll))ms"
        )
    }

    @Test func printEasyRunModuleLayouts() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        let size = CGSize(width: 1920, height: 1080)
        let context = OverlayRenderContext(
            canvasSize: size,
            activity: Self.activity(),
            elapsedTime: 30
        )
        for element in template.layout.elements {
            switch element.type {
            case .distanceTimeline:
                let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: context)
                print("DT rect=\(layout.rect) content=\(layout.contentRect) track=\(layout.trackRect) value=\(layout.valueText) start=\(layout.startText) finish=\(layout.finishText) points=\(layout.distancePointLabels) valueFont=\(layout.valueFontSize) unitFont=\(layout.unitFontSize) progress=\(layout.progress)")
            case .routeMap:
                let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
                print("RM rect=\(layout.rect) content=\(layout.contentRect) provider=\(layout.provider) shape=\(layout.shape) corner=\(layout.cornerRadius) progress=\(layout.progress) points=\(layout.projectedPoints.count) current=\(String(describing: layout.projectedCurrentPoint))")
            case .weatherWidget:
                let layout = OverlayRenderModel.weatherWidgetLayout(for: element, in: context)
                print("WW rect=\(layout.rect) condition=\(layout.condition) temp=\(layout.temperatureFormatted) location=\(layout.locationText) weekday=\(layout.weekdayText) label=\(layout.conditionLabel) symbol=\(layout.sfSymbolName) metrics=\(layout.metricSlots.map { "\($0.label)=\($0.value)" })")
            default:
                break
            }
        }
    }

    private static func ms(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
    }

    static func activity() -> ActivityTimeline {
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
    }
}
#endif
