#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

// `OverlayPreferenceFixtures` saves and restores process-wide UserDefaults
// keys, so golden tests in this suite must not overlap.
@Suite(.serialized, .skiaSerialized) struct SkiaIntervalTests {
    // MARK: - Shared geometry

    @Test func zoneBarRectsClampGapAndScaleActiveThickness() throws {
        let segments = (0..<4).map {
            IntervalHUDBarZoneSegment(index: $0, label: "Z\($0 + 1)", color: .white)
        }
        let frames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: segments.count,
            activeIndex: 2,
            activeWidthShare: 0
        )
        let rects = OverlayRenderModel.intervalZoneBarRects(
            frames: frames,
            segments: segments,
            barRect: CGRect(x: 100, y: 200, width: 400, height: 10),
            activeIndex: 2,
            activeThicknessScale: 1.5,
            segmentGap: 4,
            elementScale: 1,
            orientation: .horizontal
        )

        #expect(rects.count == 4)
        #expect(rects[0].rect == CGRect(x: 100, y: 200, width: 97, height: 10))
        #expect(rects[1].rect == CGRect(x: 201, y: 200, width: 97, height: 10))
        #expect(rects[2].rect == CGRect(x: 302, y: 197.5, width: 97, height: 15))
        #expect(rects[3].rect == CGRect(x: 403, y: 200, width: 97, height: 10))
    }

    @Test func zoneBarRectsOrderVerticallyFromTop() throws {
        let segments = (0..<2).map {
            IntervalHUDBarZoneSegment(index: $0, label: "Z\($0 + 1)", color: .white)
        }
        let frames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: segments.count,
            activeIndex: nil,
            activeWidthShare: 0
        )
        let rects = OverlayRenderModel.intervalZoneBarRects(
            frames: frames,
            segments: segments,
            barRect: CGRect(x: 100, y: 200, width: 10, height: 400),
            activeIndex: nil,
            activeThicknessScale: 1,
            segmentGap: 4,
            elementScale: 1,
            orientation: .vertical
        )

        #expect(rects.count == 2)
        #expect(rects[0].rect == CGRect(x: 100, y: 402, width: 10, height: 198))
        #expect(rects[1].rect == CGRect(x: 100, y: 200, width: 10, height: 198))
    }

    @Test func maskCacheQuantizesAndBoundsEntries() {
        let cache = SkiaIntervalDraw.MaskCache()
        let first = cache.mask(
            size: CGSize(width: 100, height: 100),
            cornerRadius: 4,
            fadeAmount: 0.2
        )
        let nearby = cache.mask(
            size: CGSize(width: 101, height: 99),
            cornerRadius: 4.2,
            fadeAmount: 0.201
        )
        #expect(first != nil)
        #expect(first == nearby)
        #expect(cache.cachedEntryCount == 1)

        for index in 0..<40 {
            _ = cache.mask(
                size: CGSize(width: 200 + index * 32, height: 200),
                cornerRadius: 4,
                fadeAmount: 0.2
            )
        }
        #expect(cache.cachedEntryCount <= 24)
        #expect(cache.cachedByteCount <= 96 * 1024 * 1024)
    }

    // MARK: - Golden frames

    @Test func timelineParity720pAnd1080p() async throws {
        let activity = Self.workoutSixLap()
        for size in [Self.size720p, Self.size1080p] {
            for variant in Self.timelineVariants() {
                try await Self.golden(
                    element: variant.element,
                    activity: activity,
                    elapsedTime: 150,
                    size: size,
                    label: "timeline-\(variant.name)-\(Int(size.height))p"
                )
            }
        }
    }

    @Test func timelineParity4KSubset() async throws {
        try await Self.golden(
            element: Self.timelineVariants()[0].element,
            activity: Self.workoutSixLap(),
            elapsedTime: 150,
            size: Self.size4K,
            label: "timeline-default-2160p"
        )
    }

    @Test func zoneEdgeBarParity720pAnd1080p() async throws {
        let activity = Self.workoutSixLap()
        for size in [Self.size720p, Self.size1080p] {
            for variant in Self.zoneBarVariants() {
                try await Self.golden(
                    element: variant.element,
                    activity: activity,
                    elapsedTime: 150,
                    size: size,
                    label: "zone-edge-bar-\(variant.name)-\(Int(size.height))p"
                )
            }
        }
    }

    @Test func zoneEdgeBarParity4KSubset() async throws {
        try await Self.golden(
            element: Self.zoneBarVariants()[0].element,
            activity: Self.workoutSixLap(),
            elapsedTime: 150,
            size: Self.size4K,
            label: "zone-edge-bar-default-2160p"
        )
    }

    @Test func countdownParity720pAnd1080p() async throws {
        let activity = Self.workoutSixLap()
        for size in [Self.size720p, Self.size1080p] {
            for variant in Self.countdownVariants() {
                // The full-foreground white glow is a broad, low-amplitude
                // layer; its falloff is the remaining calibration gap until
                // Group T's `SkiaTextEffects` owns element glows.
                let isEffects = variant.name == "effects"
                try await Self.golden(
                    element: variant.element,
                    activity: activity,
                    elapsedTime: 150,
                    size: size,
                    label: "countdown-\(variant.name)-\(Int(size.height))p",
                    maxChangedRatio: isEffects ? 0.10 : 0.03,
                    maxMeanDelta: isEffects ? 1.50 : 0.35
                )
            }
        }
    }

    @Test func countdownParity4KSubset() async throws {
        try await Self.golden(
            element: Self.countdownVariants()[0].element,
            activity: Self.workoutSixLap(),
            elapsedTime: 150,
            size: Self.size4K,
            label: "countdown-default-2160p"
        )
    }

    @Test func hudBarParity720pAnd1080p() async throws {
        let activity = Self.workoutSixLap()
        for size in [Self.size720p, Self.size1080p] {
            for variant in Self.hudBarVariants() {
                try await Self.golden(
                    element: variant.element,
                    activity: activity,
                    elapsedTime: 150,
                    size: size,
                    label: "hud-bar-\(variant.name)-\(Int(size.height))p",
                    maxChangedRatio: 0.08,
                    maxMeanDelta: 1.00
                )
            }
        }
    }

    @Test func hudBarParity4KSubset() async throws {
        try await Self.golden(
            element: Self.hudBarVariants()[0].element,
            activity: Self.workoutSixLap(),
            elapsedTime: 150,
            size: Self.size4K,
            label: "hud-bar-default-2160p",
            maxChangedRatio: 0.08,
            maxMeanDelta: 1.00
        )
    }

    @Test func workSummaryParity720pAnd1080p() async throws {
        let activity = Self.workoutSixLap()
        for size in [Self.size720p, Self.size1080p] {
            for variant in Self.workSummaryVariants() {
                // The secondary HStack's dividers set the row height, which
                // drives the spacer split; the fixed model now matches.
                try await Self.golden(
                    element: variant.element,
                    activity: activity,
                    elapsedTime: 303,
                    size: size,
                    label: "work-summary-\(variant.name)-\(Int(size.height))p",
                    maxChangedRatio: 0.04,
                    maxMeanDelta: 0.60
                )
            }
        }
    }

    @Test func workSummaryParity4KSubset() async throws {
        try await Self.golden(
            element: Self.workSummaryVariants()[0].element,
            activity: Self.workoutSixLap(),
            elapsedTime: 303,
            size: Self.size4K,
            label: "work-summary-default-2160p",
            maxChangedRatio: 0.04,
            maxMeanDelta: 0.60
        )
    }

    @Test func workSummaryDisplayWindow() {
        OverlayPreferenceFixtures.withDefaults {
            let activity = Self.workoutSixLap()
            let element = Self.workSummaryVariants()[0].element
            let layout = { (elapsed: TimeInterval) in
                OverlayRenderModel.intervalWorkSummaryLayout(
                    for: element,
                    in: OverlayRenderContext(
                        canvasSize: Self.size1080p,
                        activity: activity,
                        elapsedTime: elapsed
                    )
                )
            }
            #expect(layout(303).isVisible)
            #expect(!layout(310).isVisible)
            #expect(!layout(150).isVisible)
        }
    }

    @Test func timelineOneMinuteBy25Layout() {
        OverlayPreferenceFixtures.withDefaults {
            let activity = Self.oneMinuteBy25()
            let element = Self.timelineVariants()[0].element
            let context = OverlayRenderContext(
                canvasSize: Self.size1080p,
                activity: activity,
                elapsedTime: 400
            )
            let layout = OverlayRenderModel.intervalTimelineLayout(
                for: element,
                in: context
            )
            #expect(layout.segments.count > 0)
            #expect(layout.leftOverflowCount > 0 || layout.rightOverflowCount > 0)
        }
    }

    // MARK: - GPU parity

    private struct MetalHandles {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
    }

    private static let metal: MetalHandles? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        return MetalHandles(device: device, commandQueue: commandQueue)
    }()

    /// All five interval renderers go through `SkiaEasyRunRenderer` in preview
    /// and export, which can be Metal-backed. Compare that path against the CPU
    /// backend so GPU-only differences (mask upload, glow layers, glyph masks)
    /// are visible.
    @Test(.enabled(if: SkiaIntervalTests.metal != nil))
    func intervalFamilyMatchesGPU() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let size = Self.size1080p
            let activity = Self.workoutSixLap()

            func placed(_ element: OverlayElement, at position: CGPoint) -> OverlayElement {
                OverlayElement(
                    type: element.type,
                    position: position,
                    scale: element.scale,
                    isVisible: true,
                    isLocked: false,
                    style: element.style
                )
            }

            let layout = OverlayLayout(elements: [
                placed(Self.timelineVariants()[0].element, at: CGPoint(x: 0.5, y: 0.28)),
                placed(Self.hudBarVariants()[0].element, at: CGPoint(x: 0.5, y: 0.52)),
                placed(Self.countdownVariants()[0].element, at: CGPoint(x: 0.22, y: 0.78)),
                placed(Self.workSummaryVariants()[0].element, at: CGPoint(x: 0.76, y: 0.78)),
                placed(Self.zoneBarVariants()[0].element, at: CGPoint(x: 0.86, y: 0.28))
            ])

            guard let cpu = SkiaEasyRunRenderer(size: size) else {
                Issue.record("CPU Skia renderer unavailable")
                return
            }
            let (cpuPointer, cpuRowBytes) = try #require(cpu.render(
                layout: layout,
                activity: activity,
                elapsedTime: 303
            ))
            let cpuPixels = Array(
                UnsafeBufferPointer(
                    start: cpuPointer,
                    count: cpuRowBytes * Int(size.height)
                )
            )

            guard let handles = Self.metal,
                  let gpu = SkiaEasyRunRenderer(
                      size: size,
                      device: handles.device,
                      commandQueue: handles.commandQueue
                  )
            else {
                print("SKIA-INTERVAL-GPU skipped: no GPU Skia context")
                return
            }
            gpu.draw(layout: layout, activity: activity, elapsedTime: 303)
            gpu.flush(sync: true)
            guard let (gpuPointer, gpuRowBytes) = gpu.readPixels() else {
                Issue.record("GPU Skia readback failed")
                return
            }
            let gpuPixels = Array(
                UnsafeBufferPointer(
                    start: gpuPointer,
                    count: gpuRowBytes * Int(size.height)
                )
            )

            let width = Int(size.width)
            let height = Int(size.height)
            var changed = 0
            var totalDelta = 0
            var maxDelta = 0
            for y in 0..<height {
                for x in 0..<width {
                    var pixelDelta = 0
                    for channel in 0..<4 {
                        pixelDelta += abs(
                            Int(cpuPixels[y * cpuRowBytes + x * 4 + channel])
                                - Int(gpuPixels[y * gpuRowBytes + x * 4 + channel])
                        )
                    }
                    if pixelDelta > 8 {
                        changed += 1
                    }
                    maxDelta = max(maxDelta, pixelDelta)
                    totalDelta += pixelDelta
                }
            }
            let total = width * height
            let changedRatio = Double(changed) / Double(total)
            let meanDelta = Double(totalDelta) / Double(total * 4)
            print(
                "SKIA-INTERVAL-GPU changed=\(changed)/\(total) "
                    + "(\(String(format: "%.3f", changedRatio * 100))%) "
                    + "meanDelta=\(String(format: "%.4f", meanDelta)) "
                    + "maxDelta=\(maxDelta)"
            )
            #expect(changedRatio < 0.03)
            #expect(meanDelta < 1)
        }
    }

    // MARK: - Fixtures

    private static let size720p = CGSize(width: 1280, height: 720)
    private static let size1080p = CGSize(width: 1920, height: 1080)
    private static let size4K = CGSize(width: 3840, height: 2160)

    private struct Variant {
        var name: String
        var element: OverlayElement
    }

    private static func timelineVariants() -> [Variant] {
        // Pin to the system family so SwiftUI and Skia take the same font
        // resolution path. The production fallback ("PT Mono") is not bundled
        // on every machine (see the bridge freeze note).
        var defaultStyle = OverlayStyle.default
        defaultStyle.fontName = "SF Pro"
        defaultStyle.labelFontName = "SF Pro"
        defaultStyle.unitFontName = "SF Pro"
        defaultStyle.backgroundEnabled = true
        defaultStyle.shadowEnabled = true

        var effects = defaultStyle
        effects.backgroundFadeOutEnabled = true
        effects.backgroundFadeOutAmount = 0.30
        effects.borderEnabled = true
        effects.intervalTimeline.markerEnabled = true
        effects.intervalTimeline.markerLabelEnabled = true
        effects.intervalTimeline.currentProgressEnabled = true
        effects.intervalTimeline.markerFontName = "SF Pro"

        var plain = OverlayStyle.default
        plain.fontName = "SF Pro"
        plain.labelFontName = "SF Pro"
        plain.unitFontName = "SF Pro"
        plain.backgroundEnabled = false
        plain.shadowEnabled = false
        plain.borderEnabled = false
        plain.intervalTimeline.markerEnabled = false

        // Current segment is short enough that SwiftUI's VStack shrinks the
        // rep/label/duration stack vertically via minimumScaleFactor.
        var tight = defaultStyle
        tight.intervalTimeline.height = 56
        tight.intervalTimeline.segmentHeight = 28
        tight.intervalTimeline.currentSegmentHeightScale = 1.3
        tight.intervalTimeline.currentSegmentWidthFraction = 0.32

        return [
            Variant(
                name: "default",
                element: OverlayElement(
                    type: .intervalTimeline,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: defaultStyle
                )
            ),
            Variant(
                name: "effects",
                element: OverlayElement(
                    type: .intervalTimeline,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: effects
                )
            ),
            Variant(
                name: "plain",
                element: OverlayElement(
                    type: .intervalTimeline,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: plain
                )
            ),
            Variant(
                name: "tight",
                element: OverlayElement(
                    type: .intervalTimeline,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: tight
                )
            )
        ]
    }

    private static func zoneBarVariants() -> [Variant] {
        var defaultStyle = OverlayStyle.default
        defaultStyle.shadowEnabled = true

        var effects = defaultStyle
        effects.zoneEdgeBar.glowEnabled = true
        effects.zoneEdgeBar.glowIntensity = 0.55
        effects.zoneEdgeBar.markerShowsValue = true

        var scaled = defaultStyle
        scaled.zoneEdgeBar.markerSizeScale = 1.6
        scaled.zoneEdgeBar.thresholdMarkerSizeScale = 1.4

        var plain = OverlayStyle.default
        plain.shadowEnabled = false
        plain.zoneEdgeBar.borderEnabled = false
        plain.zoneEdgeBar.glowEnabled = false
        plain.zoneEdgeBar.markerEnabled = false
        plain.zoneEdgeBar.thresholdMarkerEnabled = false

        return [
            Variant(
                name: "default",
                element: OverlayElement(
                    type: .zoneEdgeBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: defaultStyle
                )
            ),
            Variant(
                name: "effects",
                element: OverlayElement(
                    type: .zoneEdgeBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: effects
                )
            ),
            Variant(
                name: "scaled",
                element: OverlayElement(
                    type: .zoneEdgeBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: scaled
                )
            ),
            Variant(
                name: "plain",
                element: OverlayElement(
                    type: .zoneEdgeBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: plain
                )
            )
        ]
    }

    private static func countdownVariants() -> [Variant] {
        func pinned(_ style: inout OverlayStyle) {
            style.fontName = "SF Pro"
            style.intervalCountdown.helperText.fontName = "SF Pro"
            style.intervalCountdown.phaseText.fontName = "SF Pro"
            style.intervalCountdown.repText.fontName = "SF Pro"
            style.intervalCountdown.countdownText.fontName = "SF Pro"
            style.intervalCountdown.captionText.fontName = "SF Pro"
        }

        var defaultStyle = OverlayStyle.default
        pinned(&defaultStyle)

        var effects = defaultStyle
        effects.glowEnabled = true
        effects.glowIntensity = 0.55
        effects.borderEnabled = true
        effects.intervalCountdown.ringGlowIntensity = 0.65

        var plain = OverlayStyle.default
        pinned(&plain)
        plain.backgroundEnabled = false
        plain.shadowEnabled = false
        plain.glowEnabled = false
        plain.borderEnabled = false
        plain.intervalCountdown.ringGlowEnabled = false

        return [
            Variant(
                name: "default",
                element: OverlayElement(
                    type: .intervalCountdown,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: defaultStyle
                )
            ),
            Variant(
                name: "effects",
                element: OverlayElement(
                    type: .intervalCountdown,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: effects
                )
            ),
            Variant(
                name: "plain",
                element: OverlayElement(
                    type: .intervalCountdown,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: plain
                )
            )
        ]
    }

    private static func hudBarVariants() -> [Variant] {
        func pinned(_ style: inout OverlayStyle) {
            style.fontName = "SF Pro"
            style.intervalHUDBar.labelText.fontName = "SF Pro"
            style.intervalHUDBar.primaryValueText.fontName = "SF Pro"
            style.intervalHUDBar.phaseText.fontName = "SF Pro"
            style.intervalHUDBar.phaseDetailText.fontName = "SF Pro"
            style.intervalHUDBar.metricValueText.fontName = "SF Pro"
            style.intervalHUDBar.metricUnitText.fontName = "SF Pro"
        }

        var defaultStyle = OverlayStyle.default
        pinned(&defaultStyle)

        var zones = defaultStyle
        zones.intervalHUDBar.bottomBarMode = .heartRateZones
        zones.intervalHUDBar.bottomBarGlowEnabled = true
        zones.intervalHUDBar.activeZoneWidthShare = 0.30

        var effects = defaultStyle
        effects.backgroundFadeOutEnabled = true
        effects.backgroundFadeOutAmount = 0.30
        effects.borderEnabled = true
        effects.intervalHUDBar.bottomBarGlowEnabled = true

        var plain = OverlayStyle.default
        pinned(&plain)
        plain.backgroundEnabled = false
        plain.shadowEnabled = false
        plain.borderEnabled = false
        plain.intervalHUDBar.bottomBarMode = .heartRateZones
        plain.intervalHUDBar.bottomBarBorderEnabled = false
        plain.intervalHUDBar.bottomBarGlowEnabled = false

        return [
            Variant(
                name: "default",
                element: OverlayElement(
                    type: .intervalHUDBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: defaultStyle
                )
            ),
            Variant(
                name: "zones",
                element: OverlayElement(
                    type: .intervalHUDBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: zones
                )
            ),
            Variant(
                name: "effects",
                element: OverlayElement(
                    type: .intervalHUDBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: effects
                )
            ),
            Variant(
                name: "plain",
                element: OverlayElement(
                    type: .intervalHUDBar,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: plain
                )
            )
        ]
    }

    private static func workSummaryVariants() -> [Variant] {
        func pinned(_ style: inout OverlayStyle) {
            style.fontName = "SF Pro"
            style.intervalWorkSummary.componentLabelText.fontName = "SF Pro"
            style.intervalWorkSummary.primaryValueText.fontName = "SF Pro"
            style.intervalWorkSummary.primaryLabelText.fontName = "SF Pro"
            style.intervalWorkSummary.secondaryValueText.fontName = "SF Pro"
            style.intervalWorkSummary.secondaryLabelText.fontName = "SF Pro"
        }

        var defaultStyle = OverlayStyle.default
        pinned(&defaultStyle)
        defaultStyle.backgroundEnabled = true
        defaultStyle.shadowEnabled = true

        var effects = defaultStyle
        effects.glowEnabled = true
        effects.glowIntensity = 0.55
        effects.borderEnabled = true
        effects.intervalWorkSummary.componentLabelAlignment = .leading

        var plain = OverlayStyle.default
        pinned(&plain)
        plain.backgroundEnabled = false
        plain.shadowEnabled = false
        plain.glowEnabled = false
        plain.borderEnabled = false
        plain.intervalWorkSummary.dividerEnabled = false

        return [
            Variant(
                name: "default",
                element: OverlayElement(
                    type: .intervalWorkSummary,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: defaultStyle
                )
            ),
            Variant(
                name: "effects",
                element: OverlayElement(
                    type: .intervalWorkSummary,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: effects
                )
            ),
            Variant(
                name: "plain",
                element: OverlayElement(
                    type: .intervalWorkSummary,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    isVisible: true,
                    isLocked: false,
                    style: plain
                )
            )
        ]
    }

    private struct LapSpec {
        var kind: LapKind
        var seconds: TimeInterval
        var heartRate: Int
        var paceSecondsPerKm: Double
    }

    private static func workoutSixLap() -> ActivityTimeline {
        activity(
            start: Date(timeIntervalSince1970: 1_700_000_000),
            specs: [
                LapSpec(kind: .warmup, seconds: 60, heartRate: 128, paceSecondsPerKm: 330),
                LapSpec(kind: .active, seconds: 240, heartRate: 172, paceSecondsPerKm: 248),
                LapSpec(kind: .rest, seconds: 60, heartRate: 146, paceSecondsPerKm: 420),
                LapSpec(kind: .active, seconds: 240, heartRate: 178, paceSecondsPerKm: 244),
                LapSpec(kind: .rest, seconds: 60, heartRate: 148, paceSecondsPerKm: 430),
                LapSpec(kind: .cooldown, seconds: 60, heartRate: 124, paceSecondsPerKm: 360)
            ]
        )
    }

    private static func oneMinuteBy25() -> ActivityTimeline {
        var specs: [LapSpec] = [
            LapSpec(kind: .warmup, seconds: 60, heartRate: 130, paceSecondsPerKm: 340)
        ]
        for rep in 0..<25 {
            specs.append(LapSpec(kind: .active, seconds: 60, heartRate: 176, paceSecondsPerKm: 240))
            if rep < 24 {
                specs.append(LapSpec(kind: .rest, seconds: 60, heartRate: 145, paceSecondsPerKm: 420))
            }
        }
        specs.append(LapSpec(kind: .cooldown, seconds: 60, heartRate: 125, paceSecondsPerKm: 360))
        return activity(start: Date(timeIntervalSince1970: 1_700_100_000), specs: specs)
    }

    private static func activity(start: Date, specs: [LapSpec]) -> ActivityTimeline {
        var laps: [LapRecord] = []
        var records: [ActivityRecord] = []
        var elapsed: TimeInterval = 0
        var distance: Double = 0

        for (index, spec) in specs.enumerated() {
            let lapDistance = spec.seconds * 1000 / spec.paceSecondsPerKm
            laps.append(LapRecord(
                lapIndex: index,
                startElapsedTime: elapsed,
                endElapsedTime: elapsed + spec.seconds,
                startDistanceMeters: distance,
                totalDistanceMeters: lapDistance,
                totalElapsedTime: spec.seconds,
                avgPaceSecondsPerKm: spec.paceSecondsPerKm,
                avgHeartRate: spec.heartRate,
                maxHeartRate: spec.heartRate + 4,
                avgCadenceSPM: 176,
                avgPowerWatts: 240,
                totalAscent: nil,
                kind: spec.kind
            ))
            records.append(ActivityRecord(
                elapsedTime: elapsed,
                timestamp: start.addingTimeInterval(elapsed),
                distanceMeters: distance,
                heartRate: spec.heartRate,
                paceSecondsPerKilometer: spec.paceSecondsPerKm,
                elevationMeters: 20,
                cadence: 176,
                powerWatts: 240,
                calories: elapsed / 4
            ))
            elapsed += spec.seconds
            distance += lapDistance
            records.append(ActivityRecord(
                elapsedTime: elapsed,
                timestamp: start.addingTimeInterval(elapsed),
                distanceMeters: distance,
                heartRate: spec.heartRate,
                paceSecondsPerKilometer: spec.paceSecondsPerKm,
                elevationMeters: 20,
                cadence: 176,
                powerWatts: 240,
                calories: elapsed / 4
            ))
        }

        return ActivityTimeline(
            startDate: start,
            duration: elapsed,
            distanceMeters: distance,
            records: records,
            laps: laps
        )
    }

    // MARK: - Comparison

    private struct Metrics: CustomStringConvertible {
        var label: String
        var changed: Int
        var total: Int
        var meanDelta: Double
        var maxDelta: Int
        var diffBox: CGRect
        var referenceURL: URL
        var candidateURL: URL

        var changedRatio: Double {
            total > 0 ? Double(changed) / Double(total) : 0
        }

        var description: String {
            "GOLDEN \(label) changed=\(changed)/\(total) "
                + "(\(String(format: "%.3f", changedRatio * 100))%) "
                + "meanDelta=\(String(format: "%.4f", meanDelta)) "
                + "maxDelta=\(maxDelta) diffBox=\(diffBox) "
                + "reference=\(referenceURL.path) candidate=\(candidateURL.path)"
        }
    }

    private static func golden(
        element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        label: String,
        threshold: Int = 8,
        maxChangedRatio: Double = 0.03,
        maxMeanDelta: Double = 0.35
    ) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let layout = OverlayLayout(elements: [element])
            let referenceImage = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: layout,
                activity: activity,
                elapsedTime: elapsedTime,
                size: size
            )
            let reference = try #require(SwiftUIOverlayVideoExporter.rasterizeCanvas(
                draws: [(referenceImage, CGRect(origin: .zero, size: size))],
                canvasSize: size
            ))

            let renderer = try #require(SkiaIntervalFrameRenderer(size: size))
            let (pixels, rowBytes) = try #require(renderer.render(
                layout: layout,
                activity: activity,
                elapsedTime: elapsedTime
            ))
            let width = Int(size.width)
            let height = Int(size.height)
            let referenceRowBytes = width * 4

            var changed = 0
            var maxDelta = 0
            var totalDelta = 0
            var diffBox = CGRect.null
            for y in 0..<height {
                for x in 0..<width {
                    var pixelDelta = 0
                    for channel in 0..<4 {
                        pixelDelta += abs(
                            Int(reference[y * referenceRowBytes + x * 4 + channel])
                                - Int(pixels[y * rowBytes + x * 4 + channel])
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
                .appendingPathComponent("skia-interval-goldens", isDirectory: true)
                .appendingPathComponent(label, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let referenceURL = directory.appendingPathComponent("swiftui.png")
            let candidateURL = directory.appendingPathComponent("skia.png")
            try writePNG(referenceImage, to: referenceURL)
            if let candidate = try? SkiaFrameRendererBackend.makeImage(
                pixels,
                rowBytes: rowBytes,
                size: size
            ) {
                try writePNG(candidate, to: candidateURL)
            }

            let totalPixels = width * height
            let metrics = Metrics(
                label: label,
                changed: changed,
                total: totalPixels,
                meanDelta: totalPixels > 0
                    ? Double(totalDelta) / Double(totalPixels * 4)
                    : 0,
                maxDelta: maxDelta,
                diffBox: diffBox,
                referenceURL: referenceURL,
                candidateURL: candidateURL
            )
            print(metrics)

            // Smoke bounds only. Residual is glyph antialiasing plus a ~2px
            // text-stack baseline offset that Group T's composer should absorb.
            // Tighten after human review of the PNGs.
            #expect(metrics.changedRatio < maxChangedRatio)
            #expect(metrics.meanDelta < maxMeanDelta)
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = NSBitmapImageRep(cgImage: image)
            .representation(using: .png, properties: [:]) else {
            throw GoldenFrameError.cannotCreatePNG
        }
        try data.write(to: url)
    }
}
#endif
