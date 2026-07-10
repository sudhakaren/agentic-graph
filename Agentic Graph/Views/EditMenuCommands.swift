import SwiftUI

/// Adds a "Find" item (⌘F) to the Edit menu. It reveals the floating find
/// panel on the focused document's canvas.
struct EditMenuCommands: Commands {
    @FocusedValue(\.document) var document

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find…") {
                document?.showFindPanel = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(document == nil)
        }
    }
}
