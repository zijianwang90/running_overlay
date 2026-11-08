import Foundation

/// A pure one-dimensional allocator. Layout inputs and results share the same
/// units; callers decide whether those units are design points or pixels.
enum OverlayComponentStripLayout {
    enum Mode: Equatable { case equal, weighted, emphasized }

    static func widths(
        weights: [Double],
        mode: Mode,
        currentIndex: Int?,
        emphasisFraction: Double,
        availableWidth: Double,
        gap: Double,
        minimumWidth: Double
    ) -> [Double] {
        guard !weights.isEmpty else { return [] }
        let usableWidth = max(availableWidth - gap * Double(max(weights.count - 1, 0)), 1)
        let base = usableWidth / Double(weights.count)
        if mode == .weighted {
            let totalWeight = max(weights.reduce(0, +), 1)
            var result = weights.map { max(minimumWidth, usableWidth * ($0 / totalWeight)) }
            let sum = result.reduce(0, +)
            if sum > usableWidth {
                let factor = usableWidth / sum
                result = result.map { $0 * factor }
            }
            return result
        }
        guard let currentIndex, weights.indices.contains(currentIndex), weights.count > 1,
              mode == .emphasized || emphasisFraction > 0 else {
            return Array(repeating: base, count: weights.count)
        }
        var currentWidth = max(mode == .emphasized ? minimumWidth : base, usableWidth * emphasisFraction)
        var otherWidth = max(minimumWidth, (usableWidth - currentWidth) / Double(weights.count - 1))
        let total = currentWidth + otherWidth * Double(weights.count - 1)
        if total > usableWidth {
            let scale = usableWidth / total
            currentWidth *= scale
            otherWidth *= scale
        }
        return weights.indices.map { $0 == currentIndex ? currentWidth : otherWidth }
    }
}
