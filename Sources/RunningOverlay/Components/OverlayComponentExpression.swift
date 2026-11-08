import Foundation

/// Read-only data surface exposed to a component at one playhead time.
protocol OverlayComponentDataProviding {
    func signal(path: String) -> OverlayComponentValue
    func series(path: String, window: OverlayComponentSeriesWindow, samples: Int) -> OverlayComponentValue
    func list(path: String) -> OverlayComponentValue
    /// Host-formatted metric record; see `OverlayComponentMetricCatalog`.
    /// `units` are candidates in order; the first one the metric supports wins.
    func metric(id: String, units: [String]) -> OverlayComponentValue
}

extension OverlayComponentDataProviding {
    func metric(id: String, units: [String]) -> OverlayComponentValue { .null }
}

enum OverlayComponentSeriesWindow: Equatable {
    case full
    case relative(start: Double, end: Double)
}

struct OverlayComponentEvaluationContext {
    var parameters: [String: OverlayComponentValue] = [:]
    var bindings: [String: OverlayComponentValue] = [:]
    var locals: [String: OverlayComponentValue] = [:]
    var data: (any OverlayComponentDataProviding)?
    var componentSize: OverlayComponentSize = .zero
    var diagnose: ((String) -> Void)?

    func value(for identifier: String) -> OverlayComponentValue {
        if let local = locals[identifier] { return local }
        if let binding = bindings[identifier] { return binding }
        if let parameter = parameters[identifier] { return parameter }
        switch identifier {
        case "width": return .number(componentSize.width)
        case "height": return .number(componentSize.height)
        case "pi": return .number(.pi)
        default: return .null
        }
    }
}

