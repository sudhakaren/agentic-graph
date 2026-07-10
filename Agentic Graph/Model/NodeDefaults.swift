import Foundation
import SwiftUI

struct NodeDefaults: Codable {
    // Agent fields
    var agentType: AgentType?
    var agentFramework: AgentFramework?
    var agentModel: String?
    var agentRole: String?
    var agentGoal: String?
    var agentInstructions: String?
    var agentMemory: AgentMemoryType?
    var agentMaxIterations: String?
    var agentCanDelegate: Bool?
    var agentObservability: ObservabilityLevel?
    var agentPromptManagement: AgentPromptManagement?
    var agentContextStrategy: AgentContextStrategy?
    var agentComplexity: AgentComplexity?

    // Tool fields
    var toolCategory: ToolCategory?
    var toolType: ToolType?
    var toolAsync: Bool?
    var toolInputs: String?
    var toolOutputs: String?
    var toolAuthMethod: ToolAuthMethod?
    var toolEndpoint: String?
    var toolTimeout: String?
    var toolErrorHandling: ToolErrorHandling?

    // Knowledge fields
    var risk: RiskLevel?
    var knowledgeDataFormats: String?
    var knowledgeSizeQuantity: String?
    var knowledgeLocation: String?
    var knowledgeAccessMethod: String?
    var knowledgeSensitivity: String?
    var knowledgeUpdateFrequency: String?
    var knowledgeVersioningMethod: String?
    var knowledgeRetrievalStrategy: RetrievalStrategy?

    // Human fields
    var humanInputChannel: HumanChannel?
    var humanChannel: HumanChannel?
    var humanRole: String?
    var humanLanguage: String?
    var humanTimezone: String?
    var humanAuthMethod: String?
    var humanAccessLevel: String?
    var humanSLA: String?
    var humanBehaviors: String?

    // Comment fields
    var colorHex: String?

    // Shape fields (Rectangle, Rounded Rect, Oval, Text)
    var strokeColorHex: String?
    var fillColorHex: String?
    var fillEnabled: Bool?
    var fontSize: CGFloat?
    var fontColorHex: String?

