import Foundation
import Testing
@testable import RunningOverlay

/// Export for Editor guidance: the steps shown, the package text file, and the
/// remembered options (ADR 0013).
struct EditorImportGuideTests {
    // MARK: - Steps

    @Test func finalCutProStepsNameTheTimelineAndLaneOne() {
        let guide = makeGuide(target: .finalCutPro)

        #expect(guide.steps.count == 3)
        #expect(guide.steps[0].detail.contains("Morning Run.fcpxml"))
        #expect(guide.steps[0].detail.contains("Open in Final Cut Pro"))
        #expect(guide.steps[2].detail.contains("lane 1"))
        #expect(guide.headline == "Overlay package ready for Final Cut Pro")
        #expect(guide.subtitle.contains("29.97 fps"))
    }

    @Test func resolveStepsMatchFrameRateBeforeImporting() {
        let guide = makeGuide(target: .resolve)

        #expect(guide.steps.count == 3)
        #expect(guide.steps[0].title == "Match the timeline frame rate")
        #expect(guide.steps[0].detail.contains("29.97 fps"))
        #expect(guide.steps[1].detail.contains("File > Import > Timeline"))
        #expect(guide.steps[1].detail.contains("Morning Run.fcpxml"))
        #expect(guide.notes.contains { $0.contains("HEVC with alpha") })
    }

    @Test func onlyFinalCutProOpensTheTimelineFileDirectly() {
        #expect(makeGuide(target: .finalCutPro).opensTimelineFileDirectly)
        #expect(makeGuide(target: .finalCutPro).openButtonTitle == "Open in Final Cut Pro")

        let resolve = makeGuide(target: .resolve)
        #expect(resolve.opensTimelineFileDirectly == false)
        #expect(resolve.openButtonTitle == "Open DaVinci Resolve")
        #expect(resolve.notes.contains { $0.contains("does not open FCPXML from Finder") })

        #expect(makeGuide(target: .other).opensTimelineFileDirectly == false)
    }

    @Test func otherEditorStepsReferenceTheOverlayMovie() {
        let guide = makeGuide(target: .other)

        #expect(guide.steps[0].detail.contains("A001_C001_overlay.mov"))
        #expect(guide.notes.contains { $0.contains("no keying") })
        #expect(guide.canOpenInEditor == false)
    }

    @Test func perClipAndFullActivityExplainTrimmingDifferently() {
        let perClip = makeGuide(mode: .perClip)
        let fullActivity = makeGuide(mode: .fullActivity)

        #expect(perClip.notes.contains { $0.contains("exactly as long as its clip") })
        #expect(fullActivity.notes.contains { $0.contains("slip the overlay") })
    }

