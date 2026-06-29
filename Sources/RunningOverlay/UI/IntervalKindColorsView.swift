import SwiftUI

/// Project-Settings sheet for editing the four interval-kind colors that drive
/// the FIT track on the timeline, the Interval Timeline overlay segments, and
/// the Interval HUD bar phase color.
struct IntervalKindColorsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prefs = IntervalKindColorPreferences.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title: "Phase Colors")
                    SettingsGroupBox {
                        colorRow(
                            title: "Warm Up",
                            subtitle: "Opening laps before the workout starts.",
                            color: Binding(get: { prefs.warmupColor }, set: { prefs.warmupColor = $0 })
                        )
                        dividerRow
                        colorRow(
                            title: "Active",
                            subtitle: "Work intervals or sustained efforts.",
                            color: Binding(get: { prefs.activeColor }, set: { prefs.activeColor = $0 })
                        )
                        dividerRow
                        colorRow(
                            title: "Rest",
                            subtitle: "Recovery jogs between active reps.",
                            color: Binding(get: { prefs.restColor }, set: { prefs.restColor = $0 })
                        )
                        dividerRow
                        colorRow(
                            title: "Cool Down",
                            subtitle: "Closing laps after the workout.",
                            color: Binding(get: { prefs.cooldownColor }, set: { prefs.cooldownColor = $0 })
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            footer
        }
        .frame(width: 520, height: 480)
        .background(EditorTheme.panelBackground)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Interval Colors")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Shared by the FIT timeline, Interval Timeline overlay, and Interval HUD bar.")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }

    private func colorRow(title: String, subtitle: String, color: Binding<OverlayColor>) -> some View {
        SettingsRow(
            leading: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                    Text(subtitle)
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textSecondary)
                }
            },
            trailing: {
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { Color(overlay: color.wrappedValue) },
                        set: { newColor in color.wrappedValue = OverlayColor(swiftUI: newColor, alpha: color.wrappedValue.alpha) }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 44, height: 26)
            }
        )
    }

    private var dividerRow: some View {
        Divider().overlay(EditorTheme.borderSubtle).padding(.leading, 14)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(EditorTheme.borderSubtle)
            HStack {
                Button("Reset") {
                    prefs.resetToDefaults()
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(EditorPrimaryButtonStyle())
            }
            .padding(16)
        }
    }
}

private extension Color {
    init(overlay color: OverlayColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

private extension OverlayColor {
    init(swiftUI color: Color, alpha: Double) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: alpha
        )
    }
}
