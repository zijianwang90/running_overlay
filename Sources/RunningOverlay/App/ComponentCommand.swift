import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(CSkiaBridge)
import CSkiaBridge
#endif

/// Headless authoring commands for declarative components.
///
/// ```
/// RunningOverlay --component-validate path/to/component
/// RunningOverlay --component-render path/to/component --component-output out.png
/// ```
///
/// Validation works in every build. Rendering needs the Skia build and prints
/// an explicit error otherwise.
struct ComponentValidateCommand: Equatable {
    var packageURL: URL
}

struct ComponentRenderCommand: Equatable {
    var packageURL: URL
    var outputURL: URL
    var scale: Double = 2
    var activityURL: URL?
    var elapsedTime: TimeInterval = 0
    var parametersURL: URL?
    var weatherURL: URL?
}

/// Author-facing weather input for `--component-weather`. Mirrors the host
/// snapshot a weather component renders; the author supplies data instead of
/// the CLI reaching the network.
struct ComponentWeatherInput: Decodable, Equatable {
    var condition: String
    var temperatureC: Double
    var humidity: Double?
    var highC: Double?
    var lowC: Double?
    var windKph: Double?
    var feelsLikeC: Double?
    var location: String?
}

enum ComponentCLICommand: Equatable {
    case validate(ComponentValidateCommand)
    case render(ComponentRenderCommand)

    static func parse(arguments: [String] = CommandLine.arguments) throws -> ComponentCLICommand? {
        var packagePath: String?
        var outputPath: String?
        var scale = 2.0
        var activityPath: String?
        var parametersPath: String?
        var weatherPath: String?
        var elapsedTime = 0.0
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--component-validate", "--component-render":
                index += 1
                guard index < arguments.count else {
                    throw ComponentCLIError.missingValue(argument)
                }
                packagePath = arguments[index]
            case "--component-output":
                index += 1
                guard index < arguments.count else {
                    throw ComponentCLIError.missingValue(argument)
                }
                outputPath = arguments[index]
            case "--component-activity", "--component-at", "--component-params", "--component-weather":
                index += 1
                guard index < arguments.count else {
                    throw ComponentCLIError.missingValue(argument)
                }
                switch argument {
                case "--component-activity": activityPath = arguments[index]
                case "--component-params": parametersPath = arguments[index]
                case "--component-weather": weatherPath = arguments[index]
                default:
                    guard let value = Double(arguments[index]), value.isFinite, value >= 0 else {
                        throw ComponentCLIError.invalidTime(arguments[index])
                    }
                    elapsedTime = value
                }
            case "--component-scale":
                index += 1
                guard index < arguments.count else {
                    throw ComponentCLIError.missingValue(argument)
                }
                guard let value = Double(arguments[index]), value.isFinite, value > 0 else {
                    throw ComponentCLIError.invalidScale(arguments[index])
                }
                scale = value
            default:
                break
            }
            index += 1
        }

        guard let packagePath else { return nil }
        let packageURL = resolvedURL(for: packagePath)
        if let outputPath {
            return .render(
                ComponentRenderCommand(
                    packageURL: packageURL,
                    outputURL: resolvedURL(for: outputPath),
                    scale: scale,
                    activityURL: activityPath.map(resolvedURL),
                    elapsedTime: elapsedTime,
                    parametersURL: parametersPath.map(resolvedURL),
                    weatherURL: weatherPath.map(resolvedURL)
                )
            )
        }
        // A render request without an output path is an authoring mistake, not
        // a validation request.
        if arguments.contains("--component-render") {
            throw ComponentCLIError.missingOutput
        }
        return .validate(ComponentValidateCommand(packageURL: packageURL))
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

enum ComponentCLIError: LocalizedError {
    case missingValue(String)
    case missingOutput
    case invalidScale(String)
    case invalidTime(String)
    case invalidParameters(String)
    case invalidWeather(String)
    case unresolvedDefinition
    case renderFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)."
        case .missingOutput:
            "Missing --component-output for --component-render."
        case .invalidScale(let value):
            "Invalid --component-scale '\(value)'; expected a positive number."
        case .invalidTime(let value):
            "Invalid --component-at '\(value)'; expected nonnegative activity elapsed seconds."
        case .invalidParameters(let message):
            "Invalid --component-params: \(message)."
        case .invalidWeather(let message):
            "Invalid --component-weather: \(message)."
        case .unresolvedDefinition:
            "Component definition could not be resolved."
        case .renderFailed:
            "Skia could not create a render surface."
        case .writeFailed(let path):
            "Could not write PNG to \(path)."
        }
    }
}

