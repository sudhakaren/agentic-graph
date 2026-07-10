import SwiftUI

/// One attribute-level match produced by a Find query.
struct FindResult: Identifiable {
    enum Target {
        case node(UUID)
        case edge(UUID)
    }

    let id = UUID()
    let target: Target
    let icon: String
    let iconColor: Color
    /// Node title, or "Source → Target" for an edge.
    let title: String
    /// The Inspector label of the field that matched ("Goal", "Endpoint", …).
    let attribute: LocalizedStringKey
    /// A one-line window of the matching value with the match roughly centred.
    /// Empty when the match is the item's own title (already shown as `title`).
    let snippet: String
}

/// Deterministic, case-insensitive substring search across node and edge text fields.
enum GraphSearch {
    static func run(query: String, in document: GraphDocument) -> [FindResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        var results: [FindResult] = []

        for node in document.nodes {
            for field in node.searchableFields {
                let flat = normalize(field.value)
                guard let range = flat.range(of: q, options: .caseInsensitive) else { continue }
                results.append(FindResult(
                    target: .node(node.id),
                    icon: node.kind.sfSymbol,
                    iconColor: node.kind.color,
                    title: node.title,
                    attribute: field.label,
                    snippet: field.isTitle ? "" : window(flat, around: range)
                ))
            }
        }

        for edge in document.edges {
            guard let comment = edge.comments else { continue }
            let flat = normalize(comment)
            guard let range = flat.range(of: q, options: .caseInsensitive) else { continue }
            let source = document.node(for: edge.sourceNodeID)?.title ?? "?"
            let target = document.node(for: edge.targetNodeID)?.title ?? "?"
            results.append(FindResult(
                target: .edge(edge.id),
                icon: "arrow.right",
                iconColor: .secondary,
                title: "\(source) → \(target)",
                attribute: "Comment",
                snippet: window(flat, around: range)
            ))
        }

        return results
    }

    /// Collapses runs of whitespace and newlines into single spaces.
    private static func normalize(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// A single-line window of `text` around `range`, with ellipses when truncated.
    private static func window(_ text: String, around range: Range<String.Index>,
                               pad: Int = 44) -> String {
        let start = text.index(range.lowerBound, offsetBy: -pad, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: pad, limitedBy: text.endIndex) ?? text.endIndex
        var out = String(text[start..<end])
        if start > text.startIndex { out = "…" + out }
        if end < text.endIndex { out += "…" }
        return out
    }
}

extension GraphNode {
    /// Non-empty user-facing text fields paired with their Inspector labels.
    var searchableFields: [(label: LocalizedStringKey, value: String, isTitle: Bool)] {
        var out: [(label: LocalizedStringKey, value: String, isTitle: Bool)] = []
        func add(_ label: LocalizedStringKey, _ value: String?, isTitle: Bool = false) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            out.append((label: label, value: value, isTitle: isTitle))
        }
        add("Title", title, isTitle: true)
        add("Detail", detail)
        add("Comments", comments)
        add("Expected Duration", expectedDuration)
        // Agent
        add("Model", agentModel)
        add("Role", agentRole)
        add("Goal", agentGoal)
        add("Instructions", agentInstructions)
        add("Max Iterations", agentMaxIterations)
        add("Latency Budget", agentLatencyBudget)
        add("Cost Budget", agentCostBudget)
        // Tool
        add("Inputs", toolInputs)
        add("Outputs", toolOutputs)
        add("Endpoint", toolEndpoint)
        add("Timeout", toolTimeout)
        add("Data Volume", toolDataVolume)
        // Knowledge
        add("Data Formats", knowledgeDataFormats)
        add("Size / Quantity", knowledgeSizeQuantity)
        add("Location", knowledgeLocation)
        add("Access Method", knowledgeAccessMethod)
        add("Sensitivity", knowledgeSensitivity)
        add("Update Frequency", knowledgeUpdateFrequency)
        add("Versioning", knowledgeVersioningMethod)
        add("Chunking Strategy", knowledgeChunkingStrategy)
        add("Content Type", knowledgeContentType)
        // Human
        add("Role", humanRole)
        add("Language", humanLanguage)
        add("Timezone", humanTimezone)
        add("Auth Method", humanAuthMethod)
        add("Access Level", humanAccessLevel)
        add("SLA", humanSLA)
        add("Behaviors", humanBehaviors)
        return out
    }
}
