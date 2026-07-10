import Foundation

/// Pure-calculation sizing estimator. No LLM calls — derives infrastructure
/// recommendations from graph structure and node metadata.
enum SizingEstimator {

    static func estimate(document: GraphDocument, config: SizingConfigStore) -> SizingEstimate {
        let params = config.parameters
        let agents = document.nodes.filter { $0.kind == .agent }
        let tools = document.nodes.filter { $0.kind == .tool }
        let knowledge = document.nodes.filter { $0.kind == .knowledge }
        let humans = document.nodes.filter { $0.kind == .human }

        let workload = computeWorkloadProfile(
            agents: agents, tools: tools, knowledge: knowledge, humans: humans,
            document: document, params: params
        )
        let infra = computeInfrastructure(
            agents: agents, tools: tools, knowledge: knowledge,
            document: document, params: params
        )
        let arch = computeArchitecture(
            agents: agents, tools: tools, document: document, params: params
        )
        let scaling = computeScalingRecommendations(
            agents: agents, tools: tools, knowledge: knowledge,
            document: document, params: params
        )
        let caching = computeCachingAssessment(
            tools: tools, params: params
        )

        return SizingEstimate(
            timestamp: Date(),
            workloadProfile: workload,
            infrastructure: infra,
            architecture: arch,
            scalingRecommendations: scaling,
            cachingAssessment: caching
        )
    }

    // MARK: - Workload Profile

    private static func computeWorkloadProfile(
        agents: [GraphNode], tools: [GraphNode], knowledge: [GraphNode], humans: [GraphNode],
        document: GraphDocument, params: SizingParameters
    ) -> WorkloadProfile {
        let interaction = classifyInteractionPattern(agents: agents, humans: humans)
        let concurrency = estimateConcurrency(agents: agents, humans: humans, document: document, params: params)
        let tokens = estimateTokenProfile(agents: agents)
        let external = profileExternalCalls(tools: tools)
        let consistency = classifyConsistency(humans: humans, document: document)

        return WorkloadProfile(
            interactionPattern: interaction.pattern,
            interactionRationale: interaction.rationale,
            concurrency: concurrency,
            tokenProfile: tokens,
            externalCalls: external,
            consistencyAppetite: consistency
        )
    }

    private static func classifyInteractionPattern(agents: [GraphNode], humans: [GraphNode]) -> (pattern: InteractionPattern, rationale: String) {
        var signals: [InteractionPattern] = []
        var rationales: [String] = []

        // Check latency budgets for real-time signals
        let lowLatencyAgents = agents.filter { agent in
            guard let budget = agent.agentLatencyBudget, !budget.isEmpty else { return false }
            let lower = budget.lowercased()
            if lower.contains("ms") {
                let digits = lower.replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)
                if let num = Int(digits), num < 1000 { return true }
            }
            return false
        }
        if !lowLatencyAgents.isEmpty {
            signals.append(.eventDriven)
            rationales.append(String(format: String(localized: "%lld agent(s) with sub-second latency budget"), lowLatencyAgents.count))
        }

        // Check for conversational human interaction
        let chatHumans = humans.filter { h in
            let input = h.humanInputChannel
            let output = h.humanChannel
            return input == .chat || input == .portal ||
                   output == .chat || output == .portal
        }
        if !chatHumans.isEmpty {
            signals.append(.conversational)
            rationales.append(String(format: String(localized: "%lld human node(s) with chat/portal channels"), chatHumans.count))
        }

        // Check for complex async agents
        let asyncAgents = agents.filter { a in
            (a.agentComplexity == .reasoning || a.agentComplexity == .openEnded) &&
            (Int(a.agentMaxIterations ?? "") ?? 0) > 5
        }
        if !asyncAgents.isEmpty {
            signals.append(.taskExecution)
            rationales.append(String(format: String(localized: "%lld complex agent(s) with high iteration limits"), asyncAgents.count))
        }

        // Default to conversational if humans exist, task execution otherwise
        if signals.isEmpty {
            if !humans.isEmpty {
                return (.conversational, String(localized: "Human nodes present, defaulting to conversational pattern"))
            } else {
                return (.taskExecution, String(localized: "No latency constraints or human channels detected"))
            }
        }

