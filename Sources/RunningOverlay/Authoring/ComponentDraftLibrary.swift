import Combine
import Foundation

/// Live view of the component drafts folder for the Overlay Pool.
///
/// The folder is polled once per second; a draft whose file changes while the
/// app runs is pushed into the open project, so instances added from it
/// update in place as an AI client keeps editing. Changes that happened while
/// the app was closed are not applied to existing instances.
@MainActor
final class ComponentDraftLibrary: ObservableObject {
    @Published private(set) var drafts: [ComponentDraft] = []

    let store: ComponentDraftStore
    private weak var project: ProjectDocument?
    private var fingerprint: [String: String]?
    private var timer: Timer?

    init(store: ComponentDraftStore = ComponentDraftStore()) {
        self.store = store
    }

    func start(project: ProjectDocument, interval: TimeInterval = 1) {
        self.project = project
        try? store.ensureDirectory()
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Rescans when the folder changed and reloads drafts whose files changed
    /// since the previous scan. The first scan only records the baseline.
    func refresh() {
        let current = store.fingerprint()
        guard current != fingerprint else { return }
        let previous = fingerprint
        fingerprint = current
        drafts = store.drafts()
        guard let previous, let project else { return }
        for draft in drafts {
            let key = draft.url.lastPathComponent
            guard previous[key] != current[key], let reference = draft.reference else { continue }
            project.reloadComponentDefinition(reference, displayName: draft.displayName)
        }
    }

    @discardableResult
    func saveDraft(fromPastedText text: String) throws -> ComponentDraft {
        let draft = try store.saveDraft(fromPastedText: text)
        refresh()
        return draft
    }

    func delete(_ draft: ComponentDraft) throws {
        try store.delete(draft)
        refresh()
    }
}
