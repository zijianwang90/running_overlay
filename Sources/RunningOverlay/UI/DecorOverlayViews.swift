import AppKit
import SwiftUI

// MARK: - Solid Color

/// Shared SwiftUI entry point for the Decor Solid Color element. Used by
/// `PreviewCanvasView` and `SwiftUIOverlayVideoExporter` so the live preview
/// and the exported MOV are pixel-identical.
struct OverlaySharedDecorSolidColorView: View {
    let element: OverlayElement
    let layout: DecorSolidColorRenderLayout

    var body: some View {
        DecorSolidColorOverlayView(element: element, layout: layout)
    }
}

/// Renders a filled `DecorShape` for the `decorSolidColor` element type.
/// Effects (shadow, glow, border) honor the same `OverlayStyle` fields used
/// by numeric overlays so the inspector's shared Effects / Border modules
/// "just work" without per-component re-implementation.
struct DecorSolidColorOverlayView: View {
    let element: OverlayElement
    let layout: DecorSolidColorRenderLayout

    var body: some View {
        let style = element.style
        let fill = Color(decor: layout.fillColor)
        ShapeFill(shape: layout.shape, cornerRadius: layout.cornerRadius)
            .foregroundStyle(fill)
            .frame(width: layout.size.width, height: layout.size.height)
            .overlay {
                if style.borderEnabled {
                    ShapeOutline(shape: layout.shape, cornerRadius: layout.cornerRadius)
                        .stroke(
                            Color(decor: style.borderColor).opacity(style.borderOpacity),
                            lineWidth: style.borderWidth
                        )
                }
            }
            // Glow drawn first so the shadow can sit on top of it.
            .shadow(
                color: Color(decor: style.glowColor)
                    .opacity(style.glowEnabled ? style.glowIntensity * 0.72 : 0),
                radius: style.glowEnabled ? max(style.glowIntensity * 18, 0) : 0
            )
            .shadow(
                color: Color(decor: style.glowColor)
                    .opacity(style.glowEnabled ? style.glowIntensity * 0.35 : 0),
                radius: style.glowEnabled ? max(style.glowIntensity * 34, 0) : 0
            )
            .shadow(
                color: Color(decor: style.shadowColor)
                    .opacity(style.shadowEnabled ? style.shadowOpacity : 0),
                radius: style.shadowEnabled ? style.shadowRadius : 0,
                x: style.shadowEnabled ? style.shadowOffsetX : 0,
                y: style.shadowEnabled ? style.shadowOffsetY : 0
            )
    }
}

/// Filled shape body. SwiftUI doesn't let `Shape` be returned polymorphically
/// from a switch without a wrapper, so this view dispatches at the top level.
private struct ShapeFill: View {
    let shape: DecorShape
    let cornerRadius: Double

    var body: some View {
        switch shape {
        case .rectangle:
            Rectangle()
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        case .circle:
            // Use Ellipse + a square frame elsewhere to render as a true
            // circle. Ellipse adapts to non-square bounds gracefully if the
            // user resizes outside the layout's collapse logic.
            Ellipse()
        case .capsule:
            Capsule()
        }
    }
}

/// Stroke-only outline matching `ShapeFill`. Used by the border overlay.
private struct ShapeOutline: Shape {
    let shape: DecorShape
    let cornerRadius: Double

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .rectangle:
            return Rectangle().path(in: rect)
        case .roundedRectangle:
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        case .circle:
            return Ellipse().path(in: rect)
        case .capsule:
            return Capsule().path(in: rect)
        }
    }
}

// MARK: - Icon

/// Shared SwiftUI entry point for the Decor Icon element. Used by
/// `PreviewCanvasView` and `SwiftUIOverlayVideoExporter` for pixel-identical
/// preview and export.
struct OverlaySharedDecorIconView: View {
    let element: OverlayElement
    let layout: DecorIconRenderLayout

    var body: some View {
        DecorIconOverlayView(element: element, layout: layout)
    }
}

/// Renders an `IconAsset` (SF Symbol, bundled SVG, user SVG, or Lottie)
/// inside the element's bounding box. Shadow, glow, and border are applied
/// via the same `OverlayStyle` fields used by numeric overlays.
struct DecorIconOverlayView: View {
    let element: OverlayElement
    let layout: DecorIconRenderLayout

