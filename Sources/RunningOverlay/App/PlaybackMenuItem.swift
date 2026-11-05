/// Items in the Playback menu, in menu order.
///
/// Titles never name a key. Space, J and L are menu key equivalents, so the
/// menu shows them in its shortcut column. K, Home, End and the arrow keys are
/// handled by the editor (`MainEditorView`) instead, because a menu key
/// equivalent would fire before a focused list or text field could use them;
/// those keys are listed in the item's help tag.
enum PlaybackMenuItem: CaseIterable {
    case playPause
    case playFaster
    case playSlower
    case goToStart
    case goToEnd
    case previousEditPoint
    case nextEditPoint

    func title(isPlaying: Bool) -> String {
        switch self {
        case .playPause: return isPlaying ? "Pause" : "Play"
        case .playFaster: return "Play Faster"
        case .playSlower: return "Play Slower"
        case .goToStart: return "Go to Start"
        case .goToEnd: return "Go to End"
        case .previousEditPoint: return "Previous Edit Point"
        case .nextEditPoint: return "Next Edit Point"
        }
    }

    /// Keys the editor handles for this item outside the menu.
    var editorKeysHelp: String? {
        switch self {
        case .playPause: return "Also K"
        case .playFaster, .playSlower: return nil
        case .goToStart: return "Home"
        case .goToEnd: return "End"
        case .previousEditPoint: return "Up Arrow"
        case .nextEditPoint: return "Down Arrow"
        }
    }
}
