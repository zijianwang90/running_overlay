import SwiftUI

struct IntervalCountdownOverlayView: View {
    let element: OverlayElement
    let layout: IntervalCountdownRenderLayout

    var body: some View {
        ZStack {
            if element.style.backgroundEnabled {
                RoundedRectangle(cornerRadius: backgroundCornerRadius)
                    .fill(Color(intervalCountdown: element.style.backgroundColor).opacity(element.style.backgroundOpacity))
                    .frame(width: backgroundLocalRect.width, height: backgroundLocalRect.height)
                    .position(x: backgroundLocalRect.midX, y: backgroundLocalRect.midY)
                    .intervalCountdownShadow(element: element, layout: layout, isEnabled: true)

                if element.style.borderEnabled {
                    RoundedRectangle(cornerRadius: backgroundCornerRadius)
                        .stroke(
                            Color(intervalCountdown: element.style.borderColor).opacity(element.style.borderOpacity),
                            lineWidth: layout.borderWidth
                        )
                        .frame(width: backgroundLocalRect.width, height: backgroundLocalRect.height)
                        .position(x: backgroundLocalRect.midX, y: backgroundLocalRect.midY)
                }
            }

            foregroundContent
                .intervalCountdownGlobalGlow(element: element)
                .intervalCountdownShadow(element: element, layout: layout, isEnabled: !element.style.backgroundEnabled)
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var foregroundContent: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(intervalCountdown: layout.style.trackColor).opacity(layout.style.trackOpacity),
                    style: StrokeStyle(lineWidth: layout.ringWidth, lineCap: lineCap)
                )

            Circle()
                .trim(from: 0, to: layout.progress)
                .stroke(
                    Color(intervalCountdown: layout.ringColor),
                    style: StrokeStyle(lineWidth: layout.ringWidth, lineCap: lineCap)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: layout.style.resolvedRingDirection == .counterclockwise ? -1 : 1, y: 1)
                .intervalCountdownRingGlow(layout: layout)

            innerText
                .frame(width: layout.innerDiameter, height: layout.innerDiameter)
        }
        .padding(layout.ringWidth)
    }

    private var innerText: some View {
        VStack(spacing: max(2 * element.scale, 1)) {
            if let helper = item(.helper) {
                textView(helper)
                    .textCase(.uppercase)
            }

            if item(.phase) != nil || item(.rep) != nil {
                HStack(spacing: max(5 * element.scale, 2)) {
                    if let phase = item(.phase) {
                        textView(phase)
                            .textCase(.uppercase)
                    }
                    if let rep = item(.rep) {
                        textView(rep)
                    }
                }
            }

            if let countdown = item(.countdown) {
                textView(countdown)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.vertical, max(2 * element.scale, 1))
            }

            if let caption = item(.caption) {
                textView(caption)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var backgroundLocalRect: CGRect {
        CGRect(
            x: -layout.backgroundPaddingX,
            y: -layout.backgroundPaddingY,
            width: layout.rect.width + layout.backgroundPaddingX * 2,
            height: layout.rect.height + layout.backgroundPaddingY * 2
        )
    }

    private var backgroundCornerRadius: Double {
        min(max(layout.backgroundRadius, 0), min(backgroundLocalRect.width, backgroundLocalRect.height) / 2)
    }

    private var lineCap: CGLineCap {
        layout.style.roundedLineCap ? .round : .butt
    }

    private func item(_ role: IntervalCountdownTextRole) -> IntervalCountdownRenderLayout.TextItem? {
        layout.textItems.first { $0.role == role }
    }

    private func textView(_ item: IntervalCountdownRenderLayout.TextItem) -> some View {
        Text(item.text)
            .font(.overlayFont(
                family: item.style.fontName,
                size: item.fontSize,
                overlayWeight: item.style.fontWeight
            ))
            .foregroundStyle(Color(intervalCountdown: item.color))
            .lineLimit(1)
            .minimumScaleFactor(0.64)
    }
}

private extension Color {
    init(intervalCountdown color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

private extension View {
    func intervalCountdownRingGlow(layout: IntervalCountdownRenderLayout) -> some View {
        self
            .shadow(
                color: Color(intervalCountdown: layout.ringColor).opacity(layout.style.ringGlowEnabled ? layout.style.ringGlowIntensity * 0.70 : 0),
                radius: layout.style.ringGlowEnabled ? max(layout.style.ringGlowIntensity * 16, 0) : 0
            )
            .shadow(
                color: Color(intervalCountdown: layout.ringColor).opacity(layout.style.ringGlowEnabled ? layout.style.ringGlowIntensity * 0.35 : 0),
                radius: layout.style.ringGlowEnabled ? max(layout.style.ringGlowIntensity * 28, 0) : 0
            )
    }

    func intervalCountdownGlobalGlow(element: OverlayElement) -> some View {
        self
            .shadow(
                color: Color(intervalCountdown: element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.72 : 0),
                radius: element.style.glowEnabled ? max(element.style.glowIntensity * 18, 0) : 0
            )
            .shadow(
                color: Color(intervalCountdown: element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.35 : 0),
                radius: element.style.glowEnabled ? max(element.style.glowIntensity * 34, 0) : 0
            )
    }

    func intervalCountdownShadow(element: OverlayElement, layout: IntervalCountdownRenderLayout, isEnabled: Bool) -> some View {
        self
            .shadow(
                color: Color(intervalCountdown: element.style.shadowColor).opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity : 0),
                radius: layout.shadowRadius,
                x: layout.shadowOffsetX,
                y: layout.shadowOffsetY
            )
            .shadow(
                color: Color(intervalCountdown: element.style.shadowColor).opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity * max(element.style.shadowThickness - 1, 0) * 0.32 : 0),
                radius: layout.shadowRadius * 0.72,
                x: layout.shadowOffsetX,
                y: layout.shadowOffsetY
            )
            .shadow(
                color: Color(intervalCountdown: element.style.shadowColor).opacity(isEnabled && element.style.shadowEnabled ? element.style.shadowOpacity * max(element.style.shadowThickness - 2, 0) * 0.22 : 0),
                radius: layout.shadowRadius * 0.48,
                x: layout.shadowOffsetX,
                y: layout.shadowOffsetY
            )
    }
}
