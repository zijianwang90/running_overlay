import SwiftUI

struct PoolPanelView: View {
    @Binding var activePool: PoolKind

    var body: some View {
        Group {
            switch activePool {
            case .media:
                MediaBrowserView()
            case .overlay:
                OverlayPoolView()
            case .templates:
                TemplatePoolView()
            }
        }
        .background(EditorTheme.panelBackground)
    }
}

enum PoolKind: String, CaseIterable, Identifiable {
    case media
    case overlay
    case templates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .media: "Media Pool"
        case .overlay: "Overlay Pool"
        case .templates: "Templates"
        }
    }

    var systemImage: String {
        switch self {
        case .media: "play.rectangle"
        case .overlay: "square.stack.3d.up"
        case .templates: "rectangle.stack"
        }
    }
}

struct PoolModeSwitch: View {
    @Binding var activePool: PoolKind

    var body: some View {
        HStack(spacing: EditorTheme.space2) {
            ForEach(PoolKind.allCases) { pool in
                Button {
                    activePool = pool
                } label: {
                    Label(pool.label, systemImage: pool.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(EditorTheme.bodyStrongFont)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PoolModeButtonStyle(isSelected: activePool == pool))
                .help(pool.label)
            }
        }
    }
}

private struct PoolModeButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.white : EditorTheme.textSecondary)
            .padding(.horizontal, EditorTheme.space2)
            .frame(height: 32)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? EditorTheme.accentBlue : EditorTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed {
            return EditorTheme.surfacePressed
        }
        return isSelected ? EditorTheme.accentBlue : EditorTheme.surfaceControl
    }
}