indirect enum OverlayComponentExpression: Equatable {
    case literal(OverlayComponentValue)
    case variable(String)
    case member(OverlayComponentExpression, String)
    case index(OverlayComponentExpression, OverlayComponentExpression)
    case unary(String, OverlayComponentExpression)
    case binary(String, OverlayComponentExpression, OverlayComponentExpression)
    case conditional(OverlayComponentExpression, OverlayComponentExpression, OverlayComponentExpression)
    case call(String, [OverlayComponentExpression])

    static let maximumLength = 512
    static let maximumDepth = 32
    static let maximumNodes = 256

    static func parse(_ source: String) throws -> OverlayComponentExpression {
        guard source.count <= maximumLength else {
            throw OverlayComponentExpressionError("expression exceeds \(maximumLength) characters")
        }
        var lexer = OverlayComponentLexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = OverlayComponentExpressionParser(tokens: tokens)
        let expression = try parser.parse()
        guard expression.depth <= maximumDepth else {
            throw OverlayComponentExpressionError("expression exceeds depth \(maximumDepth)")
        }
        guard expression.nodeCount <= maximumNodes else {
            throw OverlayComponentExpressionError("expression exceeds \(maximumNodes) nodes")
        }
        return expression
    }

    func evaluate(in context: OverlayComponentEvaluationContext) -> OverlayComponentValue {
        switch self {
        case .literal(let value):
            return value
        case .variable(let name):
            return context.value(for: name)
        case .member(let base, let name):
            return base.evaluate(in: context).record?[name] ?? .null
        case .index(let base, let index):
            guard let list = base.evaluate(in: context).list else { return .null }
            guard let position = index.evaluate(in: context).number.map({ Int($0) }),
                  position >= 0, position < list.count else {
                return .null
            }
            return list[position]
        case .unary(let op, let operand):
            let value = operand.evaluate(in: context)
            switch op {
            case "!":
                return .boolean(!value.isTruthy)
            case "-":
                return value.number.map { .number(-$0) } ?? .null
            default:
                return .null
            }
        case .binary(let op, let left, let right):
            return Self.evaluateBinary(op, left, right, context)
        case .conditional(let condition, let whenTrue, let whenFalse):
            return condition.evaluate(in: context).isTruthy
                ? whenTrue.evaluate(in: context)
                : whenFalse.evaluate(in: context)
        case .call(let name, let arguments):
            return Self.evaluateCall(name, arguments, context)
        }
    }

    var depth: Int {
        switch self {
        case .literal, .variable:
            return 1
        case .member(let base, _):
            return 1 + base.depth
        case .index(let base, let index):
            return 1 + max(base.depth, index.depth)
        case .unary(_, let operand):
            return 1 + operand.depth
        case .binary(_, let left, let right):
            return 1 + max(left.depth, right.depth)
        case .conditional(let condition, let whenTrue, let whenFalse):
            return 1 + max(condition.depth, max(whenTrue.depth, whenFalse.depth))
        case .call(_, let arguments):
            return 1 + (arguments.map(\.depth).max() ?? 0)
        }
    }

    var nodeCount: Int {
        switch self {
        case .literal, .variable:
            return 1
        case .member(let base, _):
            return 1 + base.nodeCount
        case .index(let base, let index):
            return 1 + base.nodeCount + index.nodeCount
        case .unary(_, let operand):
            return 1 + operand.nodeCount
        case .binary(_, let left, let right):
            return 1 + left.nodeCount + right.nodeCount
        case .conditional(let condition, let whenTrue, let whenFalse):
            return 1 + condition.nodeCount + whenTrue.nodeCount + whenFalse.nodeCount
        case .call(_, let arguments):
            return 1 + arguments.reduce(0) { $0 + $1.nodeCount }
        }
    }

    /// Identifier names referenced by the expression, excluding builtins.
    var referencedIdentifiers: Set<String> {
        switch self {
        case .literal:
            return []
        case .variable(let name):
            return [name]
        case .member(let base, _):
            return base.referencedIdentifiers
        case .index(let base, let index):
            return base.referencedIdentifiers.union(index.referencedIdentifiers)
        case .unary(_, let operand):
            return operand.referencedIdentifiers
        case .binary(_, let left, let right):
            return left.referencedIdentifiers.union(right.referencedIdentifiers)
        case .conditional(let condition, let whenTrue, let whenFalse):
            return condition.referencedIdentifiers
                .union(whenTrue.referencedIdentifiers)
                .union(whenFalse.referencedIdentifiers)
        case .call(_, let arguments):
            return arguments.reduce(into: Set<String>()) { $0.formUnion($1.referencedIdentifiers) }
        }
    }

    private static func evaluateBinary(
        _ op: String,
        _ left: OverlayComponentExpression,
        _ right: OverlayComponentExpression,
        _ context: OverlayComponentEvaluationContext
    ) -> OverlayComponentValue {
        if op == "&&" {
            let leftValue = left.evaluate(in: context)
            return .boolean(leftValue.isTruthy && right.evaluate(in: context).isTruthy)
        }
        if op == "||" {
            let leftValue = left.evaluate(in: context)
            return .boolean(leftValue.isTruthy || right.evaluate(in: context).isTruthy)
        }

        let leftValue = left.evaluate(in: context)
        let rightValue = right.evaluate(in: context)

        if op == "==" { return .boolean(leftValue == rightValue) }
        if op == "!=" { return .boolean(leftValue != rightValue) }

        switch (leftValue, rightValue) {
        case (.number(let a), .number(let b)):
            let result: Double?
            switch op {
            case "+": result = a + b
            case "-": result = a - b
            case "*": result = a * b
            case "/": result = b == 0 ? nil : a / b
            case "%": result = b == 0 ? nil : a.truncatingRemainder(dividingBy: b)
            case "<": return .boolean(a < b)
            case "<=": return .boolean(a <= b)
            case ">": return .boolean(a > b)
            case ">=": return .boolean(a >= b)
            default: result = nil
            }
            guard let result, result.isFinite else { return .null }
            return .number(result)
        case (.string(let a), .string(let b)):
            switch op {
            case "<": return .boolean(a < b)
            case "<=": return .boolean(a <= b)
            case ">": return .boolean(a > b)
            case ">=": return .boolean(a >= b)
            default: return .null
            }
        default:
            return .null
        }
    }

    private static func evaluateCall(
        _ name: String,
        _ arguments: [OverlayComponentExpression],
        _ context: OverlayComponentEvaluationContext
    ) -> OverlayComponentValue {
        func value(_ index: Int) -> OverlayComponentValue {
            arguments.indices.contains(index) ? arguments[index].evaluate(in: context) : .null
        }

        switch name {
        case "min", "max":
            let numbers = arguments.compactMap { $0.evaluate(in: context).number }
            guard let first = numbers.first else { return .null }
            return .number(numbers.reduce(first) { name == "min" ? Swift.min($0, $1) : Swift.max($0, $1) })

        case "clamp":
            guard let x = value(0).number, let lo = value(1).number, let hi = value(2).number else {
                return .null
            }
            return .number(Swift.min(Swift.max(x, lo), hi))

        case "abs":
            return value(0).number.map { .number(Swift.abs($0)) } ?? .null

        case "round":
            return value(0).number.map { .number($0.rounded()) } ?? .null

        case "floor":
            return value(0).number.map { .number($0.rounded(.down)) } ?? .null

        case "ceil":
            return value(0).number.map { .number($0.rounded(.up)) } ?? .null

        case "lerp":
            guard let a = value(0).number, let b = value(1).number, let t = value(2).number else {
                return .null
            }
            let clamped = Swift.min(Swift.max(t, 0), 1)
            return .number(a + (b - a) * clamped)

        case "map":
            guard let x = value(0).number,
                  let inLo = value(1).number, let inHi = value(2).number,
                  let outLo = value(3).number, let outHi = value(4).number,
                  inHi != inLo else {
                return .null
            }
            let progress = Swift.min(Swift.max((x - inLo) / (inHi - inLo), 0), 1)
            return .number(outLo + (outHi - outLo) * progress)

        case "sum", "avg":
            let numbers = value(0).list?.compactMap(\.number) ?? []
            guard !numbers.isEmpty else { return .null }
            let total = numbers.reduce(0, +)
            return .number(name == "sum" ? total : total / Double(numbers.count))

        case "count":
            return value(0).list.map { .number(Double($0.count)) } ?? .null

        case "first":
            return value(0).list?.first ?? .null

        case "last":
            return value(0).list?.last ?? .null

        case "at":
            guard let list = value(0).list,
                  let index = value(1).number.map({ Int($0) }),
                  index >= 0, index < list.count else {
                return .null
            }
            return list[index]

        case "coalesce":
            for argument in arguments {
                let result = argument.evaluate(in: context)
                if result != .null { return result }
            }
            return .null

        case "exists":
            return .boolean(value(0) != .null)

        case "format":
            let subject = value(0)
            let pattern = value(1).string ?? "plain"
            return .string(format(subject, pattern: pattern))

        case "concat":
            return .string(arguments.map { $0.evaluate(in: context).displayString }.joined())

        case "upper":
            return value(0).string.map { .string($0.uppercased()) } ?? .null

        case "lower":
            return value(0).string.map { .string($0.lowercased()) } ?? .null

        case "slice":
            guard let source = value(0).string,
                  let start = value(1).number.map({ Int($0) }),
                  let length = value(2).number.map({ Int($0) }) else {
                return .null
            }
            let characters = Array(source)
            let lower = Swift.min(Swift.max(start, 0), characters.count)
            let upper = Swift.min(Swift.max(lower + length, lower), characters.count)
            return .string(String(characters[lower..<upper]))

        case "mix":
            guard let a = value(0).color, let b = value(1).color, let t = value(2).number else {
                return .null
            }
            let clamped = Swift.min(Swift.max(t, 0), 1)
            return .color(OverlayColor(
                red: a.red + (b.red - a.red) * clamped,
                green: a.green + (b.green - a.green) * clamped,
                blue: a.blue + (b.blue - a.blue) * clamped,
                alpha: a.alpha + (b.alpha - a.alpha) * clamped
            ))

        case "alpha":
            guard let color = value(0).color, let alpha = value(1).number else { return .null }
            return .color(OverlayColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: Swift.min(Swift.max(alpha, 0), 1)
            ))

        case "signal":
            guard let path = value(0).string else { return .null }
            return context.data?.signal(path: path) ?? .null

        case "metric":
            guard let id = value(0).string else { return .null }
            let units = arguments.indices.dropFirst().compactMap { value($0).string }
            return context.data?.metric(id: id, units: units) ?? .null

        case "series":
            guard let path = value(0).string,
                  let window = value(1).number,
                  let samples = value(2).number.map({ Int($0) }) else {
                return .null
            }
            return context.data?.series(
                path: path,
                window: .relative(start: -Swift.abs(window), end: 0),
                samples: Swift.min(Swift.max(samples, 2), 1024)
            ) ?? .null

        default:
            return .null
        }
    }

    private static func format(_ value: OverlayComponentValue, pattern: String) -> String {
        if value == .null { return OverlayComponentValue.placeholder }
        if pattern == "plain" { return value.displayString }
        guard let number = value.number else { return value.displayString }

        let parts = pattern.split(separator: ":", maxSplits: 1).map(String.init)
        let name = parts[0]
        let argument = parts.count > 1 ? Int(parts[1]) : nil

        switch name {
        case "integer":
            return String(Int(number.rounded()))
        case "decimal":
            return OverlayComponentNumberFormatter.decimal(number, places: argument ?? 1)
        case "duration":
            return OverlayComponentNumberFormatter.duration(number)
        case "pace":
            return OverlayComponentNumberFormatter.pace(number)
        case "clock":
            return OverlayComponentNumberFormatter.clock(number)
        case "percent":
            return OverlayComponentNumberFormatter.decimal(number * 100, places: argument ?? 0) + "%"
        case "signed":
            let text = OverlayComponentNumberFormatter.plain(Swift.abs(number))
            return number < 0 ? "-" + text : "+" + text
        case "distance":
            let unit = parts.count > 1 ? parts[1] : "km"
            switch unit {
            case "mi":
                return OverlayComponentNumberFormatter.decimal(number / PaceUnit.metersPerMile, places: 2)
            default:
                return OverlayComponentNumberFormatter.decimal(number / 1000, places: 2)
            }
        default:
            return value.displayString
        }
    }
}

