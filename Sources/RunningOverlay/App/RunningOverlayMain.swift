import Foundation

@main
enum RunningOverlayMain {
    @MainActor
    static func main() {
        do {
            if let command = try HeadlessBenchmarkCommand.parse() {
                let exitCode = HeadlessBenchmarkRunner.run(command)
                exit(exitCode)
            }
            RunningOverlayLaunchConfiguration.command = try AppLaunchCommand.parse()
        } catch {
            fputs("[RunningOverlay] \(error.localizedDescription)\n", stderr)
            exit(2)
        }

        RunningOverlayApp.main()
    }
}
