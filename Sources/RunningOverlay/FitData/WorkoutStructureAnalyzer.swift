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
            relativeTolerance: 0.18
        )
        let durationCandidates = repeatedGroup(
            in: Array(internalLaps),
            value: \.totalElapsedTime,
            minimumValue: 20,
            absoluteTolerance: 8,
            relativeTolerance: 0.18
        )

        let bestGroup = [distanceCandidates, durationCandidates]
            .compactMap { $0 }
            .max { lhs, rhs in
                if lhs.lapIndexes.count == rhs.lapIndexes.count {
                    return lhs.score < rhs.score
                }
                return lhs.lapIndexes.count < rhs.lapIndexes.count
            }

        guard let group = bestGroup, group.lapIndexes.count >= 2 else {
            return nil
        }

        let workIndexes = Set(group.lapIndexes)
        let sortedWorkIndexes = group.lapIndexes.sorted()
        guard let firstWork = sortedWorkIndexes.first,
              let lastWork = sortedWorkIndexes.last,
              sortedWorkIndexes.contains(where: { index in
                  guard let previous = sortedWorkIndexes.last(where: { $0 < index }) else { return false }
                  return index - previous > 1
              }) else {
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
        var lapIndexes: [Int]
        var score: Double
    }

    private static func repeatedGroup(
        in laps: [LapRecord],
        value: KeyPath<LapRecord, Double>,
        minimumValue: Double,
        absoluteTolerance: Double,
        relativeTolerance: Double
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
            let repeated = RepeatedGroup(lapIndexes: group.map(\.lapIndex), score: score)
            if best == nil || repeated.lapIndexes.count > best!.lapIndexes.count || repeated.score > best!.score {
                best = repeated
            }
        }
        return best
    }
}
