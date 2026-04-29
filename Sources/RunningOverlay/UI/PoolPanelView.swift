import SwiftUI

struct PoolPanelView: View {
    @State private var activePool: PoolKind = .media

    var body: some View {
        VStack(spacing: 0) {
            PoolModeSwitch(activePool: $activePool)

            switch activePool {
            case .media:
                MediaBrowserView()
            case .overlay:
                OverlayPoolView()
            }
        }
        .background(EditorTheme.panelBackground)
    }
}

private enum PoolKind: String, CaseIterable, Identifiable {
    case media
    case overlay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .media: "Media Pool"
        case .overlay: "Overlay Pool"
        }
    }

    var systemImage: String {
        switch self {
        case .media: "filmstrip"
        case .overlay: "square.stack.3d.up"
        }
    }
}

private struct PoolModeSwitch: View {
    @Binding var activePool: PoolKind

    var body: some View {
        HStack(spacing: EditorTheme.space2) {
            ForEach(PoolKind.allCases) { pool in
                Button {
                    activePool = pool
                } label: {
                    Label(pool.label, systemImage: pool.systemImage)
                        .font(EditorTheme.bodyStrongFont)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PoolModeButtonStyle(isSelected: activePool == pool))
                .help(pool.label)
            }
        }
        .padding(.horizontal, EditorTheme.panelPaddingX)
        .padding(.vertical, 10)
        .background(EditorTheme.appChrome)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
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
