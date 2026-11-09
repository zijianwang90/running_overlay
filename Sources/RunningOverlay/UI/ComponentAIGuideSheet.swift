import AppKit
import SwiftUI

/// The AI client a user wants to author components with.
enum ComponentAIClient: String, CaseIterable, Identifiable {
    case claudeCode
    case codex
    case claudeDesktop
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .claudeDesktop: "Claude Desktop"
        case .other: "Other AI"
        }
    }

    static let serverName = "running-overlay"

    /// The one-time connection instruction for MCP-capable clients, or nil
    /// when the client has no MCP and uses the copy/paste flow instead.
    func connectCommand(executablePath: String) -> String? {
        let quoted = "\"\(executablePath)\""
        switch self {
        case .claudeCode:
            return "claude mcp add \(Self.serverName) -- \(quoted) --mcp"
        case .codex:
            return "codex mcp add \(Self.serverName) -- \(quoted) --mcp"
        case .claudeDesktop:
            let config: [String: Any] = [
                "mcpServers": [Self.serverName: ["command": executablePath, "args": ["--mcp"]]]
            ]
            let data = (try? JSONSerialization.data(
                withJSONObject: config,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )) ?? Data()
            return String(decoding: data, as: UTF8.self)
        case .other:
            return nil
        }
    }

    var connectHint: String {
        switch self {
        case .claudeCode, .codex:
            "Run once in Terminal to connect Running Overlay Studio:"
        case .claudeDesktop:
            "In Claude Desktop, open Settings › Developer › Edit Config, add this server to the config file, then restart Claude Desktop:"
        case .other:
            "Copy the authoring prompt, paste it into your AI chat together with your idea, then paste the component JSON it returns back here."
        }
    }

    static let examplePrompt = """
    Use the running-overlay tools to design a compact heart-rate card: a large BPM value, \
    a ring colored by heart-rate zone and a 60-second trend line. Preview it on the sample \
    workout, refine it, then save it as a draft named hr-ring.
    """

    /// The self-contained prompt for chat apps without MCP: procedure, guide
    /// and full specification, so the model needs no repository access.
    static func authoringPrompt() -> String {
        let sections: [(String, ComponentAuthoringGuide.Topic)] = [
            ("Authoring workflow", .workflow),
            ("Authoring guide", .guide),
            ("Specification", .spec)
        ]
        var text = """
        You are designing an overlay component for Running Overlay Studio, a macOS app that \
        draws sports data over running videos. Components are declarative JSON documents in \
        the ros.component/0.1 format described below. Reply with one complete component JSON \
        document in a single code block. Use your own id prefix (not "studio."), a semantic \
        version and an explicit license. You cannot run the validator here, so follow the \
        specification exactly.

        My request:
        [Describe the overlay you want here]
        """
        for (title, topic) in sections {
            guard let body = ComponentAuthoringGuide.text(for: topic) else { continue }
            text += "\n\n---\n\n# \(title)\n\n\(body)"
        }
        return text
    }
}

/// Explains how to create components with an AI client and wires the result
/// back into the Overlay Pool's Drafts section.
struct ComponentAIGuideSheet: View {
    @EnvironmentObject private var drafts: ComponentDraftLibrary
    @Environment(\.dismiss) private var dismiss
    @AppStorage("componentAIClient") private var clientRawValue = ComponentAIClient.claudeCode.rawValue
    @State private var copiedKey: String?
    @State private var pasteMessage: (text: String, isError: Bool)?

    private var client: ComponentAIClient {
        ComponentAIClient(rawValue: clientRawValue) ?? .claudeCode
    }

    private var executablePath: String {
        Bundle.main.executablePath ?? "/Applications/Running Overlay Studio.app/Contents/MacOS/RunningOverlay"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.space4) {
            HStack(spacing: EditorTheme.space3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(EditorTheme.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Components with AI")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(EditorTheme.textPrimary)
                    Text("Describe an overlay; your AI designs it, previews it and saves it to Drafts here.")
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textMuted)
                }
            }

            Picker("", selection: $clientRawValue) {
                ForEach(ComponentAIClient.allCases) { client in
                    Text(client.label).tag(client.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            step(1, title: client == .other ? "Copy the prompt" : "Connect (once)") {
                Text(client.connectHint)
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let command = client.connectCommand(executablePath: executablePath) {
                    codeBlock(command, key: "connect")
                } else {
                    HStack(spacing: EditorTheme.space2) {
                        Button {
                            copy(ComponentAIClient.authoringPrompt(), key: "prompt")
                        } label: {
                            Label(copiedKey == "prompt" ? "Copied" : "Copy Authoring Prompt", systemImage: "doc.on.doc")
                        }
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("Paste Component JSON", systemImage: "doc.on.clipboard")
                        }
                    }
                    .controlSize(.small)
                    if let pasteMessage {
                        Text(pasteMessage.text)
                            .font(EditorTheme.captionFont)
                            .foregroundStyle(pasteMessage.isError ? Color.orange : EditorTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }

            if client != .other {
                step(2, title: "Ask for a component") {
                    Text("Describe the overlay in \(client.label). For example:")
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textSecondary)
                    codeBlock(ComponentAIClient.examplePrompt, key: "example", monospaced: false)
                }
            }

            step(client == .other ? 2 : 3, title: "Review in Drafts") {
                Text(client == .other
                    ? "Pasted components appear under Overlay Pool › Components › Drafts. Click one to add it to the canvas."
                    : "Saved drafts appear under Overlay Pool › Components › Drafts. Click one to add it to the canvas. When the AI saves the same draft again, placed instances update in place; Undo reverts an update.")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: EditorTheme.space2) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(EditorTheme.textMuted)
                Text("Previews use a synthetic workout and sample weather. Your activities and projects are never shared with the AI.")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Show Drafts Folder") {
                    try? drafts.store.ensureDirectory()
                    NSWorkspace.shared.activateFileViewerSelecting([drafts.store.directory])
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(EditorTheme.space5)
        .frame(width: 520)
        .background(EditorTheme.panelBackground)
    }

    private func step<Content: View>(
        _ number: Int,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: EditorTheme.space3) {
            Text("\(number)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EditorTheme.textPrimary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(EditorTheme.surfaceControl))
            VStack(alignment: .leading, spacing: EditorTheme.space2) {
                Text(title)
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                content()
            }
            Spacer(minLength: 0)
        }
    }

    private func codeBlock(_ text: String, key: String, monospaced: Bool = true) -> some View {
        HStack(alignment: .top, spacing: EditorTheme.space2) {
            Text(text)
                .font(monospaced ? .system(size: 11, design: .monospaced) : EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                copy(text, key: key)
            } label: {
                Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .help("Copy")
        }
        .padding(EditorTheme.space2)
        .background(
            RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                .fill(EditorTheme.surfaceControl)
        )
    }

    private func copy(_ text: String, key: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedKey = key
    }

    private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            pasteMessage = ("The clipboard has no text.", true)
            return
        }
        do {
            let draft = try drafts.saveDraft(fromPastedText: text)
            pasteMessage = ("Saved draft “\(draft.displayName)”. It is listed under Drafts.", false)
        } catch let error as OverlayComponentValidationError {
            pasteMessage = (
                "The component is invalid:\n" + error.diagnostics
                    .filter { $0.severity == .error }
                    .prefix(6)
                    .map { "\($0.path): \($0.message)" }
                    .joined(separator: "\n"),
                true
            )
        } catch {
            pasteMessage = (error.localizedDescription, true)
        }
    }
}
