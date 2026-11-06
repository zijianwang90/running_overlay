import CoreGraphics
import Foundation

struct OverlayComponentDiagnostic: Equatable, Sendable {
    enum Severity: String, Sendable {
        case error
        case warning
    }

    var path: String
    var message: String
    var severity: Severity

    init(path: String, message: String, severity: Severity = .error) {
        self.path = path
        self.message = message
        self.severity = severity
    }
}

struct OverlayComponentValidationError: Error, CustomStringConvertible {
    var diagnostics: [OverlayComponentDiagnostic]

    var errors: [OverlayComponentDiagnostic] {
        diagnostics.filter { $0.severity == .error }
    }

    var description: String {
        diagnostics
            .map { "\($0.path): \($0.message)" }
            .joined(separator: "\n")
    }
}

struct OverlayComponentLocalizedText: Equatable {
    var values: [String: String]

    func resolve(language: String = "en") -> String {
        if let exact = values[language] { return exact }
        let base = language.split(separator: "-").first.map(String.init) ?? language
        if let languageMatch = values.first(where: { $0.key.split(separator: "-").first.map(String.init) == base }) {
            return languageMatch.value
        }
        if let fallback = values["en"] { return fallback }
        return values.sorted { $0.key < $1.key }.first?.value ?? ""
    }
}

struct OverlayComponentDefinition: Equatable {
    var spec: String
    var id: String
    var version: String
    var name: OverlayComponentLocalizedText
    var descriptionText: OverlayComponentLocalizedText?
    var author: String?
    var license: String
    var homepage: String?
    var size: OverlayComponentSize
    var background: OverlayComponentBackground?
    var params: [OverlayComponentParam]
    var bindings: [String: OverlayComponentBinding]
    var nodes: [OverlayComponentNode]

    func parameter(named id: String) -> OverlayComponentParam? {
        params.first { $0.id == id }
    }

    func defaultParameters() -> [String: OverlayComponentValue] {
        Dictionary(uniqueKeysWithValues: params.map { ($0.id, $0.defaultValue) })
    }
}

struct OverlayComponentBackground: Equatable {
    var color: OverlayComponentColorSource
    var radius: OverlayComponentNumberSource?
}

struct OverlayComponentParam: Equatable {
    var id: String
    var label: OverlayComponentLocalizedText
    var section: OverlayComponentLocalizedText?
    var descriptionText: OverlayComponentLocalizedText?
    var isAdvanced: Bool
    var whenExpression: OverlayComponentExpression?
    var kind: OverlayComponentParamKind
    var defaultValue: OverlayComponentValue
}

enum OverlayComponentParamKind: Equatable {
    case number(minimum: Double, maximum: Double, step: Double?, unit: String?, style: OverlayComponentParamNumberStyle)
    case boolean
    case color
    case enumeration(options: [OverlayComponentParamOption])
    case string(maxLength: Int)
    case font
    case metric(signals: [String], allowsSeries: Bool)
}

enum OverlayComponentParamNumberStyle: String, Equatable {
    case slider
    case field
    case stepper
}

struct OverlayComponentParamOption: Equatable {
    var value: String
    var label: OverlayComponentLocalizedText
}

enum OverlayComponentBinding: Equatable {
    case signal(String)
    case series(path: String, window: OverlayComponentSeriesWindow, samples: Int)
    case list(String)
}

enum OverlayComponentNumberSource: Equatable {
    case literal(Double)
    case expression(OverlayComponentExpression)

    func evaluate(in context: OverlayComponentEvaluationContext) -> Double? {
        switch self {
        case .literal(let value):
            return value.isFinite ? value : nil
        case .expression(let expression):
            guard let value = expression.evaluate(in: context).number, value.isFinite else {
                return nil
            }
            return value
        }
    }

    var identifierReferences: Set<String> {
        switch self {
        case .literal: return []
        case .expression(let expression): return expression.referencedIdentifiers
        }
    }
}

enum OverlayComponentColorSource: Equatable {
    case literal(OverlayColor)
    case expression(OverlayComponentExpression)

