import Foundation

@main
enum RunningOverlayMain {
    @MainActor
    static func main() {
        // An AI client starts the app as a stdio MCP server for component
        // authoring; no window or project is created.
        if CommandLine.arguments.dropFirst().contains("--mcp") {
            exit(ComponentAuthoringMCPServer.runStdio())
        }
        do {
            if let command = try ComponentCLICommand.parse() {
                exit(ComponentCommandRunner.run(command))
            }
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
