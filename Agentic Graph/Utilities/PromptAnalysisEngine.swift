import Foundation

// MARK: - Mode + Context

enum PromptAnalysisMode: String {
    case single
    case chain
}

/// Tools an agent has access to, summarised for the LLM.
struct PromptAnalysisToolRef {
    let title: String
    let typeDisplayName: String
    let detail: String
}

/// Knowledge sources an agent has access to, summarised for the LLM.
struct PromptAnalysisKnowledgeRef {
    let title: String
    let contentType: String?
    let location: String?
    let sensitivity: String?
    let retrievalStrategy: String?
    let detail: String
}

/// One agent slice within an analysis: its name, role/goal hints, tools, knowledge, and
/// optional routing context (the agent's free-text `detail` field).
struct PromptAnalysisAgentSlice {
    let name: String
    let role: String?
    let goal: String?
    let tools: [PromptAnalysisToolRef]
    let knowledge: [PromptAnalysisKnowledgeRef]
    let routingDetail: String?
}

struct PromptAnalysisContext {
    var mode: PromptAnalysisMode = .single
    /// In `.single` mode: one entry (the selected agent).
    /// In `.chain` mode: one entry per agent in the chain, in order.
    var agents: [PromptAnalysisAgentSlice] = []
}

// MARK: - Debug Info

struct PromptAnalysisDebugInfo {
    let systemPrompt: String
    let userMessage: String
    var rawResponse: String? = nil
    var error: String? = nil
    var duration: TimeInterval? = nil
    let timestamp: Date = Date()
}

// MARK: - State

enum PromptAnalysisState: Equatable {
    case idle
    case analyzing
    case completed(PromptAnalysisResult)
    case failed(String)
    case unavailable(String)

    static func == (lhs: PromptAnalysisState, rhs: PromptAnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.analyzing, .analyzing): true
        case (.completed, .completed): true
        case (.failed(let a), .failed(let b)): a == b
        case (.unavailable(let a), .unavailable(let b)): a == b
        default: false
        }
    }
}

// MARK: - Engine

@Observable
class PromptAnalysisEngine {
    var state: PromptAnalysisState = .idle
    var isTranslating: Bool = false
    var translationError: String? = nil
    /// Snapshot of the last LLM exchange for the debug window.
    var lastDebug: PromptAnalysisDebugInfo? = nil
    private var task: Task<Void, Never>?

    /// UserDefaults key for the customizable system prompt.
    static let systemPromptKey = "promptAnalysisSystemPrompt"
    /// UserDefaults key for the customizable user message template.
    static let userMessageTemplateKey = "promptAnalysisUserMessageTemplate"
    /// UserDefaults key for the translation target language.
    static let targetLanguageKey = "promptAnalysisTargetLanguage"
    static let defaultTargetLanguage = "English"
    /// UserDefaults key for the reverse-translation target language.
    static let reverseTargetLanguageKey = "promptAnalysisReverseTargetLanguage"
    /// UserDefaults key for the "include routing details" toggle.
    static let includeRoutingDetailsKey = "promptAnalysisIncludeRoutingDetails"

    static let defaultSystemPrompt = """
    You are an expert in LLM agent prompt engineering. Your job is to review the user's prompt or instructions and identify issues that may affect agent behavior, reliability, or safety.

    Look for problems such as:
    - Ambiguity, contradictions, or unclear directives
    - Missing context, edge cases, or guardrails
    - Overly broad or under-specified instructions
    - Risk of prompt injection or unsafe outputs
    - Tone, role, or persona inconsistencies
    - Verbosity, repetition, or unhelpful framing
    - Missing structure (no clear input/output format, role, or goal)

    Be specific and actionable. Only flag real issues — do not invent problems.
    """

    static let defaultUserMessageTemplate = """
    {{framing}}

    {{agentContext}}

    Respond with ONLY a JSON object in this format, no other text:

    {"issues":[{"title":"short title","detail":"what the issue is","recommendation":"how to fix it","severity":"warning|recommendation|info"}]}

    If there are no issues, return {"issues":[]}.

    Prompt to analyse:
    ---
    {{prompt}}
    ---
    """

    var systemPrompt: String {
        get { UserDefaults.standard.string(forKey: Self.systemPromptKey) ?? Self.defaultSystemPrompt }
        set { UserDefaults.standard.set(newValue, forKey: Self.systemPromptKey) }
    }

