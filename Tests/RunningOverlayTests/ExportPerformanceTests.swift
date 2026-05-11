import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ExportPerformanceTests {
    @Test func projectSnapshotRoundTripsExportableStateAndClearsRuntimeState() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let snapshotURL = tempDirectory.appendingPathComponent("running_overlay_project_snapshot.json")

        let source = ProjectDocument()
        source.settings.resolution = .vertical1080
        source.settings.frameRate = .fps60
        source.settings.layerDataFrameRate = .fps5
        source.settings.bitrateMbps = 42
        source.settings.exportCodec = .proRes4444
        source.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 12,
            distanceMeters: 3000,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: Date(timeIntervalSince1970: 100),
                    distanceMeters: 0,
                    heartRate: 140,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: 10,
                    cadence: 170,
                    powerWatts: 250,
                    calories: 0
                )
            ],
            laps: []
        )
        let mediaID = UUID()
        source.mediaItems = [
            MediaItem(
                id: mediaID,
                displayName: "camera.mov",
                fileURL: URL(fileURLWithPath: "/tmp/camera.mov"),
                duration: 12,
                inferredStartDate: Date(timeIntervalSince1970: 100),
                cameraGroupID: "Camera A",
                alignmentStatus: .aligned(source: "timestamp")
            )
        ]
        source.mediaFolders = [MediaFolder(name: "Race")]
        source.timeline = TimelineModel(
            tracks: [
                TimelineTrack(name: "Camera A", clips: [
                    TimelineClip(
                        mediaItemID: mediaID,
                        title: "camera.mov",
                        startTime: 0,
                        duration: 12,
                        alignmentOffset: 0,
                        cameraGroupID: "Camera A"
                    )
                ])
            ],
            zoom: .pixelsPerSecond(12),
            playhead: 3,
            fitStartTime: 1
        )
        source.overlayLayout = OverlayLayout(elements: [
            OverlayElement(type: .heartRate, position: CGPoint(x: 0.4, y: 0.6), scale: 1.2, style: .default)
        ])
        source.userAssets = [
            UserAsset(id: UUID(), kind: .svg, originalName: "icon.svg", sha256: "abc123", fileExtension: "svg")
        ]
        source.fitSourceName = "activity.fit"
        source.saveProjectSnapshot(to: snapshotURL)

        let restored = ProjectDocument()
        restored.addOverlayElement(.pace)
        restored.selection = .overlayElement(restored.overlayLayout.elements[0].id)
        restored.isPlaying = true
        restored.playbackRate = 2
        restored.mediaPoolPreviewItemID = mediaID
        restored.mediaPoolPreviewSourceTime = 4
        restored.exportProgress = ExportProgressState(
            title: "Export",
            items: [ExportProgressItem(index: 0, name: "camera.mov", progress: 0.5, status: .exporting)]
        )
        #expect(restored.canUndo)

        restored.restoreProjectSnapshot(from: snapshotURL)

        #expect(restored.settings.resolution == .vertical1080)
        #expect(restored.settings.frameRate == .fps60)
        #expect(restored.settings.layerDataFrameRate == .fps5)
        #expect(restored.settings.bitrateMbps == 42)
        #expect(restored.settings.exportCodec == .proRes4444)
        #expect(restored.activity.duration == 12)
        #expect(restored.mediaItems.first?.displayName == "camera.mov")
        #expect(restored.mediaItems.first?.fileURL?.path == "/tmp/camera.mov")
        #expect(restored.mediaFolders.first?.name == "Race")
        #expect(restored.timeline.tracks.first?.clips.first?.title == "camera.mov")
        #expect(restored.timeline.playhead == 3)
        #expect(restored.overlayLayout.elements.first?.type == .heartRate)
        #expect(restored.userAssets.first?.originalName == "icon.svg")
        #expect(restored.fitSourceName == "activity.fit")
        #expect(restored.selection == .none)
        #expect(!restored.isPlaying)
        #expect(restored.playbackRate == 1)
        #expect(restored.mediaPoolPreviewItemID == nil)
        #expect(restored.mediaPoolPreviewSourceTime == 0)
        #expect(restored.exportProgress == nil)
        #expect(!restored.canUndo)
        #expect(!restored.canRedo)
    }

    @Test func exportProfileJSONAndCSVRepresentWholeExportWithSegments() throws {
        let segment = OverlayExportSegmentProfile(
            segmentIndex: 0,
            segmentName: "camera.mov",
            outputFileName: "camera_swiftui_overlay.mov",
            duration: 3,
            frameCount: 90,
            renderedFrameCount: 30,
            reusedFrameCount: 60,
            reuseRate: 2.0 / 3.0,
            totalDuration: 6,
            imageRenderDuration: 4,
            pixelBufferDrawDuration: 1,
            staticRenderDuration: 0.75,
            dynamicRenderDuration: 3.25,
            staticDrawDuration: 0.4,
            dynamicDrawDuration: 0.6,
            dynamicRenderAreaRatio: 0.25,
            staticLayerCacheHitCount: 90,
            dynamicRenderCount: 30,
            appendDuration: 0.5,
            writerWaitDuration: 0.25,
            averageFrameDuration: 6.0 / 90.0,
            renderPath: .layeredRegion,
            dynamicRenderRectX: 100,
            dynamicRenderRectY: 200,
            dynamicRenderRectWidth: 640,
            dynamicRenderRectHeight: 360,
            dynamicOverlayCount: 2,
            staticOverlayCount: 1,
            fullFrameFallbackCount: 0,
            renderDurationP50: 0.08,
            renderDurationP95: 0.12,
            renderDurationMax: 0.2,
            drawDurationP50: 0.01,
            drawDurationP95: 0.02,
            drawDurationMax: 0.04,
            frameDurationP50: 0.09,
            frameDurationP95: 0.14,
            frameDurationMax: 0.24,
            slowFrameThreshold: 0.28,
            slowFrameCount: 1,
            slowFrames: [
                OverlayExportSlowFrameProfile(
                    frameIndex: 12,
                    clipElapsed: 0.4,
                    sampleElapsed: 0.4,
                    reusedRender: false,
                    renderDuration: 0.2,
                    drawDuration: 0.04,
                    frameDuration: 0.24
                )
            ]
        )
        let profile = OverlayExportProfile(
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 106),
            settings: ProjectSettings(),
            segments: [segment]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OverlayExportProfile.self, from: data)

        #expect(decoded.segmentCount == 1)
        #expect(decoded.schemaVersion == 4)
        #expect(decoded.totalFrameCount == 90)
        #expect(decoded.renderedFrameCount == 30)
        #expect(decoded.reusedFrameCount == 60)
        #expect(decoded.reuseRate == 2.0 / 3.0)
        #expect(decoded.staticRenderDuration == 0.75)
        #expect(decoded.dynamicRenderDuration == 3.25)
        #expect(decoded.staticDrawDuration == 0.4)
        #expect(decoded.dynamicDrawDuration == 0.6)
        #expect(decoded.dynamicRenderAreaRatio == 0.25)
        #expect(decoded.staticLayerCacheHitCount == 90)
        #expect(decoded.dynamicRenderCount == 30)
        #expect(decoded.renderPath == .layeredRegion)
        #expect(decoded.dynamicRenderRectX == 100)
        #expect(decoded.dynamicRenderRectY == 200)
        #expect(decoded.dynamicRenderRectWidth == 640)
        #expect(decoded.dynamicRenderRectHeight == 360)
        #expect(decoded.dynamicOverlayCount == 2)
        #expect(decoded.staticOverlayCount == 1)
        #expect(decoded.fullFrameFallbackCount == 0)
        #expect(decoded.renderDurationP50 == 0.08)
        #expect(abs(decoded.renderDurationP95 - 0.12) < 0.000001)
        #expect(decoded.renderDurationMax == 0.2)
        #expect(decoded.drawDurationP50 == 0.01)
        #expect(decoded.drawDurationP95 == 0.02)
        #expect(decoded.drawDurationMax == 0.04)
        #expect(decoded.frameDurationP50 == 0.09)
        #expect(decoded.frameDurationP95 == 0.14)
        #expect(decoded.frameDurationMax == 0.24)
        #expect(decoded.slowFrameThreshold == 0.28)
        #expect(decoded.slowFrameCount == 1)
        #expect(decoded.segments.first?.slowFrames.first?.frameIndex == 12)
        #expect(decoded.segments.first?.segmentName == "camera.mov")

        let csv = profile.csvString()
        #expect(csv.contains("\"rowType\",\"segmentIndex\",\"segmentName\""))
        #expect(csv.contains("\"staticRenderDuration\",\"dynamicRenderDuration\""))
        #expect(csv.contains("\"dynamicRenderAreaRatio\",\"staticLayerCacheHitCount\",\"dynamicRenderCount\""))
        #expect(csv.contains("\"renderPath\",\"dynamicRenderRectX\",\"dynamicRenderRectY\""))
        #expect(csv.contains("\"dynamicOverlayCount\",\"staticOverlayCount\",\"fullFrameFallbackCount\""))
        #expect(csv.contains("\"renderDurationP50\",\"renderDurationP95\",\"renderDurationMax\""))
        #expect(csv.contains("\"frameDurationP50\",\"frameDurationP95\",\"frameDurationMax\""))
        #expect(csv.contains("\"slowFrameThreshold\",\"slowFrameCount\""))
        #expect(csv.contains("\"summary\""))
        #expect(csv.contains("\"segment\",\"0\",\"camera.mov\",\"camera_swiftui_overlay.mov\""))
    }

    @Test func renderPlanSeparatesStaticAndDynamicOverlays() {
        let activity = ActivityTimeline.empty
        let staticOverlay = OverlayElement(type: .decorSolidColor, position: CGPoint(x: 0.2, y: 0.2), scale: 1, style: .default)
        let dynamicOverlay = OverlayElement(type: .heartRate, position: CGPoint(x: 0.7, y: 0.7), scale: 1, style: .default)

        let plan = ExportRenderPlan(
            overlays: [staticOverlay, dynamicOverlay],
            canvasSize: CGSize(width: 1920, height: 1080),
            activity: activity
        )

        #expect(plan.staticOverlays.map(\.type) == [.decorSolidColor])
        #expect(plan.dynamicOverlays.map(\.type) == [.heartRate])
        #expect(plan.dynamicRenderRect.width > 0)
        #expect(plan.dynamicRenderRect.height > 0)
        #expect(plan.dynamicRenderAreaRatio < 0.85)
        #expect(!plan.usesFullFrameDynamicRender)
        #expect(plan.renderPath == .layeredRegion)
    }

    @Test func renderPlanDynamicUnionIncludesSafePadding() throws {
        let activity = ActivityTimeline.empty
        let element = OverlayElement(type: .runningGauge, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        let canvasSize = CGSize(width: 1920, height: 1080)
        let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: 0)
        let rawRect = try #require(ExportRenderPlan.renderRect(for: element, context: context))

        let plan = ExportRenderPlan(overlays: [element], canvasSize: canvasSize, activity: activity)

        #expect(plan.dynamicRenderRect.minX <= max(rawRect.minX - ExportRenderPlan.safePadding, 0))
        #expect(plan.dynamicRenderRect.minY <= max(rawRect.minY - ExportRenderPlan.safePadding, 0))
        #expect(plan.dynamicRenderRect.maxX >= min(rawRect.maxX + ExportRenderPlan.safePadding, canvasSize.width))
        #expect(plan.dynamicRenderRect.maxY >= min(rawRect.maxY + ExportRenderPlan.safePadding, canvasSize.height))
    }

    @Test func renderPlanFallsBackToFullFrameForLargeDynamicArea() {
        var style = OverlayStyle.default
        style.routeMapWidth = 1280
        style.routeMapHeight = 720
        let element = OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 2.0, style: style)
        let canvasSize = CGSize(width: 1280, height: 720)

        let plan = ExportRenderPlan(overlays: [element], canvasSize: canvasSize, activity: .empty)

        #expect(plan.usesFullFrameDynamicRender)
        #expect(plan.renderPath == .fullFrameSingleLayer)
        #expect(plan.dynamicRenderRect == CGRect(origin: .zero, size: canvasSize))
        #expect(plan.dynamicRenderAreaRatio == 1)
    }

    @Test func exportProfileAggregatesFullFrameFallbackDiagnostics() {
        let segment = OverlayExportSegmentProfile(
            segmentIndex: 0,
            segmentName: "camera.mov",
            outputFileName: "camera_swiftui_overlay.mov",
            duration: 1,
            frameCount: 30,
            renderedFrameCount: 10,
            reusedFrameCount: 20,
            reuseRate: 2.0 / 3.0,
            totalDuration: 5,
            imageRenderDuration: 3,
            pixelBufferDrawDuration: 2,
            staticRenderDuration: 0,
            dynamicRenderDuration: 3,
            staticDrawDuration: 0,
            dynamicDrawDuration: 2,
            dynamicRenderAreaRatio: 1,
            staticLayerCacheHitCount: 0,
            dynamicRenderCount: 10,
            appendDuration: 0.1,
            writerWaitDuration: 0.1,
            averageFrameDuration: 5.0 / 30.0,
            renderPath: .fullFrameSingleLayer,
            dynamicRenderRectX: 0,
            dynamicRenderRectY: 0,
            dynamicRenderRectWidth: 1920,
            dynamicRenderRectHeight: 1080,
            dynamicOverlayCount: 6,
            staticOverlayCount: 0,
            fullFrameFallbackCount: 1,
            renderDurationP50: 0.07,
            renderDurationP95: 0.18,
            renderDurationMax: 0.3,
            drawDurationP50: 0.01,
            drawDurationP95: 0.03,
            drawDurationMax: 0.05,
            frameDurationP50: 0.08,
            frameDurationP95: 0.2,
            frameDurationMax: 0.35,
            slowFrameThreshold: 0.4,
            slowFrameCount: 2
        )

        let profile = OverlayExportProfile(
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 105),
            settings: ProjectSettings(),
            segments: [segment]
        )

        #expect(profile.renderPath == .fullFrameSingleLayer)
        #expect(profile.staticLayerCacheHitCount == 0)
        #expect(profile.fullFrameFallbackCount == 1)
        #expect(profile.dynamicRenderRectWidth == 1920)
        #expect(profile.dynamicRenderRectHeight == 1080)
        #expect(profile.dynamicOverlayCount == 6)
        #expect(profile.staticOverlayCount == 0)
        #expect(profile.renderDurationP95 == 0.18)
        #expect(profile.drawDurationMax == 0.05)
        #expect(profile.frameDurationMax == 0.35)
        #expect(profile.slowFrameCount == 2)
    }

    @Test func frameSamplingMarksRepeatedLayerDataFramesReusable() {
        let samples = SwiftUIOverlayVideoExporter.frameSamples(
            segment: OverlayExportSegment(startTime: 0, duration: 1, sourceFileName: "clip.mov"),
            frameRate: 30,
            activityDuration: 10,
            layerDataFrameRate: 10,
            fitStartTime: 0
        )

        #expect(samples.count == 30)
        #expect(samples.filter(\.reusesPreviousRender).count == 20)
        #expect(samples[0].sampleElapsed == 0)
        #expect(samples[1].sampleElapsed == 0)
        #expect(samples[3].sampleElapsed == 0.1)
    }

    @Test func frameSamplingKeepsUniqueFramesWhenLayerDataIsAtLeastVideoRate() {
        let samples = SwiftUIOverlayVideoExporter.frameSamples(
            segment: OverlayExportSegment(startTime: 5, duration: 1, sourceFileName: "clip.mov"),
            frameRate: 5,
            activityDuration: 10,
            layerDataFrameRate: 30,
            fitStartTime: 4
        )

        #expect(samples.count == 5)
        #expect(samples.filter(\.reusesPreviousRender).isEmpty)
        #expect(samples[0].clipElapsed == 0)
        #expect(samples[0].activityElapsed == 5)
        #expect(samples[0].sampleElapsed == 1)
    }
}
