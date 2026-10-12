import Foundation

do {
    guard CommandLine.arguments.count == 2 else {
        throw NSError(domain: "PackagedResources", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Usage: swift scripts/validate-packaged-resources.swift <app-path>"
        ])
    }
    let appURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let bundleURL = appURL.appendingPathComponent("Contents/Resources/RunningOverlay_RunningOverlay.bundle")
    guard let bundle = Bundle(url: bundleURL) else {
        throw NSError(domain: "PackagedResources", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Missing or invalid packaged resource bundle: \(bundleURL.path)"
        ])
    }
    let templates = ["EasyRun", "IntervalWorkout", "Race"]
    let icons = [
        "weather-rain", "weather-partly-cloudy", "weather-cloudy", "weather-snow",
        "weather-wind", "weather-heavy-rain", "weather-clear-night", "weather-thunder",
        "weather-sunny", "weather-fog"
    ]
    let resources = templates.map { ($0, "rotemplate") }
        + [("symbols", "json")]
        + icons.map { ($0, "png") }
    for (name, fileExtension) in resources {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw NSError(domain: "PackagedResources", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Cannot load packaged resource: \(name).\(fileExtension)"
            ])
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw NSError(domain: "PackagedResources", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Empty packaged resource: \(url.lastPathComponent)"
            ])
        }
        if fileExtension == "rotemplate" || fileExtension == "json" {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }
    print("Packaged resources passed: \(templates.count) built-in templates, symbol catalog, \(icons.count) weather icons.")
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