    var body: some View {
        let style = element.style
        IconView(
            asset: layout.iconAsset,
            rect: CGRect(origin: .zero, size: layout.size),
            tint: NSColor(overlayColor: layout.iconTint),
            preserveSVGColors: layout.iconPreserveSVGColors,
            contentMode: layout.iconContentMode
        )
        .frame(width: layout.size.width, height: layout.size.height)
        .overlay {
            if style.borderEnabled {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        Color(decor: style.borderColor).opacity(style.borderOpacity),
                        lineWidth: style.borderWidth
                    )
            }
        }
        .shadow(
            color: Color(decor: style.glowColor)
                .opacity(style.glowEnabled ? style.glowIntensity * 0.72 : 0),
            radius: style.glowEnabled ? max(style.glowIntensity * 18, 0) : 0
        )
        .shadow(
            color: Color(decor: style.glowColor)
                .opacity(style.glowEnabled ? style.glowIntensity * 0.35 : 0),
            radius: style.glowEnabled ? max(style.glowIntensity * 34, 0) : 0
        )
        .shadow(
            color: Color(decor: style.shadowColor)
                .opacity(style.shadowEnabled ? style.shadowOpacity : 0),
            radius: style.shadowEnabled ? style.shadowRadius : 0,
            x: style.shadowEnabled ? style.shadowOffsetX : 0,
            y: style.shadowEnabled ? style.shadowOffsetY : 0
        )
    }
}

private extension Color {
    init(decor overlayColor: OverlayColor) {
        self.init(
            red: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            opacity: overlayColor.alpha
        )
    }
}

// MARK: - Text

/// Shared SwiftUI entry point for the Decor Text element.
struct OverlaySharedDecorTextView: View {
    let element: OverlayElement
    let layout: DecorTextRenderLayout

    var body: some View {
        DecorTextOverlayView(element: element, layout: layout)
    }
}

/// Renders free-form text with the configured font, size, alignment,
/// fill, stroke, and effects.
struct DecorTextOverlayView: View {
    let element: OverlayElement
    let layout: DecorTextRenderLayout

    var body: some View {
        let style = element.style
        ZStack {
            // Stroke layer (drawn behind the fill)
            if layout.strokeWidth > 0 {
                Text(layout.content)
                    .font(resolvedFont)
                    .multilineTextAlignment(textAlignment)
                    .lineSpacing((layout.lineHeight - 1) * layout.fontSize)
                    .tracking(layout.letterSpacing / layout.fontSize)
                    .foregroundStyle(Color(decor: layout.strokeColor))
                    .scaleEffect(x: 1 + layout.strokeWidth / layout.fontSize * 0.5,
                                 y: 1 + layout.strokeWidth / layout.fontSize * 0.5)
            }
            // Fill layer
            Text(layout.content)
                .font(resolvedFont)
                .multilineTextAlignment(textAlignment)
                .lineSpacing((layout.lineHeight - 1) * layout.fontSize)
                .tracking(layout.letterSpacing / layout.fontSize)
                .foregroundColor(textFillColor)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .clipped()
        .overlay {
            if style.borderEnabled {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        Color(decor: style.borderColor).opacity(style.borderOpacity),
                        lineWidth: style.borderWidth
                    )
            }
        }
        .shadow(
            color: Color(decor: style.glowColor)
                .opacity(style.glowEnabled ? style.glowIntensity * 0.72 : 0),
            radius: style.glowEnabled ? max(style.glowIntensity * 18, 0) : 0
        )
        .shadow(
            color: Color(decor: style.shadowColor)
                .opacity(style.shadowEnabled ? style.shadowOpacity : 0),
            radius: style.shadowEnabled ? style.shadowRadius : 0,
            x: style.shadowEnabled ? style.shadowOffsetX : 0,
            y: style.shadowEnabled ? style.shadowOffsetY : 0
        )
    }

    private var resolvedFont: Font {
        switch layout.font {
        case .bundled(let name):
            return .custom(name, fixedSize: layout.fontSize)
        case .system(let family):
            return .custom(family, fixedSize: layout.fontSize)
        case .userAsset:
            return .system(size: layout.fontSize)
        }
    }

    private var textAlignment: SwiftUI.TextAlignment {
        switch layout.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var textFillColor: Color {
        switch layout.fillMode {
        case .solid(let color):
            return Color(decor: color)
        case .gradient:
            return .white // Phase F6
        }
    }
}

private extension NSColor {
    convenience init(overlayColor: OverlayColor) {
        self.init(
            red: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            alpha: overlayColor.alpha
        )
    }
}
