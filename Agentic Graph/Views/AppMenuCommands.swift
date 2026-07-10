import SwiftUI

/// Adds a standard "Settings" item to the app menu (⌘,), in addition to the
/// gear button in the sidebar. The app shows settings as an in-window mode
/// rather than a separate window, so this just switches the focused
/// document's view mode.
struct AppMenuCommands: Commands {
    @FocusedValue(\.document) var document

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                document?.viewMode = .settings
            }
            .keyboardShortcut(",", modifiers: .command)
            .disabled(document == nil)
        }
    }
}
