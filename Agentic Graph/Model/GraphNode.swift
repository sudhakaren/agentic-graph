import Foundation
import AppKit
import SwiftUI

enum RiskLevel: String, Codable, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    var sfSymbol: String {
        switch self {
        case .none: ""
        case .low: "checkmark.shield.fill"
        case .medium: "exclamationmark.triangle.fill"
        case .high: "exclamationmark.octagon.fill"
        }
    }

    var letter: String {
        switch self {
        case .none: ""
        case .low: "L"
        case .medium: "M"
        case .high: "H"
        }
    }

    var badgeColor: Color {
        switch self {
        case .none: .clear
        case .low: Color(red: 0.2, green: 0.7, blue: 0.3)
        case .medium: Color(red: 0.95, green: 0.7, blue: 0.1)
        case .high: Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
}

enum AgentFramework: String, Codable, CaseIterable {
    case langchain, langgraph, crewai, watsonx, autogen, semanticKernel, openaiAgents, custom

    var displayName: String {
        switch self {
        case .langchain: String(localized: "LangChain")
        case .langgraph: String(localized: "LangGraph")
        case .crewai: String(localized: "CrewAI")
        case .watsonx: String(localized: "watsonx Orchestrate")
        case .autogen: String(localized: "AutoGen")
        case .semanticKernel: String(localized: "Semantic Kernel")
        case .openaiAgents: String(localized: "OpenAI Agents")
        case .custom: String(localized: "Custom")
        }
    }
}

enum AgentMemoryType: String, Codable, CaseIterable {
    case none, shortTerm, longTerm, both

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .shortTerm: String(localized: "Short-term")
        case .longTerm: String(localized: "Long-term")
        case .both: String(localized: "Both")
        }
    }
}

enum ToolType: String, Codable, CaseIterable {
    case openai, mcp, python, api, shell, langchain, flow, custom

    var displayName: String {
        switch self {
        case .openai: String(localized: "OpenAI")
        case .mcp: String(localized: "MCP")
        case .python: String(localized: "Python")
        case .api: String(localized: "API")
        case .shell: String(localized: "Shell")
        case .langchain: String(localized: "LangChain")
        case .flow: String(localized: "Flow")
        case .custom: String(localized: "Custom")
        }
    }
}

enum ToolAuthMethod: String, Codable, CaseIterable {
    case none, apiKey, oauth, bearerToken

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .apiKey: String(localized: "API Key")
        case .oauth: String(localized: "OAuth")
        case .bearerToken: String(localized: "Bearer Token")
        }
    }
}

enum ToolErrorHandling: String, Codable, CaseIterable {
    case none, retry, fallback, skip, abort

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .retry: String(localized: "Retry")
        case .fallback: String(localized: "Fallback")
        case .skip: String(localized: "Skip")
        case .abort: String(localized: "Abort")
        }
    }
}

enum LockState: Int, Codable, CaseIterable {
    case unlocked = 0
    case positionLocked = 1
    case detailsLocked = 2
    case fullyLocked = 3

    var displayName: String {
        switch self {
        case .unlocked:       String(localized: "Unlocked")
        case .positionLocked: String(localized: "Position Locked")
        case .detailsLocked:  String(localized: "Details Locked")
        case .fullyLocked:    String(localized: "Fully Locked")
        }
    }

    var sfSymbol: String {
        switch self {
        case .unlocked:       "lock.open"
        case .positionLocked: "lock"
        case .detailsLocked:  "lock.rectangle"
        case .fullyLocked:    "lock.fill"
        }
    }

    /// Cycle to next state
    var next: LockState {
        LockState(rawValue: (rawValue + 1) % 4)!
    }
}

enum HumanChannel: String, Codable, CaseIterable {
    case none, email, chat, phone, portal, api, sms, custom

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .email: String(localized: "Email")
        case .chat: String(localized: "Chat")
        case .phone: String(localized: "Phone")
        case .portal: String(localized: "Portal")
        case .api: String(localized: "API")
        case .sms: String(localized: "SMS")
        case .custom: String(localized: "Custom")
        }
    }
}

