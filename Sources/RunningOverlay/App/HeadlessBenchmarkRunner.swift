import AppKit
import Foundation

/// Runs export benchmarks synchronously through a minimal AppKit run loop so
/// `ImageRenderer` and other MainActor SwiftUI work executes reliably from
/// `swift run RunningOverlay --benchmark-export …` without launching the editor.
enum HeadlessBenchmarkRunner {
    static func run(_ command: HeadlessBenchmarkCommand) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.appearance = NSAppearance(named: .darkAqua)

        final class Delegate: NSObject, NSApplicationDelegate {
            let command: HeadlessBenchmarkCommand
            var exitCode: Int32 = 0

            init(command: HeadlessBenchmarkCommand) {
                self.command = command
            }

            func applicationDidFinishLaunching(_ notification: Notification) {
                Task { @MainActor in
                    defer { NSApp.stop(nil) }
                    do {
                        switch command {
                        case .export(let exportCommand):
                            _ = try await ExportBenchmarkRunner.run(exportCommand)
                        case .elevation(let elevationCommand):
                            _ = try await ElevationBenchmarkRunner.run(elevationCommand)
                        }
                    } catch {
                        fputs("[RunningOverlayBenchmark] failed: \(error.localizedDescription)\n", stderr)
                        exitCode = 1
                    }
                }
            }
        }

        let delegate = Delegate(command: command)
        app.delegate = delegate
        app.run()
        return delegate.exitCode
    }
}

enum HeadlessBenchmarkCommand: Equatable {
    case export(ExportBenchmarkCommand)
    case elevation(ElevationBenchmarkCommand)

    static func parse(arguments: [String] = CommandLine.arguments) throws -> HeadlessBenchmarkCommand? {
        if let elevation = try ElevationBenchmarkCommand.parse(arguments: arguments) {
            return .elevation(elevation)
        }
        if let export = try ExportBenchmarkCommand.parse(arguments: arguments) {
            return .export(export)
        }
        return nil
    }
}
