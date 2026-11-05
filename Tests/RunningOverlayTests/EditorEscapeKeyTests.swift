import AppKit
import Testing
@testable import RunningOverlay

struct EditorEscapeKeyTests {
    private func decide(
        keyCode: UInt16 = EditorEscapeKey.keyCode,
        modifiers: NSEvent.ModifierFlags = [],
        hasSelection: Bool = true,
        isTextInputFocused: Bool = false,
        hasAttachedSheet: Bool = false
    ) -> Bool {
        EditorEscapeKey.shouldClearSelection(
            keyCode: keyCode,
            modifiers: modifiers,
            hasSelection: hasSelection,
            isTextInputFocused: isTextInputFocused,
            hasAttachedSheet: hasAttachedSheet
        )
    }

    @Test func plainEscapeClearsASelection() {
        #expect(decide())
    }

    @Test func escapeIsLeftAloneWhenItHasAnotherOwner() {
        #expect(!decide(hasSelection: false))
        #expect(!decide(isTextInputFocused: true))
        #expect(!decide(hasAttachedSheet: true))
        #expect(!decide(modifiers: .command))
        #expect(!decide(keyCode: 49))
    }

    @Test func capsLockDoesNotBlockEscape() {
        #expect(decide(modifiers: .capsLock))
    }

    @MainActor @Test func onlyEditableTextCountsAsTextInput() {
        let editable = NSTextView()
        let readOnly = NSTextView()
        readOnly.isEditable = false
        #expect(EditorEscapeKey.isTextInput(editable))
        #expect(EditorEscapeKey.isTextInput(NSTextField()))
        #expect(!EditorEscapeKey.isTextInput(readOnly))
        #expect(!EditorEscapeKey.isTextInput(NSView()))
        #expect(!EditorEscapeKey.isTextInput(nil))
    }
}
