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
    /// Fixed design size. `.zero` when `contentLayout` is set.
    var size: OverlayComponentSize
    /// Present when the document declares `"size": "content"`: the instance
    /// bounds come from measured content at render time.
    var contentLayout: OverlayComponentContentLayout?
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

/// Padding and minimum size for a content-sized component, in design units.
struct OverlayComponentContentLayout: Equatable {
    var paddingX: OverlayComponentNumberSource
    var paddingY: OverlayComponentNumberSource
    var minWidth: OverlayComponentNumberSource
    var minHeight: OverlayComponentNumberSource
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
    /// A value computed from parameters, signals and earlier computed
    /// bindings. Lets a definition name intermediate geometry instead of
    /// repeating one long expression on every node that needs it.
    case value(OverlayComponentExpression)
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

/// SF Symbol names are lowercase dot-separated tokens. The check keeps a
/// symbol node a reference into the system catalog rather than free text.
enum OverlayComponentSymbolName {
    static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 128 else { return false }
        return name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { token in
            !token.isEmpty && token.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
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

/// Family and weight accept expressions so `font` and enum params can drive
/// them; literals are validated at load.
struct OverlayComponentFont: Equatable {
    var family: OverlayComponentStringSource
    var size: OverlayComponentNumberSource
    var weight: OverlayComponentStringSource
}

enum OverlayComponentFontWeight: String, Equatable, CaseIterable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

enum OverlayComponentSymbolRendering: String, Equatable {
    case glyph
    case fit
}

enum OverlayComponentSymbolScale: String, Equatable {
    case small
    case medium
    case large
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
    /// Start-aligned; a child stack is also sized to the container's cross
    /// extent so its flexible spacers can distribute the extra length.
    case stretch
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

struct OverlayComponentTextRowRun: Equatable {
    var text: OverlayComponentStringSource
    var font: OverlayComponentFont
    var color: OverlayComponentColorSource
    var minimumScaleFactor: OverlayComponentNumberSource?
    var verticalPadding: OverlayComponentNumberSource?
    var opacity: OverlayComponentNumberSource?
    var monospacedDigits: Bool
    var condition: OverlayComponentExpression?
}

enum OverlayComponentTextRowAlignment: String, Equatable {
    case center
    case firstTextBaseline
}

struct OverlayComponentTextRow: Equatable {
    var runs: [OverlayComponentTextRowRun]
    var spacing: OverlayComponentNumberSource?
    var alignment: OverlayComponentTextRowAlignment
    var condition: OverlayComponentExpression?
}

struct OverlayComponentShadow: Equatable {
    var sigma: OverlayComponentNumberSource
    var dx: OverlayComponentNumberSource
    var dy: OverlayComponentNumberSource
    var color: OverlayComponentColorSource
    /// Multiplies the color alpha; 1 by default.
    var opacity: OverlayComponentNumberSource?
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
    /// Cross-axis alignment override (literal or expression naming an
    /// `OverlayComponentCrossAlignment`); only valid on a direct `stack` child.
    var alignSelf: OverlayComponentStringSource? = nil
}

/// Multiline, frame-constrained text with AppKit paragraph layout. Unlike
/// `text`, this capability can fit its font to the frame and paint glyph ink.
struct OverlayComponentRichText: Equatable {
    var text: OverlayComponentStringSource
    var font: OverlayComponentFont
    var color: OverlayComponentColorSource
    var align: OverlayComponentStringSource
    var lineHeight: OverlayComponentNumberSource?
    var tracking: OverlayComponentNumberSource?
    var stroke: OverlayComponentColorSource?
    var strokeWidth: OverlayComponentNumberSource?
    var autoFit: OverlayComponentExpression?
    var gradient: OverlayComponentTextGradient?
}

struct OverlayComponentTextGradient: Equatable {
    var stops: [Stop]
    var from: OverlayComponentPoint
    var to: OverlayComponentPoint

    struct Stop: Equatable {
        var offset: Double
        var color: OverlayComponentColorSource
    }
}

enum OverlayComponentNodeKind: Equatable {
    case richText(OverlayComponentRichText)
    /// Centered display rows that shrink each run to fit the node frame.
    /// Unlike `richText`, this is a short vertical stack of single-line runs.
    case textRows(rows: [OverlayComponentTextRow], spacing: OverlayComponentNumberSource?,
                  maxWidth: OverlayComponentNumberSource?)
    case group(children: [OverlayComponentNode], clip: Bool,
               shadows: [OverlayComponentShadow],
               shadowBounds: OverlayComponentFrame?)
    /// `direction` and `crossAlign` are literals or expressions naming
    /// `OverlayComponentStackDirection` / `OverlayComponentCrossAlignment`.
    case stack(
        direction: OverlayComponentStringSource,
        spacing: OverlayComponentNumberSource,
        crossAlign: OverlayComponentStringSource,
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
    /// Fixed gap when `length` is set, otherwise flexible: flexible spacers
    /// share a stack's leftover main-axis length. `minimum` keeps a flexible
    /// spacer from collapsing below that length when space is tight. Only
    /// valid in a stack.
    case spacer(length: OverlayComponentNumberSource?,
                minimum: OverlayComponentNumberSource?)
    /// Equal-width columns sized to `width`; children are centered vertically
    /// and optional dividers are drawn between them. Column count is the
    /// number of children that survive their `if` conditions.
    case columns(width: OverlayComponentNumberSource,
                 divider: OverlayComponentDivider?,
                 children: [OverlayComponentNode])
    case symbol(name: OverlayComponentStringSource,
                color: OverlayComponentColorSource,
                weight: OverlayComponentStringSource,
                scale: OverlayComponentStringSource,
                rendering: OverlayComponentSymbolRendering)
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
    /// One horizontal bar split into proportional segments from a data list.
    /// Segments come from records with `index` and `color`; an optional active
    /// segment can widen and thicken. Optional markers anchor to a segment by
    /// index and fraction, so a definition never re-implements the geometry.
    case segmentedBar(OverlayComponentSegmentedBar)
    indirect case timelineStrip(OverlayComponentTimelineStrip)
    /// Circular running-gauge dial; the host formats each region metric.
    indirect case runningGauge(OverlayComponentRunningGauge)
    /// Distance progress track; the host formats distance text and axis labels.
    indirect case distanceTimeline(OverlayComponentDistanceTimeline)
    /// Elevation profile chart; the host builds the sample series and labels.
    indirect case elevationChart(OverlayComponentElevationChart)
    /// Projected GPS route window; the host supplies route geometry.
    indirect case routeMap(OverlayComponentRouteMap)
    /// Weather card; the host supplies the weather snapshot and icon assets.
    indirect case weatherWidget(OverlayComponentWeatherWidget)
}

struct OverlayComponentSegmentedBar: Equatable {
    var segments: OverlayComponentExpression
    /// `horizontal` (default) or `vertical`. Vertical runs order segments
    /// from the bottom edge upward, matching the native zone bars.
    var orientation: OverlayComponentStringSource?
    var activeIndex: OverlayComponentNumberSource?
    var activeWidthShare: OverlayComponentNumberSource?
    var activeThicknessScale: OverlayComponentNumberSource?
    var gap: OverlayComponentNumberSource?
    var radius: OverlayComponentNumberSource?
    var inactiveOpacity: OverlayComponentNumberSource?
    var glow: Glow?
    /// Rounded outline drawn over the segments and under the markers, matching
    /// host bars that draw their outline before markers.
    var border: Border?
    var markers: [Marker]

    struct Border: Equatable {
        var color: OverlayComponentColorSource
        var opacity: OverlayComponentNumberSource
        var width: OverlayComponentNumberSource
    }

    struct Glow: Equatable {
        var opacity: OverlayComponentNumberSource
        /// Blur sigma in design units.
        var sigma: OverlayComponentNumberSource
    }

    struct Marker: Equatable {
        var role: OverlayComponentSegmentedBarMarkerRole
        /// `inline` (default) draws the native interval-HUD marker; `outside`
        /// draws the native zone-edge marker, which sits wholly outside the
        /// bar on `position`'s side and supports vertical bars.
        var layout: OverlayComponentSegmentedBarMarkerLayout = .inline
        var condition: OverlayComponentExpression?
        /// Segment index (as carried by the segment record's `index`).
        var index: OverlayComponentNumberSource?
        /// 0...1 position inside the segment.
        var fraction: OverlayComponentNumberSource?
        var text: OverlayComponentStringSource
        var color: OverlayComponentColorSource
        /// `above`, `below`, `leading` or `trailing` relative to the bar.
        var position: OverlayComponentStringSource?
        var showsValue: OverlayComponentNumberSource?
        /// Multiplier for the marker's arrow (inline current) or the whole
        /// outside callout/tick geometry.
        var scale: OverlayComponentNumberSource?
        var font: OverlayComponentFont
    }
}

/// A horizontally laid-out lap schedule for interval workouts. The node owns
/// the schedule geometry the way the native module does: visibility filters,
/// the centered window, weighted segment widths, labels, progress fill, the
/// overflow hints and the marker lane all derive from the segment list.
struct OverlayComponentTimelineStrip: Equatable {
    /// List expression of lap records (`structure.laps`); each record supplies
    /// `index`, `kind`, `startElapsed`, `endElapsed`, `elapsed` and `distance`.
    var segments: OverlayComponentExpression
    /// Current lap index as carried by a record's `index`.
    var currentIndex: OverlayComponentNumberSource?
    /// Activity elapsed seconds, used for completed/future styling and the
    /// fallback marker anchor.
    var elapsed: OverlayComponentNumberSource?
    /// `emphasized` (default, centered window), `equal` or `weighted`.
    var mode: OverlayComponentStringSource?
    var emphasisFraction: OverlayComponentNumberSource?
    /// Neighbor count on each side in `emphasized` mode; omitted means all.
    var window: OverlayComponentNumberSource?
    var showsWarmup: OverlayComponentNumberSource?
    var showsRest: OverlayComponentNumberSource?
    var showsCooldown: OverlayComponentNumberSource?
    /// Segment area height before vertical padding (the native `height`).
    var segmentAreaHeight: OverlayComponentNumberSource?
    var segmentHeight: OverlayComponentNumberSource?
    var currentHeightScale: OverlayComponentNumberSource?
    var minSegmentWidth: OverlayComponentNumberSource?
    var gap: OverlayComponentNumberSource?
    var radius: OverlayComponentNumberSource?
    var currentBorderWidth: OverlayComponentNumberSource?
    var completedOpacity: OverlayComponentNumberSource?
    var futureOpacity: OverlayComponentNumberSource?
    var colors: Colors?
    var labels: Labels?
    var progress: Progress?
    var marker: Marker?
    var overflow: Overflow?
    /// Rep counter line shown on the current active segment, e.g. `Rep 2 / 5`.
    var repText: OverlayComponentStringSource?
    /// Current lap distance progress, used for elapsed/remaining distance labels.
    var distanceProgress: OverlayComponentNumberSource?

    struct Colors: Equatable {
        var warmup: OverlayComponentColorSource
        var active: OverlayComponentColorSource
        var rest: OverlayComponentColorSource
        var cooldown: OverlayComponentColorSource
        var unknown: OverlayComponentColorSource
    }

    struct Labels: Equatable {
        var font: OverlayComponentFont
        /// `hidden`, `elapsed` or `remaining` for the current work segment.
        var currentWorkDistance: OverlayComponentStringSource?
        var currentWorkTime: OverlayComponentStringSource?
        /// Draw the kind text (`Rest`, `WU`, ...) on the current non-work segment.
        var currentRestKind: OverlayComponentNumberSource?
        var currentRestDistance: OverlayComponentStringSource?
        var currentRestTime: OverlayComponentStringSource?
        /// `hidden`, `distance` or `time` for non-current segments.
        var neighbor: OverlayComponentStringSource?
    }

    struct Progress: Equatable {
        var value: OverlayComponentNumberSource
        var color: OverlayComponentColorSource
        var opacity: OverlayComponentNumberSource?
    }

    struct Marker: Equatable {
        var enabled: OverlayComponentNumberSource?
        /// `progress` (default) or `center`.
        var position: OverlayComponentStringSource?
        var color: OverlayComponentColorSource
        var label: OverlayComponentStringSource?
        var showsLabel: OverlayComponentNumberSource?
        var font: OverlayComponentFont
    }

    struct Overflow: Equatable {
        var enabled: OverlayComponentNumberSource?
        /// Text drawn at the left and right edges, e.g. `···`.
        var text: OverlayComponentStringSource?
        var color: OverlayComponentColorSource
        /// Distance from the segment area edge to the hint center, design units.
        var inset: OverlayComponentNumberSource?
    }
}


/// A circular gauge dial for one activity snapshot. The host formats each
/// region's metric; the node owns the dial, rings, ticks, dividers and the
/// per-region typography, matching the native Running Gauge module.
struct OverlayComponentRunningGauge: Equatable {
    /// `topBottom`, `topMiddleBottom`, `threeZones`, `topTwoMiddleBottom`,
    /// `topThreeMiddleBottom`, `fourZones` or `fiveZones`.
    var layoutPreset: OverlayComponentStringSource?
    var progress: OverlayComponentNumberSource?
    var dialBackgroundColor: OverlayComponentColorSource?
    var dialBackgroundOpacity: OverlayComponentNumberSource?
    var glassEffectEnabled: OverlayComponentNumberSource?
    var outerRingEnabled: OverlayComponentNumberSource?
    var outerRingColor: OverlayComponentColorSource?
    var outerRingOpacity: OverlayComponentNumberSource?
    var outerRingWidthScale: OverlayComponentNumberSource?
    var tickMarksEnabled: OverlayComponentNumberSource?
    var tickColor: OverlayComponentColorSource?
    var tickOpacity: OverlayComponentNumberSource?
    var majorTickOpacity: OverlayComponentNumberSource?
    var tickCount: OverlayComponentNumberSource?
    var majorTickEvery: OverlayComponentNumberSource?
    var progressRingEnabled: OverlayComponentNumberSource?
    var progressColor: OverlayComponentColorSource?
    var progressTrackColor: OverlayComponentColorSource?
    var progressTrackOpacity: OverlayComponentNumberSource?
    var progressRingWidthScale: OverlayComponentNumberSource?
    var progressRoundedCaps: OverlayComponentNumberSource?
    var dividerEnabled: OverlayComponentNumberSource?
    var dividerColor: OverlayComponentColorSource?
    var dividerOpacity: OverlayComponentNumberSource?
    var dividerWidth: OverlayComponentNumberSource?
    var font: OverlayComponentFont
    var monospacedDigits: OverlayComponentNumberSource?
    var primaryFontWeight: OverlayComponentStringSource?
    var secondaryFontWeight: OverlayComponentStringSource?
    var primaryTextColor: OverlayComponentColorSource?
    var secondaryTextColor: OverlayComponentColorSource?
    var accentColor: OverlayComponentColorSource?
    var regions: [Region]?

    struct Region: Equatable {
        /// `top`, `middle`, `bottom`, `middleLeft`, `middleCenter`,
        /// `middleRight`, `topLeft`, `topRight`, `bottomLeft`, `bottomRight`.
        var region: OverlayComponentStringSource?
        /// Overlay metric id, e.g. `heartRate`, `pace`, `distance`.
        var metric: OverlayComponentStringSource
        var customLabel: OverlayComponentStringSource?
        var showLabel: OverlayComponentNumberSource?
        var showUnit: OverlayComponentNumberSource?
        var valueFontScale: OverlayComponentNumberSource?
        var labelFontScale: OverlayComponentNumberSource?
        var unitFontScale: OverlayComponentNumberSource?
        var valueWeight: OverlayComponentStringSource?
        var labelWeight: OverlayComponentStringSource?
        var valueColor: OverlayComponentColorSource?
        var labelColor: OverlayComponentColorSource?
    }
}

/// A distance progress track for one activity snapshot. The host computes the
/// current/total distance, axis labels and stats bar; the node owns the track,
/// marker, labels and appearance, matching the native Distance Timeline module.
struct OverlayComponentDistanceTimeline: Equatable {
    /// `minimal`, `dense`, `sport`, `splits`, `glass`, `neon`, `lowerThird` or
    /// `route`; selects the native preset defaults for any omitted field.
    var preset: OverlayComponentStringSource?
    /// Value text size in design units (native element `fontSize`).
    var valueFontSize: OverlayComponentNumberSource?
    /// `metric` or `imperial`.
    var valueUnitSystem: OverlayComponentStringSource?
    var showValue: OverlayComponentNumberSource?
    var showTotalDistance: OverlayComponentNumberSource?
    var showLabel: OverlayComponentNumberSource?
    var label: OverlayComponentStringSource?
    var labelFontFamily: OverlayComponentStringSource?
    var labelFontSize: OverlayComponentNumberSource?
    var labelFontWeight: OverlayComponentStringSource?
    var labelColor: OverlayComponentColorSource?
    var labelValueSpacing: OverlayComponentNumberSource?
    var showAxisLabels: OverlayComponentNumberSource?
    /// `startFinish` or `distance`.
    var axisLabelMode: OverlayComponentStringSource?
    var axisLabelOffset: OverlayComponentNumberSource?
    var axisLabelFontFamily: OverlayComponentStringSource?
    var axisLabelFontSize: OverlayComponentNumberSource?
    var axisLabelFontWeight: OverlayComponentStringSource?
    var axisLabelColor: OverlayComponentColorSource?
    var showDistancePoints: OverlayComponentNumberSource?
    var distancePointCount: OverlayComponentNumberSource?
    var distancePointOffset: OverlayComponentNumberSource?
    var midpointAxisLabelOffset: OverlayComponentNumberSource?
    /// `below` or `above`.
    var axisEndpointLabelPlacement: OverlayComponentStringSource?
    var axisMidpointLabelPlacement: OverlayComponentStringSource?
    var markerDistanceLabelEnabled: OverlayComponentNumberSource?
    var markerDistanceLabelPlacement: OverlayComponentStringSource?
    var markerDistanceLabelOffset: OverlayComponentNumberSource?
    var currentMarkerSizeMultiplier: OverlayComponentNumberSource?
    var backgroundEnabled: OverlayComponentNumberSource?
    var backgroundColor: OverlayComponentColorSource?
    var backgroundOpacity: OverlayComponentNumberSource?
    var borderEnabled: OverlayComponentNumberSource?
    var borderColor: OverlayComponentColorSource?
    var borderOpacity: OverlayComponentNumberSource?
    var borderWidth: OverlayComponentNumberSource?
    var cornerRadius: OverlayComponentNumberSource?
    var paddingX: OverlayComponentNumberSource?
    var paddingY: OverlayComponentNumberSource?
    var trackHeight: OverlayComponentNumberSource?
    var trackOpacity: OverlayComponentNumberSource?
    var fillColor: OverlayComponentColorSource?
    var tickMarksEnabled: OverlayComponentNumberSource?
    var tickDensity: OverlayComponentNumberSource?
    var currentMarkerEnabled: OverlayComponentNumberSource?
    /// `dot`, `pill` or `triangle`.
    var currentMarkerStyle: OverlayComponentStringSource?
    var currentMarkerColor: OverlayComponentColorSource?
    var glowEnabled: OverlayComponentNumberSource?
    var fadeEnabled: OverlayComponentNumberSource?
    /// `left`, `right`, `both`, `vertical` or `all`.
    var fadeEdge: OverlayComponentStringSource?
    var fadeAmount: OverlayComponentNumberSource?
    var mediaSlotEnabled: OverlayComponentNumberSource?
    /// `none`, `systemIcon`, `staticSVG`, `animatedSVG` or `image`.
    var mediaSlotMode: OverlayComponentStringSource?
    var mediaSystemImage: OverlayComponentStringSource?
    var mediaSlotSize: OverlayComponentNumberSource?
    var elevationProfileVisible: OverlayComponentNumberSource?
}

/// An elevation profile chart for one activity snapshot. The host builds the
/// sample series, smoothing, axis and stats-bar data; the node owns the card,
/// line, fill, marker and typography, matching the native Elevation Chart.
struct OverlayComponentElevationChart: Equatable {
    /// `gradientArea`, `dualArea`, `techGlow`, `minimalWhite` or `bigNumbers`.
    var preset: OverlayComponentStringSource?
    /// `area` or `lineOnly`.
    var chartStyle: OverlayComponentStringSource?
    var smoothingEnabled: OverlayComponentNumberSource?
    var smoothingAmount: OverlayComponentNumberSource?
    /// `fullProfile` or `progressToCurrent`.
    var progressMode: OverlayComponentStringSource?
    var chartPaddingX: OverlayComponentNumberSource?
    var chartPaddingY: OverlayComponentNumberSource?
    var lineColor: OverlayComponentColorSource?
    var lineWidth: OverlayComponentNumberSource?
    var lineOpacity: OverlayComponentNumberSource?
    var fillEnabled: OverlayComponentNumberSource?
    var fillStartColor: OverlayComponentColorSource?
    var fillEndColor: OverlayComponentColorSource?
    var fillOpacity: OverlayComponentNumberSource?
    var dualAreaEnabled: OverlayComponentNumberSource?
    var upperFillColor: OverlayComponentColorSource?
    var lowerFillColor: OverlayComponentColorSource?
    var currentMarkerEnabled: OverlayComponentNumberSource?
    var markerColor: OverlayComponentColorSource?
    var markerSizeMultiplier: OverlayComponentNumberSource?
    var markerPlayheadLineEnabled: OverlayComponentNumberSource?
    var markerLabelEnabled: OverlayComponentNumberSource?
    var gridEnabled: OverlayComponentNumberSource?
    var axisLineEnabled: OverlayComponentNumberSource?
    var axisLabelsEnabled: OverlayComponentNumberSource?
    var bigNumbersEnabled: OverlayComponentNumberSource?
    /// `currentElevation`, `elevationGain`, `maxElevation` or `minElevation`.
    var bigNumberMetric: OverlayComponentStringSource?
    var bigNumberFontSize: OverlayComponentNumberSource?
    var bigNumberFontFamily: OverlayComponentStringSource?
    var bigNumberFontWeight: OverlayComponentStringSource?
    var backgroundEnabled: OverlayComponentNumberSource?
    var backgroundColor: OverlayComponentColorSource?
    var backgroundOpacity: OverlayComponentNumberSource?
    var cornerRadius: OverlayComponentNumberSource?
    var borderEnabled: OverlayComponentNumberSource?
    var borderOpacity: OverlayComponentNumberSource?
    var shadowEnabled: OverlayComponentNumberSource?
    var shadowOpacity: OverlayComponentNumberSource?
    var shadowRadius: OverlayComponentNumberSource?
    var glowEnabled: OverlayComponentNumberSource?
    var glowOpacity: OverlayComponentNumberSource?
    /// Shared text style for the axis and value label.
    var fontFamily: OverlayComponentStringSource?
    var foregroundColor: OverlayComponentColorSource?
    /// Base text size in design units (native element `fontSize`).
    var valueFontSize: OverlayComponentNumberSource?
}

/// A projected GPS route window. The host supplies the activity route and the
/// projection; the node owns the container shape, background, route line,
/// markers and border, matching the native Route Map module.
/// Declarative appearance for the host-drawn weather widget.
///
/// The component never fetches weather. The host may supply a snapshot through
/// `weather.current`; without one the node's manual values are used, matching
/// the native widget's manual data source.
struct OverlayComponentWeatherWidget: Equatable {
    /// `simpleCard`, `compactStrip`, `forecastTile`, `minimalText` or
    /// `dashboardBar`.
    var preset: OverlayComponentStringSource?
    /// `WeatherCondition` raw value used when the host has no snapshot.
    var condition: OverlayComponentStringSource?
    var temperatureCelsius: OverlayComponentNumberSource?
    var humidity: OverlayComponentNumberSource?
    var highCelsius: OverlayComponentNumberSource?
    var lowCelsius: OverlayComponentNumberSource?
    var windKph: OverlayComponentNumberSource?
    var feelsLikeCelsius: OverlayComponentNumberSource?
    /// `celsius` or `fahrenheit`.
    var temperatureUnit: OverlayComponentStringSource?
    /// Replaces the reading with the activity's FIT temperature.
    var useActivityTemperature: OverlayComponentNumberSource?
    var locationText: OverlayComponentStringSource?
    var showLocation: OverlayComponentNumberSource?
    var showWeekday: OverlayComponentNumberSource?
    var showHumidity: OverlayComponentNumberSource?
    var showHighLow: OverlayComponentNumberSource?
    var showWind: OverlayComponentNumberSource?
    var showFeelsLike: OverlayComponentNumberSource?
    var showIcon: OverlayComponentNumberSource?
    var showConditionLabel: OverlayComponentNumberSource?
    var conditionLabelOverride: OverlayComponentStringSource?
    var humiditySuffix: OverlayComponentStringSource?
    var humidityMetricLabel: OverlayComponentStringSource?
    var windMetricLabel: OverlayComponentStringSource?
    var feelsLikeMetricLabel: OverlayComponentStringSource?
    var cardBackgroundColor: OverlayComponentColorSource?
    var cardBackgroundOpacity: OverlayComponentNumberSource?
    var cardCornerRadius: OverlayComponentNumberSource?
    var dividerEnabled: OverlayComponentNumberSource?
    var dividerColor: OverlayComponentColorSource?
    var dividerThickness: OverlayComponentNumberSource?
    var dividerOpacity: OverlayComponentNumberSource?
    /// `presetDefault`, `blueGlass`, `lightGlass`, `graphite` or
    /// `minimalWhite`.
    var palette: OverlayComponentStringSource?
    var iconSize: OverlayComponentNumberSource?
    var slotBackgroundColor: OverlayComponentColorSource?
    var slotBackgroundOpacity: OverlayComponentNumberSource?
    var slotSpacing: OverlayComponentNumberSource?
    /// Font family applied to every text role the node does not override.
    var fontFamily: OverlayComponentStringSource?
    var locationFontSize: OverlayComponentNumberSource?
    var locationFontWeight: OverlayComponentStringSource?
    var locationColor: OverlayComponentColorSource?
    var conditionFontSize: OverlayComponentNumberSource?
    var conditionFontWeight: OverlayComponentStringSource?
    var conditionColor: OverlayComponentColorSource?
    var temperatureFontSize: OverlayComponentNumberSource?
    var temperatureFontWeight: OverlayComponentStringSource?
    var temperatureColor: OverlayComponentColorSource?
    var slotTitleFontSize: OverlayComponentNumberSource?
    var slotTitleFontWeight: OverlayComponentStringSource?
    var slotTitleColor: OverlayComponentColorSource?
    var slotLabelFontSize: OverlayComponentNumberSource?
    var slotLabelFontWeight: OverlayComponentStringSource?
    var slotLabelColor: OverlayComponentColorSource?
}

struct OverlayComponentRouteMap: Equatable {
    /// `square` or `circle`.
    var shape: OverlayComponentStringSource?
    /// `none`, `dark`, `light`, `terrain` or `satellite`.
    var backgroundStyle: OverlayComponentStringSource?
    var cornerRadius: OverlayComponentNumberSource?
    var backgroundOpacity: OverlayComponentNumberSource?
    /// `hidden`, `dot`, `pin` or `flag` (the renderer draws dot geometry).
    var startMarkerStyle: OverlayComponentStringSource?
    var endMarkerStyle: OverlayComponentStringSource?
    var runnerMarkerStyle: OverlayComponentStringSource?
    var startMarkerColor: OverlayComponentColorSource?
    var endMarkerColor: OverlayComponentColorSource?
    var runnerMarkerColor: OverlayComponentColorSource?
    var glowEnabled: OverlayComponentNumberSource?
    var mapOpacity: OverlayComponentNumberSource?
    var borderEnabled: OverlayComponentNumberSource?
    var borderOpacity: OverlayComponentNumberSource?
    var foregroundColor: OverlayComponentColorSource?
    var fontFamily: OverlayComponentStringSource?
}

enum OverlayComponentSegmentedBarMarkerLayout: String, CaseIterable {
    case inline
    case outside
}

/// Side of the bar a segmented-bar marker sits on. `above`/`below` apply to
/// horizontal bars; `leading`/`trailing` apply to vertical bars.
enum OverlayComponentSegmentedBarMarkerSide: String, CaseIterable {
    case above
    case below
    case leading
    case trailing
}

enum OverlayComponentSegmentedBarMarkerRole: String, CaseIterable {
    /// Arrow plus an optional value pill, centered on the bar edge.
    case current
    /// A thin capsule crossing the bar with a value label below it.
    case threshold
}

struct OverlayComponentDivider: Equatable {
    var width: OverlayComponentNumberSource
    var color: OverlayComponentColorSource
    var opacity: OverlayComponentNumberSource
    /// Zero hides the separator without removing the space reserved by `width`.
    var height: OverlayComponentNumberSource
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
