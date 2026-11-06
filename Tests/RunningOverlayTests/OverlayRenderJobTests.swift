import Foundation
import Testing
@testable import RunningOverlay

@MainActor
@Suite(.serialized, .skiaSerialized)
struct OverlayRenderJobTests {
    // MARK: - Wire format

    @Test func jobJSONRoundTrips() throws {
        let job = OverlayRenderJob(
            activity: .activityFile(path: "run.fit"),
            template: .builtIn(id: "easyRun"),
            output: sampleOutput(),
            spans: [OverlayRenderSpan(name: "first", activityElapsedStart: 1.5, duration: 2)]
        )
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(OverlayRenderJob.self, from: data)
        #expect(decoded == job)
        #expect(decoded.schemaVersion == OverlayRenderJob.currentSchemaVersion)
    }

    @Test func decodesHandWrittenJobJSON() throws {
        // Pins the synthesized Codable wire shape: enum cases are one-key
        // objects and their associated values are nested by label.
        let json = """
        {
          "schemaVersion": 1,
          "activity": { "activityFile": { "path": "run.fit" } },
          "template": { "builtIn": { "id": "easyRun" } },
          "output": {
            "directory": "out",
            "width": 1920,
            "height": 1080,
            "frameRateID": "29.97",
            "layerDataFrameRateID": "5",
            "codec": "hevcWithAlpha",
            "bitrateMbps": 20
          },
          "spans": [
            { "name": "first", "activityElapsedStart": 0, "duration": 10 }
          ]
        }
        """
        let job = try JSONDecoder().decode(OverlayRenderJob.self, from: Data(json.utf8))

        #expect(job.schemaVersion == 1)
        #expect(job.activity == .activityFile(path: "run.fit"))
        #expect(job.template == .builtIn(id: "easyRun"))
        #expect(job.output.directory == "out")
        #expect(job.output.width == 1920)
        #expect(job.output.height == 1080)
        #expect(job.output.frameRateID == "29.97")
        #expect(job.output.layerDataFrameRateID == "5")
        #expect(job.output.codec == .hevcWithAlpha)
        #expect(job.output.bitrateMbps == 20)
        #expect(job.spans == [OverlayRenderSpan(name: "first", activityElapsedStart: 0, duration: 10)])
    }

