import SwiftUI
import FoundationModels

// MARK: - Finding Severity

enum FindingSeverity: String, CaseIterable, Codable {
    case warning
    case recommendation
    case positive
    case info

    var displayName: String {
        switch self {
        case .warning: "Warning"
        case .recommendation: "Recommendation"
        case .positive: "Positive"
        case .info: "Info"
        }
    }

    var sfSymbol: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .recommendation: "lightbulb.fill"
        case .positive: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .warning: .red
        case .recommendation: .orange
        case .positive: .green
        case .info: .blue
        }
    }

    var sortOrder: Int {
        switch self {
        case .warning: 0
        case .recommendation: 1
        case .info: 2
        case .positive: 3
        }
    }

    var tooltip: String {
        switch self {
        case .warning: "Anti-pattern detected — should be addressed"
        case .recommendation: "Improvement opportunity identified"
        case .positive: "Good practice — this pattern is followed well"
        case .info: "Informational observation"
        }
    }
}

// MARK: - Analysis Finding

struct AnalysisFinding: Identifiable, Codable {
    var id: UUID = UUID()
    let patternNumber: Int
    let patternName: String
    let severity: FindingSeverity
    let summary: String
    let detail: String
    let relatedNodeIDs: [UUID]
    let category: String
    let diagnostics: FindingDiagnostics?
}

struct FindingDiagnostics: Codable {
    let prompt: String
    let rawResponse: String
    let resolvedNodeNames: [String]
    let duration: TimeInterval

    /// Prompt with the graph summary replaced by a placeholder for readability.
    var promptForDisplay: String {
        guard let archRange = prompt.range(of: "ARCHITECTURE:\n") else { return prompt }
        return String(prompt[prompt.startIndex..<archRange.upperBound]) + "[GENERATED REPORT]"
    }
}

// MARK: - Analysis Result

struct AnalysisResult: Codable {
    let findings: [AnalysisFinding]
    let timestamp: Date

    var warnings: [AnalysisFinding] {
        findings.filter { $0.severity == .warning }
    }

    var recommendations: [AnalysisFinding] {
        findings.filter { $0.severity == .recommendation }
    }

    var positives: [AnalysisFinding] {
        findings.filter { $0.severity == .positive }
    }

    var infos: [AnalysisFinding] {
        findings.filter { $0.severity == .info }
    }

    var groupedByCategory: [(category: String, findings: [AnalysisFinding])] {
        let grouped = Dictionary(grouping: findings) { $0.category }
        let order = [
            "Foundational",
            "Scale & Reliability",
            "Knowledge & Document Processing",
            "Design-Time",
            "Operational"
        ]
        return order.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, findings: items.sorted { $0.severity.sortOrder < $1.severity.sortOrder })
        }
    }
}

// MARK: - @Generable Structs for Foundation Models

@Generable
struct PatternVerdict {
    @Guide(description: "true if anti-pattern signals are found, false otherwise")
    var hasAntiPattern: Bool

    @Guide(description: "One of: warning, recommendation — severity of the anti-pattern finding, or empty if none")
    var antiPatternSeverity: String

    @Guide(description: "Summary of the anti-pattern finding, or empty if none")
    var antiPatternSummary: String

    @Guide(description: "Detailed explanation of anti-pattern with evidence, or empty if none")
    var antiPatternDetail: String

    @Guide(description: "Comma-separated node names related to the anti-pattern, or empty")
    var antiPatternNodes: String

    @Guide(description: "true if positive pattern signals are found, false otherwise")
    var hasPositive: Bool

    @Guide(description: "Summary of what is done well, or empty if none")
    var positiveSummary: String

    @Guide(description: "Detailed explanation of positive pattern with evidence, or empty if none")
    var positiveDetail: String

    @Guide(description: "Comma-separated node names related to the positive pattern, or empty")
    var positiveNodes: String
}

// MARK: - Pattern Catalog (canonical reference)

