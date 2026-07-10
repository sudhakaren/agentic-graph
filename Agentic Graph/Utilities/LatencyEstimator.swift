import Foundation

// MARK: - Per-agent latency estimate

/// A heuristic latency estimate for a single agent and the work it triggers.
struct AgentLatencyEstimate {
    var agentID: UUID

    var typicalSeconds: Double
    var p95Seconds: Double

    /// The selected agent's own time (override or computed), excluding delegation.
    var selfSeconds: Double
    /// True when the agent's own time came from its Expected Duration field.
    var selfIsOverridden: Bool

    // Typical-figure breakdown (zeroed when the agent's own time is overridden).
    var inferenceSeconds: Double
    var syncToolSeconds: Double
    var asyncToolSeconds: Double
    var delegationSeconds: Double

    var loopCountTypical: Int
    var loopCountP95: Int

    var syncToolCount: Int
    var asyncToolCount: Int
    var delegateCount: Int

    /// Typical latency if every one of this agent's tools ran asynchronously.
    var ifAsyncTypicalSeconds: Double

    /// Latency budget in seconds, parsed from the agent's Latency Budget field.
    var budgetSeconds: Double?
    /// True when the p95 estimate exceeds the parsed budget.
    var exceedsBudget: Bool
}

// MARK: - Latency Estimator

/// Deterministic, heuristic latency model. Walks the graph from a selected
/// agent: inference + sync tools (serial) + async tools (parallel) + any
/// delegated sub-agents (summed down the chain). A node's Expected Duration
/// field, when set, overrides the heuristic for that node.
enum LatencyEstimator {

    static func estimateAgent(_ agent: GraphNode, document: GraphDocument,
                              config: LatencyConfigStore) -> AgentLatencyEstimate {
        let p = config.parameters

        let connectedTools = document.tools(connectedTo: agent.id)
        let syncTools = connectedTools.filter { !$0.toolAsync }
        let asyncTools = connectedTools.filter { $0.toolAsync }
        let syncSum = syncTools.reduce(0.0) { $0 + toolLatency($1, params: p) }
        let asyncMax = asyncTools.map { toolLatency($0, params: p) }.max() ?? 0.0
        let toolCost = syncSum + asyncMax

        let inference = inferenceTime(agent.agentComplexity, params: p)
        let maxIter = parseIterations(agent.agentMaxIterations)
        let loopsTypical = loopCount(maxIter, fraction: p.typicalIterationFraction)
        let loopsP95 = loopCount(maxIter, fraction: p.p95IterationFraction)

        // The agent's own time. An explicit Expected Duration overrides the
        // heuristic (inference loops + tool calls) entirely.
        let durationOverride = parseSeconds(agent.expectedDuration)
        let selfTypical: Double
        let selfP95: Double
        if let durationOverride {
            selfTypical = durationOverride
            selfP95 = durationOverride * p.p95CallMultiplier
        } else {
            // Tools are invoked across the whole run, not re-counted on every
            // reasoning loop — only the LLM "thinking" repeats per loop.
            selfTypical = Double(loopsTypical) * inference + toolCost
            selfP95 = (Double(loopsP95) * inference + toolCost) * p.p95CallMultiplier
        }

        // Delegated sub-agents (recursive, cycle-guarded).
        var visited: Set<UUID> = [agent.id]
        var delegationTypical = 0.0
        var delegationP95 = 0.0
        let children = document.delegatedAgents(of: agent.id)
        for child in children {
            let (t, c) = subtreeLatency(child, document: document, params: p, visited: &visited)
            delegationTypical += t
            delegationP95 += c
        }

        // What-if: every tool on this agent runs asynchronously.
        let allToolsMax = connectedTools.map { toolLatency($0, params: p) }.max() ?? 0.0
        let ifAsyncTypical = (durationOverride != nil)
            ? selfTypical + delegationTypical
            : Double(loopsTypical) * inference + allToolsMax + delegationTypical

        let budget = parseSeconds(agent.agentLatencyBudget)
        let p95Total = selfP95 + delegationP95

        return AgentLatencyEstimate(
            agentID: agent.id,
            typicalSeconds: selfTypical + delegationTypical,
            p95Seconds: p95Total,
            selfSeconds: selfTypical,
            selfIsOverridden: durationOverride != nil,
            inferenceSeconds: (durationOverride != nil) ? 0 : Double(loopsTypical) * inference,
            syncToolSeconds: (durationOverride != nil) ? 0 : syncSum,
            asyncToolSeconds: (durationOverride != nil) ? 0 : asyncMax,
            delegationSeconds: delegationTypical,
            loopCountTypical: loopsTypical,
            loopCountP95: loopsP95,
            syncToolCount: syncTools.count,
            asyncToolCount: asyncTools.count,
            delegateCount: children.count,
            ifAsyncTypicalSeconds: ifAsyncTypical,
            budgetSeconds: budget,
            exceedsBudget: budget.map { p95Total > $0 } ?? false
        )
    }

