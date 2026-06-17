import AppKit
import CoreGraphics
import Foundation

enum OverlayFeatherMaskRenderer {
    static let maxFadeAmount = 0.85

    static func makeCGMask(size: CGSize, cornerRadius: Double, fadeAmount: Double) -> CGImage? {
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)
        let clampedFadeAmount = min(max(fadeAmount, 0), maxFadeAmount)
        let minDimension = min(Double(width), Double(height))
        let fadeWidth = max(minDimension * 0.5 * clampedFadeAmount, 0)
        let radius = min(max(cornerRadius, 0), minDimension * 0.5)
        let innerInset = min(fadeWidth, max(minDimension * 0.5 - 0.5, 0))
        let innerWidth = max(Double(width) - innerInset * 2, 0.001)
        let innerHeight = max(Double(height) - innerInset * 2, 0.001)
        let innerRadius = min(radius, min(innerWidth, innerHeight) * 0.5)

        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let outerDistance = roundedRectSignedDistance(
                    point: point,
                    size: CGSize(width: width, height: height),
                    cornerRadius: radius
                )

                let alpha: Double
                if outerDistance > 0 {
                    alpha = 0
                } else if innerInset <= 0.001 {
                    alpha = 1
                } else {
                    let innerPoint = CGPoint(x: point.x - innerInset, y: point.y - innerInset)
                    let innerDistance = roundedRectSignedDistance(
                        point: innerPoint,
                        size: CGSize(width: innerWidth, height: innerHeight),
                        cornerRadius: innerRadius
                    )
                    if innerDistance <= 0 {
                        alpha = 1
                    } else {
                        let denominator = max(-outerDistance + innerDistance, 0.001)
                        alpha = smoothstep(min(max(-outerDistance / denominator, 0), 1))
                    }
                }
                pixels[y * width + x] = UInt8((alpha * 255).rounded())
            }
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    static func makeNSImage(size: CGSize, cornerRadius: Double, fadeAmount: Double) -> NSImage? {
        guard let cgMask = makeCGMask(size: size, cornerRadius: cornerRadius, fadeAmount: fadeAmount) else {
            return nil
        }
        return NSImage(cgImage: cgMask, size: size)
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func roundedRectSignedDistance(point: CGPoint, size: CGSize, cornerRadius: Double) -> Double {
        let halfWidth = Double(size.width) * 0.5
        let halfHeight = Double(size.height) * 0.5
        let radius = min(max(cornerRadius, 0), min(halfWidth, halfHeight))
        let px = Double(point.x) - halfWidth
        let py = Double(point.y) - halfHeight
        let qx = abs(px) - max(halfWidth - radius, 0)
        let qy = abs(py) - max(halfHeight - radius, 0)
        let outsideDistance = hypot(max(qx, 0), max(qy, 0))
        let insideDistance = min(max(qx, qy), 0)
        return outsideDistance + insideDistance - radius
    }
}