    func evaluate(in context: OverlayComponentEvaluationContext) -> OverlayColor? {
        switch self {
        case .literal(let color):
            return color
        case .expression(let expression):
            return expression.evaluate(in: context).color
        }
    }
}

enum OverlayComponentStringSource: Equatable {
    case literal(String)
    case expression(OverlayComponentExpression)

    func evaluate(in context: OverlayComponentEvaluationContext) -> String {
        switch self {
        case .literal(let value):
            return value
        case .expression(let expression):
            return expression.evaluate(in: context).displayString
        }
    }
}

struct OverlayComponentPoint: Equatable {
    var x: OverlayComponentNumberSource
    var y: OverlayComponentNumberSource

    func evaluate(in context: OverlayComponentEvaluationContext) -> CGPoint? {
        guard let x = x.evaluate(in: context), let y = y.evaluate(in: context) else {
            return nil
        }
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

enum OverlayComponentPointsSource: Equatable {
    case literal([OverlayComponentPoint])
    case expression(OverlayComponentExpression)

    func evaluate(in context: OverlayComponentEvaluationContext) -> [CGPoint]? {
        switch self {
        case .literal(let points):
            let resolved = points.compactMap { $0.evaluate(in: context) }
            return resolved.count == points.count ? resolved : nil
        case .expression(let expression):
            guard let list = expression.evaluate(in: context).list else { return nil }
            let points = list.compactMap { item -> CGPoint? in
                guard let pair = item.list, pair.count == 2,
                      let x = pair[0].number, let y = pair[1].number else {
                    return nil
                }
                return CGPoint(x: CGFloat(x), y: CGFloat(y))
            }
            return points.count == list.count ? points : nil
        }
    }
}

struct OverlayComponentFrame: Equatable {
    var x: OverlayComponentNumberSource
    var y: OverlayComponentNumberSource
    var width: OverlayComponentNumberSource
    var height: OverlayComponentNumberSource

    func evaluate(in context: OverlayComponentEvaluationContext) -> CGRect? {
        guard let x = x.evaluate(in: context),
              let y = y.evaluate(in: context),
              let width = width.evaluate(in: context),
              let height = height.evaluate(in: context) else {
            return nil
        }
        return CGRect(
            x: CGFloat(x),
            y: CGFloat(y),
            width: CGFloat(max(width, 0)),
            height: CGFloat(max(height, 0))
        )
    }
}

struct OverlayComponentFont: Equatable {
    var family: String
    var size: OverlayComponentNumberSource
    var weight: OverlayComponentFontWeight
}

enum OverlayComponentFontWeight: String, Equatable, CaseIterable {
    case ultraLight
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

enum OverlayComponentTextAlignment: String, Equatable {
    case left
    case center
    case right
}

enum OverlayComponentVerticalAlignment: String, Equatable {
    case top
    case center
    case bottom
}

enum OverlayComponentStackDirection: String, Equatable {
    case horizontal
    case vertical
}

enum OverlayComponentCrossAlignment: String, Equatable {
    case start
    case center
    case end
}

enum OverlayComponentLineCap: String, Equatable {
    case butt
    case round
    case square
}

enum OverlayComponentLineJoin: String, Equatable {
    case miter
    case round
    case bevel
}

enum OverlayComponentImageFit: String, Equatable {
    case fill
    case contain
}

enum OverlayComponentSmoothing: String, Equatable {
    case none
    case monotone
}

struct OverlayComponentShadow: Equatable {
    var sigma: OverlayComponentNumberSource
    var dx: OverlayComponentNumberSource
    var dy: OverlayComponentNumberSource
    var color: OverlayComponentColorSource
}

struct OverlayComponentGradientStop: Equatable {
    var offset: Double
    var color: OverlayColor
}

enum OverlayComponentPathCommand: Equatable {
    case move(OverlayComponentNumberSource, OverlayComponentNumberSource)
    case line(OverlayComponentNumberSource, OverlayComponentNumberSource)
    case quad(OverlayComponentNumberSource, OverlayComponentNumberSource,
              OverlayComponentNumberSource, OverlayComponentNumberSource)
    case cubic(OverlayComponentNumberSource, OverlayComponentNumberSource,
               OverlayComponentNumberSource, OverlayComponentNumberSource,
               OverlayComponentNumberSource, OverlayComponentNumberSource)
    case arc(OverlayComponentNumberSource, OverlayComponentNumberSource,
             OverlayComponentNumberSource, OverlayComponentNumberSource,
             OverlayComponentNumberSource)
    case close
}

struct OverlayComponentNode: Equatable {
    var id: String?
    var frame: OverlayComponentFrame?
    var condition: OverlayComponentExpression?
    var opacity: OverlayComponentNumberSource?
    var kind: OverlayComponentNodeKind
}

enum OverlayComponentNodeKind: Equatable {
    case group(children: [OverlayComponentNode], clip: Bool, shadow: OverlayComponentShadow?)
    case stack(
        direction: OverlayComponentStackDirection,
        spacing: OverlayComponentNumberSource,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentNode]
    )
    case rect(fill: OverlayComponentColorSource,
              radius: OverlayComponentNumberSource,
              stroke: OverlayComponentColorSource?,
              strokeWidth: OverlayComponentNumberSource?)
    case circle(center: OverlayComponentPoint,
                radius: OverlayComponentNumberSource,
                fill: OverlayComponentColorSource?,
                stroke: OverlayComponentColorSource?,
                strokeWidth: OverlayComponentNumberSource?)
    case line(from: OverlayComponentPoint,
              to: OverlayComponentPoint,
              width: OverlayComponentNumberSource,
              color: OverlayComponentColorSource,
              cap: OverlayComponentLineCap)
    case polyline(points: OverlayComponentPointsSource,
                  width: OverlayComponentNumberSource,
                  color: OverlayComponentColorSource,
                  cap: OverlayComponentLineCap,
                  join: OverlayComponentLineJoin,
                  dash: [OverlayComponentNumberSource]?)
    case path(commands: [OverlayComponentPathCommand],
              fill: OverlayComponentColorSource?,
              stroke: OverlayComponentColorSource?,
              strokeWidth: OverlayComponentNumberSource?,
              cap: OverlayComponentLineCap,
              join: OverlayComponentLineJoin,
              dash: [OverlayComponentNumberSource]?)
    case text(text: OverlayComponentStringSource,
              font: OverlayComponentFont,
              color: OverlayComponentColorSource,
              align: OverlayComponentTextAlignment,
              verticalAlign: OverlayComponentVerticalAlignment,
              maxWidth: OverlayComponentNumberSource?,
              lineHeight: OverlayComponentNumberSource?,
              tracking: OverlayComponentNumberSource?)
    case image(asset: String, fit: OverlayComponentImageFit)
    case gradientRect(stops: [OverlayComponentGradientStop],
                      from: OverlayComponentPoint,
                      to: OverlayComponentPoint,
                      radius: OverlayComponentNumberSource?)
    case sparkline(series: OverlayComponentExpression,
                   stroke: OverlayComponentColorSource,
                   lineWidth: OverlayComponentNumberSource,
                   fill: OverlayComponentColorSource?,
                   smoothing: OverlayComponentSmoothing)
    case progressBar(value: OverlayComponentExpression,
                     trackColor: OverlayComponentColorSource,
                     fillColor: OverlayComponentColorSource,
                     radius: OverlayComponentNumberSource?)
    case arc(value: OverlayComponentExpression,
             startDegrees: OverlayComponentNumberSource,
             sweepDegrees: OverlayComponentNumberSource,
             radius: OverlayComponentNumberSource,
             width: OverlayComponentNumberSource,
             trackColor: OverlayComponentColorSource?,
             fillColor: OverlayComponentColorSource,
             cap: OverlayComponentLineCap)
    case repeatNode(over: OverlayComponentExpression,
                    itemName: String,
                    indexName: String,
                    maximum: OverlayComponentNumberSource?,
                    children: [OverlayComponentNode])
}

struct OverlayComponentPackage: Equatable {
    var definition: OverlayComponentDefinition
    var digest: String
    /// Package-relative asset paths, e.g. `assets/heart.png`.
    var assets: Set<String>
    /// Asset bytes keyed by the same package-relative paths. Imported and
    /// project components persist these so the project is self-contained.
    var assetData: [String: Data]
}
