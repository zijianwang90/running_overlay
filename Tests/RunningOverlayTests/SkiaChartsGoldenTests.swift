#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Golden-frame comparisons for the Skia chart module ports. Each test renders
/// the SwiftUI export oracle and the Skia candidate, writes both PNGs, and
/// prints pixel deviation for review.
@Suite(.serialized, .skiaSerialized) struct SkiaChartsGoldenTests {
    @Test func distanceTimelineMinimal() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var layout = try easyRunLayout()
            layout.elements = layout.elements.filter { $0.type == .distanceTimeline }
            try await compare(
                layout: layout,
                elapsedTime: 42,
                label: "dt-minimal"
            )
        }
    }

    @Test func distanceTimelineSportChrome() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var layout = try easyRunLayout()
            guard var element = layout.elements.first(
                where: { $0.type == .distanceTimeline }
            ) else {
                Issue.record("EasyRun template has no distance timeline")
                return
            }

            var dt = element.style.distanceTimeline
            dt.preset = .sport
            dt.width = 560
            dt.height = 118
            dt.cornerRadius = 10
            dt.showLabel = true
            dt.label = "Distance"
            dt.labelFontName = "Helvetica Neue"
            dt.axisLabelFontName = "Helvetica Neue"
            dt.customValuesEnabled = true
            dt.customValues = [
                DistanceTimelineCustomValue(visible: true, metric: .pace),
                DistanceTimelineCustomValue(visible: true, metric: .heartRate)
            ]
            dt.statsBar.visible = true
            dt.statsBar.placement = .bottomAttached
            dt.statsBar.inside = false
            dt.statsBar.height = 46
            dt.statsBar.valueFontName = "Helvetica Neue"
            dt.statsBar.labelFontName = "Helvetica Neue"
            dt.statsBar.valueFontSize = 26
            dt.statsBar.labelFontSize = 10
            dt.customValueFontSize = 14
            dt.mediaSlotEnabled = true
            dt.mediaSlotMode = .systemIcon
            dt.mediaSlot.mode = .systemIcon
            dt.mediaSlot.systemImage = "figure.run"
            dt.mediaSlotSize = 44
            dt.markerDistanceLabelEnabled = true
            dt.showDistancePoints = true
            dt.tickMarksEnabled = true
            dt.tickDensity = 9
            dt.glowEnabled = true

            element.style.distanceTimeline = dt
            element.style.fontName = "Helvetica Neue"
            element.style.backgroundEnabled = true
            element.style.backgroundColor = OverlayColor(
                red: 0.05,
                green: 0.08,
                blue: 0.11,
                alpha: 1
            )
            element.style.backgroundOpacity = 0.82
            element.style.backgroundPaddingX = 12
            element.style.backgroundPaddingY = 10
            element.style.backgroundFadeOutEnabled = true
            element.style.backgroundFadeOutAmount = 0.45
            element.style.borderEnabled = true
            element.style.borderWidth = 2
            element.style.borderColor = OverlayColor(
                red: 0.25,
                green: 0.82,
                blue: 0.38,
                alpha: 1
            )
            element.style.borderOpacity = 0.8
            element.style.shadowEnabled = false
            element.style.glowEnabled = false
            element.position = CGPoint(x: 0.5, y: 0.35)
            layout.elements = [element]

            try await compare(
                layout: layout,
                elapsedTime: 42,
                label: "dt-sport-chrome"
            )
        }
    }

    @Test func distanceTimelineRouteProfile() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var layout = try easyRunLayout()
            guard var element = layout.elements.first(
                where: { $0.type == .distanceTimeline }
            ) else {
                Issue.record("EasyRun template has no distance timeline")
                return
            }

            var dt = element.style.distanceTimeline
            dt.preset = .route
            dt.width = 560
            dt.height = 118
            dt.elevationProfileVisible = true
            dt.markerDistanceLabelEnabled = true
            dt.showDistancePoints = true
            dt.tickMarksEnabled = false
            dt.glowEnabled = true
            dt.fadeEnabled = true
            dt.fadeAmount = 0.24
            element.style.distanceTimeline = dt
            element.style.backgroundEnabled = false
            element.style.borderEnabled = false
            element.style.shadowEnabled = false
            element.style.glowEnabled = false
            element.style.fontName = "Helvetica Neue"
            element.position = CGPoint(x: 0.5, y: 0.35)
            layout.elements = [element]

            try await compare(
                layout: layout,
                elapsedTime: 42,
                label: "dt-route-profile"
            )
        }
    }

    @Test func runningGaugeRoadRun() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = OverlayStyle.default
            style.gauge = .preset(.roadRun)
            style.gauge.fontName = "Helvetica Neue"
            let element = OverlayElement(
                type: .runningGauge,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 242,
                label: "gauge-road-run"
            )
        }
    }

    @Test func runningGaugeGlassGlow() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = OverlayStyle.default
            var gauge = RunningGaugeStyle.preset(.premiumGlass)
            gauge.layoutPreset = .topThreeMiddleBottom
            gauge.regions = RunningGaugeStyle.defaultRegions(
                for: .topThreeMiddleBottom
            )
            gauge.fontName = "Helvetica Neue"
            gauge.glassEffectEnabled = true
            gauge.glowEnabled = true
            gauge.glowRadius = 8
            gauge.glowOpacity = 0.7
            gauge.progressRingEnabled = true
            gauge.progressRoundedCaps = false
            style.gauge = gauge
            let element = OverlayElement(
                type: .runningGauge,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1.25,
                style: style
            )
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 242,
                label: "gauge-glass-glow"
            )
        }
    }

    @Test func elevationChartGradientArea() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = elevationElement(.gradientArea)
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 300,
                label: "elevation-gradient-area"
            )
        }
    }

    @Test func elevationChartDualArea() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = elevationElement(.dualArea)
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 300,
                label: "elevation-dual-area"
            )
        }
    }

    @Test func elevationChartTechGlow() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = elevationElement(.techGlow)
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 300,
                label: "elevation-tech-glow"
            )
        }
    }

    @Test func elevationChartBigNumbers() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = elevationElement(.bigNumbers)
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 300,
                label: "elevation-big-numbers"
            )
        }
    }

    @Test func elevationChartMinimalWhite() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = elevationElement(.minimalWhite)
            try await compare(
                layout: OverlayLayout(elements: [element]),
                elapsedTime: 300,
                label: "elevation-minimal-white"
            )
        }
    }

    private func elevationElement(
        _ preset: ElevationChartPreset
    ) -> OverlayElement {
        var style = OverlayStyle.default
        var elevation = ElevationChartStyle.preset(preset)
        elevation.bigNumberFontName = "Helvetica Neue"
        elevation.statsBar.valueFontName = "Helvetica Neue"
        elevation.statsBar.labelFontName = "Helvetica Neue"
        style.elevationChart = elevation
        style.fontName = "Helvetica Neue"
        return OverlayElement(
            type: .elevationChart,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    // MARK: - Helpers

    private func easyRunLayout() throws -> OverlayLayout {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate"
            )
        let template = try JSONDecoder().decode(
            OverlayTemplate.self,
            from: Data(contentsOf: url)
        )
        return template.layout
    }

    private func compare(
        layout: OverlayLayout,
        elapsedTime: TimeInterval,
        label: String,
        size: CGSize = CGSize(width: 1920, height: 1080),
        threshold: Int = 8
    ) async throws {
        let activity = Self.activity(duration: 600)
        let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
            overlayLayout: layout,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )
        let renderer = try #require(SkiaChartsRenderer(size: size))
        let (pixels, rowBytes) = try #require(
            renderer.render(
                layout: layout,
                activity: activity,
                elapsedTime: elapsedTime
            )
        )
        let candidate = try SkiaFrameRendererBackend.makeImage(
            pixels,
            rowBytes: rowBytes,
            size: size
        )

        let width = Int(size.width)
        let height = Int(size.height)
        let referencePixels = try Self.rgbaPixels(reference, width: width, height: height)
        let candidatePixels = try Self.rgbaPixels(candidate, width: width, height: height)

        var changed = 0
        var maxDelta = 0
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(referencePixels[index + channel])
                            - Int(candidatePixels[index + channel])
                    )
                }
                if pixelDelta > threshold {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
                maxDelta = max(maxDelta, pixelDelta)
                totalDelta += pixelDelta
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-charts-golden", isDirectory: true)
            .appendingPathComponent(label, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let referenceURL = directory.appendingPathComponent("\(label)-swiftui.png")
        let candidateURL = directory.appendingPathComponent("\(label)-skia.png")
        try Self.writePNG(reference, to: referenceURL)
        try Self.writePNG(candidate, to: candidateURL)

        let totalPixels = width * height
        print(
            "GOLDEN \(label) changed=\(changed)/\(totalPixels) "
                + "(\(String(format: "%.3f", Double(changed) / Double(totalPixels) * 100))%) "
                + "meanDelta=\(String(format: "%.4f", Double(totalDelta) / Double(totalPixels * 4))) "
                + "maxDelta=\(maxDelta) diffBox=\(diffBox) "
                + "reference=\(referenceURL.path) candidate=\(candidateURL.path)"
        )
    }

    private static func rgbaPixels(
        _ image: CGImage,
        width: Int,
        height: Int
    ) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw GoldenFrameError.cannotCreateContext
            }
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }
        return bytes
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw GoldenFrameError.cannotCreatePNG
        }
        try data.write(to: url)
    }

    static func activity(duration: TimeInterval) -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let step = 1.0
        let records = stride(from: 0.0, through: duration, by: step).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.3,
                heartRate: 130 + Int(t / 30),
                paceSecondsPerKilometer: 303,
                elevationMeters: 20 + 14 * sin(t / 60) + t / 90,
                cadence: 176,
                powerWatts: 250,
                calories: t / 4,
                latitude: 40.75 + 0.0006 * sin(t / 80),
                longitude: -73.99 + 0.0008 * cos(t / 80)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: duration,
            distanceMeters: duration * 3.3,
            records: records,
            laps: []
        )
    }
}
#endif
