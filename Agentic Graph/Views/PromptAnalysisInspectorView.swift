import SwiftUI
import AppKit

struct PromptAnalysisInspectorView: View {
    @Bindable var document: GraphDocument
    @Bindable var engine: PromptAnalysisEngine
    let llmStore: LLMProviderStore
    @AppStorage(PromptAnalysisEngine.includeRoutingDetailsKey) private var includeRoutingDetails: Bool = false

    /// Analysis mode per agent. .chain is set by the Chain button; .single by Copy or default.
    @State private var modes: [UUID: PromptAnalysisMode] = [:]
    /// Pending overwrite action awaiting user confirmation.
    @State private var pendingOverwrite: PendingOverwrite?
    /// When true, show the debug sheet.
    @State private var showDebugSheet = false

    private struct PendingOverwrite: Identifiable {
        let id = UUID()
        let kind: Kind
        let agentID: UUID
        let newValue: String
        enum Kind { case copy, chain }
        var title: String {
            switch kind {
            case .copy: String(localized: "Replace prompt with agent instructions?")
            case .chain: String(localized: "Replace prompt with chain instructions?")
            }
        }
    }

    var body: some View {
        Group {
            if let agent = selectedAgent {
                agentView(agent)
            } else {
                emptyView
            }
        }
        .onChange(of: document.selectedNodeID) { _, _ in
            // Reset transient analysis state when selection changes
            if case .completed = engine.state { engine.reset() }
            if case .failed = engine.state { engine.reset() }
        }
    }