// MARK: - Agent Type (structured role)

enum AgentType: String, Codable, CaseIterable {
    case worker, supervisor, router, specialist, orchestrator, custom

    var displayName: String {
        switch self {
        case .worker: String(localized: "Worker")
        case .supervisor: String(localized: "Supervisor")
        case .router: String(localized: "Router")
        case .specialist: String(localized: "Specialist")
        case .orchestrator: String(localized: "Orchestrator")
        case .custom: String(localized: "Custom")
        }
    }
}

// MARK: - Tool Category (purpose)

enum ToolCategory: String, Codable, CaseIterable {
    case general, guardrail, monitoring, caching, testing, feedback
    case workflow, delivery, security, routing, extraction, processing

    var displayName: String {
        switch self {
        case .general: String(localized: "General")
        case .guardrail: String(localized: "Guardrail")
        case .monitoring: String(localized: "Monitoring")
        case .caching: String(localized: "Caching")
        case .testing: String(localized: "Testing")
        case .feedback: String(localized: "Feedback")
        case .workflow: String(localized: "Workflow")
        case .delivery: String(localized: "Delivery")
        case .security: String(localized: "Security")
        case .routing: String(localized: "Routing")
        case .extraction: String(localized: "Extraction")
        case .processing: String(localized: "Processing")
        }
    }
}

// MARK: - Knowledge Retrieval Strategy

enum RetrievalStrategy: String, Codable, CaseIterable {
    case none, rag, sql, api, fullDocument, hybrid

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .rag: String(localized: "RAG (Semantic)")
        case .sql: String(localized: "SQL / Database")
        case .api: String(localized: "API")
        case .fullDocument: String(localized: "Full Document")
        case .hybrid: String(localized: "Hybrid (RAG + Keyword)")
        }
    }
}

// MARK: - Observability Level

enum ObservabilityLevel: String, Codable, CaseIterable {
    case none, basic, structured, full

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .basic: String(localized: "Basic Logging")
        case .structured: String(localized: "Structured Tracing")
        case .full: String(localized: "Full Observability")
        }
    }
}

// MARK: - Agent Prompt Management

enum AgentPromptManagement: String, Codable, CaseIterable {
    case none, hardcoded, templated, versioned, registry

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .hardcoded: String(localized: "Hardcoded")
        case .templated: String(localized: "Templated")
        case .versioned: String(localized: "Versioned")
        case .registry: String(localized: "Registry")
        }
    }
}

// MARK: - Agent Context Strategy

enum AgentContextStrategy: String, Codable, CaseIterable {
    case none, fixed, prioritised, windowed, compressed

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .fixed: String(localized: "Fixed")
        case .prioritised: String(localized: "Prioritised")
        case .windowed: String(localized: "Windowed")
        case .compressed: String(localized: "Compressed")
        }
    }
}

// MARK: - Agent Complexity

enum AgentComplexity: String, Codable, CaseIterable {
    case deterministic, conditional, reasoning, openEnded

    var displayName: String {
        switch self {
        case .deterministic: String(localized: "Deterministic")
        case .conditional: String(localized: "Conditional")
        case .reasoning: String(localized: "Reasoning")
        case .openEnded: String(localized: "Open-ended")
        }
    }
}

enum DeploymentTarget: String, Codable, CaseIterable, Identifiable {
    case cloud, onPrem, hybrid
    var id: Self { self }
    var displayName: String {
        switch self {
        case .cloud:  String(localized: "Cloud")
        case .onPrem: String(localized: "On-Prem")
        case .hybrid: String(localized: "Hybrid")
        }
    }
}

struct GraphNode: Identifiable {
    var id: UUID
    var kind: NodeKind
    var title: String
    var detail: String
    var position: CGPoint
    var size: CGSize
    var ports: [NodePort]
    var colorHex: String?        // Custom color (used for comments)
    var groupID: UUID?           // Nodes with same groupID move together
    var lockState: LockState = .unlocked

