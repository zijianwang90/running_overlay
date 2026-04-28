import AppKit
import Foundation

enum OverlayIconRenderer {
    static func image(slot: OverlayIconSlot, size: CGSize, elapsedTime: TimeInterval, tintColor: NSColor) -> NSImage? {
        guard slot.hasEmbeddedSVG else {
            return nil
        }
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        draw(slot: slot, in: CGRect(origin: .zero, size: size), elapsedTime: elapsedTime, tintColor: tintColor)
        return image
    }

    static func draw(slot: OverlayIconSlot, in rect: CGRect, elapsedTime: TimeInterval, tintColor: NSColor) {
        guard slot.hasEmbeddedSVG else {
            return
        }
        let document = SimpleSVGDocument(source: slot.svgSource)
        guard !document.shapes.isEmpty else {
            return
        }

        let duration = max(document.animationDuration ?? slot.animationDuration, 0.05)
        let localTime = slot.loop
            ? (elapsedTime * max(slot.animationSpeed, 0.05)).truncatingRemainder(dividingBy: duration)
            : min(elapsedTime * max(slot.animationSpeed, 0.05), duration)
        let progress = localTime / duration
        let opacity = document.opacity(at: progress)
        let transform = document.transform(in: rect, progress: progress)

        NSGraphicsContext.current?.saveGraphicsState()
        transform.concat()
        for shape in document.shapes {
            draw(shape: shape, document: document, in: rect, tintColor: tintColor, opacity: opacity)
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private static func draw(shape: SimpleSVGShape, document: SimpleSVGDocument, in rect: CGRect, tintColor: NSColor, opacity: Double) {
        guard let path = shape.path(viewBox: document.viewBox, targetRect: rect) else {
            return
        }
        if let fill = shape.fillColor(tintColor: tintColor)?.withAlphaComponent(shape.opacity * opacity) {
            fill.setFill()
            path.fill()
        }
        if let stroke = shape.strokeColor(tintColor: tintColor)?.withAlphaComponent(shape.opacity * opacity) {
            stroke.setStroke()
            path.lineWidth = max(shape.strokeWidth * min(rect.width / document.viewBox.width, rect.height / document.viewBox.height), 0.8)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}

private struct SimpleSVGDocument {
    var viewBox: CGRect
    var shapes: [SimpleSVGShape]
    var animationDuration: Double?
    var rotateFrom: Double?
    var rotateTo: Double?
    var pulseOpacity = false

    init(source: String) {
        viewBox = Self.parseViewBox(source) ?? CGRect(x: 0, y: 0, width: 24, height: 24)
        shapes = Self.parseShapes(source)
        animationDuration = Self.parseDuration(source)
        let rotate = Self.parseRotateAnimation(source)
        rotateFrom = rotate?.from
        rotateTo = rotate?.to
        pulseOpacity = source.localizedCaseInsensitiveContains("attributeName=\"opacity\"")
            || source.localizedCaseInsensitiveContains("attributeName='opacity'")
    }

    func opacity(at progress: Double) -> Double {
        guard pulseOpacity else {
            return 1
        }
        return 0.55 + 0.45 * sin(progress * .pi)
    }

    func transform(in rect: CGRect, progress: Double) -> NSAffineTransform {
        let transform = NSAffineTransform()
        guard let rotateFrom, let rotateTo else {
            return transform
        }
        let angle = rotateFrom + (rotateTo - rotateFrom) * progress
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: CGFloat(angle))
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        return transform
    }

    private static func parseViewBox(_ source: String) -> CGRect? {
        guard let value = firstAttribute("viewBox", in: source) ?? firstAttribute("viewbox", in: source) else {
            return nil
        }
        let numbers = parseNumbers(value)
        guard numbers.count >= 4, numbers[2] > 0, numbers[3] > 0 else {
            return nil
        }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    private static func parseDuration(_ source: String) -> Double? {
        guard let value = firstAttribute("dur", in: source) else {
            return nil
        }
        if value.hasSuffix("ms") {
            return Double(value.dropLast(2)).map { $0 / 1000 }
        }
        if value.hasSuffix("s") {
            return Double(value.dropLast())
        }
        return Double(value)
    }

    private static func parseRotateAnimation(_ source: String) -> (from: Double, to: Double)? {
        guard source.localizedCaseInsensitiveContains("animateTransform"),
              source.localizedCaseInsensitiveContains("rotate") else {
            return nil
        }
        let from = firstAttribute("from", in: source).flatMap { parseNumbers($0).first } ?? 0
        let to = firstAttribute("to", in: source).flatMap { parseNumbers($0).first } ?? 360
        return (from, to)
    }

    private static func parseShapes(_ source: String) -> [SimpleSVGShape] {
        let pattern = #"<\s*(rect|circle|line|polyline|polygon|path)\b([^>]*)/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: source),
                  let attrRange = Range(match.range(at: 2), in: source) else {
                return nil
            }
            let tag = String(source[tagRange]).lowercased()
            let attributes = parseAttributes(String(source[attrRange]))
            return SimpleSVGShape(tag: tag, attributes: attributes)
        }
    }

    private static func parseAttributes(_ source: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*("[^"]*"|'[^']*')"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        var result: [String: String] = [:]
        for match in regex.matches(in: source, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: source),
                  let valueRange = Range(match.range(at: 2), in: source) else {
                continue
            }
            var value = String(source[valueRange])
            value.removeFirst()
            value.removeLast()
            result[String(source[keyRange]).lowercased()] = value
        }
        return result
    }

    private static func firstAttribute(_ name: String, in source: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*("[^"]*"|'[^']*')"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..<source.endIndex, in: source)),
              let range = Range(match.range(at: 1), in: source) else {
            return nil
        }
        var value = String(source[range])
        value.removeFirst()
        value.removeLast()
        return value
    }

