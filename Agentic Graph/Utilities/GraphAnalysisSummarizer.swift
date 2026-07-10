import Foundation

/// Converts a GraphDocument into a compact text summary for LLM analysis.
/// Pre-computes structural observations that the model would struggle with.
enum GraphAnalysisSummarizer {

    /// Summarize with optional filtering to only include specific node kinds.
    static func summarize(document: GraphDocument, relevantKinds: Set<String>? = nil) -> String {
        let graphNodes = document.nodes.filter { !$0.kind.isShape }
        let includeAll = relevantKinds == nil
        let agents = graphNodes.filter { $0.kind == .agent && (includeAll || relevantKinds!.contains("agent")) }
        let tools = graphNodes.filter { $0.kind == .tool && (includeAll || relevantKinds!.contains("tool")) }
        let knowledge = graphNodes.filter { $0.kind == .knowledge && (includeAll || relevantKinds!.contains("knowledge")) }
        let humans = graphNodes.filter { $0.kind == .human && (includeAll || relevantKinds!.contains("human")) }

        let graphEdges = document.edges.filter { edge in
            guard let source = document.node(for: edge.sourceNodeID),
                  let target = document.node(for: edge.targetNodeID) else { return false }
            return !source.kind.isShape && !target.kind.isShape
        }

        var text = ""

        // Project header
        text += "PROJECT: \(document.projectName)\n"
        text += "DEPLOYMENT: \(document.deploymentTarget?.displayName ?? "Not set")"
        text += " | RISK: \(document.overallRiskLevel.displayName)"
        if let compliance = document.complianceRequirements, !compliance.isEmpty {
            text += " | COMPLIANCE: \(compliance)"
        }
        text += "\n"
        if let desc = document.projectDescription, !desc.isEmpty {
            text += "DESCRIPTION: \(desc)\n"
        }
        text += "\n"

        // Agents
        if !agents.isEmpty {
            text += "AGENTS (\(agents.count)):\n"
            for node in agents {
                let connectedTools = toolsConnected(to: node, document: document)
                let connectedKnowledge = knowledgeConnected(to: node, document: document)

                text += "- \"\(node.title)\" [type=\(node.agentType.displayName)"
                text += ", framework=\(node.agentFramework.displayName)"
                if let model = node.agentModel, !model.isEmpty { text += ", model=\(model)" }
                text += ", memory=\(node.agentMemory.displayName)"
                text += ", delegation=\(node.agentCanDelegate ? "yes" : "no")"
                text += ", complexity=\(node.agentComplexity.displayName)"
                text += ", promptMgmt=\(node.agentPromptManagement.displayName)"
                text += ", contextStrategy=\(node.agentContextStrategy.displayName)"
                text += ", observability=\(node.agentObservability.displayName)"
                if let maxIter = node.agentMaxIterations, !maxIter.isEmpty { text += ", maxIter=\(maxIter)" }
                if let latency = node.agentLatencyBudget, !latency.isEmpty { text += ", latencyBudget=\(latency)" }
                if let cost = node.agentCostBudget, !cost.isEmpty { text += ", costBudget=\(cost)" }
                text += ", risk=\(node.risk.displayName)"
                text += "]\n"

                if let role = node.agentRole, !role.isEmpty { text += "  Role: \(role)\n" }
                if let goal = node.agentGoal, !goal.isEmpty { text += "  Goal: \(goal)\n" }
                if !node.detail.isEmpty { text += "  Detail: \(node.detail)\n" }
                if !connectedTools.isEmpty {
                    text += "  Connected tools: [\(connectedTools.map(\.title).joined(separator: ", "))]\n"
                }
                if !connectedKnowledge.isEmpty {
                    text += "  Connected knowledge: [\(connectedKnowledge.map(\.title).joined(separator: ", "))]\n"
                }
            }
            text += "\n"
        }

        // Tools
        if !tools.isEmpty {
            text += "TOOLS (\(tools.count)):\n"
            for node in tools {
                let connectedFrom = agentsConnected(to: node, document: document)

                text += "- \"\(node.title)\" [type=\(node.toolType.displayName)"
                text += ", category=\(node.toolCategory.displayName)"
                text += ", async=\(node.toolAsync ? "yes" : "no")"
                text += ", auth=\(node.toolAuthMethod.displayName)"
                text += ", errorHandling=\(node.toolErrorHandling.displayName)"
                text += ", idempotent=\(node.toolIdempotent ? "yes" : "no")"
                if let timeout = node.toolTimeout, !timeout.isEmpty { text += ", timeout=\(timeout)" }
                if let vol = node.toolDataVolume, !vol.isEmpty { text += ", dataVolume=\(vol)" }
                text += "]\n"

                if !node.detail.isEmpty { text += "  Detail: \(node.detail)\n" }
                if let inputs = node.toolInputs, !inputs.isEmpty { text += "  Inputs: \(inputs)\n" }
                if let outputs = node.toolOutputs, !outputs.isEmpty { text += "  Outputs: \(outputs)\n" }
                if !connectedFrom.isEmpty {
                    text += "  Connected from agents: [\(connectedFrom.map(\.title).joined(separator: ", "))]\n"
                }
            }
            text += "\n"
        }

        // Knowledge
        if !knowledge.isEmpty {
            text += "KNOWLEDGE (\(knowledge.count)):\n"
            for node in knowledge {
                let connectedFrom = nodesConnected(to: node, document: document)

                text += "- \"\(node.title)\" ["
                if let formats = node.knowledgeDataFormats, !formats.isEmpty { text += "formats=\(formats), " }
                if let sensitivity = node.knowledgeSensitivity, !sensitivity.isEmpty { text += "sensitivity=\(sensitivity), " }
                if let size = node.knowledgeSizeQuantity, !size.isEmpty { text += "size=\(size), " }
                if let freq = node.knowledgeUpdateFrequency, !freq.isEmpty { text += "updateFreq=\(freq), " }
                text += "retrieval=\(node.knowledgeRetrievalStrategy.displayName)"
                if let chunking = node.knowledgeChunkingStrategy, !chunking.isEmpty { text += ", chunking=\(chunking)" }
                if let contentType = node.knowledgeContentType, !contentType.isEmpty { text += ", contentType=\(contentType)" }
                text += ", risk=\(node.risk.displayName)"
                text += "]\n"

                if !node.detail.isEmpty { text += "  Detail: \(node.detail)\n" }
                if !connectedFrom.isEmpty {
                    text += "  Connected from: [\(connectedFrom.map { "\($0.title) (\($0.kind.displayName))" }.joined(separator: ", "))]\n"
                }
            }
            text += "\n"
        }

        // Humans
        if !humans.isEmpty {
            text += "HUMANS (\(humans.count)):\n"
            for node in humans {
                let connectedFrom = nodesConnected(to: node, document: document)

                text += "- \"\(node.title)\" [input=\(node.humanInputChannel.displayName), output=\(node.humanChannel.displayName)"
                if let role = node.humanRole, !role.isEmpty { text += ", role=\(role)" }
                if let lang = node.humanLanguage, !lang.isEmpty { text += ", language=\(lang)" }
                if let tz = node.humanTimezone, !tz.isEmpty { text += ", timezone=\(tz)" }
                if let auth = node.humanAuthMethod, !auth.isEmpty { text += ", auth=\(auth)" }
                if let access = node.humanAccessLevel, !access.isEmpty { text += ", access=\(access)" }
                if let sla = node.humanSLA, !sla.isEmpty { text += ", sla=\(sla)" }
                text += "]\n"

                if !node.detail.isEmpty { text += "  Detail: \(node.detail)\n" }
                if let behaviors = node.humanBehaviors, !behaviors.isEmpty { text += "  Behaviors: \(behaviors)\n" }
                if !connectedFrom.isEmpty {
                    text += "  Connected to: [\(connectedFrom.map { "\($0.title) (\($0.kind.displayName))" }.joined(separator: ", "))]\n"
                }
            }
            text += "\n"
        }

        // Data flow
        if !graphEdges.isEmpty {
            text += "DATA FLOW (\(graphEdges.count) connections):\n"
            for edge in graphEdges {
                if let source = document.node(for: edge.sourceNodeID),
                   let target = document.node(for: edge.targetNodeID) {
                    text += "- \"\(source.title)\" (\(source.kind.displayName)) -> \"\(target.title)\" (\(target.kind.displayName))\n"
                }
            }
            text += "\n"
        }

        // Pre-computed structural observations
        text += "STRUCTURAL OBSERVATIONS:\n"
        text += computeStructuralObservations(agents: agents, tools: tools, knowledge: knowledge,
                                               humans: humans, edges: graphEdges, document: document)

        return text
    }

