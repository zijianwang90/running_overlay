import Foundation
import Testing
@testable import RunningOverlay

struct EditorPackageTests {
    // MARK: - Planner

    @Test func perClipPlannerMapsTimelineTimeToActivityElapsedTime() throws {
        let clips = [
            EditorPackageSourceClip(
                mediaName: "clip.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/clip.mov"),
                effectiveStartTime: 10,
                duration: 5,
                trackIndex: 0,
                clipIndex: 0
            ),
            EditorPackageSourceClip(
                mediaName: "My Run 01.MOV",
                mediaURL: URL(fileURLWithPath: "/tmp/run.mov"),
                effectiveStartTime: 7,
                duration: 2,
                trackIndex: 1,
                clipIndex: 0
            ),
            EditorPackageSourceClip(
                mediaName: "missing.mov",
                mediaURL: nil,
                effectiveStartTime: 5,
                duration: 1,
                trackIndex: 0,
                clipIndex: 1
            ),
            EditorPackageSourceClip(
                mediaName: "clip.MP4",
                mediaURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
                effectiveStartTime: 20,
                duration: 3,
                trackIndex: 0,
                clipIndex: 2
            )
        ]

        let plan = EditorPackagePlanner.plan(
            clips: clips,
            fitStartTime: 10,
            activityDuration: 30,
            mode: .perClip
        )