struct OverlayComponentExpressionError: Error, Equatable, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

private enum OverlayComponentToken: Equatable {
    case number(Double)
    case string(String)
    case identifier(String)
    case symbol(String)
    case end
}

private struct OverlayComponentLexer {
    let source: String
    private var characters: [Character] = []
    private var index = 0

    init(source: String) {
        self.source = source
        self.characters = Array(source)
    }

    mutating func tokenize() throws -> [OverlayComponentToken] {
        var tokens: [OverlayComponentToken] = []
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
                continue
            }
            if character.isNumber || (character == "." && peek(1)?.isNumber == true) {
                tokens.append(try readNumber())
                continue
            }
            if character == "\"" {
                tokens.append(try readString())
                continue
            }
            if character.isLetter || character == "_" {
                tokens.append(readIdentifier())
                continue
            }
            if let symbol = readSymbol() {
                tokens.append(symbol)
                continue
            }
            throw OverlayComponentExpressionError("unexpected character '\(character)'")
        }
        tokens.append(.end)
        return tokens
    }

    private func peek(_ offset: Int) -> Character? {
        let position = index + offset
        return position < characters.count ? characters[position] : nil
    }

    private mutating func readNumber() throws -> OverlayComponentToken {
        let start = index
        var sawDot = false
        while index < characters.count {
            let character = characters[index]
            if character.isNumber {
                index += 1
            } else if character == ".", !sawDot {
                sawDot = true
                index += 1
            } else if character == "e" || character == "E" {
                index += 1
                if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                    index += 1
                }
            } else {
                break
            }
        }
        let text = String(characters[start..<index])
        guard let value = Double(text) else {
            throw OverlayComponentExpressionError("invalid number '\(text)'")
        }
        return .number(value)
    }

    private mutating func readString() throws -> OverlayComponentToken {
        index += 1
        var result = ""
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                index += 1
                return .string(result)
            }
            if character == "\\" {
                index += 1
                guard index < characters.count else { break }
                let escaped = characters[index]
                switch escaped {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(escaped)
                }
                index += 1
                continue
            }
            result.append(character)
            index += 1
        }
        throw OverlayComponentExpressionError("unterminated string")
    }

    private mutating func readIdentifier() -> OverlayComponentToken {
        let start = index
        while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" {
            index += 1
        }
        return .identifier(String(characters[start..<index]))
    }

    private mutating func readSymbol() -> OverlayComponentToken? {
        let twoCharacterSymbols = ["==", "!=", "<=", ">=", "&&", "||"]
        if index + 1 < characters.count {
            let pair = String(characters[index...index + 1])
            if twoCharacterSymbols.contains(pair) {
                index += 2
                return .symbol(pair)
            }
        }
        let single = String(characters[index])
        if "+-*/%!<>?:()[].,".contains(single) {
            index += 1
            return .symbol(single)
        }
        return nil
    }
}

