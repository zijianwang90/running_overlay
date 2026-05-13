import SwiftUI

struct HeartRateZonesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prefs = HeartRateZonePreferences.shared

    // Shared column metrics so the table header and zone rows align pixel-for-pixel.
    private static let zoneLabelColumnWidth: CGFloat = 76
    private static let hrFieldWidth: CGFloat = 56
    private static let paceFieldWidth: CGFloat = 60
    private static let rangeUnitColumnWidth: CGFloat = 56
    private static let rangeInternalSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topSettingsGroup
                    thresholdSection
                    zonesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            footer
        }
        .frame(width: 720, height: 660)
        .background(EditorTheme.panelBackground)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Heart Rate Zones")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Configure HR and pace ranges for each zone.")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }

    // MARK: - Top settings (Zone Count + Pace Unit)

    private var topSettingsGroup: some View {
        SettingsGroupBox {
            SettingsRow(
                leading: { rowLabel("Zone Count") },
                trailing: {
                    Picker("", selection: $prefs.zoneCount) {
                        ForEach(HRZoneCount.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            )
            Divider().overlay(EditorTheme.borderSubtle).padding(.leading, 14)
            SettingsRow(
                leading: { rowLabel("Pace Unit") },
                trailing: {
                    Picker("", selection: $prefs.paceUnit) {
                        ForEach(PaceUnit.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            )
        }
    }

    // MARK: - Threshold

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: "Threshold")
                .padding(.bottom, 0)

            SettingsGroupBox {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("Threshold HR")
                            .font(EditorTheme.bodyFont)
                            .foregroundStyle(EditorTheme.textPrimary)
                            .fixedSize()
                        IntField(value: $prefs.thresholdHR, placeholder: "—", width: 64)
                        Text("bpm")
                            .font(EditorTheme.captionFont)
                            .foregroundStyle(EditorTheme.textMuted)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text("Threshold Pace")
                            .font(EditorTheme.bodyFont)
                            .foregroundStyle(EditorTheme.textPrimary)
                            .fixedSize()
                        PaceField(secondsPerKm: $prefs.thresholdPaceSecPerKm, unit: prefs.paceUnit, width: 64)
                        Text(prefs.paceUnit.label)
                            .font(EditorTheme.captionFont)
                            .foregroundStyle(EditorTheme.textMuted)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Zones

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            zonesHeaderRow

            SettingsGroupBox {
                ForEach(0..<prefs.zoneCount.rawValue, id: \.self) { index in
                    HeartRateZoneRow(
                        index: index,
                        paceUnit: prefs.paceUnit,
                        zoneLabelColumnWidth: Self.zoneLabelColumnWidth,
                        hrFieldWidth: Self.hrFieldWidth,
                        paceFieldWidth: Self.paceFieldWidth,
                        rangeUnitColumnWidth: Self.rangeUnitColumnWidth,
                        rangeInternalSpacing: Self.rangeInternalSpacing,
                        zone: Binding(
                            get: { prefs.zones[index] },
                            set: { prefs.zones[index] = $0 }
                        )
                    )
                    if index < prefs.zoneCount.rawValue - 1 {
                        Divider().overlay(EditorTheme.borderSubtle).padding(.leading, 14)
                    }
                }
            }
        }
    }

    private var zonesHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.zoneLabelColumnWidth)
            Text("HR Range")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: rangeColumnWidth, alignment: .leading)
            Text("Pace Range")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: rangeColumnWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var rangeColumnWidth: CGFloat {
        // mirrors HeartRateZoneRow's HR-range cluster width: 2 fields + dash + unit column + spacing
        let dashWidth: CGFloat = 12
        let spacing = Self.rangeInternalSpacing
        return Self.hrFieldWidth * 2 + dashWidth + Self.rangeUnitColumnWidth + spacing * 3
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(EditorTheme.borderSubtle)
            HStack {
                Button("Reset") {
                    prefs.resetVisibleZones()
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

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.bodyFont)
            .foregroundStyle(EditorTheme.textPrimary)
    }
}

private struct HeartRateZoneRow: View {
    let index: Int
    let paceUnit: PaceUnit
    let zoneLabelColumnWidth: CGFloat
    let hrFieldWidth: CGFloat
    let paceFieldWidth: CGFloat
    let rangeUnitColumnWidth: CGFloat
    let rangeInternalSpacing: CGFloat
    @Binding var zone: HeartRateZone

    var body: some View {
        HStack(spacing: 0) {
            // Zone label column: colored dot + Z# pill.
            HStack(spacing: 8) {
                Circle()
                    .fill(HRZonePalette.color(forIndex: index))
                    .frame(width: 10, height: 10)
                Text("Z\(index + 1)")
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .frame(width: 32, height: 22)
                    .background(EditorTheme.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(EditorTheme.borderSubtle, lineWidth: 1))
            }
            .frame(width: zoneLabelColumnWidth, alignment: .leading)

            rangeCluster(
                minBinding: $zone.minHR,
                maxBinding: $zone.maxHR,
                unitText: "bpm"
            )

            rangeCluster(
                paceMin: $zone.minPaceSecPerKm,
                paceMax: $zone.maxPaceSecPerKm,
                unitText: paceUnit.label
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }

    private func rangeCluster(minBinding: Binding<Int?>, maxBinding: Binding<Int?>, unitText: String) -> some View {
        HStack(spacing: rangeInternalSpacing) {
            IntField(value: minBinding, placeholder: "min", width: hrFieldWidth)
            Text("–")
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: 12)
            IntField(value: maxBinding, placeholder: "max", width: hrFieldWidth)
            Text(unitText)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: rangeUnitColumnWidth, alignment: .leading)
        }
    }

    private func rangeCluster(paceMin: Binding<Int?>, paceMax: Binding<Int?>, unitText: String) -> some View {
        HStack(spacing: rangeInternalSpacing) {
            PaceField(secondsPerKm: paceMin, unit: paceUnit, width: paceFieldWidth)
            Text("–")
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: 12)
            PaceField(secondsPerKm: paceMax, unit: paceUnit, width: paceFieldWidth)
            Text(unitText)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: rangeUnitColumnWidth, alignment: .leading)
        }
    }
}

