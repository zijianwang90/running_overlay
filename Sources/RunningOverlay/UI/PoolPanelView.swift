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

    var toolbarLabel: String {
        switch self {
        case .media: "Media"
        case .overlay: "Overlays"
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
        Picker("Pool", selection: $activePool) {
            ForEach(PoolKind.allCases) { pool in
                Label(pool.toolbarLabel, systemImage: pool.systemImage)
                    .help(pool.label)
                    .tag(pool)
            }
        }
        .pickerStyle(.segmented)
        .labelStyle(.titleAndIcon)
        .labelsHidden()
    }
}
