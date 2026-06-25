import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectSettingsTests {
    @Test func freshInstallUsesBundledHeartRateAndPaceZones() {
        let suiteName = "RunningOverlayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let snapshot = HeartRateZonePreferences.snapshot(defaults: defaults)

        #expect(snapshot.zoneCount == 6)
        #expect(snapshot.paceUnit == .minPerKm)
        #expect(snapshot.thresholdHR == 168)
        #expect(snapshot.thresholdPaceSecPerKm == 239)
        #expect(snapshot.zones.map(\.minHR) == [0, 134, 152, 161, 172, 178])
        #expect(snapshot.zones.map(\.maxHR) == [134, 151, 160, 171, 178, 250])
        #expect(snapshot.zones.map(\.minPaceSecPerKm) == [332, 272, 256, 234, 215, nil])
        #expect(snapshot.zones.map(\.maxPaceSecPerKm) == [nil, 332, 271, 255, 233, 215])
    }

    @Test func savedHeartRateZonesTakePrecedenceOverBundledDefaults() throws {
        let suiteName = "RunningOverlayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let savedZones = [
            HeartRateZone(minHR: 100, maxHR: 120, minPaceSecPerKm: 360, maxPaceSecPerKm: 420)
        ]
        defaults.set(try JSONEncoder().encode(savedZones), forKey: "heartRateZones.zones")
        defaults.set(5, forKey: "heartRateZones.zoneCount")
        defaults.set(PaceUnit.minPerMile.rawValue, forKey: "heartRateZones.paceUnit")

        let snapshot = HeartRateZonePreferences.snapshot(defaults: defaults)

        #expect(snapshot.zoneCount == 5)
        #expect(snapshot.paceUnit == .minPerMile)
        #expect(snapshot.zones[0] == savedZones[0])
        #expect(snapshot.thresholdHR == nil)
        #expect(snapshot.thresholdPaceSecPerKm == nil)
    }

    @Test func keychainServiceMatchesReleaseBundleIdentifier() {
        #expect(
            KeychainCredentialStore.serviceIdentifier
                == "io.github.zijianwang90.runningoverlay.credentials"
        )
    }

    @Test func decodesLegacySettingsWithoutOpenWeatherKey() throws {
        let json = #"{"resolution":"1920x1080","frameRate":"30","layerDataFrameRate":"5"}"#.data(using: .utf8)!

        let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)

        #expect(settings.resolution == .hd1080)
        #expect(settings.frameRate == .fps30)
        #expect(settings.layerDataFrameRate == .fps5)
        #expect(settings.legacyOpenWeatherAPIKey == nil)
    }

    @Test func legacyOpenWeatherAPIKeyDecodesButDoesNotEncode() throws {
        let legacyJSON = #"{"resolution":"1920x1080","frameRate":"30","layerDataFrameRate":"5","openWeatherAPIKey":"abc123"}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ProjectSettings.self, from: legacyJSON)

        let data = try JSONEncoder().encode(settings)
        let encoded = try #require(String(data: data, encoding: .utf8))

        #expect(settings.legacyOpenWeatherAPIKey == "abc123")
        #expect(!encoded.contains("openWeatherAPIKey"))
        #expect(!encoded.contains("abc123"))
    }

    @Test func projectLoadsAndUpdatesOpenWeatherKeyThroughCredentialStore() {
        let store = TestCredentialStore(values: [
            KeychainCredentialStore.openWeatherAccount: "stored-key"
        ])
        let project = ProjectDocument(credentialStore: store)

        #expect(project.openWeatherAPIKey == "stored-key")

        project.setOpenWeatherAPIKey(" new-key ")
        #expect(project.openWeatherAPIKey == "new-key")
        #expect(store.values[KeychainCredentialStore.openWeatherAccount] == "new-key")

        project.setOpenWeatherAPIKey(" ")
        #expect(project.openWeatherAPIKey.isEmpty)
        #expect(store.values[KeychainCredentialStore.openWeatherAccount] == nil)
    }

    @Test func restoringLegacySnapshotMigratesOpenWeatherKeyAndRemovesItOnResave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-key-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyURL = directory.appendingPathComponent("legacy.json")
        let resavedURL = directory.appendingPathComponent("resaved.json")
        let snapshot = ProjectPerformanceSnapshot(
            settings: ProjectSettings(),
            activity: .empty,
            mediaItems: [],
            mediaFolders: [],
            timeline: .empty,
            overlayElements: [],
            userAssets: [],
            fitSourceName: ""
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var settings = try #require(object["settings"] as? [String: Any])
        settings["openWeatherAPIKey"] = "legacy-secret"
        object["settings"] = settings
        try JSONSerialization.data(withJSONObject: object).write(to: legacyURL)

        let store = TestCredentialStore()
        let project = ProjectDocument(credentialStore: store)
        project.restoreProjectSnapshot(from: legacyURL)

        #expect(project.openWeatherAPIKey == "legacy-secret")
        #expect(store.values[KeychainCredentialStore.openWeatherAccount] == "legacy-secret")
        #expect(project.settings.legacyOpenWeatherAPIKey == nil)
        #expect(project.statusMessage.contains("Migrated"))

        project.saveProjectSnapshot(to: resavedURL)
        let resaved = try #require(String(data: Data(contentsOf: resavedURL), encoding: .utf8))
        #expect(!resaved.contains("openWeatherAPIKey"))
        #expect(!resaved.contains("legacy-secret"))
    }

    @Test func layerDataSampleTimeUsesConfiguredFrameRate() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps5
        project.setPlayhead(1.29)

        #expect(project.layerDataSampleTime == 1.2)
    }

    @Test func layerDataSampleTimeUsesFitAxisOffset() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps5
        project.moveFitStart(to: 5)
        project.setPlayhead(6.29)

        #expect(project.layerDataSampleTime == 1.2)
    }

    @Test func layerDataSampleTimeClampsToActivityDuration() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 2,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps30

        #expect(project.quantizedLayerDataTime(for: 3) == 2)
    }

    @Test func playbackTimeUpdatesPlayheadOnlyWhilePlaying() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 5,
            distanceMeters: 0,
            records: [],
            laps: []
        )

        project.setPlayheadFromPlayback(2)
        #expect(project.timeline.playhead == 0)

        project.togglePlayback()
        project.setPlayheadFromPlayback(2)
        #expect(project.timeline.playhead == 2)
    }

    @Test func playbackTimeClampsAndStopsAtActivityEnd() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 5,
            distanceMeters: 0,
            records: [],
            laps: []
        )

        project.togglePlayback()
        project.setPlayheadFromPlayback(8)

        #expect(project.timeline.playhead == 5)
        #expect(!project.isPlaying)
    }

    @Test func arrowFrameSteppingUsesProjectFrameRate() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.frameRate = .fps25
        project.setPlayhead(2)

        project.stepPlayheadByFrames(1)
        #expect(abs(project.timeline.playhead - 2.04) < 0.0001)

        project.stepPlayheadByFrames(-2)
        #expect(abs(project.timeline.playhead - 1.96) < 0.0001)
    }

    @Test func collapsedPlaybackSkipsTimelineGaps() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [
                TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 10, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A"),
                TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 40, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
            ])
        ])
        project.toggleTimelineCollapse()
        project.setPlayhead(14.99)

        project.togglePlayback()
        project.advancePlayback(by: 1.0 / 30.0)

        #expect(project.timeline.playhead == 40)
        #expect(project.isPlaying)
    }

    @Test func defaultExportDestinationUsesFirstVideoFolder() {
        let project = ProjectDocument()
        project.mediaItems = [
            MediaItem(
                displayName: "clip-b.mov",
                fileURL: URL(fileURLWithPath: "/tmp/running-overlay/source-a/clip-b.mov"),
                duration: 10,
                inferredStartDate: nil,
                cameraGroupID: "Camera A",
                alignmentStatus: .needsManualPlacement
            ),
            MediaItem(
                displayName: "clip-a.mov",
                fileURL: URL(fileURLWithPath: "/tmp/running-overlay/source-b/clip-a.mov"),
                duration: 10,
                inferredStartDate: nil,
                cameraGroupID: "Camera B",
                alignmentStatus: .needsManualPlacement
            )
        ]

        #expect(project.defaultExportDestinationURL.path == "/tmp/running-overlay/source-a")
    }

    @Test func defaultExportDestinationFallsBackToMoviesWithoutVideoFiles() {
        let project = ProjectDocument()

        #expect(project.defaultExportDestinationURL.path.hasSuffix("/Movies"))
    }

    @Test func timelineZoomSliderUsesFineLowEndMapping() {
        let project = ProjectDocument()
        project.fitPixelsPerSecond = ProjectDocument.minimumTimelinePixelsPerSecond

        #expect(project.timelineZoomSliderValue == 0)

        project.setTimelineZoomSliderValue(3)
        if case .pixelsPerSecond(let value) = project.timeline.zoom {
            #expect(value < 0.5)
        } else {
            Issue.record("Expected pixels-per-second zoom")
        }
    }

    @Test func fontLibraryRestoreDefaultsRestoresMonospacedFavoritesAndDefault() {
        let manager = FontLibraryManager.shared
        let originalFavorites = manager.favoriteFamilies
        let originalDefault = manager.defaultFamily
        defer {
            manager.favoriteFamilies = originalFavorites
            manager.defaultFamily = originalDefault
        }

        manager.favoriteFamilies = ["Avenir Next", "Helvetica Neue"]
        manager.defaultFamily = "Helvetica Neue"

        manager.restoreDefaults()

        #expect(manager.favoriteFamilies == ["PT Mono", "Monaco", "Menlo", "Andale Mono"])
        #expect(manager.defaultFamily == "PT Mono")
    }
}

private final class TestCredentialStore: CredentialStore {
    var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func value(for account: String) throws -> String? {
        values[account]
    }

    func setValue(_ value: String?, for account: String) throws {
        values[account] = value
    }
}