    // MARK: - Structural Observations

    private static func computeStructuralObservations(
        agents: [GraphNode], tools: [GraphNode], knowledge: [GraphNode],
        humans: [GraphNode], edges: [GraphEdge], document: GraphDocument
    ) -> String {
        var obs = ""

        // Agents with no tools connected
        let agentsNoTools = agents.filter { agent in
            toolsConnected(to: agent, document: document).isEmpty
        }
        obs += "- Agents with no tools connected: \(listOrNone(agentsNoTools))\n"

        // Agents with 10+ tools
        let agentsManyTools = agents.filter { agent in
            toolsConnected(to: agent, document: document).count >= 10
        }
        obs += "- Agents with 10+ tools: \(listOrNone(agentsManyTools))\n"

        // Tools with no error handling
        let toolsNoErrorHandling = tools.filter { $0.toolErrorHandling == .none }
        obs += "- Tools with no error handling: \(listOrNone(toolsNoErrorHandling))\n"

        // Tools connected to multiple agents
        let toolsMultiAgent = tools.filter { tool in
            agentsConnected(to: tool, document: document).count > 1
        }
        obs += "- Tools connected to multiple agents: \(listOrNone(toolsMultiAgent))\n"

        // Agents with delegation enabled
        let agentsDelegation = agents.filter(\.agentCanDelegate)
        obs += "- Agents with delegation enabled: \(listOrNone(agentsDelegation))\n"

        // Agents with no memory
        let agentsNoMemory = agents.filter { $0.agentMemory == .none }
        obs += "- Agents with no memory configured: \(listOrNone(agentsNoMemory))\n"

        // Agents with no role/goal
        let agentsNoRoleGoal = agents.filter {
            ($0.agentRole ?? "").isEmpty && ($0.agentGoal ?? "").isEmpty
        }
        obs += "- Agents with no role or goal defined: \(listOrNone(agentsNoRoleGoal))\n"

        // Agents with no max iterations
        let agentsNoMaxIter = agents.filter { ($0.agentMaxIterations ?? "").isEmpty }
        obs += "- Agents with no max iterations: \(listOrNone(agentsNoMaxIter))\n"

        // High-risk nodes
        let highRisk = (agents + tools + knowledge).filter { $0.risk == .high }
        obs += "- High-risk nodes: \(listOrNone(highRisk))\n"

        // Knowledge with no sensitivity set
        let knowledgeNoSensitivity = knowledge.filter { ($0.knowledgeSensitivity ?? "").isEmpty }
        obs += "- Knowledge sources with no sensitivity set: \(listOrNone(knowledgeNoSensitivity))\n"

        // Disconnected nodes (no edges at all)
        let allGraphNodes = agents + tools + knowledge + humans
        let disconnected = allGraphNodes.filter { node in
            document.edges(connectedTo: node.id).isEmpty
        }
        obs += "- Disconnected nodes (no connections): \(listOrNone(disconnected))\n"

        // Tools with no auth
        let toolsNoAuth = tools.filter { $0.toolAuthMethod == .none }
        obs += "- Tools with no authentication: \(listOrNone(toolsNoAuth))\n"

        // New field observations
        let supervisors = agents.filter { $0.agentType == .supervisor || $0.agentType == .orchestrator }
        obs += "- Supervisor/orchestrator agents: \(listOrNone(supervisors))\n"

        let routers = agents.filter { $0.agentType == .router }
        obs += "- Router agents: \(listOrNone(routers))\n"

        let agentsNoObservability = agents.filter { $0.agentObservability == .none }
        obs += "- Agents with no observability: \(listOrNone(agentsNoObservability))\n"

        let agentsNoPromptMgmt = agents.filter { $0.agentPromptManagement == .none || $0.agentPromptManagement == .hardcoded }
        obs += "- Agents with no/hardcoded prompt management: \(listOrNone(agentsNoPromptMgmt))\n"

        let agentsNoContextStrategy = agents.filter { $0.agentContextStrategy == .none }
        obs += "- Agents with no context strategy: \(listOrNone(agentsNoContextStrategy))\n"

        let deterministicAgents = agents.filter { $0.agentComplexity == .deterministic }
        obs += "- Deterministic agents (potential agent washing): \(listOrNone(deterministicAgents))\n"

        let guardrailTools = tools.filter { $0.toolCategory == .guardrail }
        obs += "- Guardrail tools: \(listOrNone(guardrailTools))\n"

        let monitoringTools = tools.filter { $0.toolCategory == .monitoring }
        obs += "- Monitoring tools: \(listOrNone(monitoringTools))\n"

        let cachingTools = tools.filter { $0.toolCategory == .caching }
        obs += "- Caching tools: \(listOrNone(cachingTools))\n"

        let testingTools = tools.filter { $0.toolCategory == .testing }
        obs += "- Testing/evaluation tools: \(listOrNone(testingTools))\n"

        let feedbackTools = tools.filter { $0.toolCategory == .feedback }
        obs += "- Feedback tools: \(listOrNone(feedbackTools))\n"

        let securityTools = tools.filter { $0.toolCategory == .security }
        obs += "- Security tools: \(listOrNone(securityTools))\n"

        let workflowTools = tools.filter { $0.toolCategory == .workflow }
        obs += "- Workflow tools: \(listOrNone(workflowTools))\n"

        let deliveryTools = tools.filter { $0.toolCategory == .delivery }
        obs += "- Delivery tools: \(listOrNone(deliveryTools))\n"

        let toolsNotIdempotent = tools.filter { !$0.toolIdempotent }
        obs += "- Tools not idempotent: \(listOrNone(toolsNotIdempotent))\n"

        let knowledgeNoRetrieval = knowledge.filter { $0.knowledgeRetrievalStrategy == .none }
        obs += "- Knowledge with no retrieval strategy: \(listOrNone(knowledgeNoRetrieval))\n"

        let knowledgeNoChunking = knowledge.filter { ($0.knowledgeChunkingStrategy ?? "").isEmpty }
        obs += "- Knowledge with no chunking strategy: \(listOrNone(knowledgeNoChunking))\n"

        // Architecture type
        obs += "- Single-agent architecture: \(agents.count <= 1 ? "yes" : "no")\n"
        obs += "- Total agents: \(agents.count), tools: \(tools.count), knowledge: \(knowledge.count), humans: \(humans.count)\n"
        obs += "- Total connections: \(edges.count)\n"

        return obs
    }

