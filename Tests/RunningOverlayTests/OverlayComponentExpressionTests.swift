import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentExpressionTests {
    private func evaluate(
        _ source: String,
        context: OverlayComponentEvaluationContext = .init()
    ) throws -> OverlayComponentValue {
        try OverlayComponentExpression.parse(source).evaluate(in: context)
    }

    @Test func arithmeticPrecedenceAndParentheses() throws {
        #expect(try evaluate("1 + 2 * 3") == .number(7))
        #expect(try evaluate("(1 + 2) * 3") == .number(9))
        #expect(try evaluate("10 - 4 / 2") == .number(8))
        #expect(try evaluate("7 % 4") == .number(3))
        #expect(try evaluate("-2 * 3") == .number(-6))
    }

    @Test func comparisonsAndBooleanOperators() throws {
        #expect(try evaluate("3 > 2 && 2 <= 2") == .boolean(true))
        #expect(try evaluate("false || !false") == .boolean(true))
        #expect(try evaluate("1 == 1") == .boolean(true))
        #expect(try evaluate("1 != 2") == .boolean(true))
        #expect(try evaluate("\"a\" < \"b\"") == .boolean(true))
        #expect(try evaluate("1 == \"1\"") == .boolean(false))
    }

    @Test func ternaryUsesJSONTruthiness() throws {
        #expect(try evaluate("true ? 1 : 2") == .number(1))
        #expect(try evaluate("0 ? 1 : 2") == .number(2))
        #expect(try evaluate("\"\" ? 1 : 2") == .number(2))
        #expect(try evaluate("\"x\" ? 1 : 2") == .number(1))
        #expect(try evaluate("null ? 1 : 2") == .number(2))
    }

    @Test func nullPropagationAndDivisionByZero() throws {
        #expect(try evaluate("missing + 1") == .null)
        #expect(try evaluate("1 / 0") == .null)
        #expect(try evaluate("1 % 0") == .null)
        #expect(try evaluate("missing < 2") == .null)
        #expect(try evaluate("missing == null") == .boolean(true))
        #expect(try evaluate("coalesce(missing, 3)") == .number(3))
        #expect(try evaluate("exists(missing)") == .boolean(false))
    }

    @Test func numericBuiltins() throws {
        #expect(try evaluate("min(3, 1, 2)") == .number(1))
        #expect(try evaluate("max(3, 1, 2)") == .number(3))
        #expect(try evaluate("clamp(150, 100, 140)") == .number(140))
        #expect(try evaluate("abs(-4)") == .number(4))
        #expect(try evaluate("round(2.6)") == .number(3))
        #expect(try evaluate("floor(2.9)") == .number(2))
        #expect(try evaluate("ceil(2.1)") == .number(3))
        #expect(try evaluate("lerp(10, 20, 0.25)") == .number(12.5))
        #expect(try evaluate("map(5, 0, 10, 0, 100)") == .number(50))
        #expect(try evaluate("map(20, 0, 10, 0, 100)") == .number(100))
    }

    @Test func listBuiltins() throws {
        let context = OverlayComponentEvaluationContext(
            bindings: ["values": .list([.number(1), .number(2), .number(3)])]
        )
        #expect(try evaluate("sum(values)", context: context) == .number(6))
        #expect(try evaluate("avg(values)", context: context) == .number(2))
        #expect(try evaluate("count(values)", context: context) == .number(3))
        #expect(try evaluate("first(values)", context: context) == .number(1))
        #expect(try evaluate("last(values)", context: context) == .number(3))
        #expect(try evaluate("at(values, 1)", context: context) == .number(2))
        #expect(try evaluate("values[1]", context: context) == .number(2))
    }

    @Test func memberAccessOnRecords() throws {
        let context = OverlayComponentEvaluationContext(
            bindings: [
                "zone": .record([
                    "index": .number(2),
                    "label": .string("Z2"),
                    "color": .color(OverlayColor(red: 0.2, green: 0.6, blue: 1, alpha: 1))
                ])
            ]
        )
        #expect(try evaluate("zone.index", context: context) == .number(2))
        #expect(try evaluate("zone.label", context: context) == .string("Z2"))
        #expect(try evaluate("zone.missing", context: context) == .null)
    }

    @Test func formatPatterns() throws {
        #expect(try evaluate("format(432, \"duration\")") == .string("7:12"))
        #expect(try evaluate("format(3661, \"duration\")") == .string("1:01:01"))
        #expect(try evaluate("format(272, \"pace\")") == .string("4:32"))
        #expect(try evaluate("format(148, \"integer\")") == .string("148"))
        #expect(try evaluate("format(4.567, \"decimal:2\")") == .string("4.57"))
        #expect(try evaluate("format(0.72, \"percent\")") == .string("72%"))
        #expect(try evaluate("format(-3, \"signed\")") == .string("-3"))
        #expect(try evaluate("format(12, \"signed\")") == .string("+12"))
        #expect(try evaluate("format(1500, \"distance:km\")") == .string("1.50"))
        #expect(try evaluate("format(null, \"integer\")") == .string("—"))
    }

    @Test func stringAndColorBuiltins() throws {
        #expect(try evaluate("concat(\"Z\", format(2, \"integer\"))") == .string("Z2"))
        #expect(try evaluate("upper(\"run\")") == .string("RUN"))
        #expect(try evaluate("lower(\"RUN\")") == .string("run"))
        #expect(try evaluate("slice(\"running\", 0, 3)") == .string("run"))

        let mixed = try evaluate("mix(\"#000000FF\", \"#FFFFFFFF\", 0.5)")
        let color = try #require(mixed.color)
        #expect(abs(color.red - 0.5) < 0.01)
        #expect(abs(color.alpha - 1) < 0.01)

        let faded = try evaluate("alpha(\"#FF0000FF\", 0.25)")
        let fadedColor = try #require(faded.color)
        #expect(abs(fadedColor.alpha - 0.25) < 0.01)
    }

    @Test func dataBuiltinsUseProvidedSurface() throws {
        let data = OverlayComponentStubData(
            signals: ["activity.heartRate": .number(152)],
            seriesValues: ["activity.heartRate": [.number(120), .number(140), .number(152)]]
        )
        let context = OverlayComponentEvaluationContext(data: data)
        #expect(try evaluate("signal(\"activity.heartRate\")", context: context) == .number(152))
        #expect(
            try evaluate("series(\"activity.heartRate\", 60, 3)", context: context)
                == .list([.number(120), .number(140), .number(152)])
        )
        #expect(try evaluate("signal(\"activity.power\")", context: context) == .null)
    }

    @Test func parametersBindingsAndLocalsResolveInOrder() throws {
        let context = OverlayComponentEvaluationContext(
            parameters: ["value": .number(1)],
            bindings: ["value": .number(2)],
            locals: ["value": .number(3)]
        )
        #expect(try evaluate("value", context: context) == .number(3))
        #expect(try evaluate("width + height", context: OverlayComponentEvaluationContext(componentSize: .init(width: 10, height: 5))) == .number(15))
        #expect(try evaluate("pi > 3", context: context) == .boolean(true))
    }

    @Test func rejectsUnparseableExpressions() {
        #expect(throws: OverlayComponentExpressionError.self) {
            _ = try OverlayComponentExpression.parse("1 +")
        }
        #expect(throws: OverlayComponentExpressionError.self) {
            _ = try OverlayComponentExpression.parse("\"unterminated")
        }
        #expect(throws: OverlayComponentExpressionError.self) {
            _ = try OverlayComponentExpression.parse("1 2")
        }
    }

    @Test func enforcesLengthAndDepthLimits() {
        let longExpression = String(repeating: "1+", count: 300) + "1"
        #expect(throws: OverlayComponentExpressionError.self) {
            _ = try OverlayComponentExpression.parse(longExpression)
        }

        let deepExpression = Array(repeating: "1", count: 40).joined(separator: "+")
        #expect(throws: OverlayComponentExpressionError.self) {
            _ = try OverlayComponentExpression.parse(deepExpression)
        }
    }
}

struct OverlayComponentStubData: OverlayComponentDataProviding {
    var signals: [String: OverlayComponentValue] = [:]
    var seriesValues: [String: [OverlayComponentValue]] = [:]
    var lists: [String: [OverlayComponentValue]] = [:]

    func signal(path: String) -> OverlayComponentValue {
        signals[path] ?? .null
    }

    func series(
        path: String,
        window: OverlayComponentSeriesWindow,
        samples: Int
    ) -> OverlayComponentValue {
        guard let values = seriesValues[path] else { return .null }
        var padded = values
        if padded.count > samples {
            padded = Array(padded.prefix(samples))
        }
        while padded.count < samples {
            padded.append(.null)
        }
        return .list(padded)
    }

    func list(path: String) -> OverlayComponentValue {
        lists[path].map(OverlayComponentValue.list) ?? .null
    }
}
