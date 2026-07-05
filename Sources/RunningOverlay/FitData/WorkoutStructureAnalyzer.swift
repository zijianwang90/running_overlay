import Foundation

struct WorkoutStructureAnalyzer {
    static func analyze(
        laps: [LapRecord],
        source: WorkoutStructureSource = .auto,
        forcedKind: WorkoutStructureKind? = nil
    ) -> (laps: [LapRecord], analysis: WorkoutStructureAnalysis) {
        if forcedKind == .normal {
            return (laps.map { lap in
                var copy = lap
                copy.kind = .unknown
                return copy
            }, WorkoutStructureAnalysis(
                kind: .normal,
                subtype: .none,
                source: source,
                confidence: 1,
                reason: "User selected Normal."
            ))
        }

        guard laps.count >= 3 else {
            return (laps.map { lap in
                var copy = lap
                copy.kind = .unknown
                return copy
            }, WorkoutStructureAnalysis(
                kind: forcedKind ?? .normal,
                subtype: forcedKind == .structured ? .genericLaps : .none,
                source: source,
                confidence: forcedKind == .structured ? 0.45 : 0.9,
                reason: forcedKind == .structured ? "Not enough laps for detailed structure." : "No structured lap pattern detected."
            ))
        }

        if let interval = intervalResult(for: laps, source: source) {
            return interval
        }

        if let steady = steadyPlanResult(for: laps, source: source) {
            return steady
        }

        if forcedKind == .structured {
            return genericStructuredResult(for: laps, source: source)
        }

        return (laps.map { lap in
            var copy = lap
            copy.kind = .unknown
            return copy
        }, WorkoutStructureAnalysis(
            kind: .normal,
            subtype: .none,
            source: source,
            confidence: 0.8,
            reason: "No repeat or plan-like lap pattern detected."
        ))
    }

    private static func intervalResult(
        for laps: [LapRecord],
        source: WorkoutStructureSource
    ) -> (laps: [LapRecord], analysis: WorkoutStructureAnalysis)? {
        let internalLaps = laps.dropFirst().dropLast()
        let distanceCandidates = repeatedGroup(
            in: Array(internalLaps),
            value: \.totalDistanceMeters,
            minimumValue: 100,
            absoluteTolerance: 60,
            relativeTolerance: 0.18,
            basis: .distance
        )
        let durationCandidates = repeatedGroup(
            in: Array(internalLaps),
            value: \.totalElapsedTime,
            minimumValue: 20,
            absoluteTolerance: 8,
            relativeTolerance: 0.18,
            basis: .duration
        )

        let groups = [distanceCandidates, durationCandidates]
            .compactMap { $0 }
            .sorted { lhs, rhs in
                if lhs.lapIndexes.count == rhs.lapIndexes.count {
                    return lhs.score > rhs.score
                }
                return lhs.lapIndexes.count > rhs.lapIndexes.count
            }

        for group in groups where group.lapIndexes.count >= 2 {
            if let result = intervalResult(for: group, laps: laps, source: source) {
                return result
            }
        }

        return nil
    }

    private static func intervalResult(
        for group: RepeatedGroup,
        laps: [LapRecord],
        source: WorkoutStructureSource
    ) -> (laps: [LapRecord], analysis: WorkoutStructureAnalysis)? {
        let workIndexes = expandedWorkIndexes(for: group, in: laps)
        let sortedWorkIndexes = workIndexes.sorted()
        guard let firstWork = sortedWorkIndexes.first,
              let lastWork = sortedWorkIndexes.last,
              sortedWorkIndexes.contains(where: { index in
                  guard let previous = sortedWorkIndexes.last(where: { $0 < index }) else { return false }
                  return index - previous > 1
              }),
              !isUniformDistanceAutoLapDurationPattern(group: group, workIndexes: workIndexes, in: laps) else {
            return nil
        }

        var classified = laps
        for index in classified.indices {
            if workIndexes.contains(index) {
                classified[index].kind = .active
            } else if index < firstWork {
                classified[index].kind = .warmup
            } else if index > lastWork {
                classified[index].kind = .cooldown
            } else {
                classified[index].kind = .rest
            }
        }

        if let finalWork = sortedWorkIndexes.last,
           finalWork + 1 < classified.count - 1,
           isRecoveryLike(lap: classified[finalWork + 1], comparedToWorkLapsAt: sortedWorkIndexes, in: laps) {
            classified[finalWork + 1].kind = .rest
        }

        let restCount = classified.filter { $0.kind == .rest }.count
        guard restCount >= 1 else { return nil }

        return (classified, WorkoutStructureAnalysis(
            kind: .structured,
            subtype: .interval,
            source: source,
            confidence: min(0.95, 0.55 + Double(group.lapIndexes.count) * 0.05),
            reason: "Detected repeated work laps separated by recovery laps."
        ))
    }