    var isPositionLocked: Bool { lockState == .positionLocked || lockState == .fullyLocked }
    var isDetailsLocked: Bool { lockState == .detailsLocked || lockState == .fullyLocked }

    // Knowledge metadata
    var risk: RiskLevel
    var knowledgeDataFormats: String?
    var knowledgeSizeQuantity: String?
    var knowledgeLocation: String?
    var knowledgeAccessMethod: String?
    var knowledgeSensitivity: String?
    var knowledgeUpdateFrequency: String?
    var knowledgeVersioningMethod: String?
    var knowledgeRetrievalStrategy: RetrievalStrategy
    var knowledgeChunkingStrategy: String?   // e.g. "512 tokens", "by paragraph", "semantic"
    var knowledgeContentType: String?        // e.g. "legal", "technical", "FAQ", "policy"

    // Agent metadata
    var agentFramework: AgentFramework
    var agentType: AgentType
    var agentModel: String?
    var agentRole: String?
    var agentGoal: String?
    var agentInstructions: String?
    var agentMemory: AgentMemoryType
    var agentMaxIterations: String?
    var agentCanDelegate: Bool
    var agentObservability: ObservabilityLevel
    var agentPromptManagement: AgentPromptManagement
    var agentContextStrategy: AgentContextStrategy
    var agentComplexity: AgentComplexity
    var agentLatencyBudget: String?     // e.g. "300ms", "3s"
    var agentCostBudget: String?        // e.g. "$0.10/call", "1000 tokens"

    // Tool metadata
    var toolType: ToolType
    var toolCategory: ToolCategory
    var toolAsync: Bool
    var toolInputs: String?
    var toolOutputs: String?
    var toolAuthMethod: ToolAuthMethod
    var toolEndpoint: String?
    var toolTimeout: String?
    var toolErrorHandling: ToolErrorHandling
    var toolIdempotent: Bool
    var toolDataVolume: String?         // e.g. "small", "large", "paginated"

    // Human metadata
    var humanInputChannel: HumanChannel
    var humanChannel: HumanChannel  // Output channel
    var humanRole: String?
    var humanLanguage: String?
    var humanTimezone: String?
    var humanAuthMethod: String?
    var humanAccessLevel: String?
    var humanSLA: String?
    var humanBehaviors: String?

    // Shape properties
    var strokeColorHex: String?  // Line color (nil = default gray)
    var fillColorHex: String?    // Fill color
    var fillEnabled: Bool        // Whether fill is active
    var fontSize: CGFloat?       // Text shape font size
    var fontColorHex: String?    // Text shape font color

    // User-authored comments (separate from `detail`; surfaced in reports)
    var comments: String? = nil

    // Expected per-run duration override for the latency model (e.g. "1.5s", "800ms")
    var expectedDuration: String? = nil

    // Stable identity of the source artifact this node was imported from
    // (e.g. "agent:agents/researcher.yaml:researcher") — used to match nodes
    // when re-importing / merging.
    var importSourceKey: String? = nil

    /// Minimum width for standard (non-shape) nodes
    static let minNodeWidth: CGFloat = 160

