import Foundation

/// Dynamic value used by the declarative overlay component runtime.
///
/// Components can only produce these values. There are no references to host
/// objects, clocks, files, or functions.
enum OverlayComponentValue: Equatable {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case color(OverlayColor)
    case list([OverlayComponentValue])
    case record([String: OverlayComponentValue])
    case null

    var number: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var boolean: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }

    var list: [OverlayComponentValue]? {
        guard case .list(let value) = self else { return nil }
        return value
    }

    var record: [String: OverlayComponentValue]? {
        guard case .record(let value) = self else { return nil }
        return value
    }

    var color: OverlayColor? {
        switch self {
        case .color(let value):
            return value
        case .string(let value):
            return OverlayComponentColorParser.parse(value)
        default:
            return nil
        }
    }

    /// JSON Schema truthiness used by `if` and the ternary operator.
    var isTruthy: Bool {
        switch self {
        case .null:
            return false
        case .boolean(let value):
            return value
        case .number(let value):
            return value != 0 && value.isFinite
        case .string(let value):
            return !value.isEmpty
        case .list(let value):
            return !value.isEmpty
        case .record(let value):
            return !value.isEmpty
        case .color:
            return true
        }
    }

    /// Value rendered by a `text` node or `format` without a pattern.
    var displayString: String {
        switch self {
        case .null:
            return OverlayComponentValue.placeholder
        case .number(let value):
            return OverlayComponentNumberFormatter.plain(value)
        case .string(let value):
            return value
        case .boolean(let value):
            return value ? "true" : "false"
        case .color(let value):
            return value.componentHexString
        case .list, .record:
            return OverlayComponentValue.placeholder
        }
    }

    static let placeholder = "—"
}

enum OverlayComponentNumberFormatter {
    static func plain(_ value: Double) -> String {
        guard value.isFinite else { return OverlayComponentValue.placeholder }
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        var text = String(format: "%.3f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func decimal(_ value: Double, places: Int) -> String {
        guard value.isFinite else { return OverlayComponentValue.placeholder }
        return String(format: "%.\(max(0, min(places, 6)))f", value)
    }

    /// `1:02:33` above one hour, `2:33` below.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return OverlayComponentValue.placeholder }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func pace(_ secondsPerKilometer: Double) -> String {
        guard secondsPerKilometer.isFinite, secondsPerKilometer > 0 else {
            return OverlayComponentValue.placeholder
        }
        let total = Int(secondsPerKilometer.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func clock(_ secondsSinceMidnight: Double) -> String {
        guard secondsSinceMidnight.isFinite else { return OverlayComponentValue.placeholder }
        let normalized = ((Int(secondsSinceMidnight.rounded()) % 86_400) + 86_400) % 86_400
        return String(format: "%02d:%02d", normalized / 3600, (normalized % 3600) / 60)
    }
}

enum OverlayComponentColorParser {
    /// Parses `#RRGGBB`, `#RRGGBBAA`, and `transparent`.
    static func parse(_ source: String) -> OverlayColor? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "transparent" {
            return OverlayColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        guard trimmed.hasPrefix("#") else { return nil }
        let hex = String(trimmed.dropFirst())
        guard hex.count == 6 || hex.count == 8,
              hex.allSatisfy({ $0.isHexDigit }),
              let value = UInt64(hex, radix: 16) else {
            return nil
        }
        if hex.count == 6 {
            return OverlayColor(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                alpha: 1
            )
        }
        return OverlayColor(
            red: Double((value >> 24) & 0xFF) / 255,
            green: Double((value >> 16) & 0xFF) / 255,
            blue: Double((value >> 8) & 0xFF) / 255,
            alpha: Double(value & 0xFF) / 255
        )
    }
}

extension OverlayColor {
    var componentHexString: String {
        func channel(_ value: Double) -> Int {
            Int((max(0, min(1, value)) * 255).rounded())
        }
        return String(
            format: "#%02X%02X%02X%02X",
            channel(red), channel(green), channel(blue), channel(alpha)
        )
    }
}

struct OverlayComponentSize: Equatable {
    var width: Double
    var height: Double

    static let zero = OverlayComponentSize(width: 0, height: 0)
}
