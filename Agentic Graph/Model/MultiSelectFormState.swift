import Foundation

/// Holds temporary form values for the multi-select inspector.
/// Each field starts disabled. The user toggles a field on to activate it,
/// then edits its value. Only enabled fields with content are applied.
@Observable
class MultiSelectFormState {
    /// Which fields the user has activated (by key name)
    var enabledFields: Set<String> = []

    // MARK: - Universal Fields

    var title: String = ""
    var detail: String = ""
    var lockState: LockState = .unlocked
    var colorHex: String = "808080"

    // MARK: - Risk

    var risk: RiskLevel = .none

    // MARK: - Agent Fields

    var agentFramework: AgentFramework = .custom
    var agentModel: String = ""
    var agentRole: String = ""
    var agentGoal: String = ""
    var agentInstructions: String = ""
    var agentMemory: AgentMemoryType = .none
    var agentMaxIterations: String = ""
    var agentCanDelegate: Bool = false

    // MARK: - Tool Fields

    var toolType: ToolType = .custom
    var toolAsync: Bool = false
    var toolInputs: String = ""
    var toolOutputs: String = ""
    var toolAuthMethod: ToolAuthMethod = .none
    var toolEndpoint: String = ""
    var toolTimeout: String = ""
    var toolErrorHandling: ToolErrorHandling = .none

    // MARK: - Knowledge Fields

    var knowledgeDataFormats: String = ""
    var knowledgeSizeQuantity: String = ""
    var knowledgeLocation: String = ""
    var knowledgeAccessMethod: String = ""
    var knowledgeSensitivity: String = ""
    var knowledgeUpdateFrequency: String = ""
    var knowledgeVersioningMethod: String = ""

    // MARK: - Shape Fields

    var strokeColorHex: String = "808080"
    var fillColorHex: String = "4A90D9"
    var fillEnabled: Bool = false

    // MARK: - Text Shape Fields

    var fontSize: String = ""
    var fontColorHex: String = "808080"

    // MARK: - Edge Fields

    var edgeColorHex: String = "808080"
    var edgeLineStyle: EdgeLineStyle = .solid

    // MARK: - Helpers

    /// Whether any field has been activated by the user
    var hasChanges: Bool {
        !enabledFields.isEmpty
    }

    /// Check if a string field has meaningful content after trimming
    func hasContent(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Reset all fields to defaults and clear all enabled flags
    func reset() {
        enabledFields = []
        title = ""
        detail = ""
        lockState = .unlocked
        colorHex = "808080"
        risk = .none
        agentFramework = .custom
        agentModel = ""
        agentRole = ""
        agentGoal = ""
        agentInstructions = ""
        agentMemory = .none
        agentMaxIterations = ""
        agentCanDelegate = false
        toolType = .custom
        toolAsync = false
        toolInputs = ""
        toolOutputs = ""
        toolAuthMethod = .none
        toolEndpoint = ""
        toolTimeout = ""
        toolErrorHandling = .none
        knowledgeDataFormats = ""
        knowledgeSizeQuantity = ""
        knowledgeLocation = ""
        knowledgeAccessMethod = ""
        knowledgeSensitivity = ""
        knowledgeUpdateFrequency = ""
        knowledgeVersioningMethod = ""
        strokeColorHex = "808080"
        fillColorHex = "4A90D9"
        fillEnabled = false
        fontSize = ""
        fontColorHex = "808080"
        edgeColorHex = "808080"
        edgeLineStyle = .solid
    }
}
