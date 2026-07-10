import SwiftUI

struct AnalysisMenuCommands: Commands {
    @FocusedValue(\.analyzeGraphAction) var analyzeAction
    @FocusedValue(\.analysisDisabled) var analysisDisabled

    var body: some Commands {
        CommandMenu("Analysis") {
            Button("Analyze Architecture...") {
                analyzeAction?()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(analyzeAction == nil || analysisDisabled == true)
        }
    }
}