    /// Compute ideal width for a standard node based on its title, risk badge, and lock icon.
    /// Layout: .padding(.horizontal, 10) → Icon (≤17px) + 6 spacing + Text + Spacer(0) + badges
    static func idealWidth(for title: String, fontSize: CGFloat = 13,
                           risk: RiskLevel = .none, lockState: LockState = .unlocked,
                           isComment: Bool = false) -> CGFloat {
        if isComment {
            // Comment layout: .padding(10) → Title text only, no icon/risk/lock
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ]
            let textWidth = (title as NSString).size(withAttributes: attrs).width
            return max(ceil(textWidth + 28), minNodeWidth) // 20 padding + 8 breathing room
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        ]
        let textWidth = (title as NSString).size(withAttributes: attrs).width
        // 20 padding + 17 icon + 6 spacing + 6 spacing (before spacer) + 6 breathing room = 55
        var chrome: CGFloat = 55
        if risk != .none { chrome += 18 }        // risk letter + spacing
        if lockState != .unlocked { chrome += 18 } // lock icon + spacing
        return max(ceil(textWidth + chrome), minNodeWidth)
    }

    init(id: UUID = UUID(), kind: NodeKind, title: String = "", detail: String = "",
         position: CGPoint, size: CGSize = CGSize(width: 180, height: 80), ports: [NodePort] = [],
         colorHex: String? = nil,
         risk: RiskLevel = .none,
         knowledgeDataFormats: String? = nil, knowledgeSizeQuantity: String? = nil,
         knowledgeLocation: String? = nil, knowledgeAccessMethod: String? = nil,
         knowledgeSensitivity: String? = nil, knowledgeUpdateFrequency: String? = nil,
         knowledgeVersioningMethod: String? = nil,
         knowledgeRetrievalStrategy: RetrievalStrategy = .none,
         knowledgeChunkingStrategy: String? = nil, knowledgeContentType: String? = nil,
         agentFramework: AgentFramework = .custom, agentType: AgentType = .worker,
         agentModel: String? = nil,
         agentRole: String? = nil, agentGoal: String? = nil,
         agentInstructions: String? = nil, agentMemory: AgentMemoryType = .none,
         agentMaxIterations: String? = nil, agentCanDelegate: Bool = false,
         agentObservability: ObservabilityLevel = .none,
         agentPromptManagement: AgentPromptManagement = .none,
         agentContextStrategy: AgentContextStrategy = .none,
         agentComplexity: AgentComplexity = .reasoning,
         agentLatencyBudget: String? = nil, agentCostBudget: String? = nil,
         toolType: ToolType = .custom, toolCategory: ToolCategory = .general,
         toolAsync: Bool = false,
         toolInputs: String? = nil, toolOutputs: String? = nil,
         toolAuthMethod: ToolAuthMethod = .none, toolEndpoint: String? = nil,
         toolTimeout: String? = nil, toolErrorHandling: ToolErrorHandling = .none,
         toolIdempotent: Bool = false, toolDataVolume: String? = nil,
         humanInputChannel: HumanChannel = .none, humanChannel: HumanChannel = .email,
         humanRole: String? = nil,
         humanLanguage: String? = nil, humanTimezone: String? = nil,
         humanAuthMethod: String? = nil, humanAccessLevel: String? = nil,
         humanSLA: String? = nil, humanBehaviors: String? = nil,
         strokeColorHex: String? = nil, fillColorHex: String? = nil,
         fillEnabled: Bool = false, fontSize: CGFloat? = nil, fontColorHex: String? = nil,
         groupID: UUID? = nil, lockState: LockState = .unlocked) {
        self.id = id
        self.kind = kind
        self.title = title.isEmpty ? kind.displayName : title
        self.detail = detail
        self.position = position
        self.size = size
        self.ports = ports
        self.colorHex = colorHex
        self.risk = risk
        self.knowledgeDataFormats = knowledgeDataFormats
        self.knowledgeSizeQuantity = knowledgeSizeQuantity
        self.knowledgeLocation = knowledgeLocation
        self.knowledgeAccessMethod = knowledgeAccessMethod
        self.knowledgeSensitivity = knowledgeSensitivity
        self.knowledgeUpdateFrequency = knowledgeUpdateFrequency
        self.knowledgeVersioningMethod = knowledgeVersioningMethod
        self.knowledgeRetrievalStrategy = knowledgeRetrievalStrategy
        self.knowledgeChunkingStrategy = knowledgeChunkingStrategy
        self.knowledgeContentType = knowledgeContentType
        self.agentFramework = agentFramework
        self.agentType = agentType
        self.agentModel = agentModel
        self.agentRole = agentRole
        self.agentGoal = agentGoal
        self.agentInstructions = agentInstructions
        self.agentMemory = agentMemory
        self.agentMaxIterations = agentMaxIterations
        self.agentCanDelegate = agentCanDelegate
        self.agentObservability = agentObservability
        self.agentPromptManagement = agentPromptManagement
        self.agentContextStrategy = agentContextStrategy
        self.agentComplexity = agentComplexity
        self.agentLatencyBudget = agentLatencyBudget
        self.agentCostBudget = agentCostBudget
        self.toolType = toolType
        self.toolCategory = toolCategory
        self.toolAsync = toolAsync
        self.toolInputs = toolInputs
        self.toolOutputs = toolOutputs
        self.toolAuthMethod = toolAuthMethod
        self.toolEndpoint = toolEndpoint
        self.toolTimeout = toolTimeout
        self.toolErrorHandling = toolErrorHandling
        self.toolIdempotent = toolIdempotent
        self.toolDataVolume = toolDataVolume
        self.humanInputChannel = humanInputChannel
        self.humanChannel = humanChannel
        self.humanRole = humanRole
        self.humanLanguage = humanLanguage
        self.humanTimezone = humanTimezone
        self.humanAuthMethod = humanAuthMethod
        self.humanAccessLevel = humanAccessLevel
        self.humanSLA = humanSLA
        self.humanBehaviors = humanBehaviors
        self.strokeColorHex = strokeColorHex
        self.fillColorHex = fillColorHex
        self.fillEnabled = fillEnabled
        self.fontSize = fontSize
        self.fontColorHex = fontColorHex
        self.groupID = groupID
        self.lockState = lockState
    }

    static func make(kind: NodeKind, at position: CGPoint) -> GraphNode {
        switch kind {
        case .agent:
            let ports = [NodePort(label: "Connect", kind: .output)]
            let w = idealWidth(for: kind.displayName)
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: w, height: 80), ports: ports)
        case .tool:
            let ports = [NodePort(label: "Connect", kind: .input)]
            let w = idealWidth(for: kind.displayName)
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: w, height: 80), ports: ports)
        case .knowledge:
            let ports = [NodePort(label: "Connect", kind: .input)]
            let w = idealWidth(for: kind.displayName)
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: w, height: 80), ports: ports)
        case .human:
            let ports = [
                NodePort(label: "Out", kind: .output)
            ]
            let w = idealWidth(for: kind.displayName)
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: w, height: 80), ports: ports)
        case .comment:
            let w = idealWidth(for: kind.displayName)
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: w, height: 80), ports: [])
        case .shapeRectangle, .shapeRoundedRect, .shapeOval:
            return GraphNode(kind: kind, position: position,
                             size: CGSize(width: 200, height: 120), ports: [])
        case .shapeText:
            return GraphNode(kind: kind, title: "Text", position: position,
                             size: CGSize(width: 160, height: 40), ports: [],
                             fontSize: 14, fontColorHex: "808080")
        }
    }
}