        #expect(plan.spans.map(\.name) == [
            "My_Run_01_overlay", "clip_overlay", "clip_2_overlay"
        ])
        #expect(plan.spans.map(\.activityElapsedStart) == [-3, 0, 10])
        #expect(plan.spans.map(\.duration) == [2, 5, 3])
        #expect(plan.clips.map(\.overlayFileName) == [
            "My_Run_01_overlay.mov", "clip_overlay.mov", "clip_2_overlay.mov"
        ])
        #expect(plan.clips.allSatisfy { $0.overlaySourceStart == 0 })
        #expect(plan.clips.allSatisfy { $0.mediaSourceStart == 0 })
        #expect(plan.sources.count == 3)
    }

    @Test func fullActivityPlannerUsesOneSpanAndClipAnchors() {
        let clips = [
            EditorPackageSourceClip(
                mediaName: "before.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/before.mov"),
                effectiveStartTime: 7,
                duration: 2,
                trackIndex: 0,
                clipIndex: 0
            ),
            EditorPackageSourceClip(
                mediaName: "at.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/at.mov"),
                effectiveStartTime: 10,
                duration: 5,
                trackIndex: 0,
                clipIndex: 1
            )
        ]

        let plan = EditorPackagePlanner.plan(
            clips: clips,
            fitStartTime: 10,
            activityDuration: 30,
            mode: .fullActivity
        )

        #expect(plan.spans == [
            OverlayRenderSpan(
                name: "full_activity_overlay",
                activityElapsedStart: 0,
                duration: 30
            )
        ])
        #expect(plan.clips.map(\.activityElapsedStart) == [-3, 0])
        #expect(plan.clips.map(\.overlaySourceStart) == [-3, 0])
        #expect(plan.clips.allSatisfy { $0.overlayFileName == "full_activity_overlay.mov" })
    }

    @Test func plannerSortsByStartThenTrackThenClipOrder() {
        let clips = [
            EditorPackageSourceClip(
                mediaName: "c.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/c.mov"),
                effectiveStartTime: 5,
                duration: 1,
                trackIndex: 1,
                clipIndex: 0
            ),
            EditorPackageSourceClip(
                mediaName: "b.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/b.mov"),
                effectiveStartTime: 5,
                duration: 1,
                trackIndex: 0,
                clipIndex: 1
            ),
            EditorPackageSourceClip(
                mediaName: "a.mov",
                mediaURL: URL(fileURLWithPath: "/tmp/a.mov"),
                effectiveStartTime: 5,
                duration: 1,
                trackIndex: 0,
                clipIndex: 0
            )
        ]

        let plan = EditorPackagePlanner.plan(
            clips: clips,
            fitStartTime: 0,
            activityDuration: 10,
            mode: .perClip
        )

        #expect(plan.spans.map(\.name) == ["a_overlay", "b_overlay", "c_overlay"])
    }

    @Test func overlayNameSanitizingDropsExtensionsDotsAndSlashes() {
        #expect(EditorPackageNaming.sanitizedBaseName("a.b/c d") == "a_b_c_d")
        #expect(EditorPackageNaming.sanitizedBaseName("???.mov") == "clip")
        #expect(EditorPackageNaming.sanitizedBaseName("  _run-01_ .mp4") == "run-01")

        var used: Set<String> = []
        #expect(EditorPackageNaming.uniqueOverlayName(base: "clip", usedNames: &used) == "clip_overlay")
        #expect(EditorPackageNaming.uniqueOverlayName(base: "clip", usedNames: &used) == "clip_2_overlay")
        #expect(EditorPackageNaming.uniqueOverlayName(base: "CLIP", usedNames: &used) == "CLIP_3_overlay")
    }

    // MARK: - Rational time

    @Test func frameDurationMatchesProjectFrameRates() {
        #expect(FCPXMLFrameRate(frameRate: .fps23976).frameDurationString == "1001/24000s")
        #expect(FCPXMLFrameRate(frameRate: .fps2997).frameDurationString == "1001/30000s")
        #expect(FCPXMLFrameRate(frameRate: .fps5994).frameDurationString == "1001/60000s")
        #expect(FCPXMLFrameRate(frameRate: .fps30).frameDurationString == "1/30s")
        #expect(FCPXMLFrameRate(frameRate: .fps60).frameDurationString == "1/60s")
    }

    @Test func timeStringsAreWholeFrameMultiples() {
        #expect(FCPXMLFrameRate(frameRate: .fps23976).timeString(seconds: 1) == "1001/1000s")
        #expect(FCPXMLFrameRate(frameRate: .fps2997).timeString(seconds: 1) == "1001/1000s")
        #expect(FCPXMLFrameRate(frameRate: .fps5994).timeString(seconds: 1) == "1001/1000s")
        #expect(FCPXMLFrameRate(frameRate: .fps30).timeString(seconds: 1) == "1s")
        #expect(FCPXMLFrameRate(frameRate: .fps60).timeString(frames: 1) == "1/60s")
        #expect(FCPXMLFrameRate(frameRate: .fps30).timeString(frames: 1) == "1/30s")
        #expect(FCPXMLFrameRate(frameRate: .fps30).timeString(frames: 0) == "0s")
    }

    @Test func timesRoundToNearestFrame() {
        let rate = FCPXMLFrameRate(frameRate: .fps30)
        #expect(rate.frames(seconds: 0.01) == 0)
        #expect(rate.timeString(seconds: 0.01) == "0s")
        #expect(rate.frames(seconds: 0.02) == 1)
        #expect(rate.timeString(seconds: 0.02) == "1/30s")
        #expect(rate.frames(seconds: 0.51) == 15)
        #expect(rate.timeString(seconds: 0.51) == "1/2s")
        #expect(rate.frames(seconds: 0.52) == 16)
        #expect(rate.timeString(seconds: 0.52) == "8/15s")
    }

    // MARK: - FCPXML

    @Test func fcpxmlPlacesSourceClipsBackToBackWithLaneOneOverlays() throws {
        let writer = makeWriter(clips: [
            (name: "a.mov", url: "/tmp/a.mov", duration: 2, overlay: "a_overlay.mov", sourceStart: 0, start: 0, track: 0),
            (name: "b.mov", url: "/tmp/b.mov", duration: 3, overlay: "b_overlay.mov", sourceStart: 0, start: 2, track: 0)
        ], overlays: [
            ("a_overlay.mov", 2),
            ("b_overlay.mov", 3)
        ])

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let root = try #require(document.rootElement())
        #expect(root.name == "fcpxml")
        #expect(root.attribute(forName: "version")?.stringValue == "1.10")

        let resources = try #require(root.elements(forName: "resources").first)
        let resourceIDs = (resources.elements(forName: "format") + resources.elements(forName: "asset"))
            .compactMap { $0.attribute(forName: "id")?.stringValue }
        #expect(resourceIDs.count == 5)
        #expect(Set(resourceIDs).count == resourceIDs.count)

        let documentedIDs = Set(resourceIDs)
        for node in try elements(in: document, xpath: "//*") {
            for attributeName in ["ref", "format"] {
                if let value = node.attribute(forName: attributeName)?.stringValue {
                    #expect(documentedIDs.contains(value), "Unresolved \(attributeName)=\(value)")
                }
            }
        }

        let spineClips = try elements(in: document, xpath: "//spine/asset-clip")
        #expect(spineClips.count == 2)
        #expect(spineClips[0].attribute(forName: "offset")?.stringValue == "0s")
        #expect(spineClips[0].attribute(forName: "duration")?.stringValue == "1001/500s")
        #expect(spineClips[0].attribute(forName: "start")?.stringValue == "0s")
        #expect(spineClips[1].attribute(forName: "offset")?.stringValue == "1001/500s")
        #expect(spineClips[1].attribute(forName: "duration")?.stringValue == "3003/1000s")

        let laneOne = try elements(in: document, xpath: "//asset-clip[@lane='1']")
        #expect(laneOne.count == 2)
        #expect(laneOne[0].attribute(forName: "offset")?.stringValue == "0s")
        #expect(laneOne[0].attribute(forName: "start")?.stringValue == "0s")
        #expect(laneOne[0].attribute(forName: "duration")?.stringValue == "1001/500s")
        // Connected offsets are in the parent's local time, not sequence time.
        #expect(laneOne[1].attribute(forName: "offset")?.stringValue == "0s")
        #expect(laneOne[1].attribute(forName: "start")?.stringValue == "0s")
        #expect(laneOne[1].attribute(forName: "duration")?.stringValue == "3003/1000s")

        let mediaReps = try elements(in: document, xpath: "//media-rep")
        #expect(mediaReps.count == 4)
        #expect(mediaReps.allSatisfy { ($0.attribute(forName: "src")?.stringValue ?? "").hasPrefix("file:///") })
    }

    @Test func fullActivityShiftsNegativeStartAndClampsToMovieDuration() throws {
        // 30 fps so the expected strings stay readable.
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [
                EditorPackageTimelineOverlay(
                    fileName: "full_activity_overlay.mov",
                    fileURL: URL(fileURLWithPath: "/tmp/full_activity_overlay.mov"),
                    duration: 20
                )
            ],
            clips: [
                EditorPackageTimelineClip(
                    mediaName: "early.mov",
                    mediaURL: URL(fileURLWithPath: "/tmp/early.mov"),
                    duration: 10,
                    overlayFileName: "full_activity_overlay.mov",
                    overlaySourceStart: -2,
                    startTime: 0
                ),
                EditorPackageTimelineClip(
                    mediaName: "late.mov",
                    mediaURL: URL(fileURLWithPath: "/tmp/late.mov"),
                    duration: 5,
                    overlayFileName: "full_activity_overlay.mov",
                    overlaySourceStart: 19,
                    startTime: 10
                )
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let laneOne = try elements(in: document, xpath: "//asset-clip[@lane='1']")
        #expect(laneOne.count == 2)

        // The clip starts 2 s before the activity: the overlay starts at its
        // own 0 and is shortened by 2 s.
        #expect(laneOne[0].attribute(forName: "offset")?.stringValue == "2s")
        #expect(laneOne[0].attribute(forName: "start")?.stringValue == "0s")
        #expect(laneOne[0].attribute(forName: "duration")?.stringValue == "8s")

        // The second clip begins at activity 19 s in a 20 s movie: only 1 s of
        // overlay remains. The connected clip stays at its parent's start and
        // reads from 19 s into the movie.
        #expect(laneOne[1].attribute(forName: "offset")?.stringValue == "0s")
        #expect(laneOne[1].attribute(forName: "start")?.stringValue == "19s")
        #expect(laneOne[1].attribute(forName: "duration")?.stringValue == "1s")
    }

    @Test func fullActivityOmitsOverlayOutsideMovieRange() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [
                EditorPackageTimelineOverlay(
                    fileName: "full_activity_overlay.mov",
                    fileURL: URL(fileURLWithPath: "/tmp/full_activity_overlay.mov"),
                    duration: 20
                )
            ],
            clips: [
                EditorPackageTimelineClip(
                    mediaName: "after.mov",
                    mediaURL: URL(fileURLWithPath: "/tmp/after.mov"),
                    duration: 5,
                    overlayFileName: "full_activity_overlay.mov",
                    overlaySourceStart: 21
                )
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let laneOne = try elements(in: document, xpath: "//asset-clip[@lane='1']")
        let spineClips = try elements(in: document, xpath: "//spine/asset-clip")
        #expect(laneOne.isEmpty)
        #expect(spineClips.count == 1)
    }

    @Test func fcpxmlValidatesAgainstDTDWhenConfigured() throws {
        guard let dtdPath = ProcessInfo.processInfo.environment["FCPXML_DTD"],
              FileManager.default.fileExists(atPath: dtdPath) else {
            return
        }

        let singleTrack = makeWriter(clips: [
            (name: "a.mov", url: "/tmp/a.mov", duration: 2, overlay: "a_overlay.mov", sourceStart: 0, start: 0, track: 0)
        ], overlays: [
            ("a_overlay.mov", 2)
        ])
        let multiTrack = makeWriter(clips: [
            (name: "a.mov", url: "/tmp/a.mov", duration: 2, overlay: "a_overlay.mov", sourceStart: 0, start: 0, track: 0),
            (name: "b.mov", url: "/tmp/b.mov", duration: 2, overlay: "b_overlay.mov", sourceStart: 0, start: 0.5, track: 1),
            (name: "c.mov", url: "/tmp/c.mov", duration: 1, overlay: "c_overlay.mov", sourceStart: 0, start: 3, track: 1)
        ], overlays: [
            ("a_overlay.mov", 2),
            ("b_overlay.mov", 2),
            ("c_overlay.mov", 1)
        ])

        // Foundation only consults an external subset named by the document's
        // own doctype, so point a copy at the DTD before validating.
        let dtdURL = URL(fileURLWithPath: dtdPath)
        for writer in [singleTrack, multiTrack] {
            let xml = writer.xmlString().replacingOccurrences(
                of: "<!DOCTYPE fcpxml>",
                with: "<!DOCTYPE fcpxml SYSTEM \"\(dtdURL.absoluteString)\">"
            )
            let document = try XMLDocument(data: Data(xml.utf8))
            try document.validate()
        }
    }

    // MARK: - Manifest

    @Test func manifestJSONRoundTrips() throws {
        let template = OverlayTemplate(
            name: "Overlay",
            referenceResolution: OverlayTemplateResolution(width: 1920, height: 1080),
            elements: []
        )
        let manifest = EditorPackageManifest(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            activity: EditorPackageManifest.Activity(
                startDate: Date(timeIntervalSince1970: 1_699_999_000),
                duration: 1_800,
                contentHash: "abc123"
            ),
            template: try OverlayTemplateManifest(template: template),
            output: OverlayRenderJobOutput(
                directory: ".",
                width: 1920,
                height: 1080,
                frameRateID: "29.97",
                layerDataFrameRateID: "5",
                codec: .hevcWithAlpha,
                bitrateMbps: 30
            ),
            mode: .perClip,
            overlays: [
                EditorPackageManifest.Overlay(
                    fileName: "a_overlay.mov",
                    cacheKey: "key1",
                    activityElapsedStart: 0,
                    duration: 5
                )
            ],
            clips: [
                EditorPackageManifest.Clip(
                    mediaName: "a.mov",
                    mediaSourceStart: 0,
                    duration: 5,
                    activityElapsedStart: -1,
                    overlayFileName: "a_overlay.mov",
                    overlaySourceStart: 0
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(EditorPackageManifest.self, from: data)

        #expect(decoded == manifest)
        #expect(manifest.output.directory == ".")
        #expect(manifest.overlays.allSatisfy { !$0.fileName.contains("/") })
    }

    // MARK: - Multi-track timelines

    @Test func overlappingTracksBecomeConnectedLanes() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [
                EditorPackageTimelineOverlay(fileName: "a_overlay.mov", fileURL: URL(fileURLWithPath: "/tmp/a_overlay.mov"), duration: 10),
                EditorPackageTimelineOverlay(fileName: "b_overlay.mov", fileURL: URL(fileURLWithPath: "/tmp/b_overlay.mov"), duration: 10)
            ],
            clips: [
                EditorPackageTimelineClip(mediaName: "cam-a.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-a.mov"), duration: 10, overlayFileName: "a_overlay.mov", overlaySourceStart: 0, startTime: 0, trackIndex: 0),
                EditorPackageTimelineClip(mediaName: "cam-b.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-b.mov"), duration: 10, overlayFileName: "b_overlay.mov", overlaySourceStart: 0, startTime: 0, trackIndex: 1)
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let spineClips = try elements(in: document, xpath: "//spine/asset-clip")
        #expect(spineClips.count == 1)
        #expect(spineClips[0].attribute(forName: "name")?.stringValue == "cam-a.mov")
        #expect(spineClips[0].attribute(forName: "offset")?.stringValue == "0s")

        // The second camera is a connected clip on lane 1, still at 0 s.
        let laneClips = try elements(in: document, xpath: "//spine/asset-clip/asset-clip[@lane='1']")
        #expect(laneClips.count == 1)
        #expect(laneClips[0].attribute(forName: "name")?.stringValue == "cam-b.mov")
        #expect(laneClips[0].attribute(forName: "offset")?.stringValue == "0s")
        #expect(laneClips[0].attribute(forName: "duration")?.stringValue == "10s")

        // Both overlays sit above every source lane. Lane numbers are relative
        // to the parent, so cam-a's overlay is on absolute lane 2 and cam-b's
        // overlay is on absolute lane 3 (lane 2 relative to cam-b's lane 1).
        let spineOverlay = try elements(in: document, xpath: "//spine/asset-clip/asset-clip[@name='a_overlay.mov']")
        #expect(spineOverlay.first?.attribute(forName: "lane")?.stringValue == "2")
        let attachedOverlay = try elements(in: document, xpath: "//spine/asset-clip/asset-clip/asset-clip[@name='b_overlay.mov']")
        #expect(attachedOverlay.first?.attribute(forName: "lane")?.stringValue == "2")

        #expect(try elements(in: document, xpath: "//gap").isEmpty)
        #expect(document.rootElement()?.elements(forName: "library").first?
            .elements(forName: "event").first?
            .elements(forName: "project").first?
            .elements(forName: "sequence").first?
            .attribute(forName: "duration")?.stringValue == "10s")
    }

    @Test func partiallyOverlappingTrackKeepsItsTimelineOffset() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [
                EditorPackageTimelineOverlay(fileName: "a_overlay.mov", fileURL: URL(fileURLWithPath: "/tmp/a_overlay.mov"), duration: 10),
                EditorPackageTimelineOverlay(fileName: "b_overlay.mov", fileURL: URL(fileURLWithPath: "/tmp/b_overlay.mov"), duration: 10)
            ],
            clips: [
                EditorPackageTimelineClip(mediaName: "cam-a.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-a.mov"), duration: 10, overlayFileName: "a_overlay.mov", overlaySourceStart: 0, startTime: 0, trackIndex: 0),
                EditorPackageTimelineClip(mediaName: "cam-b.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-b.mov"), duration: 10, overlayFileName: "b_overlay.mov", overlaySourceStart: 5, startTime: 5, trackIndex: 1)
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let laneClip = try #require(try elements(in: document, xpath: "//asset-clip[@lane='1']").first)
        #expect(laneClip.attribute(forName: "name")?.stringValue == "cam-b.mov")
        // Offset is relative to its parent clip, which starts at 0 s.
        #expect(laneClip.attribute(forName: "offset")?.stringValue == "5s")
        #expect(laneClip.attribute(forName: "duration")?.stringValue == "10s")

        let sequenceDuration = document.rootElement()?.elements(forName: "library").first?
            .elements(forName: "event").first?
            .elements(forName: "project").first?
            .elements(forName: "sequence").first?
            .attribute(forName: "duration")?.stringValue
        #expect(sequenceDuration == "15s")
    }

    @Test func threeTracksStackOnSeparateLanes() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [],
            clips: (0..<3).map { track in
                EditorPackageTimelineClip(
                    mediaName: "cam-\(track).mov",
                    mediaURL: URL(fileURLWithPath: "/tmp/cam-\(track).mov"),
                    duration: 5,
                    overlayFileName: "",
                    overlaySourceStart: 0,
                    startTime: 0,
                    trackIndex: track
                )
            }
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let laneClips = try elements(in: document, xpath: "//asset-clip[@lane]")
        #expect(laneClips.count == 2)
        #expect(laneClips.compactMap { $0.attribute(forName: "lane")?.stringValue }.sorted() == ["1", "2"])
    }

    @Test func gapAppearsOnlyWhereNoTrackHasMedia() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [],
            clips: [
                EditorPackageTimelineClip(mediaName: "a.mov", mediaURL: URL(fileURLWithPath: "/tmp/a.mov"), duration: 5, overlayFileName: "", overlaySourceStart: 0, startTime: 0, trackIndex: 0),
                EditorPackageTimelineClip(mediaName: "b.mov", mediaURL: URL(fileURLWithPath: "/tmp/b.mov"), duration: 5, overlayFileName: "", overlaySourceStart: 0, startTime: 10, trackIndex: 1)
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let gaps = try elements(in: document, xpath: "//gap")
        #expect(gaps.count == 1)
        #expect(gaps[0].attribute(forName: "offset")?.stringValue == "5s")
        #expect(gaps[0].attribute(forName: "duration")?.stringValue == "5s")
        // Both clips are in the spine; the gap proves the gap is not used to
        // carry connected clips.
        #expect(try elements(in: document, xpath: "//spine/asset-clip").count == 2)
    }

    @Test func sharedFullActivityOverlayIsAttachedOnceAcrossTracks() throws {
        let writer = FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps30,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: [
                EditorPackageTimelineOverlay(fileName: "full_activity_overlay.mov", fileURL: URL(fileURLWithPath: "/tmp/full.mov"), duration: 10)
            ],
            clips: [
                EditorPackageTimelineClip(mediaName: "cam-a.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-a.mov"), duration: 10, overlayFileName: "full_activity_overlay.mov", overlaySourceStart: 0, startTime: 0, trackIndex: 0),
                EditorPackageTimelineClip(mediaName: "cam-b.mov", mediaURL: URL(fileURLWithPath: "/tmp/cam-b.mov"), duration: 10, overlayFileName: "full_activity_overlay.mov", overlaySourceStart: 0, startTime: 0, trackIndex: 1)
            ]
        )

        let document = try XMLDocument(data: Data(writer.xmlString().utf8))
        let overlays = try elements(in: document, xpath: "//asset-clip[@name='full_activity_overlay.mov']")
        #expect(overlays.count == 1)
        #expect(overlays[0].attribute(forName: "duration")?.stringValue == "10s")
    }

    // MARK: - Helpers

    private func elements(in document: XMLDocument, xpath: String) throws -> [XMLElement] {
        try document.nodes(forXPath: xpath).compactMap { $0 as? XMLElement }
    }

    private func makeWriter(
        clips: [(name: String, url: String, duration: TimeInterval, overlay: String, sourceStart: TimeInterval, start: TimeInterval, track: Int)],
        overlays: [(fileName: String, duration: TimeInterval)]
    ) -> FCPXMLTimelineWriter {
        FCPXMLTimelineWriter(
            projectName: "Run",
            frameRate: .fps2997,
            canvasWidth: 1920,
            canvasHeight: 1080,
            overlays: overlays.map { overlay in
                EditorPackageTimelineOverlay(
                    fileName: overlay.fileName,
                    fileURL: URL(fileURLWithPath: "/tmp/package/\(overlay.fileName)"),
                    duration: overlay.duration
                )
            },
            clips: clips.map { clip in
                EditorPackageTimelineClip(
                    mediaName: clip.name,
                    mediaURL: URL(fileURLWithPath: clip.url),
                    duration: clip.duration,
                    overlayFileName: clip.overlay,
                    overlaySourceStart: clip.sourceStart,
                    startTime: clip.start,
                    trackIndex: clip.track
                )
            }
        )
    }
}
