import SwiftUI

struct OverlayPoolView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var activeCategory: OverlayCategory = .metrics

    private let columns = [
        GridItem(.flexible(), spacing: EditorTheme.space2),
        GridItem(.flexible(), spacing: EditorTheme.space2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorPanelHeader(title: "Overlay Pool") {
                Text("Add overlays")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textMuted)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: EditorTheme.space3) {
                HStack {
                    Spacer()
                    Picker("", selection: $activeCategory) {
                        ForEach(OverlayCategory.allCases) { category in
                            Text(category.label)
                                .font(EditorTheme.bodyStrongFont)
                                .tag(category)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .tint(EditorTheme.accentBlue)
                    .frame(maxWidth: 392)
                    .frame(height: 24)
                    Spacer()
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                        ForEach(OverlayTileInfo.tiles(for: activeCategory)) { tile in
                            OverlayAddTile(tile: tile) {
                                project.addOverlayElement(tile.type)
                            }
                        }
                    }
                    .padding(.bottom, EditorTheme.space4)
                }
            }
            .padding(.horizontal, EditorTheme.panelPaddingX)
            .padding(.vertical, EditorTheme.space3)
        }
        .background(EditorTheme.panelBackground)
    }
}

enum OverlayCategory: String, CaseIterable, Identifiable {
    case metrics
    case charts
    case route

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metrics: "Metrics"
        case .charts: "Charts"
        case .route: "Route"
        }
    }
}

struct OverlayTileInfo: Identifiable {
    var type: OverlayElementType
    var hint: String
    var systemImage: String
    var category: OverlayCategory
    var isAccent = false

    var id: OverlayElementType { type }
    var label: String { type.label }

    static let all: [OverlayTileInfo] = [
        OverlayTileInfo(type: .heartRate, hint: "bpm", systemImage: "heart", category: .metrics),
        OverlayTileInfo(type: .pace, hint: "min/km", systemImage: "timer", category: .metrics),
        OverlayTileInfo(type: .calories, hint: "kcal", systemImage: "flame", category: .metrics),
        OverlayTileInfo(type: .elapsedTime, hint: "duration", systemImage: "clock", category: .metrics),
        OverlayTileInfo(type: .realTime, hint: "clock time", systemImage: "watch.analog", category: .metrics),
        OverlayTileInfo(type: .distance, hint: "km / mi", systemImage: "ruler", category: .metrics),
        OverlayTileInfo(type: .distanceTimeline, hint: "progress", systemImage: "waveform.path.ecg", category: .charts),
        OverlayTileInfo(type: .elevation, hint: "altitude", systemImage: "mountain.2", category: .metrics),
        OverlayTileInfo(type: .elevationChart, hint: "profile", systemImage: "chart.line.uptrend.xyaxis", category: .charts),
        OverlayTileInfo(type: .cadence, hint: "spm", systemImage: "figure.run", category: .metrics),
        OverlayTileInfo(type: .power, hint: "watts", systemImage: "bolt", category: .metrics),
        OverlayTileInfo(type: .verticalOscillation, hint: "cm", systemImage: "arrow.up.and.down", category: .metrics),
        OverlayTileInfo(type: .groundContactTime, hint: "ms", systemImage: "timer", category: .metrics),
        OverlayTileInfo(type: .strideLength, hint: "m", systemImage: "arrow.left.and.right", category: .metrics),
        OverlayTileInfo(type: .verticalRatio, hint: "%", systemImage: "percent", category: .metrics),
        OverlayTileInfo(type: .groundContactBalance, hint: "L/R", systemImage: "scale.3d", category: .metrics),
        OverlayTileInfo(type: .temperature, hint: "°C / °F", systemImage: "thermometer", category: .metrics),
        OverlayTileInfo(type: .grade, hint: "slope %", systemImage: "arrow.up.right", category: .metrics),
        OverlayTileInfo(type: .runningGauge, hint: "live gauge", systemImage: "gauge", category: .charts, isAccent: true),
        OverlayTileInfo(type: .routeMap, hint: "GPS path", systemImage: "map", category: .route, isAccent: true),
        OverlayTileInfo(type: .lapList, hint: "lap teleprompter", systemImage: "list.number", category: .charts, isAccent: true),
        OverlayTileInfo(type: .lapCard, hint: "lap recap card", systemImage: "rectangle.badge.checkmark", category: .charts, isAccent: true),
        OverlayTileInfo(type: .lapLive, hint: "live lap HUD", systemImage: "stopwatch", category: .charts, isAccent: true)
    ]

    static func tiles(for category: OverlayCategory) -> [OverlayTileInfo] {
        all.filter { $0.category == category }
    }
}

struct OverlayAddTile: View {
    let tile: OverlayTileInfo
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EditorTheme.space3) {
                Image(systemName: tile.systemImage)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(EditorTheme.textPrimary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.label)
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                        .lineLimit(1)
                    Text(tile.hint)
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: EditorTheme.space1)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(EditorTheme.textSecondary)
                    .frame(width: 18, alignment: .center)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(OverlayTileButtonStyle(isAccent: tile.isAccent))
        .help("Add \(tile.label)")
    }
}

private struct OverlayTileButtonStyle: ButtonStyle {
    var isAccent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? EditorTheme.surfacePressed : background)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(isAccent ? EditorTheme.borderStrong : EditorTheme.borderSubtle, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                if isAccent {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(EditorTheme.accentBlue)
                        .frame(width: 2)
                        .padding(.vertical, EditorTheme.space2)
                }
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var background: Color {
        EditorTheme.surfaceControl
    }
}