private struct OverlayComponentExpressionParser {
    let tokens: [OverlayComponentToken]
    private var index = 0

    init(tokens: [OverlayComponentToken]) {
        self.tokens = tokens
    }

    mutating func parse() throws -> OverlayComponentExpression {
        let expression = try parseConditional()
        guard case .end = current else {
            throw OverlayComponentExpressionError("unexpected token after expression")
        }
        return expression
    }

    private var current: OverlayComponentToken {
        tokens.indices.contains(index) ? tokens[index] : .end
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func match(_ symbols: String...) -> String? {
        guard case .symbol(let symbol) = current, symbols.contains(symbol) else { return nil }
        advance()
        return symbol
    }

    private mutating func parseConditional() throws -> OverlayComponentExpression {
        let condition = try parseOr()
        guard match("?") != nil else { return condition }
        let whenTrue = try parseConditional()
        guard match(":") != nil else {
            throw OverlayComponentExpressionError("expected ':' in conditional")
        }
        let whenFalse = try parseConditional()
        return .conditional(condition, whenTrue, whenFalse)
    }

    private mutating func parseOr() throws -> OverlayComponentExpression {
        var expression = try parseAnd()
        while match("||") != nil {
            expression = .binary("||", expression, try parseAnd())
        }
        return expression
    }

    private mutating func parseAnd() throws -> OverlayComponentExpression {
        var expression = try parseEquality()
        while match("&&") != nil {
            expression = .binary("&&", expression, try parseEquality())
        }
        return expression
    }

    private mutating func parseEquality() throws -> OverlayComponentExpression {
        var expression = try parseComparison()
        while let op = match("==", "!=") {
            expression = .binary(op, expression, try parseComparison())
        }
        return expression
    }

    private mutating func parseComparison() throws -> OverlayComponentExpression {
        var expression = try parseAdditive()
        while let op = match("<", "<=", ">", ">=") {
            expression = .binary(op, expression, try parseAdditive())
        }
        return expression
    }

    private mutating func parseAdditive() throws -> OverlayComponentExpression {
        var expression = try parseMultiplicative()
        while let op = match("+", "-") {
            expression = .binary(op, expression, try parseMultiplicative())
        }
        return expression
    }

    private mutating func parseMultiplicative() throws -> OverlayComponentExpression {
        var expression = try parseUnary()
        while let op = match("*", "/", "%") {
            expression = .binary(op, expression, try parseUnary())
        }
        return expression
    }

    private mutating func parseUnary() throws -> OverlayComponentExpression {
        if let op = match("!", "-") {
            return .unary(op, try parseUnary())
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> OverlayComponentExpression {
        var expression = try parsePrimary()
        while true {
            if match(".") != nil {
                guard case .identifier(let name) = current else {
                    throw OverlayComponentExpressionError("expected member name after '.'")
                }
                advance()
                expression = .member(expression, name)
            } else if match("[") != nil {
                let subscriptExpression = try parseConditional()
                guard match("]") != nil else {
                    throw OverlayComponentExpressionError("expected ']'")
                }
                expression = .index(expression, subscriptExpression)
            } else {
                return expression
            }
        }
    }

    private mutating func parsePrimary() throws -> OverlayComponentExpression {
        switch current {
        case .number(let value):
            advance()
            return .literal(.number(value))
        case .string(let value):
            advance()
            return .literal(.string(value))
        case .identifier(let name):
            advance()
            if match("(") != nil {
                var arguments: [OverlayComponentExpression] = []
                if match(")") == nil {
                    repeat {
                        arguments.append(try parseConditional())
                    } while match(",") != nil
                    guard match(")") != nil else {
                        throw OverlayComponentExpressionError("expected ')' in call to \(name)")
                    }
                }
                return .call(name, arguments)
            }
            switch name {
            case "true": return .literal(.boolean(true))
            case "false": return .literal(.boolean(false))
            case "null": return .literal(.null)
            default: return .variable(name)
            }
        case .symbol("("):
            advance()
            let expression = try parseConditional()
            guard match(")") != nil else {
                throw OverlayComponentExpressionError("expected ')'")
            }
            return expression
        default:
            throw OverlayComponentExpressionError("unexpected end of expression")
        }
    }
}
