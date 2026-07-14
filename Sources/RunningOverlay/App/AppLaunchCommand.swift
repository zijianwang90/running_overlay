import Foundation

struct AppLaunchCommand: Equatable {
    var fitURL: URL?
    var videoURL: URL?

    static func parse(arguments: [String] = CommandLine.arguments) throws -> AppLaunchCommand? {
        var fitPath: String?
        var videoPath: String?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--fit":
                fitPath = try value(after: argument, arguments: arguments, index: &index)
            case "--video":
                videoPath = try value(after: argument, arguments: arguments, index: &index)
            default:
                break
            }
            index += 1
        }

        guard fitPath != nil || videoPath != nil else {
            return nil
        }

        return AppLaunchCommand(
            fitURL: fitPath.map(resolvedURL(for:)),
            videoURL: videoPath.map(resolvedURL(for:))
        )
    }

    private static func value(
        after argument: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        index += 1
        guard index < arguments.count, !arguments[index].hasPrefix("--") else {
            throw AppLaunchCommandError.missingValue(argument)
        }
        return arguments[index]
    }

    private static func resolvedURL(for path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(expanded)
    }
}

enum AppLaunchCommandError: LocalizedError, Equatable {
    case missingValue(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)."
        }
    }
}

@MainActor
enum RunningOverlayLaunchConfiguration {
    static var command: AppLaunchCommand?
}
