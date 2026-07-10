import Foundation

/// A single issue identified by the prompt analysis LLM.
struct PromptAnalysisIssue: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var recommendation: String
    var severity: String?  // optional: "warning" | "recommendation" | "info"

    init(id: UUID = UUID(), title: String, detail: String, recommendation: String, severity: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.recommendation = recommendation
        self.severity = severity
    }
}

/// Result of a single prompt analysis run.
struct PromptAnalysisResult: Codable, Hashable {
    var issues: [PromptAnalysisIssue]
    var timestamp: Date
    var promptAnalyzed: String
}