    // MARK: - Connection Helpers

    private static func toolsConnected(to agent: GraphNode, document: GraphDocument) -> [GraphNode] {
        document.edges.compactMap { edge in
            if edge.sourceNodeID == agent.id,
               let target = document.node(for: edge.targetNodeID),
               target.kind == .tool {
                return target
            }
            return nil
        }
    }

    private static func knowledgeConnected(to agent: GraphNode, document: GraphDocument) -> [GraphNode] {
        document.edges.compactMap { edge in
            // Knowledge can be connected in either direction
            if edge.sourceNodeID == agent.id,
               let target = document.node(for: edge.targetNodeID),
               target.kind == .knowledge {
                return target
            }
            if edge.targetNodeID == agent.id,
               let source = document.node(for: edge.sourceNodeID),
               source.kind == .knowledge {
                return source
            }
            return nil
        }
    }

    private static func agentsConnected(to tool: GraphNode, document: GraphDocument) -> [GraphNode] {
        document.edges.compactMap { edge in
            if edge.targetNodeID == tool.id,
               let source = document.node(for: edge.sourceNodeID),
               source.kind == .agent {
                return source
            }
            return nil
        }
    }

    private static func nodesConnected(to node: GraphNode, document: GraphDocument) -> [GraphNode] {
        document.edges.compactMap { edge in
            if edge.targetNodeID == node.id,
               let source = document.node(for: edge.sourceNodeID),
               !source.kind.isShape {
                return source
            }
            if edge.sourceNodeID == node.id,
               let target = document.node(for: edge.targetNodeID),
               !target.kind.isShape {
                return target
            }
            return nil
        }
    }

    private static func listOrNone(_ nodes: [GraphNode]) -> String {
        nodes.isEmpty ? "none" : nodes.map { "\"\($0.title)\"" }.joined(separator: ", ")
    }
}
