import SwiftUI

struct ArrangeMenuCommands: Commands {
    @FocusedValue(\.document) var document

    var body: some Commands {
        CommandMenu("Arrange") {
            Button("Align Left") {
                document?.alignSelectedNodes(.left)
            }
            .keyboardShortcut("[", modifiers: [.command, .option])
            .disabled(!(document?.canAlign ?? false))

            Button("Align Center") {
                document?.alignSelectedNodes(.centerH)
            }
            .disabled(!(document?.canAlign ?? false))

            Button("Align Right") {
                document?.alignSelectedNodes(.right)
            }
            .keyboardShortcut("]", modifiers: [.command, .option])
            .disabled(!(document?.canAlign ?? false))

            Divider()

            Button("Align Top") {
                document?.alignSelectedNodes(.top)
            }
            .disabled(!(document?.canAlign ?? false))

            Button("Align Middle") {
                document?.alignSelectedNodes(.centerV)
            }
            .disabled(!(document?.canAlign ?? false))

            Button("Align Bottom") {
                document?.alignSelectedNodes(.bottom)
            }
            .disabled(!(document?.canAlign ?? false))

            Divider()

            Button("Distribute Horizontally") {
                document?.distributeSelectedNodes(.horizontal)
            }
            .disabled(!(document?.canDistribute ?? false))

            Button("Distribute Vertically") {
                document?.distributeSelectedNodes(.vertical)
            }
            .disabled(!(document?.canDistribute ?? false))

            Divider()

            Button("Group Selection") {
                document?.groupSelectedNodes()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(!(document?.canGroup ?? false))

            Button("Ungroup") {
                document?.ungroupSelectedNodes()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!(document?.canUngroup ?? false))
        }
    }
}