    fileprivate static func parseNumbers(_ text: String) -> [Double] {
        let pattern = #"[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).flatMap { Double(text[$0]) }
        }
    }
}

private struct SimpleSVGShape {
    var tag: String
    var attributes: [String: String]

    var opacity: Double {
        Double(attributes["opacity"] ?? "") ?? 1
    }

    var strokeWidth: Double {
        Double(attributes["stroke-width"] ?? "") ?? 1.5
    }

    func fillColor(tintColor: NSColor) -> NSColor? {
        color(attributes["fill"], tintColor: tintColor, defaultColor: tag == "line" ? nil : tintColor)
    }

    func strokeColor(tintColor: NSColor) -> NSColor? {
        color(attributes["stroke"], tintColor: tintColor, defaultColor: tag == "line" ? tintColor : nil)
    }

    func path(viewBox: CGRect, targetRect: CGRect) -> NSBezierPath? {
        switch tag {
        case "rect":
            let x = number("x")
            let y = number("y")
            let width = number("width")
            let height = number("height")
            guard width > 0, height > 0 else { return nil }
            return transformed(NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: number("rx"), yRadius: number("ry")), viewBox: viewBox, targetRect: targetRect)
        case "circle":
            let r = number("r")
            guard r > 0 else { return nil }
            return transformed(NSBezierPath(ovalIn: CGRect(x: number("cx") - r, y: number("cy") - r, width: r * 2, height: r * 2)), viewBox: viewBox, targetRect: targetRect)
        case "line":
            let path = NSBezierPath()
            path.move(to: CGPoint(x: number("x1"), y: number("y1")))
            path.line(to: CGPoint(x: number("x2"), y: number("y2")))
            return transformed(path, viewBox: viewBox, targetRect: targetRect)
        case "polyline", "polygon":
            let numbers = SimpleSVGDocument.parseNumbers(attributes["points"] ?? "")
            guard numbers.count >= 4 else { return nil }
            let path = NSBezierPath()
            path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            var index = 2
            while index + 1 < numbers.count {
                path.line(to: CGPoint(x: numbers[index], y: numbers[index + 1]))
                index += 2
            }
            if tag == "polygon" { path.close() }
            return transformed(path, viewBox: viewBox, targetRect: targetRect)
        case "path":
            guard let d = attributes["d"], let path = parsePathData(d) else { return nil }
            return transformed(path, viewBox: viewBox, targetRect: targetRect)
        default:
            return nil
        }
    }

    private func number(_ key: String) -> Double {
        Double(attributes[key] ?? "") ?? 0
    }

    private func transformed(_ path: NSBezierPath, viewBox: CGRect, targetRect: CGRect) -> NSBezierPath {
        let scale = min(targetRect.width / viewBox.width, targetRect.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale
        var transform = AffineTransform()
        transform.translate(x: targetRect.minX + (targetRect.width - width) / 2, y: targetRect.minY + (targetRect.height - height) / 2)
        transform.scale(scale)
        transform.translate(x: -viewBox.minX, y: -viewBox.minY)
        let copy = path.copy() as? NSBezierPath ?? path
        copy.transform(using: transform)
        return copy
    }

    private func color(_ raw: String?, tintColor: NSColor, defaultColor: NSColor?) -> NSColor? {
        guard let raw, !raw.isEmpty else {
            return defaultColor
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "none" { return nil }
        if value == "currentcolor" { return tintColor }
        if value.hasPrefix("#") {
            return NSColor(hex: value)
        }
        return defaultColor
    }

    private func parsePathData(_ d: String) -> NSBezierPath? {
        let tokenPattern = #"[MmLlHhVvZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return nil }
        let matches = regex.matches(in: d, range: NSRange(d.startIndex..<d.endIndex, in: d))
        let tokens = matches.compactMap { Range($0.range, in: d).map { String(d[$0]) } }
        guard !tokens.isEmpty else { return nil }
        let path = NSBezierPath()
        var index = 0
        var command = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        func isCommand(_ token: String) -> Bool { token.range(of: #"^[A-Za-z]$"#, options: .regularExpression) != nil }
        func nextNumber() -> Double? {
            guard index < tokens.count, !isCommand(tokens[index]) else { return nil }
            defer { index += 1 }
            return Double(tokens[index])
        }
        while index < tokens.count {
            if isCommand(tokens[index]) {
                command = tokens[index]
                index += 1
            }
            switch command {
            case "M", "m":
                guard let x = nextNumber(), let y = nextNumber() else { return path }
                current = command == "m" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.move(to: current)
                start = current
                command = command == "m" ? "l" : "L"
            case "L", "l":
                guard let x = nextNumber(), let y = nextNumber() else { break }
                current = command == "l" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.line(to: current)
            case "H", "h":
                guard let x = nextNumber() else { break }
                current.x = command == "h" ? current.x + x : x
                path.line(to: current)
            case "V", "v":
                guard let y = nextNumber() else { break }
                current.y = command == "v" ? current.y + y : y
                path.line(to: current)
            case "Z", "z":
                path.close()
                current = start
            default:
                // Unsupported path commands are ignored rather than making
                // preview/export nondeterministic or failing the whole overlay.
                index += 1
            }
        }
        return path
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let text = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard text.count == 6, let value = Int(text, radix: 16) else {
            return nil
        }
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
