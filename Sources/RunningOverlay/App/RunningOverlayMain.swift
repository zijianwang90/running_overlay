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
        } catch {
            fputs("[RunningOverlayBenchmark] \(error.localizedDescription)\n", stderr)
            exit(2)
        }

        RunningOverlayApp.main()
    }
}
