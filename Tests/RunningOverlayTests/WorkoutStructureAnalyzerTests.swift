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

    @Test func mixedDistanceWorkAfterRepeatedSetStaysActive() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 1_162, distance: 2_054),
            lap(1, start: 1_163, end: 1_550, distance: 1_609),
            lap(2, start: 1_550, end: 1_747, distance: 66),
            lap(3, start: 1_747, end: 2_125, distance: 1_601),
            lap(4, start: 2_125, end: 2_339, distance: 169),
            lap(5, start: 2_340, end: 2_737, distance: 1_572),
            lap(6, start: 2_736, end: 2_921, distance: 51),
            lap(7, start: 2_921, end: 3_294, distance: 1_587),
            lap(8, start: 3_294, end: 3_418, distance: 100),
            lap(9, start: 3_418, end: 3_931, distance: 2_016),
            lap(10, start: 3_931, end: 4_459, distance: 1_000),
            lap(11, start: 4_459, end: 4_816, distance: 1_000)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .interval)
        #expect(activity.laps.map(\.kind) == [
            .warmup,
            .active,
            .rest,
            .active,
            .rest,
            .active,
            .rest,
            .active,
            .rest,
            .active,
            .rest,
            .cooldown
        ])
    }

    @Test func shortRepsWithSimilarDistanceRecoveriesUseDurationPattern() {
        var laps = [
            lap(0, start: 0, end: 1_500, distance: 3_200)
        ]
        var t: TimeInterval = 1_500
        for rep in 0..<20 {
            laps.append(lap(laps.count, start: t, end: t + 36, distance: 200))
            t += 36
            if rep < 19 {
                laps.append(lap(laps.count, start: t, end: t + 95, distance: 235))
                t += 95
            }
        }
        laps.append(lap(laps.count, start: t, end: t + 800, distance: 2_200))

        let activity = activityWithLaps(laps).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .interval)
        #expect(activity.laps.filter { $0.kind == .active }.count == 20)
        #expect(activity.laps.filter { $0.kind == .rest }.count == 19)
        #expect(activity.laps.first?.kind == .warmup)
        #expect(activity.laps.last?.kind == .cooldown)
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

    @Test func pausedAutoKilometerLapsStayNormal() {
        let activity = activityWithLaps([
            lap(0, start: 0, end: 357, distance: 1_000),
            lap(1, start: 357, end: 720, distance: 1_000),
            lap(2, start: 720, end: 1_145, distance: 1_000),
            lap(3, start: 1_145, end: 1_504, distance: 1_000),
            lap(4, start: 1_504, end: 1_868, distance: 1_000),
            lap(5, start: 1_868, end: 3_267, distance: 1_000),
            lap(6, start: 3_267, end: 3_983, distance: 1_000),
            lap(7, start: 3_983, end: 4_454, distance: 1_000),
            lap(8, start: 4_454, end: 5_331, distance: 1_000),
            lap(9, start: 5_331, end: 5_672, distance: 1_000),
            lap(10, start: 5_672, end: 5_678, distance: 14)
        ]).applyingWorkoutStructureSelection(.auto)

        #expect(activity.workoutStructure.kind == .normal)
        #expect(activity.workoutStructure.subtype == .none)
        #expect(!activity.isIntervalWorkout)
        #expect(activity.laps.allSatisfy { $0.kind == .unknown })
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
        guard let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_INTERVAL_FIT_SAMPLE"] else {
            return
        }
        let url = URL(fileURLWithPath: path)

        let activity = try FitFileParser.parse(url: url)

        #expect(activity.workoutStructure.kind == .structured)
        #expect(activity.workoutStructure.subtype == .interval)
        #expect(activity.isIntervalWorkout)
        #expect(activity.laps.filter { $0.kind == .active }.count >= 5)
        #expect(activity.laps.filter { $0.kind == .rest }.count >= 1)
    }

    @Test func parsesProvidedNormalPausedFitSampleWhenAvailable() throws {
        guard let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_NORMAL_FIT_SAMPLE"] else {
            return
        }
        let url = URL(fileURLWithPath: path)

        let activity = try FitFileParser.parse(url: url)

        #expect(activity.workoutStructure.kind == .normal)
        #expect(activity.workoutStructure.subtype == .none)
        #expect(!activity.isIntervalWorkout)
        #expect(activity.laps.allSatisfy { $0.kind == .unknown })
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
