import SwiftUI
import UniformTypeIdentifiers

struct OverlayPoolView: View {
    @EnvironmentObject private var project: ProjectDocument
    @EnvironmentObject private var componentDrafts: ComponentDraftLibrary
    @State private var activeCategory: OverlayCategory = .metrics
    @State private var alert: ComponentAlert?
    @State private var showsAIGuide = false

    private struct ComponentAlert {
        var title: String
        var message: String
    }

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
                    HStack(spacing: EditorTheme.space4) {
                        Button {
                            showsAIGuide = true
                        } label: {
                            Label("Create with AI…", systemImage: "sparkles")
                                .font(EditorTheme.captionFont)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EditorTheme.accentBlue)
                        .help("Design a component with Claude, Codex or another AI")
                        Button {
                            importComponent()
                        } label: {
                            Label("Import Component…", systemImage: "square.and.arrow.down")
                                .font(EditorTheme.captionFont)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EditorTheme.textSecondary)
                        .help("Import a .rocomponent package (folder or ZIP) or component JSON file")
                        Spacer()
                    }
                }

                ScrollView {
                    if activeCategory == .components {
                        VStack(alignment: .leading, spacing: EditorTheme.space3) {
                            draftsSection
                            componentSectionHeader("Bundled")
                            LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                                ForEach(OverlayComponentLibraryItem.componentsTabItems) { item in
                                    OverlayComponentAddTile(
                                        displayName: item.displayName,
                                        hint: item.hint,
                                        systemImage: item.systemImage
                                    ) {
                                        project.addComponentFromLibrary(item)
                                    }
                                }
                            }

                            componentSectionHeader("My Components")
                            if project.projectComponentEntries.isEmpty {
                                Text("Imported and duplicated components appear here.")
                                    .font(EditorTheme.captionFont)
                                    .foregroundStyle(EditorTheme.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                                    ForEach(project.projectComponentEntries) { entry in
                                        projectComponentTile(entry)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, EditorTheme.space4)
                    } else if activeCategory == .metrics {
                        // Numeric readings are presets of the bundled
                        // `studio.numeric` component (ADR 0014).
                        LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                            ForEach(OverlayComponentLibraryItem.numericPresets) { item in
                                OverlayComponentAddTile(
                                    displayName: item.displayName,
                                    hint: item.hint,
                                    systemImage: item.systemImage
                                ) {
                                    project.addComponentFromLibrary(item)
                                }
                            }
                        }
                        .padding(.bottom, EditorTheme.space4)
                    } else {
                        LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                            ForEach(OverlayTileInfo.tiles(for: activeCategory)) { tile in
                                OverlayAddTile(tile: tile) {
                                    // Tiles create the declarative component,
                                    // never the legacy native element. Native
                                    // types still decode until their bundled
                                    // templates convert (ADR 0013, ADR 0015).
                                    guard let item = OverlayComponentLibraryItem.all.first(
                                        where: { $0.id == tile.componentID }
                                    ) else { return }
                                    project.addComponentFromLibrary(item)
                                }
                            }
                        }
                        .padding(.bottom, EditorTheme.space4)
                    }
                }
            }
            .padding(.horizontal, EditorTheme.panelPaddingX)
            .padding(.vertical, EditorTheme.space3)
        }
        .background(EditorTheme.panelBackground)
        .sheet(isPresented: $showsAIGuide) {
            ComponentAIGuideSheet()
                .environmentObject(componentDrafts)
        }
        .alert(
            alert?.title ?? "Component",
            isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                alert = nil
            }
        } message: {
            Text(alert?.message ?? "")
        }
    }

    /// Drafts saved by an AI client or by hand, shown live from the drafts
    /// folder. The section stays out of the way until a draft exists.
    @ViewBuilder
    private var draftsSection: some View {
        if !componentDrafts.drafts.isEmpty {
            HStack {
                componentSectionHeader("Drafts")
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([componentDrafts.store.directory])
                } label: {
                    Image(systemName: "folder")
                        .font(EditorTheme.captionFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorTheme.textSecondary)
                .help("Show Drafts Folder")
            }
            LazyVGrid(columns: columns, spacing: EditorTheme.space2) {
                ForEach(componentDrafts.drafts) { draft in
                    draftTile(draft)
                }
            }
        }
    }

    private func draftTile(_ draft: ComponentDraft) -> some View {
        let isValid = draft.reference != nil
        let errorCount: Int
        if case let .invalid(diagnostics) = draft.status {
            errorCount = max(diagnostics.count, 1)
        } else {
            errorCount = 0
        }
        return OverlayComponentAddTile(
            displayName: draft.displayName,
            hint: isValid
                ? "draft · \(draft.modified.formatted(.relative(presentation: .named)))"
                : (errorCount == 1 ? "1 error" : "\(errorCount) errors"),
            systemImage: isValid ? "sparkles" : "exclamationmark.triangle"
        ) {
            if isValid {
                project.addComponentFromDraft(draft)
            } else if case let .invalid(diagnostics) = draft.status {
                alert = ComponentAlert(
                    title: "Draft “\(draft.id)” Is Invalid",
                    message: diagnostics.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
                )
            }
        }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([draft.url])
            }
            Button("Delete Draft", role: .destructive) {
                do {
                    try componentDrafts.delete(draft)
                } catch {
                    alert = ComponentAlert(title: "Could Not Delete Draft", message: error.localizedDescription)
                }
            }
        }
    }

    private func componentSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(EditorTheme.bodyStrongFont)
            .foregroundStyle(EditorTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func projectComponentTile(_ entry: OverlayComponentProjectEntry) -> some View {
        OverlayComponentAddTile(
            displayName: entry.displayName,
            hint: entry.instanceCount == 1 ? "1 instance" : "\(entry.instanceCount) instances",
            systemImage: "square.stack.3d.up"
        ) {
            project.addComponentFromProject(entry)
        }
        .contextMenu {
            Button("Export Component…") {
                exportComponent(entry)
            }
            Button("Remove All Instances", role: .destructive) {
                project.removeProjectComponent(entry)
            }
        }
    }

    private func importComponent() {
        let panel = NSOpenPanel()
        panel.title = "Import Component"
        panel.prompt = "Import"
        panel.message = "Choose a .rocomponent package (folder or ZIP) or a component JSON file."
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, .zip]
            + [UTType(filenameExtension: "rocomponent")].compactMap { $0 }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            _ = try SecurityScopedURLAccess.withAccess(to: url) {
                try project.importComponentPackage(at: url)
            }
        } catch let error as OverlayComponentValidationError {
            alert = ComponentAlert(
                title: "Component Import Failed",
                message: error.diagnostics
                    .filter { $0.severity == .error }
                    .map { "\($0.path): \($0.message)" }
                    .joined(separator: "\n")
            )
        } catch {
            alert = ComponentAlert(
                title: "Component Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func exportComponent(_ entry: OverlayComponentProjectEntry) {
        let panel = NSSavePanel()
        panel.title = "Export Component"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "\(entry.displayName).rocomponent"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SecurityScopedURLAccess.withAccess(to: url) {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try OverlayComponentPackageWriter.write(entry.reference, to: url)
            }
        } catch {
            alert = ComponentAlert(
                title: "Component Export Failed",
                message: error.localizedDescription
            )
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
    /// Stable pool entry identity, independent of legacy element types.
    var id: String
    var label: String
    /// Bundled component this tile creates.
    var componentID: String
    var hint: String
    var systemImage: String
    var category: OverlayCategory
    var isAccent = false

    static let all: [OverlayTileInfo] = [
        OverlayTileInfo(id: "distance-timeline", label: "Distance Timeline", componentID: "studio.distance-timeline", hint: "progress", systemImage: "waveform.path.ecg", category: .visuals),
        OverlayTileInfo(id: "elevation-chart", label: "Elevation Chart", componentID: "studio.elevation-chart", hint: "profile", systemImage: "chart.line.uptrend.xyaxis", category: .visuals),
        OverlayTileInfo(id: "running-gauge", label: "Running Gauge", componentID: "studio.running-gauge", hint: "live gauge", systemImage: "gauge", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "interval-hud-bar", label: "Interval HUD Bar", componentID: "studio.interval-hud-bar", hint: "interval HUD", systemImage: "rectangle.split.3x1", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "interval-timeline", label: "Interval Timeline", componentID: "studio.interval-timeline", hint: "interval plan", systemImage: "timeline.selection", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "interval-countdown", label: "Interval Countdown", componentID: "studio.interval-countdown", hint: "set timer", systemImage: "timer.circle", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "interval-work-summary", label: "Interval Work Summary", componentID: "studio.interval-work-summary", hint: "work summary", systemImage: "flag.checkered.2.crossed", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "zone-edge-bar", label: "Zone Edge Bar", componentID: "studio.zone-edge-bar", hint: "HR / Pace zones", systemImage: "rectangle.compress.vertical", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "route-map", label: "Route Map", componentID: "studio.route-map", hint: "GPS path", systemImage: "map", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "stats-bar", label: "Stats Bar", componentID: "studio.stats-bar", hint: "metric strip", systemImage: "rectangle.split.2x1", category: .visuals),
        OverlayTileInfo(id: "weather-widget", label: "Weather Widget", componentID: "studio.weather-widget", hint: "current weather", systemImage: "cloud.sun.fill", category: .visuals, isAccent: true),
        OverlayTileInfo(id: "decor-shape", label: "Solid Color", componentID: "studio.decor-shape", hint: "shape", systemImage: "square.fill", category: .decor),
        OverlayTileInfo(id: "decor-icon", label: "Icon", componentID: "studio.decor-icon", hint: "symbol", systemImage: "star", category: .decor),
        OverlayTileInfo(id: "decor-text", label: "Text", componentID: "studio.decor-text", hint: "label", systemImage: "textformat", category: .decor)
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

/// Add tile for a bundled or project component. Bundled definitions are
/// read-only; the Inspector offers "Duplicate to My Components".
struct OverlayComponentAddTile: View {
    let displayName: String
    let hint: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EditorTheme.space3) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(EditorTheme.textPrimary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                        .lineLimit(1)
                    Text(hint)
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
        .help("Add \(displayName)")
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
