import SwiftUI
import UniformTypeIdentifiers

struct OverlayPoolView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var activeCategory: OverlayCategory = .metrics
    @State private var importErrorMessage: String?

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
                        ForEach(OverlayCategory.allCases.filter { $0 != .decor }) { category in
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

                if activeCategory == .components {
                    HStack {
                        Button {
                            importComponent()
                        } label: {
                            Label("Import Component…", systemImage: "square.and.arrow.down")
                                .font(EditorTheme.captionFont)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EditorTheme.textSecondary)
                        .help("Import a .rocomponent package or component JSON file")
                        Spacer()
                    }
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                        if activeCategory == .components {
                            ForEach(OverlayComponentLibraryItem.all) { item in
                                OverlayComponentAddTile(item: item) {
                                    project.addComponentFromLibrary(item)
                                }
                            }
                        } else {
                            ForEach(OverlayTileInfo.tiles(for: activeCategory)) { tile in
                                OverlayAddTile(tile: tile) {
                                    project.addOverlayElement(tile.type)
                                }
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
        .alert(
            "Component Import Failed",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private func importComponent() {
        let panel = NSOpenPanel()
        panel.title = "Import Component"
        panel.prompt = "Import"
        panel.message = "Choose a .rocomponent package folder or a component JSON file."
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            _ = try SecurityScopedURLAccess.withAccess(to: url) {
                try project.importComponentPackage(at: url)
            }
        } catch let error as OverlayComponentValidationError {
            importErrorMessage = error.diagnostics
                .filter { $0.severity == .error }
                .map { "\($0.path): \($0.message)" }
                .joined(separator: "\n")
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

enum OverlayCategory: String, CaseIterable, Identifiable {
    case metrics
    case visuals
    case components
    case decor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metrics: "Metrics"
        case .visuals: "Visuals"
        case .components: "Components"
        case .decor: "Decor"
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
        OverlayTileInfo(type: .heartRateZone, hint: "Z1–Z6", systemImage: "heart.text.square.fill", category: .metrics),
        OverlayTileInfo(type: .pace, hint: "min/km", systemImage: "timer", category: .metrics),
        OverlayTileInfo(type: .avgPace, hint: "avg", systemImage: "speedometer", category: .metrics),
        OverlayTileInfo(type: .lapPace, hint: "lap", systemImage: "flag.checkered", category: .metrics),
        OverlayTileInfo(type: .calories, hint: "kcal", systemImage: "flame", category: .metrics),
        OverlayTileInfo(type: .elapsedTime, hint: "duration", systemImage: "clock", category: .metrics),
        OverlayTileInfo(type: .realTime, hint: "clock time", systemImage: "watch.analog", category: .metrics),
        OverlayTileInfo(type: .date, hint: "year / month / day", systemImage: "calendar", category: .metrics),
        OverlayTileInfo(type: .distance, hint: "km / mi", systemImage: "ruler", category: .metrics),
        OverlayTileInfo(type: .elevation, hint: "altitude", systemImage: "mountain.2", category: .metrics),
        OverlayTileInfo(type: .cadence, hint: "spm", systemImage: "figure.run", category: .metrics),
        OverlayTileInfo(type: .power, hint: "watts", systemImage: "bolt", category: .metrics),
        OverlayTileInfo(type: .verticalOscillation, hint: "cm", systemImage: "arrow.up.and.down", category: .metrics),
        OverlayTileInfo(type: .groundContactTime, hint: "ms", systemImage: "timer", category: .metrics),
        OverlayTileInfo(type: .strideLength, hint: "m", systemImage: "arrow.left.and.right", category: .metrics),
        OverlayTileInfo(type: .verticalRatio, hint: "%", systemImage: "percent", category: .metrics),
        OverlayTileInfo(type: .groundContactBalance, hint: "L/R", systemImage: "scale.3d", category: .metrics),
        OverlayTileInfo(type: .temperature, hint: "°C / °F", systemImage: "thermometer", category: .metrics),
        OverlayTileInfo(type: .grade, hint: "slope %", systemImage: "arrow.up.right", category: .metrics),
        OverlayTileInfo(type: .customNumeric, hint: "custom activity field", systemImage: "number", category: .metrics),
        OverlayTileInfo(type: .distanceTimeline, hint: "progress", systemImage: "waveform.path.ecg", category: .visuals),
        OverlayTileInfo(type: .elevationChart, hint: "profile", systemImage: "chart.line.uptrend.xyaxis", category: .visuals),
        OverlayTileInfo(type: .runningGauge, hint: "live gauge", systemImage: "gauge", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .intervalHUDBar, hint: "interval HUD", systemImage: "rectangle.split.3x1", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .intervalTimeline, hint: "interval plan", systemImage: "timeline.selection", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .intervalCountdown, hint: "set timer", systemImage: "timer.circle", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .intervalWorkSummary, hint: "work summary", systemImage: "flag.checkered.2.crossed", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .zoneEdgeBar, hint: "HR / Pace zones", systemImage: "rectangle.compress.vertical", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .routeMap, hint: "GPS path", systemImage: "map", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .weatherWidget, hint: "current weather", systemImage: "cloud.sun.fill", category: .visuals, isAccent: true),
        OverlayTileInfo(type: .decorSolidColor, hint: "shape", systemImage: "square.fill", category: .decor),
        OverlayTileInfo(type: .decorIcon, hint: "symbol", systemImage: "star", category: .decor),
        OverlayTileInfo(type: .decorText, hint: "label", systemImage: "textformat", category: .decor)
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

/// Add tile for a read-only bundled component. Bundled definitions cannot be
/// edited in place; the Inspector offers "Duplicate to My Components".
struct OverlayComponentAddTile: View {
    let item: OverlayComponentLibraryItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EditorTheme.space3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(EditorTheme.textPrimary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                        .lineLimit(1)
                    Text(item.hint)
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
        .buttonStyle(OverlayTileButtonStyle(isAccent: false))
        .help("Add \(item.displayName)")
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
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var background: Color {
        EditorTheme.surfaceControl
    }
}
