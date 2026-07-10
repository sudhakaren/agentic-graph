import Foundation

// MARK: - Analysis State

struct PatternStatus: Equatable, Identifiable {
    let id: Int // pattern number
    let name: String
    var state: PatternRunState

    enum PatternRunState: Equatable {
        case pending
        case running
        case done(FindingSeverity?)  // nil = not applicable, severity = finding generated
    }
}

struct AnalysisProgress: Equatable {
    var patterns: [PatternStatus]

    var completedCount: Int {
        patterns.filter { if case .done = $0.state { return true }; return false }.count
    }
}

enum AnalysisState: Equatable {
    case idle
    case analyzing(progress: AnalysisProgress)
    case completed(AnalysisResult)
    case failed(String)
    case unavailable(String)

    static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.analyzing(let a), .analyzing(let b)): a == b
        case (.completed, .completed): true
        case (.failed(let a), .failed(let b)): a == b
        case (.unavailable(let a), .unavailable(let b)): a == b
        default: false
        }
    }
}

// MARK: - Analysis Engine

@Observable
class GraphAnalysisEngine {
    var state: AnalysisState = .idle
    private var analysisTask: Task<Void, Never>?

    func analyze(document: GraphDocument, patternStore: AnalysisPatternStore, llmStore: LLMProviderStore? = nil) {
        analysisTask?.cancel()
        state = .analyzing(progress: AnalysisProgress(patterns: []))

        let resolvedStore = llmStore ?? LLMProviderStore()
        let provider = LLMProviderFactory.create(store: resolvedStore)
        let concurrency = resolvedStore.settings(for: resolvedStore.activeProvider).concurrency ?? resolvedStore.activeProvider.defaultConcurrency

        analysisTask = Task {
            do {
                let result = try await performAnalysis(document: document, patternStore: patternStore, provider: provider, maxConcurrency: concurrency)
                if !Task.isCancelled {
                    document.lastAnalysisResult = result
                    state = .completed(result)
                }
            } catch is CancellationError {
                // cancel() already set state to .idle — don't override it
            } catch {
                if !Task.isCancelled {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancel() {
        analysisTask?.cancel()
        state = .idle
    }

    /// Load the last saved analysis result from the document, if any.
    func loadLastResult(from document: GraphDocument) {
        if let result = document.lastAnalysisResult {
            state = .completed(result)
        }
    }

    // MARK: - Analysis Execution

    private func performAnalysis(document: GraphDocument, patternStore: AnalysisPatternStore, provider: LLMProvider, maxConcurrency: Int) async throws -> AnalysisResult {
        // Early return for empty graphs
        let functionalNodes = document.nodes.filter { !$0.kind.isShape }
        let hasAgents = functionalNodes.contains { $0.kind == .agent }
        let hasTools = functionalNodes.contains { $0.kind == .tool }
        let hasKnowledge = functionalNodes.contains { $0.kind == .knowledge }
        let hasHumans = functionalNodes.contains { $0.kind == .human }

        if !hasAgents && !hasTools && !hasKnowledge && !hasHumans {
            return AnalysisResult(
                findings: [AnalysisFinding(
                    patternNumber: 0,
                    patternName: "Empty Graph",
                    severity: .info,
                    summary: "No agents, tools, or knowledge sources to analyze.",
                    detail: "Add nodes to the graph to enable architecture analysis.",
                    relatedNodeIDs: [],
                    category: "Foundational",
                    diagnostics: nil
                )],
                timestamp: Date()
            )
        }

        let filterPerPattern = patternStore.filterSummaryPerPattern
        let fullSummary = GraphAnalysisSummarizer.summarize(document: document)
        let enabledPatterns = patternStore.enabledPatterns.sorted { $0.number < $1.number }
        let graphNodes = document.nodes.filter { !$0.kind.isShape }
        let sysInstructions = patternStore.systemPrompt
        let promptTemplate = patternStore.patternPromptTemplate

        // Build initial progress checklist
        var progress = AnalysisProgress(
            patterns: enabledPatterns.map { PatternStatus(id: $0.number, name: $0.name, state: .pending) }
        )
        state = .analyzing(progress: progress)

        // Pre-build all prompts (with per-pattern filtered summaries if enabled)
        let patternPrompts: [(pattern: AnalysisPattern, prompt: String)] = enabledPatterns.map { pattern in
            let summary: String
            if filterPerPattern {
                let kinds = Set(pattern.relevantNodeKinds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                summary = kinds.isEmpty ? fullSummary : GraphAnalysisSummarizer.summarize(document: document, relevantKinds: kinds)
            } else {
                summary = fullSummary
            }
            return (pattern: pattern, prompt: buildPatternPrompt(pattern: pattern, graphSummary: summary, template: promptTemplate))
        }

        // Return type includes pattern number for tracking — can return multiple findings
        typealias EvalResult = (patternNumber: Int, findings: [AnalysisFinding])

        var results: [AnalysisFinding] = []
        var nextIndex = 0

        try await withThrowingTaskGroup(of: EvalResult.self) { group in
            // Mark initial batch as running and seed
            while nextIndex < min(maxConcurrency, patternPrompts.count) {
                let item = patternPrompts[nextIndex]
                if let idx = progress.patterns.firstIndex(where: { $0.id == item.pattern.number }) {
                    progress.patterns[idx].state = .running
                }
                group.addTask { [sysInstructions, graphNodes, provider] in
                    try Task.checkCancellation()
                    let findings = await Self.evaluatePattern(pattern: item.pattern, prompt: item.prompt,
                                                               systemInstructions: sysInstructions, graphNodes: graphNodes,
                                                               provider: provider)
                    return (patternNumber: item.pattern.number, findings: findings)
                }
                nextIndex += 1
            }
            state = .analyzing(progress: progress)

            // As each completes, update status and enqueue next
            for try await evalResult in group {
                try Task.checkCancellation()

                results.append(contentsOf: evalResult.findings)

                // Mark completed — show the most severe finding's severity
                if let idx = progress.patterns.firstIndex(where: { $0.id == evalResult.patternNumber }) {
                    let severity = evalResult.findings.min(by: { $0.severity.sortOrder < $1.severity.sortOrder })?.severity
                    progress.patterns[idx].state = .done(severity)
                }

                // Enqueue next and mark as running
                if nextIndex < patternPrompts.count {
                    let item = patternPrompts[nextIndex]
                    if let idx = progress.patterns.firstIndex(where: { $0.id == item.pattern.number }) {
                        progress.patterns[idx].state = .running
                    }
                    group.addTask { [sysInstructions, graphNodes, provider] in
                        try Task.checkCancellation()
                        let findings = await Self.evaluatePattern(pattern: item.pattern, prompt: item.prompt,
                                                                   systemInstructions: sysInstructions, graphNodes: graphNodes,
                                                                   provider: provider)
                        return (patternNumber: item.pattern.number, findings: findings)
                    }
                    nextIndex += 1
                }

                state = .analyzing(progress: progress)
            }
        }

        return AnalysisResult(
            findings: results.sorted { $0.patternNumber < $1.patternNumber },
            timestamp: Date()
        )
    }

    // MARK: - Single Pattern Evaluation

    private static func evaluatePattern(pattern: AnalysisPattern, prompt: String,
                                         systemInstructions: String, graphNodes: [GraphNode],
                                         provider: LLMProvider) async -> [AnalysisFinding] {
        let startTime = Date()
        let catalogEntry = patternCatalog[pattern.number]

        do {
            let verdict = try await provider.evaluate(systemInstructions: systemInstructions, prompt: prompt)
            let duration = Date().timeIntervalSince(startTime)

            guard !verdict.findings.isEmpty else { return [] }

            return verdict.findings.map { finding in
                let severity: FindingSeverity
                switch finding.severity.lowercased() {
                case "warning": severity = .warning
                case "recommendation": severity = .recommendation
                case "positive": severity = .positive
                default: severity = .info
                }

                let nodeNames = finding.relatedNodeNames
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                let relatedNodeIDs = resolveNodeNames(nodeNames, in: graphNodes)
                let resolvedNames = relatedNodeIDs.compactMap { id in
                    graphNodes.first(where: { $0.id == id })?.title
                }

                let diagnostics = FindingDiagnostics(
                    prompt: prompt,
                    rawResponse: "severity=\(finding.severity), summary=\(finding.summary), detail=\(finding.detail), nodes=\(finding.relatedNodeNames)",
                    resolvedNodeNames: resolvedNames,
                    duration: duration
                )

                return AnalysisFinding(
                    patternNumber: pattern.number,
                    patternName: catalogEntry?.name ?? pattern.name,
                    severity: severity,
                    summary: finding.summary,
                    detail: finding.detail,
                    relatedNodeIDs: relatedNodeIDs,
                    category: catalogEntry?.category ?? pattern.category,
                    diagnostics: diagnostics
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let errorDiag = FindingDiagnostics(
                prompt: prompt,
                rawResponse: "ERROR: \(error.localizedDescription)",
                resolvedNodeNames: [],
                duration: duration
            )
            return [AnalysisFinding(
                patternNumber: pattern.number,
                patternName: catalogEntry?.name ?? pattern.name,
                severity: .info,
                summary: "Could not evaluate this pattern.",
                detail: error.localizedDescription,
                relatedNodeIDs: [],
                category: catalogEntry?.category ?? pattern.category,
                diagnostics: errorDiag
            )]
        }
    }

    // MARK: - Per-Pattern Prompt

    private func buildPatternPrompt(pattern: AnalysisPattern, graphSummary: String, template: String) -> String {
        template
            .replacingOccurrences(of: "{{number}}", with: "\(pattern.number)")
            .replacingOccurrences(of: "{{name}}", with: pattern.name)
            .replacingOccurrences(of: "{{antiPatternSignals}}", with: pattern.antiPatternSignals)
            .replacingOccurrences(of: "{{positiveSignals}}", with: pattern.positiveSignals)
            .replacingOccurrences(of: "{{relevantNodeKinds}}", with: pattern.relevantNodeKinds)
            .replacingOccurrences(of: "{{graphSummary}}", with: graphSummary)
    }

    // MARK: - Node Name Resolution

    private static func resolveNodeNames(_ names: [String], in graphNodes: [GraphNode]) -> [UUID] {
        names.compactMap { name -> UUID? in
            // Exact match first
            if let node = graphNodes.first(where: { $0.title.lowercased() == name.lowercased() }) {
                return node.id
            }
            // Contains fallback
            if let node = graphNodes.first(where: { $0.title.lowercased().contains(name.lowercased()) ||
                                                     name.lowercased().contains($0.title.lowercased()) }) {
                return node.id
            }
            return nil
        }
    }
}