    @Test func packedPerClipGuideExplainsMissingEmptyStretches() {
        let packed = makeGuide(keepsTimelinePositions: false)
        let preserved = makeGuide()

        #expect(packed.notes.contains { $0.contains("packed back to back") })
        #expect(!preserved.notes.contains { $0.contains("packed back to back") })
        // The full-activity layout keeps positions, so it never says this.
        #expect(!makeGuide(mode: .fullActivity, keepsTimelinePositions: false)
            .notes.contains { $0.contains("packed back to back") })
    }

    @Test func proResGuideSuggestsProResForGrading() {
        let guide = makeGuide(codec: .proRes4444)
        #expect(guide.notes.contains { $0.contains("ProRes 4444 keeps text crisp") })
    }

    // MARK: - Package help

    @Test func genericHelpGuideHasNoPackageFiles() {
        let guide = makeGuide(packageURL: nil, fcpxmlFileName: nil)

        #expect(guide.packageFileNames.isEmpty)
        #expect(guide.canOpenInEditor == false)
        #expect(guide.steps[0].detail.contains("the .fcpxml file in the package"))
        #expect(guide.headline == "Import overlays into Final Cut Pro")
    }

    @Test func packageFileNamesFollowPackageOrder() {
        let guide = makeGuide()

        #expect(guide.packageFileNames == [
            "Morning Run.fcpxml",
            "A001_C001_overlay.mov",
            "A001_C002_overlay.mov",
            EditorPackageManifest.fileName,
            EditorImportGuideText.fileName
        ])
    }

    @Test func instructionsTextNamesFilesStepsAndNotes() {
        let text = makeGuide(target: .resolve).importInstructionsText()

        #expect(text.contains("Project: Morning Run"))
        #expect(text.contains("Prepared for: DaVinci Resolve"))
        #expect(text.contains("Frame rate: 29.97 fps"))
        #expect(text.contains("- A001_C001_overlay.mov"))
        #expect(text.contains("1. Match the timeline frame rate"))
        #expect(text.contains("Notes"))
        #expect(text.hasSuffix("\n"))
    }

    // MARK: - Options

    @Test func exportOptionsRoundTripThroughJSON() throws {
        let options = EditorPackageExportOptions(
            enabled: true,
            target: .resolve,
            mode: .fullActivity,
            keepsTimelinePositions: true
        )
        let data = try JSONEncoder().encode(options)
        #expect(try JSONDecoder().decode(EditorPackageExportOptions.self, from: data) == options)
        #expect(EditorPackageExportOptions() == EditorPackageExportOptions(
            enabled: false,
            target: .finalCutPro,
            mode: .perClip
        ))
    }

    @Test func savedOptionsWithoutEnabledDecodeAsDisabled() throws {
        // Options written before the Export dialog toggle existed.
        let legacy = Data(#"{"target":"resolve","mode":"fullActivity"}"#.utf8)
        let options = try JSONDecoder().decode(EditorPackageExportOptions.self, from: legacy)
        #expect(options.enabled == false)
        #expect(options.target == .resolve)
        #expect(options.mode == .fullActivity)
        #expect(options.keepsTimelinePositions == false)
    }

    // MARK: - Export writes the guide

    @Test @MainActor func exportWritesHowToImportTextAndReturnsGuide() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-editor-guide-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mediaItem = MediaItem(
            displayName: "Clip One.mov",
            fileURL: root.appendingPathComponent("Clip One.mov"),
            duration: 0.3,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        let mediaItemID = mediaItem.id
        let request = EditorPackageExportRequest(
            activity: sampleActivity(),
            settings: makeSettings(),
            timeline: TimelineModel(tracks: [
                TimelineTrack(name: "Camera A", clips: [
                    TimelineClip(
                        mediaItemID: mediaItemID,
                        title: "Clip One",
                        startTime: 0,
                        duration: 0.3,
                        alignmentOffset: 0,
                        cameraGroupID: "Camera A"
                    )
                ])
            ]),
            mediaItems: [mediaItem],
            overlayLayout: OverlayLayout(elements: [makeDecorElement()]),
            templateName: "Morning Run",
            projectName: "Morning Run",
            mode: .perClip,
            target: .finalCutPro
        )

        let result = try await EditorPackageExporter.export(request: request, to: root)

        #expect(result.guide.editor == .finalCutPro)
        #expect(result.guide.packageURL == result.packageURL)
        #expect(result.guide.projectName == "Morning Run")

        let package = result.packageURL
        let textURL = package.appendingPathComponent(EditorImportGuideText.fileName)
        let text = try String(contentsOf: textURL, encoding: .utf8)
        #expect(text.contains("Prepared for: Final Cut Pro"))
        #expect(text.contains("Morning Run.fcpxml"))
        #expect(text.contains("Clip_One_overlay.mov"))

        #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent("Morning Run.fcpxml").path))
        #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent(EditorPackageManifest.fileName).path))
        #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent("Clip_One_overlay.mov").path))
    }

    // MARK: - Helpers

    private func makeGuide(
        target: EditorTarget = .finalCutPro,
        packageURL: URL? = URL(fileURLWithPath: "/tmp/Morning Run Editor Package", isDirectory: true),
        fcpxmlFileName: String? = "Morning Run.fcpxml",
        mode: EditorPackageMode = .perClip,
        codec: ProjectExportCodec = .hevcWithAlpha,
        keepsTimelinePositions: Bool = true
    ) -> EditorImportGuide {
        EditorImportGuide(
            editor: target,
            projectName: "Morning Run",
            packageURL: packageURL,
            fcpxmlFileName: fcpxmlFileName,
            overlayFileNames: ["A001_C001_overlay", "A001_C002_overlay"],
            frameRateID: "29.97",
            mode: mode,
            codec: codec,
            keepsTimelinePositions: keepsTimelinePositions
        )
    }

    private func sampleActivity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 1.0, by: 0.5).map { elapsed in
            ActivityRecord(
                elapsedTime: elapsed,
                timestamp: start.addingTimeInterval(elapsed),
                distanceMeters: elapsed * 2,
                heartRate: 140,
                paceSecondsPerKilometer: 300,
                elevationMeters: 10,
                cadence: 170,
                powerWatts: 250,
                calories: elapsed * 10
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 1,
            distanceMeters: 2,
            records: records,
            laps: []
        )
    }

    private func makeSettings() -> ProjectSettings {
        var settings = ProjectSettings()
        settings.resolution = ProjectResolution(id: "320x180", label: "Tiny", width: 320, height: 180)
        settings.frameRate = .fps30
        settings.exportCodec = .proRes4444
        settings.bitrateMbps = 4
        return settings
    }

    private func makeDecorElement() -> OverlayElement {
        var style = OverlayStyle.default
        style.decor.textContent = "FINISH"
        style.decor.textFont = .system(family: "Menlo")
        style.decor.textSize = 24
        style.decor.textAlignment = .center
        style.decor.textLineHeight = 1.2
        style.decor.textLetterSpacing = 0
        style.decor.textFillMode = .solid(color: .white)
        style.decor.textStrokeWidth = 0
        style.decor.textStrokeColor = .white
        style.decor.textAutoFit = false
        style.decor.width = 160
        style.decor.height = 60
        return OverlayElement(
            type: .decorText,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }
}