    var userMessageTemplate: String {
        get { UserDefaults.standard.string(forKey: Self.userMessageTemplateKey) ?? Self.defaultUserMessageTemplate }
        set { UserDefaults.standard.set(newValue, forKey: Self.userMessageTemplateKey) }
    }

    /// Primary translation target. Empty = forward Translate button hidden.
    /// Defaults to English only when the key has never been set; once the user
    /// clears the field it stays empty.
    var targetLanguage: String {
        get {
            guard let value = UserDefaults.standard.string(forKey: Self.targetLanguageKey) else {
                return Self.defaultTargetLanguage
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.targetLanguageKey) }
    }

    /// Optional reverse-translation target. Empty = reverse button hidden.
    var reverseTargetLanguage: String {
        get {
            UserDefaults.standard.string(forKey: Self.reverseTargetLanguageKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.reverseTargetLanguageKey) }
    }

    /// When true, each agent's `detail` field is included in the LLM context as routing context.
    var includeRoutingDetails: Bool {
        get { UserDefaults.standard.bool(forKey: Self.includeRoutingDetailsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.includeRoutingDetailsKey) }
    }

    func resetSystemPrompt() {
        UserDefaults.standard.removeObject(forKey: Self.systemPromptKey)
    }

    // MARK: - Analyze

