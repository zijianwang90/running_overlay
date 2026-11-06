import AppKit

@main
enum FxPlugDiagnosticWrapper {
    static func main() {
        // The app bundle provides PlugInKit discovery. It has no Studio editor
        // window and performs no installation into another application's data.
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
    }
}