// MARK: - Codable

extension GraphNode: Codable {
    enum CodingKeys: String, CodingKey {
        case id, kind, title, detail, positionX, positionY, width, height, ports, colorHex
        case risk = "knowledgeRisk"
        case knowledgeDataFormats, knowledgeSizeQuantity, knowledgeLocation
        case knowledgeAccessMethod, knowledgeSensitivity
        case knowledgeUpdateFrequency, knowledgeVersioningMethod
        case knowledgeRetrievalStrategy, knowledgeChunkingStrategy, knowledgeContentType
        case agentFramework, agentType, agentModel, agentRole, agentGoal
        case agentInstructions, agentMemory, agentMaxIterations, agentCanDelegate
        case agentObservability, agentPromptManagement, agentContextStrategy, agentComplexity
        case agentLatencyBudget, agentCostBudget
        case toolType, toolCategory, toolAsync, toolInputs, toolOutputs
        case toolAuthMethod, toolEndpoint, toolTimeout, toolErrorHandling
        case toolIdempotent, toolDataVolume
        case humanInputChannel, humanChannel, humanRole, humanLanguage, humanTimezone
        case humanAuthMethod, humanAccessLevel, humanSLA, humanBehaviors
        case strokeColorHex, fillColorHex, fillEnabled, fontSize, fontColorHex
        case groupID, lockState
        case comments
        case expectedDuration
        case importSourceKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(NodeKind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decode(String.self, forKey: .detail)
        let px = try c.decode(CGFloat.self, forKey: .positionX)
        let py = try c.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: px, y: py)
        let w = try c.decode(CGFloat.self, forKey: .width)
        let h = try c.decode(CGFloat.self, forKey: .height)
        size = CGSize(width: w, height: h)
        ports = try c.decode([NodePort].self, forKey: .ports)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        risk = try c.decodeIfPresent(RiskLevel.self, forKey: .risk) ?? .none
        knowledgeDataFormats = try c.decodeIfPresent(String.self, forKey: .knowledgeDataFormats)
        knowledgeSizeQuantity = try c.decodeIfPresent(String.self, forKey: .knowledgeSizeQuantity)
        knowledgeLocation = try c.decodeIfPresent(String.self, forKey: .knowledgeLocation)
        knowledgeAccessMethod = try c.decodeIfPresent(String.self, forKey: .knowledgeAccessMethod)
        knowledgeSensitivity = try c.decodeIfPresent(String.self, forKey: .knowledgeSensitivity)
        knowledgeUpdateFrequency = try c.decodeIfPresent(String.self, forKey: .knowledgeUpdateFrequency)
        knowledgeVersioningMethod = try c.decodeIfPresent(String.self, forKey: .knowledgeVersioningMethod)
        knowledgeRetrievalStrategy = try c.decodeIfPresent(RetrievalStrategy.self, forKey: .knowledgeRetrievalStrategy) ?? .none
        knowledgeChunkingStrategy = try c.decodeIfPresent(String.self, forKey: .knowledgeChunkingStrategy)
        knowledgeContentType = try c.decodeIfPresent(String.self, forKey: .knowledgeContentType)
        agentFramework = try c.decodeIfPresent(AgentFramework.self, forKey: .agentFramework) ?? .custom
        agentType = try c.decodeIfPresent(AgentType.self, forKey: .agentType) ?? .worker
        agentModel = try c.decodeIfPresent(String.self, forKey: .agentModel)
        agentRole = try c.decodeIfPresent(String.self, forKey: .agentRole)
        agentGoal = try c.decodeIfPresent(String.self, forKey: .agentGoal)
        agentInstructions = try c.decodeIfPresent(String.self, forKey: .agentInstructions)
        agentMemory = try c.decodeIfPresent(AgentMemoryType.self, forKey: .agentMemory) ?? .none
        agentMaxIterations = try c.decodeIfPresent(String.self, forKey: .agentMaxIterations)
        agentCanDelegate = try c.decodeIfPresent(Bool.self, forKey: .agentCanDelegate) ?? false
        agentObservability = try c.decodeIfPresent(ObservabilityLevel.self, forKey: .agentObservability) ?? .none
        agentPromptManagement = try c.decodeIfPresent(AgentPromptManagement.self, forKey: .agentPromptManagement) ?? .none
        agentContextStrategy = try c.decodeIfPresent(AgentContextStrategy.self, forKey: .agentContextStrategy) ?? .none
        agentComplexity = try c.decodeIfPresent(AgentComplexity.self, forKey: .agentComplexity) ?? .reasoning
        agentLatencyBudget = try c.decodeIfPresent(String.self, forKey: .agentLatencyBudget)
        agentCostBudget = try c.decodeIfPresent(String.self, forKey: .agentCostBudget)
        toolType = try c.decodeIfPresent(ToolType.self, forKey: .toolType) ?? .custom
        toolCategory = try c.decodeIfPresent(ToolCategory.self, forKey: .toolCategory) ?? .general
        toolAsync = try c.decodeIfPresent(Bool.self, forKey: .toolAsync) ?? false
        toolInputs = try c.decodeIfPresent(String.self, forKey: .toolInputs)
        toolOutputs = try c.decodeIfPresent(String.self, forKey: .toolOutputs)
        toolAuthMethod = try c.decodeIfPresent(ToolAuthMethod.self, forKey: .toolAuthMethod) ?? .none
        toolEndpoint = try c.decodeIfPresent(String.self, forKey: .toolEndpoint)
        toolTimeout = try c.decodeIfPresent(String.self, forKey: .toolTimeout)
        toolErrorHandling = try c.decodeIfPresent(ToolErrorHandling.self, forKey: .toolErrorHandling) ?? .none
        toolIdempotent = try c.decodeIfPresent(Bool.self, forKey: .toolIdempotent) ?? false
        toolDataVolume = try c.decodeIfPresent(String.self, forKey: .toolDataVolume)
        humanInputChannel = try c.decodeIfPresent(HumanChannel.self, forKey: .humanInputChannel) ?? .none
        humanChannel = try c.decodeIfPresent(HumanChannel.self, forKey: .humanChannel) ?? .email
        humanRole = try c.decodeIfPresent(String.self, forKey: .humanRole)
        humanLanguage = try c.decodeIfPresent(String.self, forKey: .humanLanguage)
        humanTimezone = try c.decodeIfPresent(String.self, forKey: .humanTimezone)
        humanAuthMethod = try c.decodeIfPresent(String.self, forKey: .humanAuthMethod)
        humanAccessLevel = try c.decodeIfPresent(String.self, forKey: .humanAccessLevel)
        humanSLA = try c.decodeIfPresent(String.self, forKey: .humanSLA)
        humanBehaviors = try c.decodeIfPresent(String.self, forKey: .humanBehaviors)
        strokeColorHex = try c.decodeIfPresent(String.self, forKey: .strokeColorHex)
        fillColorHex = try c.decodeIfPresent(String.self, forKey: .fillColorHex)
        fillEnabled = try c.decodeIfPresent(Bool.self, forKey: .fillEnabled) ?? false
        fontSize = try c.decodeIfPresent(CGFloat.self, forKey: .fontSize)
        fontColorHex = try c.decodeIfPresent(String.self, forKey: .fontColorHex)
        groupID = try c.decodeIfPresent(UUID.self, forKey: .groupID)
        lockState = try c.decodeIfPresent(LockState.self, forKey: .lockState) ?? .unlocked
        comments = try c.decodeIfPresent(String.self, forKey: .comments)
        expectedDuration = try c.decodeIfPresent(String.self, forKey: .expectedDuration)
        importSourceKey = try c.decodeIfPresent(String.self, forKey: .importSourceKey)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(title, forKey: .title)
        try c.encode(detail, forKey: .detail)
        try c.encode(position.x, forKey: .positionX)
        try c.encode(position.y, forKey: .positionY)
        try c.encode(size.width, forKey: .width)
        try c.encode(size.height, forKey: .height)
        try c.encode(ports, forKey: .ports)
        try c.encodeIfPresent(colorHex, forKey: .colorHex)
        if risk != .none { try c.encode(risk, forKey: .risk) }
        try c.encodeIfPresent(knowledgeDataFormats, forKey: .knowledgeDataFormats)
        try c.encodeIfPresent(knowledgeSizeQuantity, forKey: .knowledgeSizeQuantity)
        try c.encodeIfPresent(knowledgeLocation, forKey: .knowledgeLocation)
        try c.encodeIfPresent(knowledgeAccessMethod, forKey: .knowledgeAccessMethod)
        try c.encodeIfPresent(knowledgeSensitivity, forKey: .knowledgeSensitivity)
        try c.encodeIfPresent(knowledgeUpdateFrequency, forKey: .knowledgeUpdateFrequency)
        try c.encodeIfPresent(knowledgeVersioningMethod, forKey: .knowledgeVersioningMethod)
        if knowledgeRetrievalStrategy != .none { try c.encode(knowledgeRetrievalStrategy, forKey: .knowledgeRetrievalStrategy) }
        try c.encodeIfPresent(knowledgeChunkingStrategy, forKey: .knowledgeChunkingStrategy)
        try c.encodeIfPresent(knowledgeContentType, forKey: .knowledgeContentType)
        if agentFramework != .custom { try c.encode(agentFramework, forKey: .agentFramework) }
        if agentType != .worker { try c.encode(agentType, forKey: .agentType) }
        try c.encodeIfPresent(agentModel, forKey: .agentModel)
        try c.encodeIfPresent(agentRole, forKey: .agentRole)
        try c.encodeIfPresent(agentGoal, forKey: .agentGoal)
        try c.encodeIfPresent(agentInstructions, forKey: .agentInstructions)
        if agentMemory != .none { try c.encode(agentMemory, forKey: .agentMemory) }
        try c.encodeIfPresent(agentMaxIterations, forKey: .agentMaxIterations)
        if agentCanDelegate { try c.encode(agentCanDelegate, forKey: .agentCanDelegate) }
        if agentObservability != .none { try c.encode(agentObservability, forKey: .agentObservability) }
        if agentPromptManagement != .none { try c.encode(agentPromptManagement, forKey: .agentPromptManagement) }
        if agentContextStrategy != .none { try c.encode(agentContextStrategy, forKey: .agentContextStrategy) }
        if agentComplexity != .reasoning { try c.encode(agentComplexity, forKey: .agentComplexity) }
        try c.encodeIfPresent(agentLatencyBudget, forKey: .agentLatencyBudget)
        try c.encodeIfPresent(agentCostBudget, forKey: .agentCostBudget)
        if toolType != .custom { try c.encode(toolType, forKey: .toolType) }
        if toolCategory != .general { try c.encode(toolCategory, forKey: .toolCategory) }
        if toolAsync { try c.encode(toolAsync, forKey: .toolAsync) }
        try c.encodeIfPresent(toolInputs, forKey: .toolInputs)
        try c.encodeIfPresent(toolOutputs, forKey: .toolOutputs)
        if toolAuthMethod != .none { try c.encode(toolAuthMethod, forKey: .toolAuthMethod) }
        try c.encodeIfPresent(toolEndpoint, forKey: .toolEndpoint)
        try c.encodeIfPresent(toolTimeout, forKey: .toolTimeout)
        if toolErrorHandling != .none { try c.encode(toolErrorHandling, forKey: .toolErrorHandling) }
        if toolIdempotent { try c.encode(toolIdempotent, forKey: .toolIdempotent) }
        try c.encodeIfPresent(toolDataVolume, forKey: .toolDataVolume)
        if humanInputChannel != .none { try c.encode(humanInputChannel, forKey: .humanInputChannel) }
        if humanChannel != .email { try c.encode(humanChannel, forKey: .humanChannel) }
        try c.encodeIfPresent(humanRole, forKey: .humanRole)
        try c.encodeIfPresent(humanLanguage, forKey: .humanLanguage)
        try c.encodeIfPresent(humanTimezone, forKey: .humanTimezone)
        try c.encodeIfPresent(humanAuthMethod, forKey: .humanAuthMethod)
        try c.encodeIfPresent(humanAccessLevel, forKey: .humanAccessLevel)
        try c.encodeIfPresent(humanSLA, forKey: .humanSLA)
        try c.encodeIfPresent(humanBehaviors, forKey: .humanBehaviors)
        try c.encodeIfPresent(strokeColorHex, forKey: .strokeColorHex)
        try c.encodeIfPresent(fillColorHex, forKey: .fillColorHex)
        try c.encode(fillEnabled, forKey: .fillEnabled)
        try c.encodeIfPresent(fontSize, forKey: .fontSize)
        try c.encodeIfPresent(fontColorHex, forKey: .fontColorHex)
        try c.encodeIfPresent(groupID, forKey: .groupID)
        if lockState != .unlocked { try c.encode(lockState, forKey: .lockState) }
        try c.encodeIfPresent(comments, forKey: .comments)
        try c.encodeIfPresent(expectedDuration, forKey: .expectedDuration)
        try c.encodeIfPresent(importSourceKey, forKey: .importSourceKey)
    }
}

// MARK: - Color ↔ Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "FFCC00" }
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