    func analyze(prompt: String, context: PromptAnalysisContext, llmStore: LLMProviderStore) {
        task?.cancel()
        state = .analyzing

        let provider = LLMProviderFactory.create(store: llmStore)
        let userMessage = buildUserMessage(prompt: prompt, context: context)
        let sys = systemPrompt
        // Capture what's about to be sent for the debug window.
        lastDebug = PromptAnalysisDebugInfo(systemPrompt: sys, userMessage: userMessage)

        task = Task {
            let started = Date()
            do {
                let raw = try await provider.chat(systemInstructions: sys, prompt: userMessage)
                if Task.isCancelled { return }
                let duration = Date().timeIntervalSince(started)
                let issues = try Self.parseIssues(raw)
                let result = PromptAnalysisResult(issues: issues, timestamp: Date(), promptAnalyzed: prompt)
                lastDebug?.rawResponse = raw
                lastDebug?.duration = duration
                state = .completed(result)
            } catch is CancellationError {
                // cancel() already set state
            } catch let LLMError.unavailable(reason) {
                if !Task.isCancelled {
                    lastDebug?.error = reason
                    lastDebug?.duration = Date().timeIntervalSince(started)
                    state = .unavailable(reason)
                }
            } catch {
                if !Task.isCancelled {
                    lastDebug?.error = error.localizedDescription
                    lastDebug?.duration = Date().timeIntervalSince(started)
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        state = .idle
    }

    func reset() {
        task?.cancel()
        state = .idle
    }

    // MARK: - Translate

    /// Translate `text` to the primary target language using the configured LLM.
    func translate(text: String, llmStore: LLMProviderStore) async throws -> String {
        try await translate(text: text, to: targetLanguage, llmStore: llmStore)
    }

    /// Translate `text` to the reverse target language. Requires `reverseTargetLanguage` to be set.
    func reverseTranslate(text: String, llmStore: LLMProviderStore) async throws -> String {
        let language = reverseTargetLanguage
        guard !language.isEmpty else {
            throw LLMError.invalidResponse("Reverse target language not set in Settings → Prompt Analysis.")
        }
        return try await translate(text: text, to: language, llmStore: llmStore)
    }

    /// Translate `text` to an explicit target language using the configured LLM.
    func translate(text: String, to language: String, llmStore: LLMProviderStore) async throws -> String {
        let provider = LLMProviderFactory.create(store: llmStore)
        let systemMsg = "You are a translator. Translate the user's text into \(language). Preserve formatting, line breaks, lists, and markdown. Output ONLY the translation — no preamble, no commentary, no quotation marks."
        let userMsg = text
        await MainActor.run { self.isTranslating = true; self.translationError = nil }
        defer { Task { @MainActor in self.isTranslating = false } }

        let raw = try await provider.chat(systemInstructions: systemMsg, prompt: userMsg)
        return Self.cleanTranslationOutput(raw)
    }

    /// Strip stray code-fence or JSON wrapping that some providers add when asked for plain text.
    private static func cleanTranslationOutput(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip ```...``` fence
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If the provider wrapped it in a JSON object with a "translation" key, unwrap.
        if s.hasPrefix("{"),
           let data = s.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["translation", "translated", "text", "output"] {
                if let value = json[key] as? String, !value.isEmpty {
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return s
    }

    // MARK: - Prompt

    func buildUserMessage(prompt: String, context: PromptAnalysisContext) -> String {
        let framing = Self.buildFraming(mode: context.mode)
        let agentContext = Self.buildAgentContext(agents: context.agents, mode: context.mode)
        return userMessageTemplate
            .replacingOccurrences(of: "{{framing}}", with: framing)
            .replacingOccurrences(of: "{{agentContext}}", with: agentContext)
            .replacingOccurrences(of: "{{prompt}}", with: prompt)
    }

    private static func buildFraming(mode: PromptAnalysisMode) -> String {
        switch mode {
        case .single:
            return "Analyse the following prompt/instructions for a single LLM agent and identify issues."
        case .chain:
            return """
            Analyse the following multi-agent chain. Each section (separated by `---`) is a different agent's \
            prompt; they run in sequence and pass context from one to the next.

            Look for issues BOTH within each agent's prompt AND in the INTERACTIONS between them — for example: \
            context loss across handoffs, redundant or conflicting instructions, ambiguous role boundaries, \
            missing acknowledgement of upstream output, or unclear coordination.
            """
        }
    }

    private static func buildAgentContext(agents: [PromptAnalysisAgentSlice], mode: PromptAnalysisMode) -> String {
        guard !agents.isEmpty else { return "" }
        var msg = "Context about the agents involved:\n"
        for (index, slice) in agents.enumerated() {
            if mode == .chain {
                msg += "\n\(index + 1). \(slice.name)\n"
            } else {
                msg += "\nAgent: \(slice.name)\n"
            }
            if let role = slice.role, !role.isEmpty { msg += "   Role: \(role)\n" }
            if let goal = slice.goal, !goal.isEmpty { msg += "   Goal: \(goal)\n" }
            if slice.tools.isEmpty {
                msg += "   Tools: (none)\n"
            } else {
                msg += "   Tools:\n"
                for tool in slice.tools {
                    var line = "     - \(tool.title) (\(tool.typeDisplayName))"
                    let detail = tool.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !detail.isEmpty {
                        let trimmed = detail.count > 160 ? String(detail.prefix(160)) + "…" : detail
                        line += ": \(trimmed)"
                    }
                    msg += line + "\n"
                }
            }
            if slice.knowledge.isEmpty {
                msg += "   Knowledge: (none)\n"
            } else {
                msg += "   Knowledge:\n"
                for kb in slice.knowledge {
                    var line = "     - \(kb.title)"
                    var attrs: [String] = []
                    if let t = kb.contentType, !t.isEmpty { attrs.append(t) }
                    if let r = kb.retrievalStrategy, !r.isEmpty { attrs.append("retrieval: \(r)") }
                    if let s = kb.sensitivity, !s.isEmpty { attrs.append("sensitivity: \(s)") }
                    if let l = kb.location, !l.isEmpty { attrs.append("at \(l)") }
                    if !attrs.isEmpty { line += " (\(attrs.joined(separator: "; ")))" }
                    let detail = kb.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !detail.isEmpty {
                        let trimmed = detail.count > 160 ? String(detail.prefix(160)) + "…" : detail
                        line += ": \(trimmed)"
                    }
                    msg += line + "\n"
                }
            }
            if let routing = slice.routingDetail, !routing.isEmpty {
                msg += "   Routing description (what this agent does; upstream agents read this to route requests to it):\n"
                let indented = routing
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "     " + $0 }
                    .joined(separator: "\n")
                msg += indented + "\n"
            }
        }
        return msg
    }

    // MARK: - JSON Parsing

    private struct RawResponse: Decodable {
        let issues: [RawIssue]
    }

    private struct RawIssue: Decodable {
        let title: String?
        let detail: String?
        let recommendation: String?
        let severity: String?
    }

    private static func parseIssues(_ text: String) throws -> [PromptAnalysisIssue] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LLMError.invalidResponse("Empty response from model")
        }

        var jsonStr = trimmed
        if let start = trimmed.range(of: "{"),
           let end = trimmed.range(of: "}", options: .backwards),
           start.lowerBound < end.lowerBound {
            jsonStr = String(trimmed[start.lowerBound...end.lowerBound])
        }

        guard let data = jsonStr.data(using: .utf8) else {
            throw LLMError.invalidResponse("Could not parse response as UTF-8")
        }

        do {
            let raw = try JSONDecoder().decode(RawResponse.self, from: data)
            return raw.issues.compactMap { item in
                let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else { return nil }
                return PromptAnalysisIssue(
                    title: title,
                    detail: item.detail ?? "",
                    recommendation: item.recommendation ?? "",
                    severity: item.severity
                )
            }
        } catch {
            let preview = String(trimmed.prefix(200))
            throw LLMError.invalidResponse("Could not parse JSON from model response: \(preview)")
        }
    }
}

// MARK: - Chain + Tool Helpers

extension GraphDocument {
    /// Returns direct upstream agents that connect into the given node.
    func directAgentCallers(of nodeID: UUID) -> [GraphNode] {
        edges
            .filter { $0.targetNodeID == nodeID }
            .compactMap { node(for: $0.sourceNodeID) }
            .filter { $0.kind == .agent }
    }

    /// Walks back through linear agent chains. Returns the chain of agent nodes from the
    /// earliest ancestor up to (and including) the given agent. Stops when an agent has
    /// !=1 direct agent caller or a cycle is detected.
    func upstreamAgentChain(endingAt nodeID: UUID) -> [GraphNode] {
        guard let start = node(for: nodeID), start.kind == .agent else { return [] }
        var chain: [GraphNode] = [start]
        var current = start
        var visited: Set<UUID> = [start.id]
        while true {
            let callers = directAgentCallers(of: current.id)
            guard callers.count == 1 else { break }
            let prev = callers[0]
            if visited.contains(prev.id) { break }
            chain.insert(prev, at: 0)
            visited.insert(prev.id)
            current = prev
        }
        return chain
    }

    /// Returns nodes of a particular kind connected to the given node (in either direction).
    func neighbors(of nodeID: UUID, ofKind kind: NodeKind) -> [GraphNode] {
        let touching = edges.filter { $0.sourceNodeID == nodeID || $0.targetNodeID == nodeID }
        let otherIDs = touching.map { $0.sourceNodeID == nodeID ? $0.targetNodeID : $0.sourceNodeID }
        var seen = Set<UUID>()
        var result: [GraphNode] = []
        for id in otherIDs where !seen.contains(id) {
            seen.insert(id)
            if let node = node(for: id), node.kind == kind {
                result.append(node)
            }
        }
        return result
    }

    func tools(connectedTo nodeID: UUID) -> [GraphNode] {
        neighbors(of: nodeID, ofKind: .tool)
    }

    func knowledgeSources(connectedTo nodeID: UUID) -> [GraphNode] {
        neighbors(of: nodeID, ofKind: .knowledge)
    }

    /// Build a single agent slice for the prompt analysis context.
    /// - Parameter includeRoutingDetail: When true, populate `routingDetail` from the agent's `detail` field.
    func promptAnalysisSlice(forAgent agent: GraphNode,
                             includeRoutingDetail: Bool = false) -> PromptAnalysisAgentSlice {
        let trimmedDetail = agent.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return PromptAnalysisAgentSlice(
            name: agent.title,
            role: agent.agentRole,
            goal: agent.agentGoal,
            tools: tools(connectedTo: agent.id).map { tool in
                PromptAnalysisToolRef(
                    title: tool.title,
                    typeDisplayName: tool.toolType.displayName,
                    detail: tool.detail
                )
            },
            knowledge: knowledgeSources(connectedTo: agent.id).map { kb in
                PromptAnalysisKnowledgeRef(
                    title: kb.title,
                    contentType: kb.knowledgeContentType,
                    location: kb.knowledgeLocation,
                    sensitivity: kb.knowledgeSensitivity,
                    retrievalStrategy: kb.knowledgeRetrievalStrategy == .none
                        ? nil
                        : kb.knowledgeRetrievalStrategy.displayName,
                    detail: kb.detail
                )
            },
            routingDetail: (includeRoutingDetail && !trimmedDetail.isEmpty) ? trimmedDetail : nil
        )
    }
}
