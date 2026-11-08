import Foundation

/// Display-only series preparation shared by native charts and components.
/// The samples retain activity-record order; no resampling onto a different
/// time axis is introduced by moving this calculation into the host service.
enum OverlayComponentPlotData {
    static func elevationSamples(from activity: ActivityTimeline) -> [Double] {
        let records = activity.records.compactMap(\.elevationMeters)
        if !records.isEmpty { return records }
        return (0..<40).map { index in
            activity.elevation(at: activity.duration * Double(index) / 39) ?? 0
        }
    }

    static func smoothed(_ samples: [Double], amount: Double = 0.85) -> [Double] {
        let clampedAmount = min(max(amount, 0), 1)
        guard samples.count > 2, clampedAmount > 0 else { return samples }
        let maxRadius = min(28, max(2, (samples.count - 1) / 2))
        let radius = min(maxRadius, max(2, Int((2 + clampedAmount * 18).rounded())))
        let sigma = max(1, Double(radius) * 0.45)
        let weights = (-radius...radius).map { offset in
            exp(-pow(Double(offset), 2) / (2 * pow(sigma, 2)))
        }
        let passCount = max(1, Int((1 + clampedAmount * 5).rounded()))
        var filtered = samples
        for _ in 0..<passCount {
            let source = filtered
            for index in source.indices.dropFirst().dropLast() {
                var weightedSum = 0.0
                var weightSum = 0.0
                for offset in -radius...radius {
                    let neighbor = min(max(index + offset, source.startIndex), source.index(before: source.endIndex))
                    let weight = weights[offset + radius]
                    weightedSum += source[neighbor] * weight
                    weightSum += weight
                }
                filtered[index] = weightedSum / weightSum
            }
        }
        return zip(samples, filtered).map { original, smoothed in
            original + (smoothed - original) * clampedAmount
        }
    }
}
