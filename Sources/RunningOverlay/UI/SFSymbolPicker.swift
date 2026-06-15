import AppKit
import SwiftUI

struct SFSymbolPicker: View {
    @Binding var symbolName: String
    var placeholder: String
    var defaultSymbolName: String?
    var defaultLabel: String = "Default"
    var onSubmit: () -> Void = {}
    var onDefault: (() -> Void)?

    @State private var isPopoverPresented = false
    @State private var searchText = ""
    @AppStorage("sfSymbolPicker.recentSymbols") private var recentSymbolsStorage = ""

    var body: some View {
        HStack(spacing: NumericTokens.space2) {
            TextField(placeholder, text: $symbolName, onCommit: onSubmit)
                .textFieldStyle(.plain)
                .font(NumericTokens.bodyFont)
                .padding(.horizontal, NumericTokens.space2)
                .frame(height: NumericTokens.controlHeight)
                .background(NumericTokens.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            Button {
                searchText = ""
                isPopoverPresented.toggle()
            } label: {
                Image(systemName: previewSymbolName)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: NumericTokens.controlHeight, height: NumericTokens.controlHeight)
                    .background(NumericTokens.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Browse SF Symbols")
            .popover(isPresented: $isPopoverPresented, arrowEdge: .trailing) {
                pickerPopover
            }
        }
    }

    private var previewSymbolName: String {
        let trimmed = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        if SFSymbolCatalog.isRenderable(trimmed) {
            return trimmed
        }
        if let defaultSymbolName, SFSymbolCatalog.isRenderable(defaultSymbolName) {
            return defaultSymbolName
        }
        return "square.grid.3x3"
    }

    private var recentSymbols: [String] {
        recentSymbolsStorage
            .split(separator: ",")
            .map(String.init)
            .filter(SFSymbolCatalog.isRenderable)
    }

    private var visibleSymbols: [String] {
        SFSymbolCatalog.search(searchText, limit: 240)
    }

    private var pickerPopover: some View {
        VStack(alignment: .leading, spacing: NumericTokens.space3) {
            HStack(spacing: NumericTokens.space2) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(NumericTokens.textSecondary)
                TextField("Search SF Symbols", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(NumericTokens.bodyFont)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(NumericTokens.textMuted)
                    .help("Clear Search")
                }
            }
            .padding(.horizontal, NumericTokens.space2)
            .frame(height: NumericTokens.controlHeight)
            .background(NumericTokens.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(NumericTokens.borderSubtle, lineWidth: 1))

            if onDefault != nil || !recentSymbols.isEmpty {
                VStack(alignment: .leading, spacing: NumericTokens.space2) {
                    if let onDefault, let defaultSymbolName {
                        Button {
                            onDefault()
                            addRecent(defaultSymbolName)
                            isPopoverPresented = false
                        } label: {
                            Label(defaultLabel, systemImage: defaultSymbolName)
                                .font(NumericTokens.captionFont)
                        }
                        .buttonStyle(.plain)
                    }
                    if !recentSymbols.isEmpty {
                        symbolGrid(recentSymbols, columnMinWidth: 34, iconSize: 14)
                            .frame(maxHeight: 84)
                    }
                }
            }

            Divider()

            ScrollView {
                symbolGrid(visibleSymbols, columnMinWidth: 44, iconSize: 16)
                    .padding(.vertical, 2)
            }
            .frame(height: 300)
        }
        .padding(NumericTokens.space3)
        .frame(width: 360)
        .background(NumericTokens.panelBackgroundElevated)
    }

    private func symbolGrid(_ symbols: [String], columnMinWidth: CGFloat, iconSize: CGFloat) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnMinWidth), spacing: 6)], spacing: 6) {
            ForEach(symbols, id: \.self) { name in
                Button {
                    symbolName = name
                    addRecent(name)
                    onSubmit()
                    isPopoverPresented = false
                } label: {
                    Image(systemName: name)
                        .font(.system(size: iconSize, weight: .medium))
                        .frame(width: columnMinWidth, height: columnMinWidth)
                        .background(name == symbolName ? NumericTokens.accentBlue.opacity(0.24) : NumericTokens.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumericTokens.controlRadius))
                        .overlay(RoundedRectangle(cornerRadius: NumericTokens.controlRadius).stroke(name == symbolName ? NumericTokens.accentBlue : NumericTokens.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
    }

    private func addRecent(_ name: String) {
        var symbols = recentSymbols.filter { $0 != name }
        symbols.insert(name, at: 0)
        recentSymbolsStorage = symbols.prefix(24).joined(separator: ",")
    }
}

@MainActor
enum SFSymbolCatalog {
    static let allNames: [String] = loadSymbolNames()
    static let sportFirstNames: [String] = uniqueNames(sportNames + preferredNames + allNames)
    private static var renderableCache: [String: Bool] = [:]

    static func search(_ query: String, limit: Int = 240) -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return Array(sportFirstNames.prefix(limit))
        }

        var exact: [String] = []
        var prefixed: [String] = []
        var contained: [String] = []

        for name in allNames {
            let searchable = name.lowercased()
            if searchable == normalized {
                exact.append(name)
            } else if searchable.hasPrefix(normalized) {
                prefixed.append(name)
            } else if searchable.contains(normalized) {
                contained.append(name)
            }
            if exact.count + prefixed.count + contained.count >= limit * 4 {
                break
            }
        }

        let ranked = exact + prefixed + contained
        return Array(ranked.filter(isRenderable).prefix(limit))
    }

    static func isRenderable(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let cached = renderableCache[trimmed] {
            return cached
        }
        let isRenderable = NSImage(systemSymbolName: trimmed, accessibilityDescription: nil) != nil
        renderableCache[trimmed] = isRenderable
        return isRenderable
    }

    private static func loadSymbolNames() -> [String] {
        let resourceURL = Bundle.module.url(forResource: "symbols", withExtension: "json")
            ?? Bundle.module.url(forResource: "symbols", withExtension: "json", subdirectory: "SFSymbols")
        guard let url = resourceURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return fallbackNames
        }
        return uniqueNames(preferredNames + decoded)
    }

    private static func uniqueNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    private static let preferredNames: [String] = [
        "heart", "heart.fill", "heart.text.square.fill", "speedometer", "timer",
        "clock", "watch.analog", "flag.checkered", "flame", "flame.fill",
        "ruler", "mountain.2", "figure.run", "bolt", "bolt.fill",
        "arrow.up.and.down", "arrow.left.and.right", "percent", "scale.3d",
        "thermometer", "arrow.up.right", "location.fill", "map", "waveform.path.ecg",
        "star.fill", "circle.fill", "square.fill", "figure.walk", "figure.outdoor.cycle"
    ]

    private static let sportNames: [String] = [
        "figure.run", "figure.run.circle", "figure.walk", "figure.outdoor.cycle",
        "figure.indoor.cycle", "figure.pool.swim", "figure.open.water.swim", "figure.hiking",
        "heart", "heart.fill", "heart.text.square.fill", "waveform.path.ecg",
        "speedometer", "gauge", "gauge.open.with.lines.needle.33percent",
        "timer", "timer.circle", "stopwatch", "stopwatch.fill", "clock", "watch.analog",
        "bolt", "bolt.fill", "flame", "flame.fill", "ruler", "mountain.2", "mountain.2.fill",
        "map", "map.fill", "location", "location.fill",
        "flag.checkered", "flag.fill", "shoe", "shoe.fill", "figure.water.fitness",
        "arrow.up.and.down", "arrow.left.and.right", "arrow.up.right", "percent",
        "scale.3d", "thermometer", "humidity", "wind",
        "figure.walk.circle", "figure.walk.motion", "figure.cooldown", "figure.flexibility",
        "figure.core.training", "figure.strengthtraining.functional",
        "figure.strengthtraining.traditional", "figure.highintensity.intervaltraining",
        "figure.cross.training", "figure.rower", "figure.stair.stepper", "figure.stairs",
        "figure.step.training", "figure.track.and.field", "figure.skiing.crosscountry",
        "figure.skiing.downhill", "figure.snowboarding", "figure.soccer",
        "figure.basketball", "figure.tennis", "figure.table.tennis", "figure.badminton",
        "figure.pickleball", "figure.golf", "figure.boxing"
    ]

    private static let fallbackNames: [String] = preferredNames
}
