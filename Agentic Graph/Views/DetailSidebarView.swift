import SwiftUI

struct DetailSidebarView: View {
    @Bindable var document: GraphDocument
    @Bindable var engine: GraphAnalysisEngine
    @Bindable var promptEngine: PromptAnalysisEngine
    let patternStore: AnalysisPatternStore
    let llmStore: LLMProviderStore
    let sizingConfig: SizingConfigStore
    let latencyConfig: LatencyConfigStore

    /// The inspector tab to actually show. Analysis and Prompt Analysis fold
    /// back to Properties when AI analysis is disabled.
    private var currentTab: GraphDocument.InspectorTab {
        let tab = document.inspectorTab
        if llmStore.analysisDisabled, tab == .analysis || tab == .promptAnalysis {
            return .properties
        }
        return tab
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            if currentTab == .analysis || currentTab == .promptAnalysis {
                aiDisclaimer
            }
            if currentTab == .sizing {
                sizingDisclaimer
            }
            Divider()
            tabContent
        }
    }

    private var aiDisclaimer: some View {
        HStack(spacing: 6) {
            Text("AI")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.2)))
            Text("Analysis is AI-assisted. Findings should be verified by a qualified reviewer.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var sizingDisclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Estimates based on graph structure and sizing rules of thumb. Actual requirements may vary.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var tabPicker: some View {
        Picker("Inspector", selection: Binding(
            get: { currentTab },
            set: { document.inspectorTab = $0 }
        )) {
            Image(systemName: "sidebar.right")
                .help("Properties")
                .tag(GraphDocument.InspectorTab.properties)
            Image(systemName: "bubble.left.and.bubble.right")
                .help("Comments")
                .tag(GraphDocument.InspectorTab.comments)
            if !llmStore.analysisDisabled {
                Image(systemName: "wand.and.stars")
                    .help("Analysis")
                    .tag(GraphDocument.InspectorTab.analysis)
            }
            Image(systemName: "square.stack.3d.up")
                .help("Sizing")
                .tag(GraphDocument.InspectorTab.sizing)
            Image(systemName: "chart.xyaxis.line")
                .help("Load Simulation (BETA)")
                .tag(GraphDocument.InspectorTab.loadSimulation)
            if !llmStore.analysisDisabled {
                Image(systemName: "text.magnifyingglass")
                    .help("Prompt Analysis")
                    .tag(GraphDocument.InspectorTab.promptAnalysis)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch currentTab {
        case .properties:
            InspectorView(document: document)
        case .analysis:
            AnalysisInspectorView(document: document, engine: engine, patternStore: patternStore, llmStore: llmStore)
        case .sizing:
            SizingInspectorView(document: document, sizingConfig: sizingConfig)
        case .promptAnalysis:
            PromptAnalysisInspectorView(document: document, engine: promptEngine, llmStore: llmStore)
        case .loadSimulation:
            LoadSimulationInspectorView(document: document, latencyConfig: latencyConfig)
        case .comments:
            CommentsInspectorView(document: document)
        }
    }
}