    @Test(arguments: [0, 2, 99])
    func rejectsUnsupportedSchemaVersions(_ version: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("job.json")
        try Data(minimalJobJSON(schemaVersion: version).utf8).write(to: url)

        #expect(throws: RenderJobError.unsupportedSchemaVersion(version)) {
            try OverlayRenderJobResolver.load(jobURL: url)
        }
    }

    @Test func loadsValidJobFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("job.json")
        try Data(minimalJobJSON(schemaVersion: 1).utf8).write(to: url)

        let job = try OverlayRenderJobResolver.load(jobURL: url)
        #expect(job.schemaVersion == 1)
        #expect(job.spans.count == 1)
    }

    // MARK: - Command line

    @Test func commandLineParsingUsesDefaults() throws {
        let command = try #require(try RenderJobCommand.parse(arguments: [
            "RunningOverlay", "--render-job", "jobs/run.json"
        ]))

        #expect(command.jobURL.path.hasSuffix("/jobs/run.json"))
        #expect(command.cacheDirectory == nil)
        #expect(command.usesCache)
    }

    @Test func commandLineParsesCacheArguments() throws {
        let withDirectory = try #require(try RenderJobCommand.parse(arguments: [
            "RunningOverlay", "--render-job", "job.json", "--render-cache", "cache"
        ]))
        #expect(withDirectory.cacheDirectory?.path.hasSuffix("/cache") == true)
        #expect(withDirectory.usesCache)

        let withoutCache = try #require(try RenderJobCommand.parse(arguments: [
            "RunningOverlay", "--render-job", "job.json", "--no-render-cache"
        ]))
        #expect(withoutCache.cacheDirectory == nil)
        #expect(!withoutCache.usesCache)
    }

    @Test func commandLineReturnsNilWithoutRenderJob() throws {
        #expect(try RenderJobCommand.parse(arguments: ["RunningOverlay"]) == nil)
        #expect(try RenderJobCommand.parse(arguments: ["RunningOverlay", "--fit", "run.fit"]) == nil)
        #expect(try HeadlessBenchmarkCommand.parse(arguments: ["RunningOverlay"]) == nil)
    }

    @Test func commandLineRejectsMissingValue() {
        #expect(throws: RenderJobError.missingValue("--render-job")) {
            try RenderJobCommand.parse(arguments: ["RunningOverlay", "--render-job"])
        }
        #expect(throws: RenderJobError.missingValue("--render-cache")) {
            try RenderJobCommand.parse(arguments: ["RunningOverlay", "--render-job", "job.json", "--render-cache"])
        }
    }

    @Test func headlessCommandParsesRenderJobFirst() throws {
        let command = try #require(try HeadlessBenchmarkCommand.parse(arguments: [
            "RunningOverlay",
            "--benchmark-template-segments", "run.fit",
            "--template", "template.rotemplate",
            "--render-job", "job.json"
        ]))
        guard case .renderJob(let renderJob) = command else {
            Issue.record("Expected a render job command, got \(command)")
            return
        }
        #expect(renderJob.jobURL.path.hasSuffix("/job.json"))
    }

    // MARK: - Resolver

    @Test func resolvesRelativeAbsoluteAndTildePaths() {
        let directory = URL(fileURLWithPath: "/tmp/running-overlay-job", isDirectory: true)

        #expect(OverlayRenderJobResolver.resolvedURL("run.fit", relativeTo: directory).path
            == "/tmp/running-overlay-job/run.fit")
        #expect(OverlayRenderJobResolver.resolvedURL("inputs/run.fit", relativeTo: directory).path
            == "/tmp/running-overlay-job/inputs/run.fit")
        #expect(OverlayRenderJobResolver.resolvedURL("/var/tmp/run.fit", relativeTo: directory).path
            == "/var/tmp/run.fit")

        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(OverlayRenderJobResolver.resolvedURL("~/run.fit", relativeTo: directory).path
            == home.appendingPathComponent("run.fit").path)
    }

    @Test func resolvesBuiltInEasyRunTemplate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try OverlayRenderJobResolver.writeActivitySnapshot(
            sampleActivity(),
            to: directory.appendingPathComponent("activity.json")
        )
        let job = OverlayRenderJob(
            activity: .activitySnapshot(path: "activity.json"),
            template: .builtIn(id: "easyRun"),
            output: sampleOutput(),
            spans: [OverlayRenderSpan(name: "first", activityElapsedStart: 0, duration: 0.3)]
        )

        let resolved = try OverlayRenderJobResolver.resolve(job, jobDirectory: directory)
        #expect(!resolved.input.template.elements.isEmpty)
        #expect(resolved.outputDirectory.path == directory.appendingPathComponent("out").path)
        #expect(resolved.input.activityHash.count == 64)
        #expect(resolved.input.templateHash.count == 64)
    }

    @Test func resolvesUnknownBuiltInTemplateThrows() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try OverlayRenderJobResolver.writeActivitySnapshot(
            sampleActivity(),
            to: directory.appendingPathComponent("activity.json")
        )
        let job = OverlayRenderJob(
            activity: .activitySnapshot(path: "activity.json"),
            template: .builtIn(id: "notARealTemplate"),
            output: sampleOutput(),
            spans: [OverlayRenderSpan(name: "first", activityElapsedStart: 0, duration: 0.3)]
        )

        #expect(throws: RenderJobError.unknownBuiltInTemplate("notARealTemplate")) {
            try OverlayRenderJobResolver.resolve(job, jobDirectory: directory)
        }
    }

    @Test func activitySnapshotRoundTripsThroughTheResolver() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("activity.json")
        let activity = sampleActivity()
        try OverlayRenderJobResolver.writeActivitySnapshot(activity, to: url)

        let restored = try OverlayRenderJobResolver.loadActivitySnapshot(from: url)
        #expect(restored.startDate == activity.startDate)
        #expect(restored.duration == activity.duration)
        #expect(restored.distanceMeters == activity.distanceMeters)
        #expect(restored.records.count == activity.records.count)
        #expect(restored.records.map(\.elapsedTime) == activity.records.map(\.elapsedTime))
        #expect(restored.records.map(\.heartRate) == activity.records.map(\.heartRate))
        #expect(restored.laps == activity.laps)
        #expect(restored.workoutStructure == activity.workoutStructure)
        // `ProjectFileFormat` uses `.iso8601`, which drops sub-second
        // timestamps, so compare durations and whole-second fields rather
        // than full record equality.
        #expect(restored.records.first?.id == activity.records.first?.id)
        #expect(restored.records.first?.timestamp == activity.records.first?.timestamp)
    }

    // MARK: - Cache keys

    @Test func spanCacheKeyIsDeterministicAndSensitiveToItsInputs() throws {
        let activityHash = try OverlayRenderContentHash.activity(sampleActivity())
        let template = simpleTextTemplate()
        let templateHash = try OverlayRenderContentHash.template(template)
        let output = sampleOutput()
        let span = OverlayRenderSpan(name: "first", activityElapsedStart: 1, duration: 2)

        func key(
            activityHash: String = activityHash,
            templateHash: String = templateHash,
            output: OverlayRenderJobOutput = output,
            span: OverlayRenderSpan = span
        ) throws -> String {
            try OverlayRenderContentHash.spanCacheKey(
                activityHash: activityHash,
                templateHash: templateHash,
                output: output,
                span: span
            )
        }

        let baseline = try key()
        #expect(try key() == baseline)
        #expect(try key(activityHash: String(repeating: "0", count: 64)) != baseline)

        var movedSpan = span
        movedSpan.activityElapsedStart = 2
        #expect(try key(span: movedSpan) != baseline)
        var longerSpan = span
        longerSpan.duration = 3
        #expect(try key(span: longerSpan) != baseline)

        var proRes = output
        proRes.codec = .proRes4444
        #expect(try key(output: proRes) != baseline)

        var changedElement = template
        changedElement.elements[0].positionX += 0.1
        #expect(try OverlayRenderContentHash.template(changedElement) != templateHash)
    }

    @Test func spanCacheKeyIgnoresTemplateNameAndTimestamps() throws {
        let original = simpleTextTemplate()
        let originalHash = try OverlayRenderContentHash.template(original)

        var renamed = original
        renamed.name = "Renamed Template"
        renamed.updatedAt = original.updatedAt.addingTimeInterval(3600)
        let renamedHash = try OverlayRenderContentHash.template(renamed)
        #expect(renamedHash == originalHash)

        let output = sampleOutput()
        let span = OverlayRenderSpan(name: "first", activityElapsedStart: 0, duration: 1)
        let activityHash = try OverlayRenderContentHash.activity(sampleActivity())
        #expect(try OverlayRenderContentHash.spanCacheKey(
            activityHash: activityHash, templateHash: originalHash, output: output, span: span
        ) == OverlayRenderContentHash.spanCacheKey(
            activityHash: activityHash, templateHash: renamedHash, output: output, span: span
        ))
    }

    // MARK: - Template manifest

    @Test func templateManifestSortsAndDeduplicatesElementTypes() throws {
        let template = OverlayTemplate(name: "Mixed", elements: [
            makeElement(.pace),
            makeElement(.heartRate),
            makeElement(.pace),
            makeElement(.distance),
            makeElement(.heartRate)
        ])

        let manifest = try OverlayTemplateManifest(template: template)
        #expect(manifest.elementTypes == ["distance", "heartRate", "pace"])
        #expect(manifest.templateID == template.id)
        #expect(manifest.name == "Mixed")
        #expect(manifest.rendererVersion == OverlayRendererVersion.current)
        #expect(manifest.contentHash.count == 64)
    }

    // MARK: - Render service validation

    @Test func renderServiceRejectsEmptySpans() async throws {
        let input = try OverlayRenderInput(activity: sampleActivity(), template: simpleTextTemplate())
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(throws: OverlayRenderServiceError.noSpans) {
            _ = try await OverlayRenderService.render(
                input: input,
                output: sampleOutput(),
                outputDirectory: directory.appendingPathComponent("out"),
                spans: [],
                cache: nil
            )
        }
    }

    @Test(arguments: [("", 1.0), ("a.b", 1.0), ("a/b", 1.0), ("ok", 0.0)])
    func renderServiceRejectsInvalidSpans(name: String, duration: TimeInterval) async throws {
        let input = try OverlayRenderInput(activity: sampleActivity(), template: simpleTextTemplate())
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(throws: OverlayRenderServiceError.invalidSpan(name)) {
            _ = try await OverlayRenderService.render(
                input: input,
                output: sampleOutput(),
                outputDirectory: directory.appendingPathComponent("out"),
                spans: [OverlayRenderSpan(name: name, activityElapsedStart: 0, duration: duration)],
                cache: nil
            )
        }
    }

    // MARK: - End to end

    @Test func rendersTinySpanAndReusesTheCachedMovie() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let jobDirectory = root.appendingPathComponent("job", isDirectory: true)
        let cacheDirectory = root.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: jobDirectory, withIntermediateDirectories: true)

        try OverlayRenderJobResolver.writeActivitySnapshot(
            sampleActivity(),
            to: jobDirectory.appendingPathComponent("activity.json")
        )
        let template = simpleTextTemplate()
        let templateEncoder = JSONEncoder()
        templateEncoder.outputFormatting = [.sortedKeys]
        try templateEncoder.encode(template).write(
            to: jobDirectory.appendingPathComponent("template.rotemplate")
        )

        let jobURL = jobDirectory.appendingPathComponent("job.json")
        try Data(renderableJobJSON.utf8).write(to: jobURL)

        let command = try #require(try RenderJobCommand.parse(arguments: [
            "RunningOverlay",
            "--render-job", jobURL.path,
            "--render-cache", cacheDirectory.path
        ]))

        let outputDirectory = try await RenderJobRunner.run(command)
        let movieURL = outputDirectory.appendingPathComponent("first.mov")
        #expect(FileManager.default.fileExists(atPath: movieURL.path))

        let firstResult = try decodeResult(in: outputDirectory)
        #expect(firstResult.schemaVersion == RenderJobResult.currentSchemaVersion)
        #expect(firstResult.rendererVersion == OverlayRendererVersion.current)
        #expect(firstResult.activityHash.count == 64)
        #expect(firstResult.spans.count == 1)
        #expect(firstResult.spans[0].name == "first")
        #expect(firstResult.spans[0].fileName == "first.mov")
        #expect(firstResult.spans[0].reusedCache == false)
        #expect(firstResult.spans[0].cacheKey.count == 64)

        _ = try await RenderJobRunner.run(command)
        #expect(FileManager.default.fileExists(atPath: movieURL.path))
        let secondResult = try decodeResult(in: outputDirectory)
        #expect(secondResult.spans.count == 1)
        #expect(secondResult.spans[0].reusedCache)
        #expect(secondResult.spans[0].cacheKey == firstResult.spans[0].cacheKey)
    }

    // MARK: - Helpers

    private var renderableJobJSON: String {
        """
        {
          "schemaVersion": 1,
          "activity": { "activitySnapshot": { "path": "activity.json" } },
          "template": { "templateFile": { "path": "template.rotemplate" } },
          "output": {
            "directory": "out",
            "width": 320,
            "height": 180,
            "frameRateID": "30",
            "layerDataFrameRateID": "5",
            "codec": "proRes4444",
            "bitrateMbps": 4
          },
          "spans": [
            { "name": "first", "activityElapsedStart": 0, "duration": 0.3 }
          ]
        }
        """
    }

    private func minimalJobJSON(schemaVersion: Int) -> String {
        """
        {
          "schemaVersion": \(schemaVersion),
          "activity": { "activityFile": { "path": "run.fit" } },
          "template": { "builtIn": { "id": "easyRun" } },
          "output": {
            "directory": "out",
            "width": 1920,
            "height": 1080,
            "frameRateID": "30",
            "layerDataFrameRateID": "5",
            "codec": "hevcWithAlpha",
            "bitrateMbps": 20
          },
          "spans": [
            { "name": "first", "activityElapsedStart": 0, "duration": 1 }
          ]
        }
        """
    }

    private func decodeResult(in directory: URL) throws -> RenderJobResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: directory.appendingPathComponent(RenderJobResult.fileName))
        return try decoder.decode(RenderJobResult.self, from: data)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-render-job-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleOutput() -> OverlayRenderJobOutput {
        OverlayRenderJobOutput(
            directory: "out",
            width: 1920,
            height: 1080,
            frameRateID: "30",
            layerDataFrameRateID: "5",
            codec: .hevcWithAlpha,
            bitrateMbps: 20
        )
    }

    /// Synthetic activity: two seconds of one-second records, no private data.
    private func sampleActivity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 2.0, by: 0.5).map { elapsed in
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
            duration: 2,
            distanceMeters: 4,
            records: records,
            laps: []
        )
    }

    /// A minimal visible text element, avoiding map/weather inputs.
    private func simpleTextTemplate() -> OverlayTemplate {
        var style = OverlayStyle.default
        style.decor.textContent = "FINISH"
        style.decor.textFont = .system(family: "Menlo")
        style.decor.textSize = 40
        style.decor.textAlignment = .center
        style.decor.textLineHeight = 1.2
        style.decor.textLetterSpacing = 0
        style.decor.textFillMode = .solid(color: .white)
        style.decor.textStrokeWidth = 0
        style.decor.textStrokeColor = .white
        style.decor.textAutoFit = false
        style.decor.width = 240
        style.decor.height = 80

        let element = OverlayElement(
            type: .decorText,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
        return OverlayTemplate(name: "Tiny Text", elements: [OverlayTemplateElement(element: element)])
    }

    private func makeElement(_ type: OverlayElementType) -> OverlayTemplateElement {
        OverlayTemplateElement(
            type: type,
            positionX: 0.5,
            positionY: 0.5,
            scale: 1,
            style: .default
        )
    }
}