    /// Full subtree latency (typical, p95) for a delegated agent and everything it calls.
    private static func subtreeLatency(_ agent: GraphNode, document: GraphDocument,
                                       params p: LatencyParameters,
                                       visited: inout Set<UUID>) -> (Double, Double) {
        guard !visited.contains(agent.id) else { return (0, 0) }
        visited.insert(agent.id)

        let tools = document.tools(connectedTo: agent.id)
        let syncSum = tools.filter { !$0.toolAsync }.reduce(0.0) { $0 + toolLatency($1, params: p) }
        let asyncMax = tools.filter { $0.toolAsync }.map { toolLatency($0, params: p) }.max() ?? 0.0
        let toolCost = syncSum + asyncMax

        var typical: Double
        var p95: Double
        if let durationOverride = parseSeconds(agent.expectedDuration) {
            typical = durationOverride
            p95 = durationOverride * p.p95CallMultiplier
        } else {
            let inference = inferenceTime(agent.agentComplexity, params: p)
            let maxIter = parseIterations(agent.agentMaxIterations)
            typical = Double(loopCount(maxIter, fraction: p.typicalIterationFraction)) * inference + toolCost
            p95 = (Double(loopCount(maxIter, fraction: p.p95IterationFraction)) * inference + toolCost) * p.p95CallMultiplier
        }

        for child in document.delegatedAgents(of: agent.id) {
            let (t, c) = subtreeLatency(child, document: document, params: p, visited: &visited)
            typical += t
            p95 += c
        }
        return (typical, p95)
    }

    // MARK: - Component helpers

    /// A tool's call latency — its Expected Duration override, or the type heuristic.
    private static func toolLatency(_ tool: GraphNode, params p: LatencyParameters) -> Double {
        if let toolOverride = parseSeconds(tool.expectedDuration) { return toolOverride }
        return toolTime(tool.toolType, params: p)
    }

    private static func inferenceTime(_ c: AgentComplexity, params p: LatencyParameters) -> Double {
        switch c {
        case .deterministic: return p.inferenceDeterministic
        case .conditional:   return p.inferenceConditional
        case .reasoning:     return p.inferenceReasoning
        case .openEnded:     return p.inferenceOpenEnded
        }
    }

    private static func toolTime(_ t: ToolType, params p: LatencyParameters) -> Double {
        switch t {
        case .openai:    return p.toolOpenAI
        case .mcp:       return p.toolMCP
        case .python:    return p.toolPython
        case .api:       return p.toolAPI
        case .shell:     return p.toolShell
        case .langchain: return p.toolLangChain
        case .flow:      return p.toolFlow
        case .custom:    return p.toolCustom
        }
    }

    private static func loopCount(_ maxIter: Int?, fraction: Double) -> Int {
        guard let maxIter, maxIter > 1 else { return 1 }
        return max(1, Int((Double(maxIter) * fraction).rounded()))
    }

    /// Parses an agent's Max Iterations string (e.g. "5", "10") to an Int.
    private static func parseIterations(_ s: String?) -> Int? {
        guard let s else { return nil }
        let digits = s.filter { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// Parses a duration string (e.g. "300ms", "3s", "5-8s") to seconds. Each
    /// number is read with its own trailing unit — "ms"/"milliseconds" are
    /// milliseconds, anything else is seconds. Ranges resolve to the larger bound.
    private static func parseSeconds(_ s: String?) -> Double? {
        guard let raw = s?.lowercased(), !raw.isEmpty else { return nil }
        let chars = Array(raw)
        var values: [Double] = []
        var i = 0
        while i < chars.count {
            guard chars[i].isNumber || chars[i] == "." else { i += 1; continue }
            var numStr = ""
            while i < chars.count, chars[i].isNumber || chars[i] == "." {
                numStr.append(chars[i]); i += 1
            }
            while i < chars.count, chars[i] == " " { i += 1 }
            var unit = ""
            while i < chars.count, chars[i].isLetter {
                unit.append(chars[i]); i += 1
            }
            guard let n = Double(numStr) else { continue }
            let isMs = unit.hasPrefix("ms") || unit.hasPrefix("milli")
            values.append(isMs ? n / 1000.0 : n)
        }
        return values.max()
    }
}

// MARK: - Graph traversal

extension GraphDocument {
    /// Agents this node delegates to — agents that are the target of an edge from this node.
    func delegatedAgents(of nodeID: UUID) -> [GraphNode] {
        var seen = Set<UUID>()
        var result: [GraphNode] = []
        for edge in edges where edge.sourceNodeID == nodeID {
            let targetID = edge.targetNodeID
            guard !seen.contains(targetID) else { continue }
            seen.insert(targetID)
            if let n = node(for: targetID), n.kind == .agent {
                result.append(n)
            }
        }
        return result
    }
}
