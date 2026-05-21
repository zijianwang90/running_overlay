import SwiftUI

struct FontLibraryView: View {
    @State private var searchText = ""
    @State private var hoveredFamily: String? = nil
    @Environment(\.dismiss) private var dismiss
    private let manager = FontLibraryManager.shared

    private let previewMetrics = ["5\u{2032}42\u{2033}/km", "10.24 km", "4\u{2032}58\u{2033}/km", "42.20 km", "4\u{2032}45\u{2033}/km"]

    private var favorites: [String] {
        let favs = manager.favoriteFamilies
        if searchText.isEmpty { return favs }
        return favs.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var allFonts: [String] {
        let favSet = Set(manager.favoriteFamilies)
        let base = searchText.isEmpty
            ? manager.allSystemFamilies
            : manager.allSystemFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
        return base.filter { !favSet.contains($0) }
    }

    private func preview(for family: String) -> String {
        let hash = abs(family.hash)
        return previewMetrics[hash % previewMetrics.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Font Library")
                    .font(EditorTheme.panelTitleFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Manage fonts shown in overlay menus.")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EditorTheme.textMuted)
                TextField("Search fonts", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(EditorTheme.textPrimary)
            }
            .padding(8)
            .background(EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 20).padding(.bottom, 16)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !favorites.isEmpty {
                        favoritesSection
                    }

                    allFontsSection
                }
                .padding(.horizontal, 20)
            }

            // Footer
            Divider()
                .overlay(EditorTheme.borderSubtle)
            HStack {
                Button("Restore Defaults") {
                    manager.restoreDefaults()
                    searchText = ""
                }
                .buttonStyle(EditorSecondaryButtonStyle())

                Text("\(manager.favoriteFamilies.count) fonts selected \u{2022} Default: \(manager.defaultFamily)")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(EditorPrimaryButtonStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(width: 560, height: 600)
        .background(EditorTheme.panelBackground)
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Favorites")
            SettingsGroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(favorites.enumerated()), id: \.element) { i, family in
                        fontRow(family, isFavorites: true)
                        if i < favorites.count - 1 {
                            dividerRow
                        }
                    }
                }
            }
        }
    }

    // MARK: - All Fonts

    private var allFontsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "All Fonts")
            SettingsGroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(allFonts.enumerated()), id: \.element) { i, family in
                        fontRow(family, isFavorites: false)
                        if i < allFonts.count - 1 {
                            dividerRow
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func fontRow(_ family: String, isFavorites: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                manager.toggle(family)
            } label: {
                Image(systemName: manager.isFavorite(family) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(manager.isFavorite(family) ? EditorTheme.accentBlue : EditorTheme.textMuted)
            }
            .buttonStyle(.plain)

            Text(family)
                .font(.custom(family, size: 13))
                .foregroundStyle(EditorTheme.textPrimary)
                .lineLimit(1)

            // Default action slot — only in Favorites, fixed width to prevent layout jump
            if isFavorites {
                defaultSlot(for: family)
            }

            Spacer()

            Text(preview(for: family))
                .font(.custom(family, size: 13))
                .foregroundStyle(EditorTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .onHover { hovering in
            hoveredFamily = hovering ? family : nil
        }
    }

    @ViewBuilder
    private func defaultSlot(for family: String) -> some View {
        ZStack(alignment: .leading) {
            if manager.isDefault(family) {
                defaultPill
            } else if hoveredFamily == family {
                Button("Default") {
                    manager.setDefault(family)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EditorTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(EditorTheme.surfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(width: 54, alignment: .leading)
    }

    private var defaultPill: some View {
        Text("Default")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(EditorTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var dividerRow: some View {
        Divider()
            .overlay(EditorTheme.borderSubtle)
            .padding(.leading, 14)
    }
}