struct PatternCatalogEntry {
    let name: String
    let category: String
}

let patternCatalog: [Int: PatternCatalogEntry] = [
    1: PatternCatalogEntry(name: "Monolithic Mega-Prompt", category: "Foundational"),
    2: PatternCatalogEntry(name: "Agent-as-Business-Process Fallacy", category: "Foundational"),
    3: PatternCatalogEntry(name: "Invisible State", category: "Foundational"),
    4: PatternCatalogEntry(name: "All-or-Nothing Autonomy", category: "Foundational"),
    5: PatternCatalogEntry(name: "Passing As-Is Content Through the Model", category: "Foundational"),
    6: PatternCatalogEntry(name: "Chasing Exotic Agent Patterns", category: "Foundational"),
    7: PatternCatalogEntry(name: "Tool Soup", category: "Scale & Reliability"),
    8: PatternCatalogEntry(name: "Tool Data Overload", category: "Scale & Reliability"),
    9: PatternCatalogEntry(name: "Agent Washing", category: "Scale & Reliability"),
    10: PatternCatalogEntry(name: "Trust Before Verify", category: "Scale & Reliability"),
    11: PatternCatalogEntry(name: "Happy Path Engineering", category: "Scale & Reliability"),
    12: PatternCatalogEntry(name: "Multi-Agent Chaos", category: "Scale & Reliability"),
    13: PatternCatalogEntry(name: "Responsiveness Afterthought", category: "Scale & Reliability"),
    14: PatternCatalogEntry(name: "Unbound Execution Cost", category: "Scale & Reliability"),
    15: PatternCatalogEntry(name: "Demo-Grade Agent in Production", category: "Scale & Reliability"),
    16: PatternCatalogEntry(name: "Mixing Extraction with Processing", category: "Knowledge & Document Processing"),
    17: PatternCatalogEntry(name: "Lazy Field Definitions", category: "Knowledge & Document Processing"),
    18: PatternCatalogEntry(name: "Using RAG for Whole-Document Operations", category: "Knowledge & Document Processing"),
    19: PatternCatalogEntry(name: "One-Size-Fits-All Chunking", category: "Knowledge & Document Processing"),
    20: PatternCatalogEntry(name: "No Guardrails", category: "Design-Time"),
    21: PatternCatalogEntry(name: "Implicit Routing", category: "Design-Time"),
    22: PatternCatalogEntry(name: "No Evaluation Framework", category: "Design-Time"),
    23: PatternCatalogEntry(name: "Prompt Fragility", category: "Design-Time"),
    24: PatternCatalogEntry(name: "Bolted-On Human-in-the-Loop", category: "Design-Time"),
    25: PatternCatalogEntry(name: "Stateless Between Sessions", category: "Design-Time"),
    26: PatternCatalogEntry(name: "Flying Blind", category: "Operational"),
    27: PatternCatalogEntry(name: "No Caching Strategy", category: "Operational"),
    28: PatternCatalogEntry(name: "Context Window Mismanagement", category: "Operational"),
    29: PatternCatalogEntry(name: "RAG as a Black Box", category: "Operational"),
    30: PatternCatalogEntry(name: "No Feedback Loop", category: "Operational"),
    31: PatternCatalogEntry(name: "Security as an Afterthought", category: "Operational"),
    32: PatternCatalogEntry(name: "Cascade Latency Risk", category: "Performance"),
    33: PatternCatalogEntry(name: "No Load Resilience Design", category: "Performance"),
    34: PatternCatalogEntry(name: "Knowledge Retrieval at Scale", category: "Performance"),
    35: PatternCatalogEntry(name: "Missing Cost-Performance Baseline", category: "Performance"),
    36: PatternCatalogEntry(name: "Stateful Bottleneck Under Concurrency", category: "Performance"),
    37: PatternCatalogEntry(name: "No Performance Observability", category: "Performance"),
]
