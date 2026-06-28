import Foundation

extension Bundle {
    static var runningOverlayResources: Bundle {
        RunningOverlayResourceBundle.bundle
    }
}

private enum RunningOverlayResourceBundle {
    static let bundle: Bundle = {
        let bundleName = "RunningOverlay_RunningOverlay.bundle"
        var candidateURLs: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(bundleName),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName)
        ]

        if var directory = Bundle.main.executableURL?.deletingLastPathComponent() {
            appendBundleCandidates(from: directory, bundleName: bundleName, to: &candidateURLs)
        }

        for argument in CommandLine.arguments {
            var url = URL(fileURLWithPath: argument)
            if !argument.hasSuffix("/") {
                url.deleteLastPathComponent()
            }
            appendBundleCandidates(from: url, bundleName: bundleName, to: &candidateURLs)
        }

        for url in candidateURLs.compactMap({ $0 }) {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return .main
    }()

    private static func appendBundleCandidates(from startDirectory: URL, bundleName: String, to urls: inout [URL?]) {
        var directory = startDirectory
        for _ in 0..<10 {
            urls.append(directory.appendingPathComponent(bundleName))
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { break }
            directory = parent
        }
    }
}
