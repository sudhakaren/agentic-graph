import SwiftUI

struct SettingsContentView: View {
    @Bindable var document: GraphDocument
    @Bindable var llmStore: LLMProviderStore
    let patternStore: AnalysisPatternStore
    @Bindable var sizingConfig: SizingConfigStore
    @Bindable var latencyConfig: LatencyConfigStore
    @Binding var selectedPatternID: UUID?
    @Binding var showAddPatternForm: Bool
    @State private var defaults: [String: NodeDefaults] = NodeDefaults.loadAll()

    var body: some View {
        Group {
            if document.settingsTab == "general" {
                GeneralSettingsTab()
            } else if document.settingsTab == "llm" {
                LLMSettingsTab(store: llmStore)
            } else if document.settingsTab == "analysisConfig" {
                AnalysisConfigTab(store: patternStore)
            } else if document.settingsTab == "analysis" {
                PatternListView(store: patternStore, selectedPatternID: $selectedPatternID, showAddForm: $showAddPatternForm)
            } else if document.settingsTab == "promptAnalysis" {
                PromptAnalysisSettingsTab()
            } else if document.settingsTab == "sizing" {
                SizingSettingsTab(config: sizingConfig)
            } else if document.settingsTab == "latency" {
                LatencySettingsTab(config: latencyConfig)
            } else if let kind = NodeKind(rawValue: document.settingsTab) {
                NodeDefaultsTab(kind: kind, defaults: $defaults)
            } else {
                Text("Select a settings tab")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