    private var selectedAgent: GraphNode? {
        guard document.totalSelectedCount < 2,
              let index = document.selectedNodeIndex,
              index < document.nodes.count else { return nil }
        let node = document.nodes[index]
        return node.kind == .agent ? node : nil
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Prompt Analysis")
                .font(.title3)
            Text("Please select an agent node to analyse.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Agent View

    @ViewBuilder
    private func agentView(_ agent: GraphNode) -> some View {
        let key = agent.id.uuidString
        let promptBinding = Binding<String>(
            get: { document.promptAnalysisDrafts[key] ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    document.promptAnalysisDrafts.removeValue(forKey: key)
                } else {
                    document.promptAnalysisDrafts[key] = newValue
                }
                document.isDirty = true
            }
        )
        let callers = document.directAgentCallers(of: agent.id)
        let chainAvailable = callers.count == 1

        VStack(spacing: 0) {
            // Fixed top: header, prompt, actions
            VStack(alignment: .leading, spacing: 12) {
                agentHeader(agent)
                promptSection(agent: agent, binding: promptBinding, chainAvailable: chainAvailable)
                actionsSection(agent: agent, prompt: promptBinding.wrappedValue)
            }
            .padding(10)

            Divider()

            // Scrollable bottom: results / errors
            ScrollView {
                resultsSection
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .alert(item: $pendingOverwrite) { pending in
            Alert(
                title: Text(pending.title),
                message: Text("The prompt field has content that doesn't match. This action will replace it."),
                primaryButton: .destructive(Text("Replace")) {
                    applyOverwrite(pending.kind, agentID: pending.agentID,
                                   newValue: pending.newValue, binding: promptBinding)
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showDebugSheet) {
            if let debug = engine.lastDebug {
                PromptAnalysisDebugWindow(info: debug)
            }
        }
    }

    // MARK: - Header

    private func agentHeader(_ agent: GraphNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: agent.kind.sfSymbol)
                .foregroundStyle(agent.kind.color)
            Text(agent.title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text("Agent")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Prompt Editor

    private func promptSection(agent: GraphNode, binding: Binding<String>,
                               chainAvailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prompt")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextEditor(text: binding)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140, maxHeight: 240)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))

            HStack(spacing: 8) {
                Button {
                    attemptOverwrite(.copy, agent: agent, binding: binding,
                                     newValue: agent.agentInstructions ?? "")
                } label: {
                    Label("Copy from agent", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .help("Copy this agent's instructions into the prompt field")

                Button {
                    attemptOverwrite(.chain, agent: agent, binding: binding,
                                     newValue: chainedPrompt(for: agent))
                } label: {
                    Label("Chain", systemImage: "link")
                        .font(.caption)
                }
                .disabled(!chainAvailable)
                .help(chainAvailable
                    ? "Concatenate the linear upstream agent chain into the prompt"
                    : "Disabled: this agent has \(document.directAgentCallers(of: agent.id).count) upstream agent caller(s); chain requires exactly 1")

                if !engine.targetLanguage.isEmpty {
                    Button {
                        runTranslate(binding: binding, reverse: false)
                    } label: {
                        if engine.isTranslating {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                                Text("Translating...").font(.caption)
                            }
                        } else {
                            Label("To \(engine.targetLanguage)", systemImage: "character.bubble")
                                .font(.caption)
                        }
                    }
                    .disabled(engine.isTranslating
                              || binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Translate the prompt field into \(engine.targetLanguage). Change the target language in Settings → Prompt Analysis.")
                }

                if !engine.reverseTargetLanguage.isEmpty {
                    Button {
                        runTranslate(binding: binding, reverse: true)
                    } label: {
                        Label("To \(engine.reverseTargetLanguage)", systemImage: "arrow.uturn.left")
                            .font(.caption)
                    }
                    .disabled(engine.isTranslating
                              || binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Translate the prompt field into \(engine.reverseTargetLanguage). Change in Settings → Prompt Analysis.")
                }

                Spacer()
            }

            if let err = engine.translationError, !err.isEmpty {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func attemptOverwrite(_ kind: PendingOverwrite.Kind, agent: GraphNode,
                                  binding: Binding<String>, newValue: String) {
        let current = binding.wrappedValue
        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCurrent.isEmpty && current != newValue {
            pendingOverwrite = PendingOverwrite(kind: kind, agentID: agent.id, newValue: newValue)
        } else {
            applyOverwrite(kind, agentID: agent.id, newValue: newValue, binding: binding)
        }
    }

    private func applyOverwrite(_ kind: PendingOverwrite.Kind, agentID: UUID,
                                newValue: String, binding: Binding<String>) {
        binding.wrappedValue = newValue
        modes[agentID] = (kind == .chain) ? .chain : .single
    }

    private func runTranslate(binding: Binding<String>, reverse: Bool) {
        let text = binding.wrappedValue
        Task {
            do {
                let translated: String
                if reverse {
                    translated = try await engine.reverseTranslate(text: text, llmStore: llmStore)
                } else {
                    translated = try await engine.translate(text: text, llmStore: llmStore)
                }
                await MainActor.run { binding.wrappedValue = translated }
            } catch {
                await MainActor.run { engine.translationError = error.localizedDescription }
            }
        }
    }

    private func chainedPrompt(for agent: GraphNode) -> String {
        let chain = document.upstreamAgentChain(endingAt: agent.id)
        return chain.map { node in
            let title = node.title
            let body = node.agentInstructions ?? ""
            return "# \(title)\n\(body)"
        }
        .joined(separator: "\n\n---\n\n")
    }

    // MARK: - Actions

    private func actionsSection(agent: GraphNode, prompt: String) -> some View {
        let mode = modes[agent.id] ?? .single
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $includeRoutingDetails) {
                HStack(spacing: 4) {
                    Text("Include routing details").font(.caption)
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("Treats each agent's Details field as its routing description — what the agent does, used by upstream agents to decide where to route requests.")
                }
            }
            .toggleStyle(.checkbox)

            HStack {
                Button {
                    let context = buildContext(for: agent, mode: mode)
                    engine.analyze(prompt: prompt, context: context, llmStore: llmStore)
                } label: {
                    if case .analyzing = engine.state {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                            Text("Analysing...")
                        }
                    } else {
                        Label("Analyse", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || engine.state == .analyzing)

                if case .analyzing = engine.state {
                    Button("Cancel") { engine.cancel() }
                        .buttonStyle(.plain)
                        .font(.caption)
                }

                Spacer()

                if engine.lastDebug != nil {
                    Button {
                        showDebugSheet = true
                    } label: {
                        Image(systemName: "ladybug")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Show what was sent to the LLM")
                }

                modeBadge(mode: mode, agent: agent)
            }
        }
    }

    private func modeBadge(mode: PromptAnalysisMode, agent: GraphNode) -> some View {
        let chain = document.upstreamAgentChain(endingAt: agent.id)
        let label: String
        let icon: String
        switch mode {
        case .single:
            label = String(localized: "Single agent")
            icon = "person.fill"
        case .chain:
            label = String(format: String(localized: "Chain (%lld)"), chain.count)
            icon = "link"
        }
        return HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(verbatim: label).font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(.quaternary.opacity(0.5)))
        .help(mode == .chain
              ? "Analysis will treat the prompt as a multi-agent chain with \(chain.count) agents."
              : "Analysis will treat the prompt as a single agent's instructions.")
    }

    private func buildContext(for agent: GraphNode, mode: PromptAnalysisMode) -> PromptAnalysisContext {
        let withRouting = includeRoutingDetails
        switch mode {
        case .single:
            return PromptAnalysisContext(
                mode: .single,
                agents: [document.promptAnalysisSlice(forAgent: agent, includeRoutingDetail: withRouting)]
            )
        case .chain:
            let chain = document.upstreamAgentChain(endingAt: agent.id)
            let slices = chain.map {
                document.promptAnalysisSlice(forAgent: $0, includeRoutingDetail: withRouting)
            }
            // If chain collapsed to a single agent (no upstream), fall back to single mode framing.
            if slices.count <= 1 {
                return PromptAnalysisContext(mode: .single, agents: slices)
            }
            return PromptAnalysisContext(mode: .chain, agents: slices)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        switch engine.state {
        case .idle:
            EmptyView()
        case .analyzing:
            EmptyView()
        case .completed(let result):
            completedResults(result)
        case .failed(let message):
            failedView(message)
        case .unavailable(let reason):
            unavailableView(reason)
        }
    }

    private func completedResults(_ result: PromptAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(result.issues.count) \(result.issues.count == 1 ? "issue" : "issues")")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(result.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button {
                    appendAnalysisToComments(result)
                } label: {
                    Image(systemName: "text.append")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Append this analysis to the agent's Comments")
                Button {
                    copyAnalysisToClipboard(result)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy this analysis to the clipboard")
            }

            if result.issues.isEmpty {
                Text("No issues found in the prompt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(result.issues) { issue in
                    IssueRowView(issue: issue)
                }
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Analysis Failed")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func unavailableView(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.secondary)
                Text("Provider Unavailable")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Result Actions

    /// Formats an analysis result as a plain-text block for the Comments field or clipboard.
    /// Labels are localised; the date, dashes, and blank lines are language-neutral.
    private func formattedAnalysis(_ result: PromptAnalysisResult) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - HH:mm"
        let stamp = formatter.string(from: result.timestamp)
        let header = "---- " + String(localized: "Analysis - \(stamp)") + " ----"

        let body: [String]
        if result.issues.isEmpty {
            body = [String(localized: "No issues found in the prompt.")]
        } else {
            let issueLabel = String(localized: "Issue:")
            let recLabel = String(localized: "Recommendation:")
            body = result.issues.map { issue in
                var block = "-- \(issue.title) --\n"
                block += issueLabel + "\n"
                block += issue.detail + "\n\n"
                block += recLabel + "\n"
                block += issue.recommendation
                return block
            }
        }
        return header + "\n\n" + body.joined(separator: "\n\n") + "\n"
    }

    /// Appends the formatted analysis to the selected agent's Comments field,
    /// with a blank line above the block so runs stay visually separated.
    private func appendAnalysisToComments(_ result: PromptAnalysisResult) {
        guard let index = document.selectedNodeIndex,
              index < document.nodes.count,
              document.nodes[index].kind == .agent else { return }
        let block = formattedAnalysis(result)
        let existing = document.nodes[index].comments ?? ""
        let combined: String
        if existing.isEmpty {
            combined = block
        } else {
            let base = existing.hasSuffix("\n") ? existing : existing + "\n"
            combined = base + "\n" + block
        }
        document.nodes[index].comments = combined
        document.isDirty = true
    }

    /// Copies the formatted analysis to the system clipboard.
    private func copyAnalysisToClipboard(_ result: PromptAnalysisResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedAnalysis(result), forType: .string)
    }
}

// MARK: - Debug Window

private struct PromptAnalysisDebugWindow: View {
    let info: PromptAnalysisDebugInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryRow
                    section("System Prompt", text: info.systemPrompt)
                    section("User Message", text: info.userMessage)
                    if let raw = info.rawResponse {
                        section("Raw Response", text: raw)
                    }
                    if let err = info.error {
                        section("Error", text: err, accent: .orange)
                    }
                }
                .padding()
            }
        }
        .frame(width: 620, height: 640)
    }

    private var header: some View {
        HStack {
            Image(systemName: "ladybug")
                .foregroundStyle(.secondary)
            Text("Prompt Analysis — Last LLM Exchange")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            pill(label: "Time", value: info.timestamp.formatted(date: .omitted, time: .shortened), icon: "clock")
            if let duration = info.duration {
                pill(label: "Duration", value: String(format: "%.2fs", duration), icon: "stopwatch")
            }
            if let raw = info.rawResponse {
                pill(label: "Response",
                     value: String(format: String(localized: "%lld chars"), raw.count),
                     icon: "doc.text")
            } else if info.error == nil {
                pill(label: "Status", value: String(localized: "Pending"), icon: "hourglass")
            }
            Spacer()
        }
    }

    private func pill(label: LocalizedStringKey, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.body)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, text: String, accent: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
            }
        }
    }
}

// MARK: - Issue Row

private struct IssueRowView: View {
    let issue: PromptAnalysisIssue
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: severityIcon)
                    .foregroundStyle(severityColor)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(issue.title)
                            .font(.system(size: 13, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            isExpanded.toggle()
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    if isExpanded {
                        if !issue.detail.isEmpty {
                            Text(issue.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !issue.recommendation.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recommendation")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .textCase(.uppercase)
                                Text(issue.recommendation)
                                    .font(.system(size: 12))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
    }

    private var severityIcon: String {
        switch issue.severity?.lowercased() {
        case "warning": "exclamationmark.triangle.fill"
        case "recommendation": "lightbulb.fill"
        case "info": "info.circle.fill"
        default: "circle.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity?.lowercased() {
        case "warning": .orange
        case "recommendation": .blue
        case "info": .secondary
        default: .secondary
        }
    }
}
