import Foundation

struct AppLaunchCommand: Equatable {
    var activityURL: URL?
    var videoURLs: [URL]

    var fitURL: URL? {
        activityURL
    }

    static func parse(arguments: [String] = CommandLine.arguments) throws -> AppLaunchCommand? {
        var activityPath: String?
        var videoPaths: [String] = []
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--activity", "--fit":
                activityPath = try value(after: argument, arguments: arguments, index: &index)
            case "--video":
                videoPaths.append(try value(after: argument, arguments: arguments, index: &index))
            default:
                break
            }
            index += 1
        }

        guard activityPath != nil || !videoPaths.isEmpty else {
            return nil
        }

        return AppLaunchCommand(
            activityURL: activityPath.map(resolvedURL(for:)),
            videoURLs: videoPaths.map(resolvedURL(for:))
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
