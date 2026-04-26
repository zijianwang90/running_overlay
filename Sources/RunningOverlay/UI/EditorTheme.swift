import AppKit
import SwiftUI

enum EditorTheme {
    static let appBackground = Color(hex: 0x0B0F12)
    static let appChrome = Color(hex: 0x101418)
    static let panelBackground = Color(hex: 0x15191D)
    static let panelHeader = Color(hex: 0x1B2025)
    static let surfaceRaised = Color(hex: 0x1B2025)
    static let surfaceControl = Color(hex: 0x20252A)
    static let surfaceHover = Color(hex: 0x272D33)
    static let surfacePressed = Color(hex: 0x11161A)
    static let surfaceSelected = Color(hex: 0x263244)
    static let borderSubtle = Color(hex: 0x2B3238)
    static let borderStrong = Color(hex: 0x3A424A)
    static let textPrimary = Color(hex: 0xF3F6F8)
    static let textSecondary = Color(hex: 0xB6BEC7)
    static let textMuted = Color(hex: 0x7E8893)
    static let accentBlue = Color(hex: 0x2F8CFF)
    static let accentBlueSoft = Color(hex: 0x123052)
    static let dangerRed = Color(hex: 0xFF5A5F)
    static let successGreen = Color(hex: 0x51C96B)
    static let warningYellow = Color(hex: 0xFFD166)

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24

    static let panelPaddingX: CGFloat = 14
    static let panelHeaderHeight: CGFloat = 54
    static let controlHeight: CGFloat = 32
    static let compactRowHeight: CGFloat = 52
    static let mediaRowHeight: CGFloat = 72
    static let iconButtonSize: CGFloat = 30
    static let controlRadius: CGFloat = 7
    static let panelRadius: CGFloat = 8

    static let panelTitleFont = Font.system(size: 22, weight: .semibold)
    static let sectionTitleFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let bodyStrongFont = Font.system(size: 13, weight: .semibold)
    static let captionFont = Font.system(size: 11, weight: .regular)
    static let numericFont = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let timelineLabelFont = Font.system(size: 11, weight: .medium)
}

struct EditorPanelHeader<Actions: View>: View {
    var title: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: EditorTheme.space2) {
            Text(title)
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            actions
        }
        .padding(.horizontal, EditorTheme.panelPaddingX)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(EditorTheme.panelHeader)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }
}

struct EditorIconButtonStyle: ButtonStyle {
    var isEnabled = true
    var role: ButtonRole?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: EditorTheme.iconButtonSize, height: EditorTheme.iconButtonSize)
            .background(configuration.isPressed ? EditorTheme.surfacePressed : EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
    }

    private var foreground: Color {
        if !isEnabled {
            return EditorTheme.textMuted
        }
        return role == .destructive ? EditorTheme.dangerRed : EditorTheme.textSecondary
    }
}

struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EditorTheme.bodyStrongFont)
            .foregroundStyle(Color.white)
            .padding(.horizontal, EditorTheme.space3)
            .frame(height: EditorTheme.controlHeight)
            .background(configuration.isPressed ? EditorTheme.accentBlue.opacity(0.72) : EditorTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
    }
}

struct EditorSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EditorTheme.bodyStrongFont)
            .foregroundStyle(EditorTheme.textSecondary)
            .padding(.horizontal, EditorTheme.space3)
            .frame(height: EditorTheme.controlHeight)
            .background(configuration.isPressed ? EditorTheme.surfacePressed : EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static let editorAppBackground = NSColor(hex: 0x0B0F12)
    static let editorChrome = NSColor(hex: 0x101418)
    static let editorPanelBackground = NSColor(hex: 0x15191D)
    static let editorPanelHeader = NSColor(hex: 0x1B2025)
    static let editorSurfaceControl = NSColor(hex: 0x20252A)
    static let editorSurfaceSelected = NSColor(hex: 0x263244)
    static let editorBorderSubtle = NSColor(hex: 0x2B3238)
    static let editorBorderStrong = NSColor(hex: 0x3A424A)
    static let editorTextPrimary = NSColor(hex: 0xF3F6F8)
    static let editorTextSecondary = NSColor(hex: 0xB6BEC7)
    static let editorTextMuted = NSColor(hex: 0x7E8893)
    static let editorAccentBlue = NSColor(hex: 0x2F8CFF)
    static let editorSuccessGreen = NSColor(hex: 0x51C96B)

    // Timeline-specific tokens from design spec (timeline-ui.spec.json).
    static let timelineFitGreen = NSColor(hex: 0x49A862)
    static let timelineClipBlue = NSColor(hex: 0x2F73D9)
    static let timelinePlayheadRed = NSColor(hex: 0xE4525A)
    static let timelineTrackBandA = NSColor(hex: 0x15191D)
    static let timelineTrackBandB = NSColor(hex: 0x171C21)
    static let timelineLabelColumnBackground = NSColor(hex: 0x11161A)
    static let timelineSpliceBorder = NSColor(hex: 0x0B0F12)
    static let timelineDropTargetBorder = NSColor(hex: 0x2F8CFF)
}
