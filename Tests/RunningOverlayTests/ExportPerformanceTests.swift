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
            appendDuration: 0.5,
            writerWaitDuration: 0.25,
            averageFrameDuration: 6.0 / 90.0
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
        #expect(decoded.totalFrameCount == 90)
        #expect(decoded.renderedFrameCount == 30)
        #expect(decoded.reusedFrameCount == 60)
        #expect(decoded.reuseRate == 2.0 / 3.0)
        #expect(decoded.segments.first?.segmentName == "camera.mov")

        let csv = profile.csvString()
        #expect(csv.contains("\"rowType\",\"segmentIndex\",\"segmentName\""))
        #expect(csv.contains("\"summary\""))
        #expect(csv.contains("\"segment\",\"0\",\"camera.mov\",\"camera_swiftui_overlay.mov\""))
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