enum ComponentCommandRunner {
    @MainActor
    static func run(_ command: ComponentCLICommand) -> Int32 {
        switch command {
        case .validate(let validateCommand):
            do {
                try validate(validateCommand)
                return 0
            } catch {
                report(error)
                return 1
            }

        case .render(let renderCommand):
            #if canImport(CSkiaBridge)
            do {
                let output = try renderComponent(renderCommand)
                print("Rendered \(output.path)")
                return 0
            } catch {
                report(error)
                return 1
            }
            #else
            fputs(
                "[RunningOverlay] --component-render requires a Skia build (set SKIA_DIR).\n",
                stderr
            )
            return 1
            #endif
        }
    }

    private static func validate(_ command: ComponentValidateCommand) throws {
        let reference = try OverlayComponentLoader.loadReference(at: command.packageURL)
        let definition = OverlayComponentRegistry.definition(for: reference)
        print("Valid: \(reference.id) \(reference.version)")
        if let name = definition?.name.resolve(language: OverlayComponentInstance.hostLanguage) {
            print("Name: \(name)")
        }
        print("Digest: \(reference.digest)")
        let assets = reference.assets ?? [:]
        let bytes = assets.values.reduce(0) { $0 + $1.count }
        print("Assets: \(assets.count) (\(bytes) bytes)")
    }

    private static func report(_ error: Error) {
        if let validation = error as? OverlayComponentValidationError {
            for diagnostic in validation.diagnostics {
                let prefix = diagnostic.severity == .error ? "error" : "warning"
                fputs("\(diagnostic.path): \(prefix): \(diagnostic.message)\n", stderr)
            }
            return
        }
        fputs("[RunningOverlay] \(error.localizedDescription)\n", stderr)
    }

    /// Load author inputs independently of Skia so validation and renderer tests
    /// exercise exactly the data and parameters used by the command.
    static func inputs(
        for command: ComponentRenderCommand,
        definition: OverlayComponentDefinition
    ) throws -> (activity: ActivityTimeline, parameters: [String: OverlayJSONValue], weather: WeatherPayload?) {
        let activity: ActivityTimeline
        if let url = command.activityURL {
            activity = try ActivityFileParser.parse(url: url)
        } else {
            activity = ActivityTimeline(
                startDate: Date(timeIntervalSince1970: 0),
                duration: 0, distanceMeters: 0, records: [], laps: []
            )
        }
        let weather = try weatherPayload(at: command.weatherURL)
        guard let url = command.parametersURL else { return (activity, [:], weather) }
        let values: [String: OverlayJSONValue]
        do {
            values = try JSONDecoder().decode([String: OverlayJSONValue].self, from: Data(contentsOf: url))
        } catch {
            throw ComponentCLIError.invalidParameters(error.localizedDescription)
        }
        return (activity, try validatedParameters(values, definition: definition), weather)
    }

    /// Persistence tolerates stale parameters, but authoring should fail on
    /// typos instead of silently rendering the default.
    static func validatedParameters(
        _ values: [String: OverlayJSONValue],
        definition: OverlayComponentDefinition
    ) throws -> [String: OverlayJSONValue] {
        for id in values.keys.sorted() {
            guard let parameter = definition.parameter(named: id), let value = values[id] else {
                throw ComponentCLIError.invalidParameters("unknown parameter '\(id)'.")
            }
            let typed = definition.parameterValues(from: [id: value])[id]
            guard let typed else {
                throw ComponentCLIError.invalidParameters("'\(id)' has the wrong type or an invalid color.")
            }
            let valid: Bool
            switch parameter.kind {
            case .number(let minimum, let maximum, _, _, _):
                valid = typed.number.map { $0 >= minimum && $0 <= maximum } ?? false
            case .enumeration(let options):
                valid = options.contains { $0.value == typed.string }
            case .metric(let signals, _):
                valid = typed.string.map(signals.contains) ?? false
            case .string(let maxLength):
                valid = typed.string.map { $0.count <= maxLength } ?? false
            default:
                valid = true
            }
            guard valid else {
                throw ComponentCLIError.invalidParameters("'\(id)' is outside its declared range or options.")
            }
        }
        return values
    }

    /// Reads the optional author-supplied weather snapshot. Authoring never
    /// reaches the network; an API data source renders exactly these values.
    private static func weatherPayload(at url: URL?) throws -> WeatherPayload? {
        guard let url else { return nil }
        let input: ComponentWeatherInput
        do {
            input = try JSONDecoder().decode(
                ComponentWeatherInput.self,
                from: Data(contentsOf: url)
            )
        } catch {
            throw ComponentCLIError.invalidWeather(error.localizedDescription)
        }
        guard let condition = WeatherCondition(rawValue: input.condition) else {
            throw ComponentCLIError.invalidWeather("unknown condition '\(input.condition)'.")
        }
        return WeatherPayload(
            condition: condition,
            temperatureCelsius: input.temperatureC,
            humidity: input.humidity,
            highTemperatureCelsius: input.highC,
            lowTemperatureCelsius: input.lowC,
            windKph: input.windKph,
            feelsLikeCelsius: input.feelsLikeC,
            resolvedLocation: input.location,
            sourceDate: nil
        )
    }

