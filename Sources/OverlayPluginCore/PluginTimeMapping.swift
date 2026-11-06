import Foundation

/// Rational media time. A host adapter must convert its input time to the
/// original media's source time before constructing this value.
public struct PluginMediaTime: Codable, Equatable, Sendable {
    public let value: Int64
    public let timescale: Int32

    public init(value: Int64, timescale: Int32) throws {
        guard timescale > 0 else { throw PluginCoreError.invalidTime }
        self.value = value
        self.timescale = timescale
    }

    public var seconds: Double { Double(value) / Double(timescale) }

    private enum CodingKeys: String, CodingKey { case value, timescale }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            value: fields.decode(Int64.self, forKey: .value),
            timescale: fields.decode(Int32.self, forKey: .timescale)
        )
    }
}

/// Content-following alignment for a normal-speed effect. Timeline placement
/// is intentionally absent: moving a clip must not change its sampled data.
/// Positive correction advances the activity relative to the video.
public struct PluginTimeMapping: Codable, Equatable, Sendable {
    public let mediaSourceAnchor: PluginMediaTime
    public let activityElapsedAnchor: Double
    public let correctionSeconds: Double

    public init(
        mediaSourceAnchor: PluginMediaTime,
        activityElapsedAnchor: Double,
        correctionSeconds: Double = 0
    ) throws {
        guard activityElapsedAnchor.isFinite, correctionSeconds.isFinite else {
            throw PluginCoreError.invalidTime
        }
        self.mediaSourceAnchor = mediaSourceAnchor
        self.activityElapsedAnchor = activityElapsedAnchor
        self.correctionSeconds = correctionSeconds
    }

    /// Stateless sampling supports seeking and concurrent/out-of-order calls.
    /// Outside the closed activity range returns nil, never a clamped metric.
    public func activityElapsedTime(
        forMediaSourceTime sourceTime: PluginMediaTime,
        activityDuration: Double
    ) throws -> Double? {
        guard activityDuration.isFinite, activityDuration > 0 else {
            throw PluginCoreError.invalidTime
        }
        // Subtract integer ticks first when possible, preserving subframes at
        // long media timecodes without overflowing at Int64 boundaries.
        let delta: Double
        let ticks = sourceTime.value.subtractingReportingOverflow(mediaSourceAnchor.value)
        if sourceTime.timescale == mediaSourceAnchor.timescale, !ticks.overflow {
            delta = Double(ticks.partialValue) / Double(sourceTime.timescale)
        } else {
            delta = sourceTime.seconds - mediaSourceAnchor.seconds
        }
        let elapsed = activityElapsedAnchor + delta + correctionSeconds
        guard elapsed.isFinite else { throw PluginCoreError.invalidTime }
        return (0...activityDuration).contains(elapsed) ? elapsed : nil
    }

    private enum CodingKeys: String, CodingKey {
        case mediaSourceAnchor, activityElapsedAnchor, correctionSeconds
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mediaSourceAnchor: fields.decode(PluginMediaTime.self, forKey: .mediaSourceAnchor),
            activityElapsedAnchor: fields.decode(Double.self, forKey: .activityElapsedAnchor),
            correctionSeconds: fields.decode(Double.self, forKey: .correctionSeconds)
        )
    }
}

public enum PluginCoreError: LocalizedError, Equatable, Sendable {
    case invalidTime
    case unsupportedPackageVersion(Int)
    case invalidPackage(String)
    case contentMismatch
    case packageTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidTime: "Plugin time values must be finite, with a positive timescale and activity duration."
        case .unsupportedPackageVersion(let version): "Plugin data package version \(version) is not supported."
        case .invalidPackage(let reason): "Invalid plugin data package: \(reason)."
        case .contentMismatch: "Plugin data package content does not match its SHA-256 digest."
        case .packageTooLarge: "Plugin data packages must be no larger than 64 MiB."
        }
    }
}
