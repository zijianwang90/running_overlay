import Foundation
import Testing
@testable import RunningOverlay

struct WorkoutStructureAnalyzerTests {
    @Test func slowRepeatedFourHundredsAreStructuredIntervals() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 150, distance: 430),
            lap(1, start: 150, end: 282, distance: 400),
            lap(2, start: 282, end: 327, distance: 140),
            lap(3, start: 327, end: 457, distance: 400),
            lap(4, start: 457, end: 502, distance: 140),
            lap(5, start: 502, end: 632, distance: 400),
            lap(6, start: 632, end: 677, distance: 140),
            lap(7, start: 677, end: 807, distance: 400),
            lap(8, start: 807, end: 900, distance: 120)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .interval)
        #expect(activity.isIntervalWorkout)
        #expect(activity.laps.filter { $0.kind == .active }.count == 4)
        #expect(activity.laps.filter { $0.kind == .rest }.count == 3)
    }

    @Test func warmupMainCooldownIsStructuredSteadyPlanNotInterval() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 600, distance: 1_500),
            lap(1, start: 600, end: 3_300, distance: 10_000),
            lap(2, start: 3_300, end: 3_900, distance: 1_400)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .steadyPlan)
        #expect(!activity.isIntervalWorkout)
        #expect(activity.laps.map(\.kind) == [.warmup, .active, .cooldown])
    }

    @Test func singleLapActivityStaysNormal() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 1_800, distance: 5_000)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .normal)
        #expect(activity.workoutStructure.subtype == .none)
        #expect(!activity.isIntervalWorkout)
        #expect(activity.laps.allSatisfy { $0.kind == .unknown })
    }

    @Test func simpleManualLapsStayNormalWithoutRepeatPattern() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 300, distance: 900),
            lap(1, start: 300, end: 660, distance: 1_100),
            lap(2, start: 660, end: 1_080, distance: 1_250),
            lap(3, start: 1_080, end: 1_560, distance: 1_450)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .normal)
        #expect(activity.workoutStructure.subtype == .none)
        #expect(!activity.isIntervalWorkout)
    }

    @Test func userNormalOverrideRemovesIntervalSemantics() {
        let autoActivity = activityWithLaps([
            lap(0, start: 0, end: 120, distance: 300),
            lap(1, start: 120, end: 240, distance: 400),
            lap(2, start: 240, end: 300, distance: 100),
            lap(3, start: 300, end: 420, distance: 400),
            lap(4, start: 420, end: 480, distance: 100),
            lap(5, start: 480, end: 600, distance: 400),
            lap(6, start: 600, end: 720, distance: 300)
        ]).applyingWorkoutStructureSelection(.auto)

        let normalActivity = autoActivity.applyingWorkoutStructureSelection(.normal)

        #expect(autoActivity.isIntervalWorkout)
        #expect(normalActivity.workoutStructure.kind == .normal)
        #expect(normalActivity.workoutStructure.source == .userOverride)
        #expect(!normalActivity.isIntervalWorkout)
        #expect(normalActivity.laps.allSatisfy { $0.kind == .unknown })
    }

    @Test func userStructuredOverrideUsesAutoSubtypeClassification() {
        let normalActivity = activityWithLaps([
            lap(0, start: 0, end: 120, distance: 300),
            lap(1, start: 120, end: 240, distance: 400),
            lap(2, start: 240, end: 300, distance: 100),
            lap(3, start: 300, end: 420, distance: 400),
            lap(4, start: 420, end: 540, distance: 300)
        ]).applyingWorkoutStructureSelection(.normal)

        let structuredActivity = normalActivity.applyingWorkoutStructureSelection(.structured)

        #expect(structuredActivity.workoutStructure.kind == .structured)
        #expect(structuredActivity.workoutStructure.subtype == .interval)
        #expect(structuredActivity.workoutStructure.source == .userOverride)
        #expect(structuredActivity.isIntervalWorkout)
    }

    @Test func parsesProvidedSlowIntervalFitSampleWhenAvailable() throws {
        let url = URL(fileURLWithPath: "/Users/codywang/Desktop/running_overlay/Test 400x8/478318880247284213.fit")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let activity = try FitFileParser.parse(url: url)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .interval)
        #expect(activity.isIntervalWorkout)
        #expect(activity.laps.filter { $0.kind == .active }.count >= 6)
        #expect(activity.laps.filter { $0.kind == .rest }.count >= 1)
    }

    private func activityWithLaps(_ laps: [LapRecord]) -> ActivityTimeline {
        ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: laps.last?.endElapsedTime ?? 0,
            distanceMeters: laps.reduce(0) { $0 + $1.totalDistanceMeters },
            records: [],
            laps: laps
        )
    }

    private func lap(_ index: Int, start: TimeInterval, end: TimeInterval, distance: Double) -> LapRecord {
        LapRecord(
            lapIndex: index,
            startElapsedTime: start,
            endElapsedTime: end,
            startDistanceMeters: 0,
            totalDistanceMeters: distance,
            totalElapsedTime: end - start,
            avgPaceSecondsPerKm: (end - start) / (distance / 1000),
            avgHeartRate: nil,
            maxHeartRate: nil,
            avgCadenceSPM: nil,
            avgPowerWatts: nil,
            totalAscent: nil,
            kind: .unknown
        )
    }
}