    private static func steadyPlanResult(
        for laps: [LapRecord],
        source: WorkoutStructureSource
    ) -> (laps: [LapRecord], analysis: WorkoutStructureAnalysis)? {
        guard laps.count >= 3, laps.count <= 5 else { return nil }
        let totalDistance = laps.reduce(0) { $0 + max($1.totalDistanceMeters, 0) }
        let totalDuration = laps.reduce(0) { $0 + max($1.totalElapsedTime, 0) }
        guard totalDistance > 0 || totalDuration > 0 else { return nil }

        let middleRange = 1..<(laps.count - 1)
        guard let mainIndex = middleRange.max(by: { lhs, rhs in
            let lhsWeight = max(laps[lhs].totalDistanceMeters / max(totalDistance, 1), laps[lhs].totalElapsedTime / max(totalDuration, 1))
            let rhsWeight = max(laps[rhs].totalDistanceMeters / max(totalDistance, 1), laps[rhs].totalElapsedTime / max(totalDuration, 1))
            return lhsWeight < rhsWeight
        }) else { return nil }

        let mainShare = max(
            laps[mainIndex].totalDistanceMeters / max(totalDistance, 1),
            laps[mainIndex].totalElapsedTime / max(totalDuration, 1)
        )
        guard mainShare >= 0.55 else { return nil }

        var classified = laps
        for index in classified.indices {
            if index == mainIndex {
                classified[index].kind = .active
            } else if index < mainIndex {
                classified[index].kind = .warmup
            } else {
                classified[index].kind = .cooldown
            }
        }

        return (classified, WorkoutStructureAnalysis(
            kind: .structured,
            subtype: .steadyPlan,
            source: source,
            confidence: 0.72,
            reason: "Detected warmup, one main workout block, and cooldown."
        ))
    }

    private static func genericStructuredResult(
        for laps: [LapRecord],
        source: WorkoutStructureSource
    ) -> (laps: [LapRecord], analysis: WorkoutStructureAnalysis) {
        let classified = laps.enumerated().map { index, lap in
            var copy = lap
            if index == 0 {
                copy.kind = .warmup
            } else if index == laps.count - 1 {
                copy.kind = .cooldown
            } else {
                copy.kind = .unknown
            }
            return copy
        }
        return (classified, WorkoutStructureAnalysis(
            kind: .structured,
            subtype: .genericLaps,
            source: source,
            confidence: 0.5,
            reason: "Detected multiple laps but no interval or steady-plan pattern."
        ))
    }

    private struct RepeatedGroup {
        enum Basis {
            case distance
            case duration
        }

        var lapIndexes: [Int]
        var score: Double
        var basis: Basis
    }

    private static func isUniformDistanceAutoLapDurationPattern(
        group: RepeatedGroup,
        workIndexes: Set<Int>,
        in laps: [LapRecord]
    ) -> Bool {
        guard group.basis == .duration,
              workIndexes.count >= 2,
              let firstWork = workIndexes.min(),
              let lastWork = workIndexes.max() else {
            return false
        }

        let classifiedRange = firstWork...lastWork
        let distances = classifiedRange.map { laps[$0].totalDistanceMeters }
        guard let meanDistance = nonZeroMean(distances),
              meanDistance >= 800 else {
            return false
        }

        let tolerance = max(40, meanDistance * 0.08)
        return distances.allSatisfy { abs($0 - meanDistance) <= tolerance }
    }