        let uniqueSignals = Set(signals.map(\.rawValue))
        if uniqueSignals.count > 1 {
            return (.mixed, rationales.joined(separator: "; "))
        }
        return (signals[0], rationales.joined(separator: "; "))
    }

    private static func estimateConcurrency(
        agents: [GraphNode], humans: [GraphNode],
        document: GraphDocument, params: SizingParameters
    ) -> ConcurrencyEstimate {
        // User sessions from teamSize or humanCount
        let teamSize = Int(document.teamSize ?? "") ?? max(humans.count, 10)
        let userSessions = max(teamSize, 1)

        // Delegation depth → inference multiplier
        let delegatingAgents = agents.filter { $0.agentCanDelegate }
        let supervisors = agents.filter { $0.agentType == .supervisor || $0.agentType == .orchestrator }
        let delegationDepth = max(delegatingAgents.count, supervisors.count)

        let multiplier: Int
        var rationale: String
        if delegationDepth == 0 {
            multiplier = 1
            rationale = String(localized: "No delegation — 1 inference per session")
        } else if delegationDepth <= 2 {
            multiplier = params.concurrencyMultiplierLow
            rationale = String(format: String(localized: "%lld delegation layer(s) → %lld inferences per session"), delegationDepth, params.concurrencyMultiplierLow)
        } else {
            multiplier = params.concurrencyMultiplierHigh
            rationale = String(format: String(localized: "%lld delegation layers → %lld inferences per session"), delegationDepth, params.concurrencyMultiplierHigh)
        }

        let peak = userSessions * multiplier
        return ConcurrencyEstimate(
            userSessions: userSessions,
            inferencePerSession: "\(multiplier)",
            peakInferenceRequests: peak,
            rationale: rationale
        )
    }

    private static func estimateTokenProfile(agents: [GraphNode]) -> TokenProfile {
        // Classify by agent complexity
        let complexAgents = agents.filter { $0.agentComplexity == .reasoning || $0.agentComplexity == .openEnded }
        let simpleAgents = agents.filter { $0.agentComplexity == .deterministic || $0.agentComplexity == .conditional }

        let inputRange: String
        let outputRange: String
        let totalEstimate: String
        var rationale: String

        if complexAgents.count > simpleAgents.count {
            inputRange = "8K–15K"
            outputRange = "200–500"
            totalEstimate = "~\(agents.count * 15)K"
            rationale = String(localized: "Majority complex/reasoning agents drive higher token usage")
        } else if agents.isEmpty {
            inputRange = "N/A"
            outputRange = "N/A"
            totalEstimate = "N/A"
            rationale = String(localized: "No agents in graph")
        } else {
            inputRange = "2K–8K"
            outputRange = "50–200"
            totalEstimate = "~\(agents.count * 5)K"
            rationale = String(localized: "Mostly deterministic/conditional agents")
        }

        // Factor in max iterations
        let highIterAgents = agents.filter { (Int($0.agentMaxIterations ?? "") ?? 1) > 5 }
        if !highIterAgents.isEmpty {
            rationale += "; " + String(format: String(localized: "%lld agent(s) with >5 iterations multiply token cost"), highIterAgents.count)
        }

        return TokenProfile(
            inputRange: inputRange,
            outputRange: outputRange,
            totalPerSession: totalEstimate,
            rationale: rationale
        )
    }

    private static func profileExternalCalls(tools: [GraphNode]) -> ExternalCallProfile {
        let externalTools = tools.filter { t in
            t.toolType == .api || t.toolType == .mcp || t.toolType == .shell
        }
        let asyncCount = externalTools.filter(\.toolAsync).count
        let syncCount = externalTools.count - asyncCount
        let withTimeout = externalTools.filter { $0.toolTimeout != nil && !($0.toolTimeout?.isEmpty ?? true) }.count
        let noErrorHandling = externalTools.filter { $0.toolErrorHandling == .none }.count

        let risk: SizingRiskLevel
        if externalTools.isEmpty {
            risk = .low
        } else {
            let noHandlingPct = Double(noErrorHandling) / Double(externalTools.count)
            if noHandlingPct > 0.5 { risk = .high }
            else if noHandlingPct > 0.25 { risk = .moderate }
            else { risk = .low }
        }

        return ExternalCallProfile(
            totalExternalTools: externalTools.count,
            asyncToolCount: asyncCount,
            syncToolCount: syncCount,
            toolsWithTimeout: withTimeout,
            toolsWithoutErrorHandling: noErrorHandling,
            riskLevel: risk
        )
    }

    private static func classifyConsistency(humans: [GraphNode], document: GraphDocument) -> String {
        if document.deploymentTarget == .cloud {
            return String(localized: "Global/always-on (cloud deployment)")
        }
        let hasTimezoneHumans = humans.filter { $0.humanTimezone != nil && !($0.humanTimezone?.isEmpty ?? true) }
        if hasTimezoneHumans.count > 1 {
            return String(localized: "Multi-timezone — potential for global operation")
        }
        if !humans.isEmpty {
            return String(localized: "Business-hours concentrated (human-driven interaction)")
        }
        return String(localized: "Event-driven or batch processing likely")
    }

    // MARK: - Infrastructure

    private static func computeInfrastructure(
        agents: [GraphNode], tools: [GraphNode], knowledge: [GraphNode],
        document: GraphDocument, params: SizingParameters
    ) -> InfrastructureEstimate {
        let agentCount = agents.count
        let toolCount = tools.count

        // Classify tier
        let tier: SizingTier
        let tierConfig: SizingTierConfig
        if agentCount <= params.simpleTier.maxAgents && toolCount <= params.simpleTier.maxTools {
            tier = .simple
            tierConfig = params.simpleTier
        } else if agentCount <= params.mediumTier.maxAgents && toolCount <= params.mediumTier.maxTools {
            tier = .medium
            tierConfig = params.mediumTier
        } else {
            tier = .hard
            tierConfig = params.hardTier
        }

        let vCPU = tierConfig.vCPU
        let ram = tierConfig.ramGB
        let pods = max(ram / 4, 1) // 1:4 CPU/memory ratio

        // Scale if teamSize available
        let teamSize = Int(document.teamSize ?? "")
        let scaledVCPU: Int?
        let scaledRAM: Int?
        let scaledUsers: Int?
        if let ts = teamSize, ts != params.baseUserCount {
            let factor = Double(ts) / Double(params.baseUserCount)
            scaledVCPU = Int(ceil(Double(vCPU) * factor))
            scaledRAM = Int(ceil(Double(ram) * factor))
            scaledUsers = ts
        } else {
            scaledVCPU = nil
            scaledRAM = nil
            scaledUsers = nil
        }

        let rationale = String(format: String(localized: "%lld agent(s) × %lld tool(s) → %@ tier"), agentCount, toolCount, tier.displayName)

        // Risk areas
        var risks: [SizingRiskArea] = []

        // Distinct tool types increase venv pressure
        let distinctToolTypes = Set(tools.map(\.toolType))
        if distinctToolTypes.count > 5 {
            risks.append(SizingRiskArea(
                id: UUID(), area: String(localized: "Tool diversity"),
                level: .moderate,
                detail: String(format: String(localized: "%lld distinct tool types — diverse virtual environments reduce cache efficiency"), distinctToolTypes.count),
                relatedNodes: []
            ))
        }

        // Knowledge volume
        let largeKnowledge = knowledge.filter { k in
            let size = (k.knowledgeSizeQuantity ?? "").lowercased()
            return size.contains("gb") || size.contains("tb") || size.contains("million") || size.contains("1m")
        }
        if !largeKnowledge.isEmpty {
            risks.append(SizingRiskArea(
                id: UUID(), area: String(localized: "Knowledge volume"),
                level: .high,
                detail: String(format: String(localized: "%lld knowledge source(s) with large data volumes — may require dedicated storage and retrieval infrastructure"), largeKnowledge.count),
                relatedNodes: largeKnowledge.map { NodeRef(id: $0.id, name: $0.title) }
            ))
        }

        // Agents with no cost budget
        let noCostBudget = agents.filter { $0.agentCostBudget == nil || ($0.agentCostBudget?.isEmpty ?? true) }
        if !noCostBudget.isEmpty && agents.count > 2 {
            risks.append(SizingRiskArea(
                id: UUID(), area: String(localized: "Unbounded cost"),
                level: .moderate,
                detail: String(format: String(localized: "%lld of %lld agents have no cost budget — risk of runaway token consumption"), noCostBudget.count, agents.count),
                relatedNodes: noCostBudget.map { NodeRef(id: $0.id, name: $0.title) }
            ))
        }

        return InfrastructureEstimate(
            tier: tier,
            vCPU: vCPU, ramGB: ram, executorPods: pods,
            baseUserCount: params.baseUserCount,
            scaledVCPU: scaledVCPU, scaledRAMGB: scaledRAM, scaledUserCount: scaledUsers,
            rationale: rationale,
            riskAreas: risks
        )
    }

    // MARK: - Architecture Decomposition

    private static func computeArchitecture(
        agents: [GraphNode], tools: [GraphNode],
        document: GraphDocument, params: SizingParameters
    ) -> ArchitectureDecomposition {
        let toolCategories = Set(tools.map(\.toolCategory.rawValue))

        // Front Door
        let frontDoorPresent = params.frontDoorCategories.filter { toolCategories.contains($0) }
        let frontDoorMissing = params.frontDoorCategories.filter { !toolCategories.contains($0) }
        let frontDoorRisk: SizingRiskLevel = frontDoorMissing.count > frontDoorPresent.count ? .high : (frontDoorMissing.isEmpty ? .low : .moderate)

        // Agent Runtime
        let runtimePresent = params.agentRuntimeCategories.filter { toolCategories.contains($0) }
        let runtimeMissing = params.agentRuntimeCategories.filter { !toolCategories.contains($0) }
        var runtimeComponents = runtimePresent.map { String(format: String(localized: "%@ tools"), categoryDisplayName($0)) }
        if !agents.isEmpty {
            runtimeComponents.insert(String(format: String(localized: "Agent runtime (%lld agents)"), agents.count), at: 0)
        }
        let runtimeRisk: SizingRiskLevel = runtimeMissing.count > runtimePresent.count ? .high : (runtimeMissing.isEmpty ? .low : .moderate)

        // Inference
        var inferenceComponents: [String] = []
        var inferenceGaps: [String] = []
        if let target = document.deploymentTarget {
            inferenceComponents.append(String(format: String(localized: "Deployment: %@"), target.displayName))
        } else {
            inferenceGaps.append(String(localized: "No deployment target set"))
        }
        let agentsWithModel = agents.filter { $0.agentModel != nil && !($0.agentModel?.isEmpty ?? true) }
        if !agentsWithModel.isEmpty {
            inferenceComponents.append(String(format: String(localized: "%lld agent(s) with model specified"), agentsWithModel.count))
        }
        let testingTools = tools.filter { params.inferenceCategories.contains($0.toolCategory.rawValue) }
        if !testingTools.isEmpty {
            inferenceComponents.append(String(format: String(localized: "%lld testing tool(s)"), testingTools.count))
        } else {
            inferenceGaps.append(String(localized: "No testing tools"))
        }
        let inferenceRisk: SizingRiskLevel = inferenceGaps.count > inferenceComponents.count ? .high : (inferenceGaps.isEmpty ? .low : .moderate)

        return ArchitectureDecomposition(
            frontDoor: TierAssessment(
                name: String(localized: "Front Door"),
                components: frontDoorPresent.map { String(format: String(localized: "%@ tools"), categoryDisplayName($0)) },
                gaps: frontDoorMissing.map { String(format: String(localized: "No %@ tools"), categoryDisplayName($0).lowercased()) },
                riskLevel: frontDoorRisk
            ),
            agentRuntime: TierAssessment(
                name: String(localized: "Agent Runtime"),
                components: runtimeComponents,
                gaps: runtimeMissing.map { String(format: String(localized: "No %@ tools"), categoryDisplayName($0).lowercased()) },
                riskLevel: runtimeRisk
            ),
            inference: TierAssessment(
                name: String(localized: "Inference"),
                components: inferenceComponents,
                gaps: inferenceGaps,
                riskLevel: inferenceRisk
            )
        )
    }

    // MARK: - Scaling Recommendations

    private static func computeScalingRecommendations(
        agents: [GraphNode], tools: [GraphNode], knowledge: [GraphNode],
        document: GraphDocument, params: SizingParameters
    ) -> [ScalingRecommendation] {
        var recs: [ScalingRecommendation] = []
        var priority = 1

        // Latency: deep chains without async tools
        let asyncTools = tools.filter(\.toolAsync)
        let hasLatencyBudgets = agents.contains { $0.agentLatencyBudget != nil && !($0.agentLatencyBudget?.isEmpty ?? true) }
        if hasLatencyBudgets && asyncTools.isEmpty && tools.count > 3 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .latency,
                title: String(localized: "Parallelise tool calls"),
                detail: String(localized: "Agents have latency budgets but no tools are marked async. Mark long-running tools as async to enable parallel execution and reduce end-to-end latency."),
                priority: priority
            ))
            priority += 1
        }

        // Latency: no caching with many tools
        let cachingTools = tools.filter { $0.toolCategory == .caching }
        if cachingTools.isEmpty && tools.count > 5 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .latency,
                title: String(localized: "Add caching layer"),
                detail: String(format: String(localized: "%lld tools with no caching — add tool result caching for frequently called, idempotent tools to reduce latency and inference costs."), tools.count),
                priority: priority
            ))
            priority += 1
        }

        // Throughput: no monitoring
        let monitoringTools = tools.filter { $0.toolCategory == .monitoring }
        if monitoringTools.isEmpty && agents.count > 2 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .throughput,
                title: String(localized: "Add throughput monitoring"),
                detail: String(localized: "No monitoring tools detected. Without metrics you cannot identify throughput bottlenecks or validate scaling decisions."),
                priority: priority
            ))
            priority += 1
        }

        // Cost: no iteration limits or cost budgets
        let noLimits = agents.filter {
            ($0.agentMaxIterations == nil || ($0.agentMaxIterations?.isEmpty ?? true)) &&
            ($0.agentCostBudget == nil || ($0.agentCostBudget?.isEmpty ?? true))
        }
        if noLimits.count > 1 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .cost,
                title: String(localized: "Set cost controls"),
                detail: String(format: String(localized: "%lld agents have no max iterations or cost budget. Unbounded agents can consume excessive tokens during complex reasoning or retry loops."), noLimits.count),
                priority: priority
            ))
            priority += 1
        }

        // Cost: all agents same model
        let modelsUsed = Set(agents.compactMap(\.agentModel).filter { !$0.isEmpty })
        if modelsUsed.count == 1 && agents.count > 3 {
            let simpleAgents = agents.filter { $0.agentComplexity == .deterministic || $0.agentComplexity == .conditional }
            if !simpleAgents.isEmpty {
                recs.append(ScalingRecommendation(
                    id: UUID(), concern: .cost,
                    title: String(localized: "Right-size models"),
                    detail: String(format: String(localized: "All %lld agents use the same model. %lld simpler agents could use a smaller, cheaper model to reduce cost without quality impact."), agents.count, simpleAgents.count),
                    priority: priority
                ))
                priority += 1
            }
        }

        // Quality: poor error handling
        let noErrorHandling = tools.filter { $0.toolErrorHandling == .none }
        if noErrorHandling.count > tools.count / 2 && tools.count > 2 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .quality,
                title: String(localized: "Improve error handling"),
                detail: String(format: String(localized: "%lld of %lld tools have no error handling. Add retry, fallback, or circuit-breaker patterns to prevent cascading failures under load."), noErrorHandling.count, tools.count),
                priority: priority
            ))
            priority += 1
        }

        // Quality: no fallback tools
        let fallbackTools = tools.filter { $0.toolErrorHandling == .fallback }
        if fallbackTools.isEmpty && tools.count > 5 {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .quality,
                title: String(localized: "Add fallback paths"),
                detail: String(localized: "No tools with fallback error handling. Under load, saturated backends need graceful degradation — serve stale cache or switch to a simpler model."),
                priority: priority
            ))
            priority += 1
        }

        // Throughput: large knowledge without caching
        let largeKnowledge = knowledge.filter { k in
            let size = (k.knowledgeSizeQuantity ?? "").lowercased()
            return size.contains("gb") || size.contains("tb") || size.contains("million")
        }
        if !largeKnowledge.isEmpty && cachingTools.isEmpty {
            recs.append(ScalingRecommendation(
                id: UUID(), concern: .throughput,
                title: String(localized: "Cache knowledge retrieval"),
                detail: String(format: String(localized: "%lld large knowledge source(s) with no caching tools. RAG retrieval latency will degrade significantly under concurrent queries."), largeKnowledge.count),
                priority: priority
            ))
            priority += 1
        }

        return recs.sorted { $0.priority < $1.priority }
    }

    // MARK: - Caching Assessment

    private static func computeCachingAssessment(
        tools: [GraphNode], params: SizingParameters
    ) -> CachingAssessment {
        let cachingTools = tools.filter { $0.toolCategory == .caching }
        let hasCaching = !cachingTools.isEmpty
        let idempotentTools = tools.filter { $0.toolIdempotent && $0.toolCategory != .caching }

        let costSavings: Int
        let latencyReduction: Int
        var recommendations: [String] = []
        var candidates: [CacheCandidate] = []

        if hasCaching {
            costSavings = params.cachingCostSavingsMax
            latencyReduction = params.cachingLatencyReductionMax
            if !idempotentTools.isEmpty {
                recommendations.append(String(format: String(localized: "Consider caching results for %lld additional idempotent tool(s):"), idempotentTools.count))
                candidates = idempotentTools.map { CacheCandidate(id: $0.id, name: $0.title, reason: String(localized: "Idempotent")) }
            }
        } else {
            costSavings = 0
            latencyReduction = 0
            recommendations.append(String(format: String(localized: "Add prompt prefix caching to reduce repeated system prompt costs (%lld–%lld%% savings possible)"), params.cachingCostSavingsMin, params.cachingCostSavingsMax))
            recommendations.append(String(localized: "Add tool result caching for infrequently changing, expensive tool calls"))
            if !idempotentTools.isEmpty {
                recommendations.append(String(format: String(localized: "%lld idempotent tool(s) are safe candidates for result caching:"), idempotentTools.count))
                candidates = idempotentTools.map { CacheCandidate(id: $0.id, name: $0.title, reason: String(localized: "Idempotent")) }
            }
        }

        return CachingAssessment(
            hasCachingTools: hasCaching,
            cachingToolNames: cachingTools.map(\.title),
            estimatedCostSavingsPercent: costSavings,
            estimatedLatencyReductionPercent: latencyReduction,
            recommendations: recommendations,
            cacheCandidates: candidates
        )
    }

    // MARK: - Helpers

    private static func categoryDisplayName(_ raw: String) -> String {
        ToolCategory(rawValue: raw)?.displayName ?? raw.capitalized
    }

    // MARK: - Markdown Export

    static func generateMarkdown(estimate: SizingEstimate, projectName: String, parameters: SizingParameters = .defaults) -> String {
        var md = "# Sizing Estimate — \(projectName)\n\n"
        md += "**Generated:** \(estimate.timestamp.formatted(date: .long, time: .shortened))\n\n"
        md += "> **Disclaimer:** Estimates are based on graph structure and sizing rules of thumb. Actual requirements may vary based on workload characteristics, model choices, and deployment environment.\n\n"

        // Infrastructure summary
        let infra = estimate.infrastructure
        md += "## Infrastructure Estimate\n\n"
        md += "**Tier:** \(infra.tier.displayName) (\(infra.rationale))\n\n"
        md += "| Resource | Per \(infra.baseUserCount) Users |"
        if let scaled = infra.scaledUserCount {
            md += " Scaled (\(scaled) Users) |"
        }
        md += "\n|---|---|"
        if infra.scaledUserCount != nil { md += "---|" }
        md += "\n"
        md += "| vCPU | \(infra.vCPU) |"
        if let sv = infra.scaledVCPU { md += " \(sv) |" }
        md += "\n"
        md += "| RAM (GB) | \(infra.ramGB) |"
        if let sr = infra.scaledRAMGB { md += " \(sr) |" }
        md += "\n"
        md += "| Executor Pods | \(infra.executorPods) |"
        if infra.scaledUserCount != nil { md += " — |" }
        md += "\n\n"

        if !infra.riskAreas.isEmpty {
            md += "### Risk Areas\n\n"
            for risk in infra.riskAreas {
                md += "- **\(risk.area)** (\(risk.level.displayName)): \(risk.detail)\n"
            }
            md += "\n"
        }

        // Workload Profile
        let wp = estimate.workloadProfile
        md += "## Workload Profile\n\n"
        md += "| Dimension | Value | Notes |\n|---|---|---|\n"
        md += "| Interaction | \(wp.interactionPattern.displayName) | \(wp.interactionRationale) |\n"
        md += "| Concurrency | \(wp.concurrency.peakInferenceRequests) peak inferences | \(wp.concurrency.rationale) |\n"
        md += "| Token Profile | Input: \(wp.tokenProfile.inputRange), Output: \(wp.tokenProfile.outputRange) | \(wp.tokenProfile.rationale) |\n"
        md += "| External Calls | \(wp.externalCalls.totalExternalTools) tools (\(wp.externalCalls.asyncToolCount) async) | Risk: \(wp.externalCalls.riskLevel.displayName) |\n"
        md += "| Consistency | \(wp.consistencyAppetite) | — |\n\n"

        // Architecture
        md += "## Architecture Decomposition\n\n"
        for tier in [estimate.architecture.frontDoor, estimate.architecture.agentRuntime, estimate.architecture.inference] {
            md += "### \(tier.name)\n"
            for comp in tier.components { md += "- ✅ \(comp)\n" }
            for gap in tier.gaps { md += "- ⚠️ \(gap)\n" }
            md += "\n"
        }

        // Scaling Recommendations
        if !estimate.scalingRecommendations.isEmpty {
            md += "## Scaling Recommendations\n\n"
            for rec in estimate.scalingRecommendations {
                md += "\(rec.priority). **\(rec.title)** (\(rec.concern.displayName)) — \(rec.detail)\n"
            }
            md += "\n"
        }

        // Caching
        let cache = estimate.cachingAssessment
        md += "## Caching Assessment\n\n"
        if cache.hasCachingTools {
            md += "Caching tools present: \(cache.cachingToolNames.joined(separator: ", "))\n\n"
        } else {
            md += "**No caching tools detected.**\n\n"
        }
        md += "- Estimated cost savings: \(cache.estimatedCostSavingsPercent)%\n"
        md += "- Estimated latency reduction: \(cache.estimatedLatencyReductionPercent)%\n\n"
        for rec in cache.recommendations {
            md += "- \(rec)\n"
        }
        // Sizing Parameters appendix
        md += "## Sizing Parameters\n\n"
        md += "| Parameter | Value |\n|---|---|\n"
        md += "| Base User Count | \(parameters.baseUserCount) |\n"
        md += "| Simple Tier | ≤\(parameters.simpleTier.maxAgents) agents, ≤\(parameters.simpleTier.maxTools) tools → \(parameters.simpleTier.vCPU) vCPU, \(parameters.simpleTier.ramGB) GB RAM |\n"
        md += "| Medium Tier | ≤\(parameters.mediumTier.maxAgents) agents, ≤\(parameters.mediumTier.maxTools) tools → \(parameters.mediumTier.vCPU) vCPU, \(parameters.mediumTier.ramGB) GB RAM |\n"
        md += "| Hard Tier | >\(parameters.mediumTier.maxAgents) agents or >\(parameters.mediumTier.maxTools) tools → \(parameters.hardTier.vCPU) vCPU, \(parameters.hardTier.ramGB) GB RAM |\n"
        md += "| Concurrency Multiplier | Low: \(parameters.concurrencyMultiplierLow), High: \(parameters.concurrencyMultiplierHigh) |\n"
        md += "| Caching Cost Savings | \(parameters.cachingCostSavingsMin)–\(parameters.cachingCostSavingsMax)% |\n"
        md += "| Caching Latency Reduction | \(parameters.cachingLatencyReductionMin)–\(parameters.cachingLatencyReductionMax)% |\n"
        md += "| Front Door Categories | \(parameters.frontDoorCategories.joined(separator: ", ")) |\n"
        md += "| Agent Runtime Categories | \(parameters.agentRuntimeCategories.joined(separator: ", ")) |\n"
        md += "| Inference Categories | \(parameters.inferenceCategories.joined(separator: ", ")) |\n\n"

        md += "---\n"

        return md
    }

    // MARK: - HTML Export

    static func generateHTML(estimate: SizingEstimate, projectName: String, parameters: SizingParameters = .defaults) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }

        let infra = estimate.infrastructure
        let wp = estimate.workloadProfile
        let cache = estimate.cachingAssessment

        let tierColor: String = switch infra.tier {
        case .simple: "#34c759"
        case .medium: "#ff9500"
        case .hard: "#ff3b30"
        }

        func riskColor(_ level: SizingRiskLevel) -> String {
            switch level {
            case .low: "#34c759"
            case .moderate: "#ff9500"
            case .high: "#ff3b30"
            }
        }

        func riskIcon(_ level: SizingRiskLevel) -> String {
            switch level {
            case .low: "&#x2705;"
            case .moderate: "&#x26A0;&#xFE0F;"
            case .high: "&#x1F6D1;"
            }
        }

        func concernIcon(_ concern: ScalingConcern) -> String {
            switch concern {
            case .latency: "&#x23F1;"
            case .throughput: "&#x1F4C8;"
            case .cost: "&#x1F4B0;"
            case .quality: "&#x2705;"
            }
        }

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Sizing Estimate — \(esc(projectName))</title>
        <style>
            :root { --bg: #ffffff; --fg: #1d1d1f; --muted: #6e6e73; --border: #d2d2d7; --accent: #0066cc; --section-bg: #f5f5f7; }
            @media (prefers-color-scheme: dark) {
                :root:not([data-theme="light"]) { --bg: #1d1d1f; --fg: #f5f5f7; --muted: #98989d; --border: #424245; --accent: #2997ff; --section-bg: #2c2c2e; }
            }
            [data-theme="dark"] { --bg: #1d1d1f; --fg: #f5f5f7; --muted: #98989d; --border: #424245; --accent: #2997ff; --section-bg: #2c2c2e; }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--fg); line-height: 1.6; padding: 40px 20px; }
            .container { max-width: 900px; margin: 0 auto; }
            h1 { font-size: 2em; margin-bottom: 0.3em; }
            h2 { font-size: 1.4em; margin-top: 2em; margin-bottom: 0.6em; color: var(--accent); border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
            h3 { font-size: 1.1em; margin-top: 1em; margin-bottom: 0.4em; }
            .overview { font-size: 1.1em; color: var(--muted); margin-bottom: 1.5em; }
            .summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 2em; }
            .summary-card { background: var(--section-bg); border-radius: 8px; padding: 16px; text-align: center; }
            .summary-card .value { font-size: 2em; font-weight: 700; }
            .summary-card .label { font-size: 0.85em; color: var(--muted); }
            .card { background: var(--section-bg); border-radius: 8px; padding: 16px 20px; margin-bottom: 12px; }
            .tier-badge { display: inline-block; padding: 4px 12px; border-radius: 4px; font-weight: 700; font-size: 0.85em; color: white; }
            table { width: 100%; border-collapse: collapse; margin: 12px 0; }
            th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); }
            th { font-weight: 600; color: var(--muted); font-size: 0.9em; }
            .risk-item { display: flex; align-items: flex-start; gap: 8px; margin: 4px 0; }
            .progress-bar { background: var(--border); border-radius: 3px; height: 8px; overflow: hidden; margin-top: 4px; }
            .progress-fill { height: 100%; border-radius: 3px; }
            .rec-card { background: var(--section-bg); border-radius: 8px; padding: 16px 20px; margin-bottom: 12px; border-left: 4px solid var(--accent); }
            .rec-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
            .concern-chip { font-size: 0.75em; padding: 2px 8px; border-radius: 4px; background: var(--border); color: var(--muted); }
            .disclaimer { font-size: 0.85em; color: var(--muted); margin-top: 3em; padding-top: 1em; border-top: 1px solid var(--border); }
        </style>
        </head>
        <body>
        <div class="container">
        <h1>Sizing Estimate — \(esc(projectName))</h1>
        <p class="overview">Generated \(estimate.timestamp.formatted(date: .long, time: .shortened))</p>
        <div class="card" style="border-left: 4px solid var(--accent); margin-bottom: 1.5em">
            <p style="color: var(--muted); font-size: 0.9em"><strong>Disclaimer:</strong> Estimates are based on graph structure and sizing rules of thumb. Actual requirements may vary based on workload characteristics, model choices, and deployment environment.</p>
        </div>
        """

        // Summary cards
        html += """
        <div class="summary-grid">
            <div class="summary-card">
                <div class="value" style="color: \(tierColor)">\(esc(infra.tier.displayName))</div>
                <div class="label">Tier</div>
            </div>
            <div class="summary-card">
                <div class="value">\(infra.vCPU)</div>
                <div class="label">vCPU</div>
            </div>
            <div class="summary-card">
                <div class="value">\(infra.ramGB)</div>
                <div class="label">GB RAM</div>
            </div>
            <div class="summary-card">
                <div class="value">\(infra.executorPods)</div>
                <div class="label">Pods</div>
            </div>
        </div>
        """

        // Infrastructure
        html += "<h2>Infrastructure Estimate</h2>"
        html += "<div class=\"card\"><p>\(esc(infra.rationale))</p>"
        html += "<table><tr><th>Resource</th><th>Per \(infra.baseUserCount) Users</th>"
        if let s = infra.scaledUserCount { html += "<th>Scaled (\(s) Users)</th>" }
        html += "</tr>"
        html += "<tr><td>vCPU</td><td>\(infra.vCPU)</td>"
        if let sv = infra.scaledVCPU { html += "<td>\(sv)</td>" }
        html += "</tr>"
        html += "<tr><td>RAM</td><td>\(infra.ramGB) GB</td>"
        if let sr = infra.scaledRAMGB { html += "<td>\(sr) GB</td>" }
        html += "</tr>"
        html += "<tr><td>Executor Pods</td><td>\(infra.executorPods)</td>"
        if infra.scaledUserCount != nil { html += "<td>—</td>" }
        html += "</tr></table></div>"

        for risk in infra.riskAreas {
            html += "<div class=\"card\" style=\"border-left: 4px solid \(riskColor(risk.level))\">"
            html += "<strong>\(riskIcon(risk.level)) \(esc(risk.area))</strong> "
            html += "<span style=\"color: var(--muted)\">(\(esc(risk.level.displayName)))</span>"
            html += "<p style=\"margin-top: 4px; color: var(--muted)\">\(esc(risk.detail))</p>"
            if !risk.relatedNodes.isEmpty {
                html += "<p style=\"margin-top: 4px\">"
                for ref in risk.relatedNodes {
                    let name = ref.name
                    html += "<span style=\"font-size: 0.8em; padding: 2px 8px; border-radius: 12px; background: var(--section-bg); border: 1px solid var(--border); margin-right: 4px\">\(esc(name))</span>"
                }
                html += "</p>"
            }
            html += "</div>"
        }

        // Workload Profile
        html += "<h2>Workload Profile</h2>"
        html += "<table><tr><th>Dimension</th><th>Value</th><th>Notes</th></tr>"
        html += "<tr><td>Interaction</td><td>\(esc(wp.interactionPattern.displayName)) (\(esc(wp.interactionPattern.latencyTarget)))</td><td>\(esc(wp.interactionRationale))</td></tr>"
        html += "<tr><td>Concurrency</td><td>\(wp.concurrency.peakInferenceRequests) peak inferences</td><td>\(esc(wp.concurrency.rationale))</td></tr>"
        html += "<tr><td>Token Profile</td><td>In: \(esc(wp.tokenProfile.inputRange)), Out: \(esc(wp.tokenProfile.outputRange))</td><td>\(esc(wp.tokenProfile.rationale))</td></tr>"
        html += "<tr><td>External Calls</td><td>\(wp.externalCalls.totalExternalTools) tools (\(wp.externalCalls.asyncToolCount) async)</td><td>\(esc(wp.externalCalls.riskLevel.displayName)) risk</td></tr>"
        html += "<tr><td>Consistency</td><td>\(esc(wp.consistencyAppetite))</td><td>—</td></tr>"
        html += "</table>"

        // Architecture Decomposition
        html += "<h2>Architecture Decomposition</h2>"
        for tier in [estimate.architecture.frontDoor, estimate.architecture.agentRuntime, estimate.architecture.inference] {
            html += "<div class=\"card\"><h3>\(esc(tier.name)) <span style=\"float: right\">\(riskIcon(tier.riskLevel))</span></h3>"
            for comp in tier.components {
                html += "<div class=\"risk-item\">&#x2705; \(esc(comp))</div>"
            }
            for gap in tier.gaps {
                html += "<div class=\"risk-item\">&#x26A0;&#xFE0F; <span style=\"color: var(--muted)\">\(esc(gap))</span></div>"
            }
            html += "</div>"
        }

        // Scaling Recommendations
        if !estimate.scalingRecommendations.isEmpty {
            html += "<h2>Scaling Recommendations</h2>"
            for rec in estimate.scalingRecommendations {
                html += "<div class=\"rec-card\">"
                html += "<div class=\"rec-header\">\(concernIcon(rec.concern)) <strong>\(esc(rec.title))</strong> "
                html += "<span class=\"concern-chip\">\(esc(rec.concern.displayName))</span></div>"
                html += "<p style=\"color: var(--muted)\">\(esc(rec.detail))</p></div>"
            }
        }

        // Caching Assessment
        html += "<h2>Caching Assessment</h2>"
        html += "<div class=\"card\">"
        if cache.hasCachingTools {
            html += "<p>&#x2705; Caching tools: \(esc(cache.cachingToolNames.joined(separator: ", ")))</p>"
        } else {
            html += "<p>&#x26A0;&#xFE0F; <strong>No caching tools detected</strong></p>"
        }
        html += "<div style=\"margin: 12px 0\">"
        html += "<p style=\"font-size: 0.9em; color: var(--muted)\">Cost savings: \(cache.estimatedCostSavingsPercent)%</p>"
        html += "<div class=\"progress-bar\"><div class=\"progress-fill\" style=\"width: \(cache.estimatedCostSavingsPercent)%; background: #34c759\"></div></div>"
        html += "<p style=\"font-size: 0.9em; color: var(--muted); margin-top: 8px\">Latency reduction: \(cache.estimatedLatencyReductionPercent)%</p>"
        html += "<div class=\"progress-bar\"><div class=\"progress-fill\" style=\"width: \(cache.estimatedLatencyReductionPercent)%; background: #007aff\"></div></div>"
        html += "</div>"
        for rec in cache.recommendations {
            html += "<p style=\"color: var(--muted); margin-top: 4px\">• \(esc(rec))</p>"
        }
        html += "</div>"

        // Sizing Parameters appendix
        html += "<h2>Sizing Parameters</h2>"
        html += "<table>"
        html += "<tr><th>Parameter</th><th>Value</th></tr>"
        html += "<tr><td>Base User Count</td><td>\(parameters.baseUserCount)</td></tr>"
        html += "<tr><td>Simple Tier</td><td>&le;\(parameters.simpleTier.maxAgents) agents, &le;\(parameters.simpleTier.maxTools) tools &rarr; \(parameters.simpleTier.vCPU) vCPU, \(parameters.simpleTier.ramGB) GB RAM</td></tr>"
        html += "<tr><td>Medium Tier</td><td>&le;\(parameters.mediumTier.maxAgents) agents, &le;\(parameters.mediumTier.maxTools) tools &rarr; \(parameters.mediumTier.vCPU) vCPU, \(parameters.mediumTier.ramGB) GB RAM</td></tr>"
        html += "<tr><td>Hard Tier</td><td>&gt;\(parameters.mediumTier.maxAgents) agents or &gt;\(parameters.mediumTier.maxTools) tools &rarr; \(parameters.hardTier.vCPU) vCPU, \(parameters.hardTier.ramGB) GB RAM</td></tr>"
        html += "<tr><td>Concurrency Multiplier</td><td>Low: \(parameters.concurrencyMultiplierLow), High: \(parameters.concurrencyMultiplierHigh)</td></tr>"
        html += "<tr><td>Caching Cost Savings</td><td>\(parameters.cachingCostSavingsMin)&ndash;\(parameters.cachingCostSavingsMax)%</td></tr>"
        html += "<tr><td>Caching Latency Reduction</td><td>\(parameters.cachingLatencyReductionMin)&ndash;\(parameters.cachingLatencyReductionMax)%</td></tr>"
        html += "<tr><td>Front Door Categories</td><td>\(esc(parameters.frontDoorCategories.joined(separator: ", ")))</td></tr>"
        html += "<tr><td>Agent Runtime Categories</td><td>\(esc(parameters.agentRuntimeCategories.joined(separator: ", ")))</td></tr>"
        html += "<tr><td>Inference Categories</td><td>\(esc(parameters.inferenceCategories.joined(separator: ", ")))</td></tr>"
        html += "</table>"

        html += "</div></body></html>"

        return html
    }
}