    #if canImport(CSkiaBridge)
    /// Renders the component with author inputs onto a transparent canvas
    /// and crops the PNG to the component's design bounds.
    static func renderComponent(_ command: ComponentRenderCommand) throws -> URL {
        let reference = try OverlayComponentLoader.loadReference(at: command.packageURL)
        guard let definition = OverlayComponentRegistry.definition(for: reference) else {
            throw ComponentCLIError.unresolvedDefinition
        }
        let inputs = try inputs(for: command, definition: definition)
        let rendered = try renderPNG(
            reference: reference,
            parameters: inputs.parameters,
            activity: inputs.activity,
            elapsedTime: command.elapsedTime,
            weather: inputs.weather,
            scale: command.scale
        )
        for diagnostic in rendered.diagnostics {
            fputs("[RunningOverlay] warning: \(diagnostic)\n", stderr)
        }
        let outputURL = command.outputURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try rendered.png.write(to: outputURL, options: .atomic)
        } catch {
            throw ComponentCLIError.writeFailed(outputURL.path)
        }
        return outputURL
    }

    /// Renders a validated reference to PNG bytes cropped to its design
    /// bounds. Shared by the CLI and the authoring MCP server so both show
    /// exactly what the app draws.
    static func renderPNG(
        reference: OverlayComponentReference,
        parameters: [String: OverlayJSONValue],
        activity: ActivityTimeline,
        elapsedTime requestedTime: TimeInterval,
        weather: WeatherPayload?,
        scale requestedScale: Double
    ) throws -> (png: Data, size: CGSize, diagnostics: [String]) {
        guard let definition = OverlayComponentRegistry.definition(for: reference) else {
            throw ComponentCLIError.unresolvedDefinition
        }
        var element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: .default
        )
        element.component = OverlayComponentInstance(reference: reference, parameters: parameters)
        let elapsedTime = min(max(requestedTime, 0), activity.duration)
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: elapsedTime, canvasSize: OverlayRenderContext.referenceCanvasSize,
            elementScale: 1, weatherPayload: weather
        )
        let resolved = element.component.flatMap { OverlayComponentRegistry.resolve(instance: $0, data: data) }
        let diagnostics = (resolved?.diagnostics ?? []).map { "\($0)" }
        // A content-sized definition has no declared size; measure it once on
        // the reference canvas (one pixel per design unit).
        let design: OverlayComponentSize
        if definition.contentLayout != nil {
            let measured = OverlayComponentSkiaRenderer.frame(
                for: element,
                renderContext: OverlayRenderContext(
                    canvasSize: OverlayRenderContext.referenceCanvasSize,
                    activity: activity,
                    elapsedTime: elapsedTime,
                    weatherPayload: weather
                )
            )?.size ?? CGSize(width: 1, height: 1)
            design = OverlayComponentSize(
                width: max(Double(measured.width), 1),
                height: max(Double(measured.height), 1)
            )
        } else {
            design = definition.size
        }
        // Keep the reference-canvas scale uniform so the component renders at
        // exactly `scale` pixels per design unit, then crop to its bounds.
        let scale = min(
            requestedScale,
            OverlayRenderContext.referenceCanvasSize.width / design.width,
            OverlayRenderContext.referenceCanvasSize.height / design.height
        )
        let canvasWidth = max(Int((OverlayRenderContext.referenceCanvasSize.width * scale).rounded()), 1)
        let canvasHeight = max(Int((OverlayRenderContext.referenceCanvasSize.height * scale).rounded()), 1)
        let outputWidth = max(Int((design.width * scale).rounded()), 1)
        let outputHeight = max(Int((design.height * scale).rounded()), 1)

        guard let context = skb_create(Int32(canvasWidth), Int32(canvasHeight)) else {
            throw ComponentCLIError.renderFailed
        }
        defer { skb_destroy(context) }
        skb_clear(context)

        let renderContext = OverlayRenderContext(
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
            activity: activity,
            elapsedTime: elapsedTime,
            weatherPayload: weather
        )
        OverlayComponentSkiaRenderer.draw(
            element,
            renderContext: renderContext,
            context: context
        )
        skb_flush(context, 1)

        var rowBytes = 0
        guard let pixels = skb_pixels(context, &rowBytes) else {
            throw ComponentCLIError.renderFailed
        }
        let bitmap = Data(bytes: pixels, count: rowBytes * canvasHeight)
        guard let provider = CGDataProvider(data: bitmap as CFData),
              let image = CGImage(
                  width: canvasWidth,
                  height: canvasHeight,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: rowBytes,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                          | CGBitmapInfo.byteOrder32Little.rawValue
                  ),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ),
              let cropped = image.cropping(
                  to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
              ) else {
            throw ComponentCLIError.renderFailed
        }

        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            png as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ComponentCLIError.renderFailed
        }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ComponentCLIError.renderFailed
        }
        return (png as Data, CGSize(width: outputWidth, height: outputHeight), diagnostics)
    }
    #endif
}