    private static func nonZeroMean(_ values: [Double]) -> Double? {
        let positive = values.filter { $0 > 0 }
        guard !positive.isEmpty else { return nil }
        return positive.reduce(0, +) / Double(positive.count)
    }

    private static func expandedWorkIndexes(for group: RepeatedGroup, in laps: [LapRecord]) -> Set<Int> {
        var indexes = Set(group.lapIndexes)
        guard indexes.count >= 2,
              let first = indexes.min(),
              let last = indexes.max(),
              let referencePace = meanPace(forIndexes: indexes, in: laps) else {
            return indexes
        }

        for index in laps.indices {
            guard index > first,
                  index < laps.count - 1,
                  !indexes.contains(index),
                  index > last,
                  isWorkLike(lap: laps[index], referencePace: referencePace) else {
                continue
            }
            indexes.insert(index)
        }
        return indexes
    }

    private static func meanPace(forIndexes indexes: Set<Int>, in laps: [LapRecord]) -> Double? {
        let paces = indexes.compactMap { index -> Double? in
            guard laps.indices.contains(index) else { return nil }
            return effectivePace(for: laps[index])
        }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }

    private static func effectivePace(for lap: LapRecord) -> Double? {
        if let pace = lap.avgPaceSecondsPerKm, pace > 0 {
            return pace
        }
        guard lap.totalElapsedTime > 0, lap.totalDistanceMeters > 0 else { return nil }
        return lap.totalElapsedTime / (lap.totalDistanceMeters / 1000)
    }

    private static func isWorkLike(lap: LapRecord, referencePace: Double) -> Bool {
        guard lap.totalElapsedTime >= 20,
              lap.totalDistanceMeters >= 100,
              let pace = effectivePace(for: lap),
              referencePace > 0 else {
            return false
        }
        let tolerance = max(45, referencePace * 0.22)
        return abs(pace - referencePace) <= tolerance
    }

    private static func isRecoveryLike(lap: LapRecord, comparedToWorkLapsAt indexes: [Int], in laps: [LapRecord]) -> Bool {
        guard lap.totalElapsedTime >= 20,
              lap.totalDistanceMeters >= 50,
              let referencePace = meanPace(forIndexes: Set(indexes), in: laps),
              let pace = effectivePace(for: lap),
              referencePace > 0 else {
            return false
        }
        return pace >= referencePace * 1.35
    }

    private static func repeatedGroup(
        in laps: [LapRecord],
        value: KeyPath<LapRecord, Double>,
        minimumValue: Double,
        absoluteTolerance: Double,
        relativeTolerance: Double,
        basis: RepeatedGroup.Basis
    ) -> RepeatedGroup? {
        let candidates = laps
            .filter { $0[keyPath: value] >= minimumValue }
            .sorted { $0[keyPath: value] > $1[keyPath: value] }

        var best: RepeatedGroup?
        for seed in candidates {
            let seedValue = seed[keyPath: value]
            let tolerance = max(absoluteTolerance, seedValue * relativeTolerance)
            let group = candidates.filter { abs($0[keyPath: value] - seedValue) <= tolerance }
            guard group.count >= 2 else { continue }
            let mean = group.reduce(0) { $0 + $1[keyPath: value] } / Double(group.count)
            let variance = group.reduce(0) { $0 + pow($1[keyPath: value] - mean, 2) } / Double(group.count)
            let score = Double(group.count) - sqrt(variance) / max(mean, 1)
            let repeated = RepeatedGroup(lapIndexes: group.map(\.lapIndex), score: score, basis: basis)
            if best == nil || repeated.lapIndexes.count > best!.lapIndexes.count || repeated.score > best!.score {
                best = repeated
            }
        }
        return best
    }
}