    var hasOverrides: Bool {
        agentType != nil || agentFramework != nil || agentModel != nil || agentRole != nil ||
        agentGoal != nil || agentInstructions != nil || agentMemory != nil ||
        agentMaxIterations != nil || agentCanDelegate != nil ||
        agentObservability != nil || agentPromptManagement != nil ||
        agentContextStrategy != nil || agentComplexity != nil ||
        toolCategory != nil || toolType != nil || toolAsync != nil || toolInputs != nil ||
        toolOutputs != nil || toolAuthMethod != nil || toolEndpoint != nil ||
        toolTimeout != nil || toolErrorHandling != nil ||
        risk != nil || knowledgeDataFormats != nil || knowledgeSizeQuantity != nil ||
        knowledgeLocation != nil || knowledgeAccessMethod != nil ||
        knowledgeSensitivity != nil || knowledgeUpdateFrequency != nil ||
        knowledgeVersioningMethod != nil || knowledgeRetrievalStrategy != nil ||
        humanInputChannel != nil || humanChannel != nil || humanRole != nil || humanLanguage != nil ||
        humanTimezone != nil || humanAuthMethod != nil || humanAccessLevel != nil ||
        humanSLA != nil || humanBehaviors != nil ||
        colorHex != nil ||
        strokeColorHex != nil || fillColorHex != nil || fillEnabled != nil ||
        fontSize != nil || fontColorHex != nil
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "NodeDefaultsByKind"
    private static let legacyKey = "ShapeDefaultsByKind"

    static func saveAll(_ defaults: [String: NodeDefaults]) {
        if let data = try? JSONEncoder().encode(defaults) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func loadAll() -> [String: NodeDefaults] {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let defaults = try? JSONDecoder().decode([String: NodeDefaults].self, from: data) {
            return defaults
        }
        // Migrate from legacy ShapeDefaults
        if let legacyData = UserDefaults.standard.data(forKey: legacyKey),
           let legacy = try? JSONDecoder().decode([String: LegacyShapeDefaults].self, from: legacyData) {
            var migrated: [String: NodeDefaults] = [:]
            for (key, old) in legacy {
                migrated[key] = NodeDefaults(
                    strokeColorHex: old.strokeColorHex,
                    fillColorHex: old.fillColorHex,
                    fillEnabled: old.fillEnabled,
                    fontSize: old.fontSize,
                    fontColorHex: old.fontColorHex
                )
            }
            saveAll(migrated)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return migrated
        }
        return [:]
    }

    // MARK: - Apply to Node

    func apply(to node: inout GraphNode) {
        switch node.kind {
        case .agent:
            if let v = agentType         { node.agentType = v }
            if let v = agentFramework    { node.agentFramework = v }
            if let v = agentModel        { node.agentModel = v }
            if let v = agentRole         { node.agentRole = v }
            if let v = agentGoal         { node.agentGoal = v }
            if let v = agentInstructions { node.agentInstructions = v }
            if let v = agentMemory       { node.agentMemory = v }
            if let v = agentMaxIterations { node.agentMaxIterations = v }
            if let v = agentCanDelegate  { node.agentCanDelegate = v }
            if let v = agentObservability { node.agentObservability = v }
            if let v = agentPromptManagement { node.agentPromptManagement = v }
            if let v = agentContextStrategy { node.agentContextStrategy = v }
            if let v = agentComplexity   { node.agentComplexity = v }
            if let v = colorHex          { node.colorHex = v }
            if let v = fontSize          { node.fontSize = v }
            if let v = fontColorHex      { node.fontColorHex = v }

        case .tool:
            if let v = toolCategory      { node.toolCategory = v }
            if let v = toolType          { node.toolType = v }
            if let v = toolAsync         { node.toolAsync = v }
            if let v = toolInputs        { node.toolInputs = v }
            if let v = toolOutputs       { node.toolOutputs = v }
            if let v = toolAuthMethod    { node.toolAuthMethod = v }
            if let v = toolEndpoint      { node.toolEndpoint = v }
            if let v = toolTimeout       { node.toolTimeout = v }
            if let v = toolErrorHandling { node.toolErrorHandling = v }
            if let v = colorHex          { node.colorHex = v }
            if let v = fontSize          { node.fontSize = v }
            if let v = fontColorHex      { node.fontColorHex = v }

        case .knowledge:
            if let v = risk                      { node.risk = v }
            if let v = knowledgeDataFormats      { node.knowledgeDataFormats = v }
            if let v = knowledgeSizeQuantity     { node.knowledgeSizeQuantity = v }
            if let v = knowledgeLocation         { node.knowledgeLocation = v }
            if let v = knowledgeAccessMethod     { node.knowledgeAccessMethod = v }
            if let v = knowledgeSensitivity      { node.knowledgeSensitivity = v }
            if let v = knowledgeUpdateFrequency  { node.knowledgeUpdateFrequency = v }
            if let v = knowledgeVersioningMethod { node.knowledgeVersioningMethod = v }
            if let v = knowledgeRetrievalStrategy { node.knowledgeRetrievalStrategy = v }
            if let v = colorHex                  { node.colorHex = v }
            if let v = fontSize                  { node.fontSize = v }
            if let v = fontColorHex              { node.fontColorHex = v }

        case .human:
            if let v = humanInputChannel { node.humanInputChannel = v }
            if let v = humanChannel   { node.humanChannel = v }
            if let v = humanRole      { node.humanRole = v }
            if let v = humanLanguage  { node.humanLanguage = v }
            if let v = humanTimezone  { node.humanTimezone = v }
            if let v = humanAuthMethod { node.humanAuthMethod = v }
            if let v = humanAccessLevel { node.humanAccessLevel = v }
            if let v = humanSLA       { node.humanSLA = v }
            if let v = humanBehaviors { node.humanBehaviors = v }
            if let v = colorHex       { node.colorHex = v }
            if let v = fontSize       { node.fontSize = v }
            if let v = fontColorHex   { node.fontColorHex = v }

        case .comment:
            if let v = colorHex { node.colorHex = v }

        case .shapeRectangle, .shapeRoundedRect, .shapeOval:
            if let v = strokeColorHex { node.strokeColorHex = v }
            if let v = fillColorHex   { node.fillColorHex = v }
            if let v = fillEnabled    { node.fillEnabled = v }

        case .shapeText:
            if let v = strokeColorHex { node.strokeColorHex = v }
            if let v = fillColorHex   { node.fillColorHex = v }
            if let v = fillEnabled    { node.fillEnabled = v }
            if let v = fontSize       { node.fontSize = v }
            if let v = fontColorHex   { node.fontColorHex = v }
        }
    }
}

// For migration only — matches the old ShapeDefaults structure
private struct LegacyShapeDefaults: Codable {
    var strokeColorHex: String?
    var fillColorHex: String?
    var fillEnabled: Bool?
    var fontSize: CGFloat?
    var fontColorHex: String?
}
