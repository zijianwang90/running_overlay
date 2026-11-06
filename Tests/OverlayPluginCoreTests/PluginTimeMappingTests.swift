import Foundation
import OverlayPluginCore
import Testing

struct PluginTimeMappingTests {
    @Test func trimSplitAndSeekFollowOriginalMediaTime() throws {
        let mapping = try PluginTimeMapping(
            mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30),
            activityElapsedAnchor: 120, correctionSeconds: 1.5
        )
        // Native source time survives moving a clip or making a cut. A host
        // adapter supplies these same times for either half after a split.
        for frame in [300, 930, 300, 0, 930, 600] {
            let time = try PluginMediaTime(value: Int64(frame), timescale: 30)
            #expect(try mapping.activityElapsedTime(forMediaSourceTime: time, activityDuration: 600)
                == 121.5 + Double(frame) / 30)
        }
    }

    @Test func fractionalFramesAndNonzeroTimecodesKeepSubframes() throws {
        let anchor = try PluginMediaTime(value: 25_920_000_000, timescale: 30_000)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: anchor, activityElapsedAnchor: 0)
        let source = try PluginMediaTime(value: anchor.value + 1001, timescale: anchor.timescale)
        #expect(try mapping.activityElapsedTime(forMediaSourceTime: source, activityDuration: 10) == 1001.0 / 30_000)
    }

    @Test func mixedTimescalesMapAndCorrectionCanBeNegative() throws {
        let mapping = try PluginTimeMapping(
            mediaSourceAnchor: PluginMediaTime(value: 150, timescale: 30),
            activityElapsedAnchor: 10, correctionSeconds: -2
        )
        let source = try PluginMediaTime(value: 4200, timescale: 600)
        #expect(try mapping.activityElapsedTime(forMediaSourceTime: source, activityDuration: 60) == 10)
    }

    @Test func outsideActivityIsTransparentInsteadOfHoldingBoundaryData() throws {
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 0)
        for frame in [-1, 301] {
            #expect(try mapping.activityElapsedTime(forMediaSourceTime: PluginMediaTime(value: Int64(frame), timescale: 30), activityDuration: 10) == nil)
        }
        for frame in [0, 300] {
            #expect(try mapping.activityElapsedTime(forMediaSourceTime: PluginMediaTime(value: Int64(frame), timescale: 30), activityDuration: 10) != nil)
        }
    }

    @Test func rejectsInvalidTimesIncludingDecodedTimes() throws {
        #expect(throws: PluginCoreError.invalidTime) { try PluginMediaTime(value: 0, timescale: 0) }
        #expect(throws: PluginCoreError.invalidTime) { try PluginMediaTime(value: 0, timescale: -1) }
        #expect(throws: PluginCoreError.invalidTime) {
            try JSONDecoder().decode(PluginMediaTime.self, from: Data(#"{"value":1,"timescale":0}"#.utf8))
        }
        let source = try PluginMediaTime(value: 0, timescale: 1)
        #expect(throws: PluginCoreError.invalidTime) { try PluginTimeMapping(mediaSourceAnchor: source, activityElapsedAnchor: .nan) }
        #expect(throws: PluginCoreError.invalidTime) { try PluginTimeMapping(mediaSourceAnchor: source, activityElapsedAnchor: 0, correctionSeconds: .infinity) }
        let mapping = try PluginTimeMapping(mediaSourceAnchor: source, activityElapsedAnchor: 0)
        #expect(throws: PluginCoreError.invalidTime) { try mapping.activityElapsedTime(forMediaSourceTime: source, activityDuration: 0) }
        #expect(throws: PluginCoreError.invalidTime) { try mapping.activityElapsedTime(forMediaSourceTime: source, activityDuration: .infinity) }
    }

    @Test func extremeTickValuesDoNotOverflow() throws {
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: .min, timescale: 1), activityElapsedAnchor: 0)
        #expect(try mapping.activityElapsedTime(forMediaSourceTime: PluginMediaTime(value: .max, timescale: 1), activityDuration: 60) == nil)
    }

    @Test func persistedAnchorsRestoreExactly() throws {
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 17017, timescale: 30000), activityElapsedAnchor: 3.75, correctionSeconds: -0.125)
        let data = try JSONEncoder().encode(mapping)
        #expect(try JSONDecoder().decode(PluginTimeMapping.self, from: data) == mapping)
    }

    @Test func concurrentRequestsDoNotSharePlaybackState() async throws {
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 10)
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for frame in (0..<90).reversed() {
                group.addTask {
                    let result = try mapping.activityElapsedTime(forMediaSourceTime: PluginMediaTime(value: Int64(frame), timescale: 30), activityDuration: 60)
                    return result == 10 + Double(frame) / 30
                }
            }
            for try await result in group { #expect(result) }
        }
    }
}