private struct IntField: View {
    @Binding var value: Int?
    var placeholder: String
    var width: CGFloat
    @State private var text: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(EditorTheme.numericFont)
            .foregroundStyle(EditorTheme.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: width, height: 26)
            .background(EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(EditorTheme.borderSubtle, lineWidth: 1))
            .onAppear { text = value.map(String.init) ?? "" }
            .onChange(of: value) { _, newValue in
                let formatted = newValue.map(String.init) ?? ""
                if formatted != text { text = formatted }
            }
            .onChange(of: text) { _, newText in
                let trimmed = newText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    if value != nil { value = nil }
                } else if let parsed = Int(trimmed) {
                    let clamped = max(0, min(parsed, 250))
                    if value != clamped { value = clamped }
                }
            }
    }
}

private struct PaceField: View {
    @Binding var secondsPerKm: Int?
    var unit: PaceUnit
    var width: CGFloat
    @State private var text: String = ""

    var body: some View {
        TextField("m:ss", text: $text)
            .textFieldStyle(.plain)
            .font(EditorTheme.numericFont)
            .foregroundStyle(EditorTheme.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: width, height: 26)
            .background(EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(EditorTheme.borderSubtle, lineWidth: 1))
            .onAppear { text = PaceConversion.format(secondsPerKm: secondsPerKm, unit: unit) }
            .onChange(of: unit) { _, newUnit in
                text = PaceConversion.format(secondsPerKm: secondsPerKm, unit: newUnit)
            }
            .onChange(of: secondsPerKm) { _, newValue in
                let formatted = PaceConversion.format(secondsPerKm: newValue, unit: unit)
                if formatted != text { text = formatted }
            }
            .onSubmit { commit() }
            .onChange(of: text) { _, _ in commit() }
    }

    private func commit() {
        let parsed = PaceConversion.parse(text, unit: unit)
        if parsed != secondsPerKm { secondsPerKm = parsed }
    }
}
