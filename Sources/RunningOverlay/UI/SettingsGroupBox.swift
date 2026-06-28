import SwiftUI

/// Reusable bordered group box for Project Settings and Font Library sections.
struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(EditorTheme.surfaceControl)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(EditorTheme.borderSubtle, lineWidth: 1)
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(EditorTheme.sectionTitleFont)
            .foregroundStyle(EditorTheme.textMuted)
            .padding(.bottom, 4)
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }
}
