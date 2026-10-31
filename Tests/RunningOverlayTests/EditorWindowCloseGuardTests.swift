import Testing
@testable import RunningOverlay

@MainActor
struct EditorWindowCloseGuardTests {
    @Test func cancellingThePromptKeepsTheWindowOpen() {
        let guardian = EditorWindowCloseGuard()
        var didClose = false

        let closed = guardian.requestClose(confirm: { false }, close: { didClose = true })

        #expect(!closed)
        #expect(!didClose)
        #expect(!guardian.closeWasConfirmed)
    }

    @Test func thePromptRunsBeforeTheWindowCloses() {
        let guardian = EditorWindowCloseGuard()
        var events: [String] = []

        let closed = guardian.requestClose {
            events.append("prompt")
            return true
        } close: {
            events.append("close")
        }

        #expect(closed)
        #expect(events == ["prompt", "close"])
        #expect(guardian.closeWasConfirmed)
    }
}
