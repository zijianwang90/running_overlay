import SwiftUI

struct OverlayFeatheredBackground: View {
    var isSelected: Bool
    var backgroundEnabled: Bool
    var color: Color
    var opacity: Double
    var cornerRadius: Double
    var usesCapsuleRadius = false
    var fadeEnabled: Bool
    var fadeAmount: Double
    var blurRadius: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let resolvedCornerRadius = usesCapsuleRadius
                ? min(size.width, size.height) * 0.5
                : cornerRadius
            let shape = RoundedRectangle(cornerRadius: resolvedCornerRadius)

            ZStack {
                if isSelected {
                    shape.fill(Color.accentColor.opacity(0.45))
                } else if backgroundEnabled {
                    if blurRadius > 0.01 {
                        shape
                            .fill(.ultraThinMaterial)
                            .opacity(min(max(blurRadius / 24, 0), 1))
                    }
                    shape.fill(color.opacity(opacity))
                }
            }
            .mask {
                if backgroundEnabled,
                   !isSelected,
                   fadeEnabled,
                   fadeAmount > 0.001,
                   size.width > 1,
                   size.height > 1,
                   let mask = OverlayFeatherMaskRenderer.makeNSImage(
                       size: size,
                       cornerRadius: resolvedCornerRadius,
                       fadeAmount: fadeAmount
                   ) {
                    Image(nsImage: mask)
                        .resizable()
                        .interpolation(.high)
                        .luminanceToAlpha()
                } else {
                    shape.fill(Color.white)
                }
            }
        }
    }
}
