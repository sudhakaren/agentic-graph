import Foundation
import AppKit
import zlib

// MARK: - Project Manifest

struct ProjectManifest: Codable {
    var version: String = "1.0"
    var nodes: [GraphNode]
    var edges: [GraphEdge]

    // Project metadata
    var projectName: String?
    var projectDescription: String?
    var businessJustification: String?
    var targetCompletionDate: String?
    var estimatedEffort: String?
    var teamSize: String?
    var integrationPoints: String?
    var deploymentTarget: DeploymentTarget?
    var overallRiskLevel: RiskLevel?
    var complianceRequirements: String?
    var dataClassification: String?
    var regulatoryConstraints: String?
    var criticalDependencies: String?
    var keyAssumptions: String?
    var openQuestions: String?
    var projectComments: String?
    var promptAnalysisDrafts: [String: String]?

    // Analysis
    var lastAnalysisResult: AnalysisResult?

    /// Populate manifest from a document's metadata fields.
    static func from(document: GraphDocument) -> ProjectManifest {
        var m = ProjectManifest(nodes: document.nodes, edges: document.edges)
        m.projectName = document.projectName
        m.projectDescription = document.projectDescription
        m.businessJustification = document.businessJustification
        m.targetCompletionDate = document.targetCompletionDate
        m.estimatedEffort = document.estimatedEffort
        m.teamSize = document.teamSize
        m.integrationPoints = document.integrationPoints
        m.deploymentTarget = document.deploymentTarget
        m.overallRiskLevel = document.overallRiskLevel == .none ? nil : document.overallRiskLevel
        m.complianceRequirements = document.complianceRequirements
        m.dataClassification = document.dataClassification
        m.regulatoryConstraints = document.regulatoryConstraints
        m.criticalDependencies = document.criticalDependencies
        m.keyAssumptions = document.keyAssumptions
        m.openQuestions = document.openQuestions
        m.projectComments = document.projectComments
        m.promptAnalysisDrafts = document.promptAnalysisDrafts.isEmpty ? nil : document.promptAnalysisDrafts
        m.lastAnalysisResult = document.lastAnalysisResult
        return m
    }

    /// Apply metadata from the manifest back to a document.
    func apply(to doc: GraphDocument) {
        doc.nodes = nodes
        doc.edges = edges
        doc.updateContentExtent()
        if let name = projectName { doc.projectName = name }
        doc.projectDescription = projectDescription
        doc.businessJustification = businessJustification
        doc.targetCompletionDate = targetCompletionDate
        doc.estimatedEffort = estimatedEffort
        doc.teamSize = teamSize
        doc.integrationPoints = integrationPoints
        doc.deploymentTarget = deploymentTarget
        doc.overallRiskLevel = overallRiskLevel ?? .none
        doc.complianceRequirements = complianceRequirements
        doc.dataClassification = dataClassification
        doc.regulatoryConstraints = regulatoryConstraints
        doc.criticalDependencies = criticalDependencies
        doc.keyAssumptions = keyAssumptions
        doc.openQuestions = openQuestions
        doc.projectComments = projectComments
        doc.promptAnalysisDrafts = promptAnalysisDrafts ?? [:]
        doc.lastAnalysisResult = lastAnalysisResult
    }
}

// MARK: - ZIP Exporter

struct ZIPExporter {

    static func exportZIP(document: GraphDocument) -> Data? {
        var zip = ZIPWriter()

        // graph.json
        let manifest = ProjectManifest.from(document: document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(manifest) else { return nil }
        zip.addEntry(name: "graph.json", data: jsonData)

        // preview.png
        let pngData = PNGExporter.export(document: document)
        if let pngData {
            zip.addEntry(name: "preview.png", data: pngData)
        }

        // docs/README.md — high-level architecture
        let readme = generateReadme(document: document)
        zip.addEntry(name: "docs/README.md", data: Data(readme.utf8))

        // docs/Architecture.html — styled HTML with embedded PNG
        let html = generateHTML(document: document, pngData: pngData)
        zip.addEntry(name: "docs/Architecture.html", data: Data(html.utf8))

        // Per-node markdown
        for node in document.nodes where node.kind.hasPorts {
            let safeName = node.title.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
            let filename = "docs/\(node.kind.rawValue)-\(safeName).md"
            let content = generateNodeMarkdown(node: node, document: document)
            zip.addEntry(name: filename, data: Data(content.utf8))
        }

        // Version snapshots
        let versionEncoder = JSONEncoder()
        versionEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        versionEncoder.dateEncodingStrategy = .iso8601

        for snapshot in document.versions {
            guard let snapshotData = try? versionEncoder.encode(snapshot) else { continue }
            let safeName = snapshot.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
            let formatter = ISO8601DateFormatter()
            let dateStr = formatter.string(from: snapshot.createdAt)
                .replacingOccurrences(of: ":", with: "-")
            let filename = "versions/\(dateStr)_\(safeName).json"
            zip.addEntry(name: filename, data: snapshotData)
        }

        return zip.finalize()
    }

    /// Import result with either a document or an error message.
    struct ImportResult {
        var document: GraphDocument?
        var error: String?
    }

    static func importZIP(from url: URL) -> GraphDocument? {
        importZIPWithDiagnostics(from: url).document
    }

    static func importZIPWithDiagnostics(from url: URL) -> ImportResult {
        guard let zipData = try? Data(contentsOf: url) else {
            return ImportResult(error: "Could not read file data from disk.")
        }
        guard let entries = ZIPReader.readEntries(from: zipData) else {
            return ImportResult(error: "File is not a valid ZIP archive.")
        }

        // Find graph.json
        guard let jsonEntry = entries.first(where: { $0.name == "graph.json" }) else {
            let names = entries.map(\.name).joined(separator: ", ")
            return ImportResult(error: "No graph.json found in ZIP. Entries: \(names)")
        }

        let decoder = JSONDecoder()
        do {
            let manifest = try decoder.decode(ProjectManifest.self, from: jsonEntry.data)

            let doc = GraphDocument()
            manifest.apply(to: doc)

            // Load version snapshots
            let versionDecoder = JSONDecoder()
            versionDecoder.dateDecodingStrategy = .iso8601

            let versionEntries = entries.filter { $0.name.hasPrefix("versions/") && $0.name.hasSuffix(".json") }
            var snapshots: [VersionSnapshot] = []
            for entry in versionEntries {
                if let snapshot = try? versionDecoder.decode(VersionSnapshot.self, from: entry.data) {
                    snapshots.append(snapshot)
                }
            }
            snapshots.sort { $0.createdAt < $1.createdAt }
            doc.versions = snapshots

            return ImportResult(document: doc)
        } catch {
            return ImportResult(error: "Failed to decode graph.json: \(error.localizedDescription)")
        }
    }

    /// Show an alert when a file fails to import.
    static func showImportError(_ message: String, filename: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Could not open \"\(filename)\""
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Individual Export Methods

    /// Export a standalone HTML report with embedded diagram image.
    static func exportHTMLReport(document: GraphDocument) -> Data? {
        let pngData = PNGExporter.export(document: document)
        let html = generateHTML(document: document, pngData: pngData)
        return Data(html.utf8)
    }

    /// Export Markdown documentation as a ZIP containing README.md and per-node docs.
    static func exportMarkdownZIP(document: GraphDocument) -> Data? {
        var zip = ZIPWriter()

        let readme = generateReadme(document: document)
        zip.addEntry(name: "README.md", data: Data(readme.utf8))

        for node in document.nodes where node.kind.hasPorts {
            let safeName = node.title.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
            let filename = "\(node.kind.rawValue)-\(safeName).md"
            let content = generateNodeMarkdown(node: node, document: document)
            zip.addEntry(name: filename, data: Data(content.utf8))
        }

        return zip.finalize()
    }

    // MARK: - Architecture README (Markdown)

    private static func generateReadme(document: GraphDocument) -> String {
        let graphNodes = document.nodes.filter { !$0.kind.isShape }
        let agents = graphNodes.filter { $0.kind == .agent }
        let tools = graphNodes.filter { $0.kind == .tool }
        let knowledge = graphNodes.filter { $0.kind == .knowledge }
        let humans = graphNodes.filter { $0.kind == .human }
        let comments = graphNodes.filter { $0.kind == .comment }

        var md = "# \(document.projectName)\n\n"

        // Overview
        md += "## Overview\n\n"
        var counts: [String] = []
        if !agents.isEmpty { counts.append("\(agents.count) agent\(agents.count == 1 ? "" : "s")") }
        if !tools.isEmpty { counts.append("\(tools.count) tool\(tools.count == 1 ? "" : "s")") }
        if !knowledge.isEmpty { counts.append("\(knowledge.count) knowledge source\(knowledge.count == 1 ? "" : "s")") }
        if !humans.isEmpty { counts.append("\(humans.count) human\(humans.count == 1 ? "" : "s")") }
        if counts.isEmpty {
            md += "This project contains no components yet.\n\n"
        } else {
            md += "This project contains \(counts.joined(separator: ", ")).\n\n"
        }

        // Project Details — always show all fields
        md += "## Project Details\n\n"
        md += "### Description\n\n\(document.projectDescription ?? "_Not provided._")\n\n"
        md += "### Business Justification\n\n\(document.businessJustification ?? "_Not provided._")\n\n"
        md += "- **Target Completion**: \(document.targetCompletionDate ?? "_Not provided_")\n"
        md += "- **Estimated Effort**: \(document.estimatedEffort ?? "_Not provided_")\n"
        md += "- **Team Size**: \(document.teamSize ?? "_Not provided_")\n"
        md += "- **Integration Points**: \(document.integrationPoints ?? "_Not provided_")\n"
        md += "- **Deployment Target**: \(document.deploymentTarget?.displayName ?? "_Not provided_")\n"
        md += "- **Overall Risk Level**: \(document.overallRiskLevel.displayName)\n"
        md += "- **Compliance**: \(document.complianceRequirements ?? "_Not provided_")\n"
        md += "- **Data Classification**: \(document.dataClassification ?? "_Not provided_")\n"
        md += "- **Regulatory Constraints**: \(document.regulatoryConstraints ?? "_Not provided_")\n\n"
        md += "### Critical Dependencies\n\n\(document.criticalDependencies ?? "_Not provided._")\n\n"
        md += "### Key Assumptions\n\n\(document.keyAssumptions ?? "_Not provided._")\n\n"
        md += "### Open Questions / Blockers\n\n\(document.openQuestions ?? "_Not provided._")\n\n"

        // Project-level user comments
        if let projectComments = document.projectComments, !projectComments.isEmpty {
            md += "## Comments\n\n\(projectComments)\n\n"
        }

        // Agents
        if !agents.isEmpty {
            md += "## Agents\n\n"
            for node in agents {
                md += "### \(node.title)\n\n"
                md += node.detail.isEmpty ? "_No description provided._\n\n" : "\(node.detail)\n\n"
                md += "- **Type**: \(node.agentType.displayName)\n"
                md += "- **Framework**: \(node.agentFramework.displayName)\n"
                md += "- **Model**: \(node.agentModel ?? "_Not provided_")\n"
                md += "- **Role**: \(node.agentRole ?? "_Not provided_")\n"
                md += "- **Goal**: \(node.agentGoal ?? "_Not provided_")\n"
                md += "- **Instructions**: \(node.agentInstructions ?? "_Not provided_")\n"
                md += "- **Memory**: \(node.agentMemory.displayName)\n"
                md += "- **Max Iterations**: \(node.agentMaxIterations ?? "_Not provided_")\n"
                md += "- **Delegation**: \(node.agentCanDelegate ? "Enabled" : "Disabled")\n"
                md += "- **Complexity**: \(node.agentComplexity.displayName)\n"
                md += "- **Prompt Management**: \(node.agentPromptManagement.displayName)\n"
                md += "- **Context Strategy**: \(node.agentContextStrategy.displayName)\n"
                md += "- **Observability**: \(node.agentObservability.displayName)\n"
                md += "- **Latency Budget**: \(node.agentLatencyBudget ?? "_Not provided_")\n"
                md += "- **Cost Budget**: \(node.agentCostBudget ?? "_Not provided_")\n\n"
                md += commentsMarkdown(node.comments)
            }
        }

        // Tools
        if !tools.isEmpty {
            md += "## Tools\n\n"
            for node in tools {
                md += "### \(node.title)\n\n"
                md += node.detail.isEmpty ? "_No description provided._\n\n" : "\(node.detail)\n\n"
                md += "- **Type**: \(node.toolType.displayName)\n"
                md += "- **Category**: \(node.toolCategory.displayName)\n"
                md += "- **Execution**: \(node.toolAsync ? "Async" : "Sync")\n"
                md += "- **Inputs**: \(node.toolInputs ?? "_Not provided_")\n"
                md += "- **Outputs**: \(node.toolOutputs ?? "_Not provided_")\n"
                md += "- **Auth Method**: \(node.toolAuthMethod.displayName)\n"
                md += "- **Endpoint**: \(node.toolEndpoint ?? "_Not provided_")\n"
                md += "- **Timeout**: \(node.toolTimeout ?? "_Not provided_")\n"
                md += "- **Error Handling**: \(node.toolErrorHandling.displayName)\n"
                md += "- **Idempotent**: \(node.toolIdempotent ? "Yes" : "No")\n\n"
                md += commentsMarkdown(node.comments)
            }
        }

        // Knowledge
        if !knowledge.isEmpty {
            md += "## Knowledge Sources\n\n"
            for node in knowledge {
                md += "### \(node.title)\n\n"
                md += node.detail.isEmpty ? "_No description provided._\n\n" : "\(node.detail)\n\n"
                md += "- **Risk**: \(node.risk.displayName)\n"
                md += "- **Data Formats**: \(node.knowledgeDataFormats ?? "_Not provided_")\n"
                md += "- **Size**: \(node.knowledgeSizeQuantity ?? "_Not provided_")\n"
                md += "- **Location**: \(node.knowledgeLocation ?? "_Not provided_")\n"
                md += "- **Access Method**: \(node.knowledgeAccessMethod ?? "_Not provided_")\n"
                md += "- **Sensitivity**: \(node.knowledgeSensitivity ?? "_Not provided_")\n"
                md += "- **Update Frequency**: \(node.knowledgeUpdateFrequency ?? "_Not provided_")\n"
                md += "- **Versioning**: \(node.knowledgeVersioningMethod ?? "_Not provided_")\n"
                md += "- **Retrieval Strategy**: \(node.knowledgeRetrievalStrategy.displayName)\n"
                md += "- **Chunking Strategy**: \(node.knowledgeChunkingStrategy ?? "_Not provided_")\n"
                md += "- **Content Type**: \(node.knowledgeContentType ?? "_Not provided_")\n\n"
                md += commentsMarkdown(node.comments)
            }
        }

        // Humans
        if !humans.isEmpty {
            md += "## Humans\n\n"
            for node in humans {
                md += "### \(node.title)\n\n"
                md += node.detail.isEmpty ? "_No description provided._\n\n" : "\(node.detail)\n\n"
                md += "- **Input Channel**: \(node.humanInputChannel.displayName)\n"
                md += "- **Output Channel**: \(node.humanChannel.displayName)\n"
                md += "- **Role**: \(node.humanRole ?? "_Not provided_")\n"
                md += "- **Language**: \(node.humanLanguage ?? "_Not provided_")\n"
                md += "- **Timezone**: \(node.humanTimezone ?? "_Not provided_")\n"
                md += "- **Auth Method**: \(node.humanAuthMethod ?? "_Not provided_")\n"
                md += "- **Access Level**: \(node.humanAccessLevel ?? "_Not provided_")\n"
                md += "- **SLA / Response**: \(node.humanSLA ?? "_Not provided_")\n"
                md += "- **Expected Behaviors**: \(node.humanBehaviors ?? "_Not provided_")\n\n"
                md += commentsMarkdown(node.comments)
            }
        }

        // Data Flow
        let graphEdges = document.edges.filter { edge in
            guard let source = document.node(for: edge.sourceNodeID),
                  let target = document.node(for: edge.targetNodeID) else { return false }
            return !source.kind.isShape && !target.kind.isShape
        }
        if !graphEdges.isEmpty {
            md += "## Data Flow\n\n"
            for edge in graphEdges {
                if let source = document.node(for: edge.sourceNodeID),
                   let target = document.node(for: edge.targetNodeID) {
                    md += "- **\(source.title)** (\(source.kind.displayName)) → **\(target.title)** (\(target.kind.displayName))"
                    if let edgeComments = edge.comments, !edgeComments.isEmpty {
                        let inline = edgeComments.replacingOccurrences(of: "\n", with: " ")
                        md += " — _\(inline)_"
                    }
                    md += "\n"
                }
            }
            md += "\n"
        }

        // Annotations
        if !comments.isEmpty {
            md += "## Annotations\n\n"
            for node in comments {
                md += "- **\(node.title)**"
                if !node.detail.isEmpty {
                    md += ": \(node.detail)"
                }
                md += "\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Architecture HTML

    private static func generateHTML(document: GraphDocument, pngData: Data?) -> String {
        let graphNodes = document.nodes.filter { !$0.kind.isShape }
        let agents = graphNodes.filter { $0.kind == .agent }
        let tools = graphNodes.filter { $0.kind == .tool }
        let knowledge = graphNodes.filter { $0.kind == .knowledge }
        let comments = graphNodes.filter { $0.kind == .comment }

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(document.projectName))</title>
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
            h3 { font-size: 1.1em; margin-top: 1.2em; margin-bottom: 0.3em; display: inline; }
            p, li { color: var(--fg); }
            .overview { font-size: 1.1em; color: var(--muted); margin-bottom: 1.5em; }
            .component { background: var(--section-bg); border-radius: 8px; padding: 16px 20px; margin-bottom: 12px; border-left: 4px solid var(--border); }
            .component h3 { margin-top: 0; }
            .component .kind { font-size: 0.85em; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
            .component .detail { margin-top: 8px; }
            .detail p, .instructions p { margin: 6px 0; color: var(--fg); }
            .detail p:first-child, .instructions p:first-of-type { margin-top: 0; }
            .detail p:last-child, .instructions p:last-of-type { margin-bottom: 0; }
            .detail h4, .detail h5, .detail h6, .instructions h4, .instructions h5, .instructions h6 { margin-top: 12px; margin-bottom: 4px; font-size: 0.95em; font-weight: 600; display: block; color: var(--fg); }
            .detail ul, .detail ol, .instructions ul, .instructions ol { margin: 6px 0 6px 24px; padding: 0; color: var(--fg); }
            .detail li, .instructions li { margin: 2px 0; }
            .detail pre, .instructions pre { background: var(--bg); border: 1px solid var(--border); padding: 10px 12px; border-radius: 6px; overflow-x: auto; font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.85em; margin: 8px 0; white-space: pre; }
            .detail code, .instructions code { background: var(--section-bg); padding: 1px 5px; border-radius: 3px; font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.9em; }
            .detail pre code, .instructions pre code { background: none; padding: 0; }
            .instructions { background: var(--bg); border: 1px solid var(--border); border-left: 3px solid #007aff; border-radius: 6px; padding: 10px 14px; margin-top: 10px; }
            .instructions > strong:first-child { display: block; font-size: 0.8em; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); margin-bottom: 4px; }
            .component .badges { display: inline; margin-left: 8px; }
            .badge { display: inline-block; font-size: 0.7em; font-weight: 600; padding: 2px 7px; border-radius: 4px; vertical-align: middle; }
            .badge-risk { background: #ff3b3010; color: #ff3b30; border: 1px solid #ff3b3040; }
            .badge-risk-high { background: #ff3b3020; color: #ff3b30; }
            .badge-risk-medium { background: #ff950020; color: #ff9500; }
            .badge-risk-low { background: #34c75920; color: #34c759; }
            .badge-lock { background: #ff950010; color: #ff9500; border: 1px solid #ff950040; }
            .flow-item { display: flex; align-items: center; gap: 8px; padding: 8px 0; border-bottom: 1px solid var(--border); }
            .flow-item:last-child { border-bottom: none; }
            .flow-arrow { flex-shrink: 0; width: 40px; height: 2px; position: relative; background: var(--muted); }
            .flow-arrow::after { content: ""; position: absolute; right: -1px; top: -4px; border: 5px solid transparent; border-left-color: var(--muted); }
            .flow-arrow.dashed { background: none; border-top: 2px dashed var(--muted); height: 0; }
            .flow-arrow.dashed::after { top: -5px; }
            .flow-arrow.dotted { background: none; border-top: 2px dotted var(--muted); height: 0; }
            .flow-arrow.dotted::after { top: -5px; }
            .flow-label { font-size: 0.85em; color: var(--muted); }
            .flow-node { font-weight: 500; }
            .flow-port { font-size: 0.8em; color: var(--muted); }
            .preview { margin: 2em 0; text-align: center; }
            .preview img { max-width: 100%; border-radius: 8px; border: 1px solid var(--border); }
            .annotation { font-style: italic; color: var(--muted); background: var(--section-bg); padding: 12px 16px; border-radius: 6px; margin-bottom: 8px; border-left: 3px solid #ffcc00; }
            .annotation strong { color: var(--fg); }
            .comments { background: var(--bg); border: 1px solid var(--border); border-left: 3px solid var(--accent); border-radius: 6px; padding: 10px 14px; margin-top: 10px; }
            .comments strong { display: block; font-size: 0.8em; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); margin-bottom: 4px; }
            .comments p { white-space: pre-wrap; color: var(--fg); }
            .flow-comment { font-style: italic; color: var(--muted); font-size: 0.85em; padding: 4px 0 4px 28px; border-bottom: 1px solid var(--border); }
            .footer { margin-top: 3em; padding-top: 1em; border-top: 1px solid var(--border); font-size: 0.85em; color: var(--muted); }
            .theme-toggle { position: fixed; top: 16px; right: 16px; background: var(--section-bg); border: 1px solid var(--border); border-radius: 8px; padding: 6px 10px; cursor: pointer; font-size: 18px; line-height: 1; color: var(--fg); transition: background 0.2s; z-index: 100; }
            .theme-toggle:hover { background: var(--border); }
        </style>
        </head>
        <body>
        <button class="theme-toggle" onclick="toggleTheme()" title="Toggle dark/light mode" aria-label="Toggle dark/light mode">&#9789;</button>
        <script>
        function toggleTheme() {
            var root = document.documentElement;
            var btn = document.querySelector('.theme-toggle');
            var current = root.getAttribute('data-theme');
            if (current === 'dark') {
                root.setAttribute('data-theme', 'light');
                btn.innerHTML = '&#9789;';
            } else if (current === 'light') {
                root.setAttribute('data-theme', 'dark');
                btn.innerHTML = '&#9788;';
            } else {
                var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                root.setAttribute('data-theme', isDark ? 'light' : 'dark');
                btn.innerHTML = isDark ? '&#9789;' : '&#9788;';
            }
        }
        (function() {
            var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            document.querySelector('.theme-toggle').innerHTML = isDark ? '&#9789;' : '&#9789;';
        })();
        </script>
        <div class="container">
        <h1>\(escapeHTML(document.projectName))</h1>

        """

        // Overview
        var counts: [String] = []
        if !agents.isEmpty { counts.append("\(agents.count) agent\(agents.count == 1 ? "" : "s")") }
        if !tools.isEmpty { counts.append("\(tools.count) tool\(tools.count == 1 ? "" : "s")") }
        if !knowledge.isEmpty { counts.append("\(knowledge.count) knowledge source\(knowledge.count == 1 ? "" : "s")") }
        if counts.isEmpty {
            html += "<p class=\"overview\">This project contains no components yet.</p>\n"
        } else {
            html += "<p class=\"overview\">This project contains \(counts.joined(separator: ", ")).</p>\n"
        }

        // Preview image
        if let pngData {
            let base64 = pngData.base64EncodedString()
            html += """
            <div class="preview">
            <img src="data:image/png;base64,\(base64)" alt="Graph Preview">
            </div>

            """
        }

        // Project Details — always show all fields
        let empty = "<em style=\"color:var(--muted)\">Not provided</em>"
        html += "<h2>Project Details</h2>\n"
        html += "<div class=\"component\"><h3>Description</h3><div class=\"detail\">\(document.projectDescription.map { markdownToHTML($0) } ?? empty)</div></div>\n"
        html += "<div class=\"component\"><h3>Business Justification</h3><div class=\"detail\">\(document.businessJustification.map { markdownToHTML($0) } ?? empty)</div></div>\n"
        html += "<div class=\"component\"><ul style=\"list-style:none;padding:0\">"
        html += "<li><strong>Target Completion:</strong> \(document.targetCompletionDate.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Estimated Effort:</strong> \(document.estimatedEffort.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Team Size:</strong> \(document.teamSize.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Integration Points:</strong> \(document.integrationPoints.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Deployment Target:</strong> \(document.deploymentTarget.map { escapeHTML($0.displayName) } ?? empty)</li>"
        html += "<li><strong>Overall Risk:</strong> \(escapeHTML(document.overallRiskLevel.displayName))</li>"
        html += "<li><strong>Compliance:</strong> \(document.complianceRequirements.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Data Classification:</strong> \(document.dataClassification.map { escapeHTML($0) } ?? empty)</li>"
        html += "<li><strong>Regulatory Constraints:</strong> \(document.regulatoryConstraints.map { escapeHTML($0) } ?? empty)</li>"
        html += "</ul></div>\n"
        html += "<div class=\"component\"><h3>Critical Dependencies</h3><div class=\"detail\">\(document.criticalDependencies.map { markdownToHTML($0) } ?? empty)</div></div>\n"
        html += "<div class=\"component\"><h3>Key Assumptions</h3><div class=\"detail\">\(document.keyAssumptions.map { markdownToHTML($0) } ?? empty)</div></div>\n"
        html += "<div class=\"component\"><h3>Open Questions / Blockers</h3><div class=\"detail\">\(document.openQuestions.map { markdownToHTML($0) } ?? empty)</div></div>\n"

        // Project-level user comments
        if let projectComments = document.projectComments, !projectComments.isEmpty {
            html += "<h2>Comments</h2>\n"
            html += "<div class=\"component\"><div class=\"detail\">\(markdownToHTML(projectComments))</div></div>\n"
        }

        // Agents
        if !agents.isEmpty {
            html += "<h2>Agents</h2>\n"
            for node in agents {
                let borderColor = node.colorHex ?? "#007aff"
                html += "<div class=\"component\" style=\"border-left-color:\(borderColor)\">\n"
                html += "  <span class=\"kind\">Agent</span>\n"
                html += "  <h3>\(escapeHTML(node.title))</h3>\(nodeBadgesHTML(node))\n"
                html += "  <div class=\"detail\">\(node.detail.isEmpty ? empty : markdownToHTML(node.detail))</div>\n"
                html += "  <ul style=\"list-style:none;padding:0;margin-top:8px;font-size:0.9em;color:var(--muted)\">"
                html += "<li><strong>Framework:</strong> \(escapeHTML(node.agentFramework.displayName))</li>"
                html += "<li><strong>Model:</strong> \(node.agentModel.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Role:</strong> \(node.agentRole.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Goal:</strong> \(node.agentGoal.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Memory:</strong> \(escapeHTML(node.agentMemory.displayName))</li>"
                html += "<li><strong>Max Iterations:</strong> \(node.agentMaxIterations.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Delegation:</strong> \(node.agentCanDelegate ? "Enabled" : "Disabled")</li>"
                html += "</ul>\n"
                html += instructionsHTML(node.agentInstructions)
                html += commentsHTML(node.comments)
                html += "</div>\n"
            }
        }

        // Tools
        if !tools.isEmpty {
            html += "<h2>Tools</h2>\n"
            for node in tools {
                let borderColor = node.colorHex ?? "#ff9500"
                html += "<div class=\"component\" style=\"border-left-color:\(borderColor)\">\n"
                html += "  <span class=\"kind\">Tool</span>\n"
                html += "  <h3>\(escapeHTML(node.title))</h3>\(nodeBadgesHTML(node))\n"
                html += "  <div class=\"detail\">\(node.detail.isEmpty ? empty : markdownToHTML(node.detail))</div>\n"
                html += "  <ul style=\"list-style:none;padding:0;margin-top:8px;font-size:0.9em;color:var(--muted)\">"
                html += "<li><strong>Type:</strong> \(escapeHTML(node.toolType.displayName))</li>"
                html += "<li><strong>Execution:</strong> \(node.toolAsync ? "Async" : "Sync")</li>"
                html += "<li><strong>Inputs:</strong> \(node.toolInputs.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Outputs:</strong> \(node.toolOutputs.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Auth Method:</strong> \(escapeHTML(node.toolAuthMethod.displayName))</li>"
                html += "<li><strong>Endpoint:</strong> \(node.toolEndpoint.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Timeout:</strong> \(node.toolTimeout.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Error Handling:</strong> \(escapeHTML(node.toolErrorHandling.displayName))</li>"
                html += "</ul>\n"
                html += commentsHTML(node.comments)
                html += "</div>\n"
            }
        }

        // Knowledge
        if !knowledge.isEmpty {
            html += "<h2>Knowledge Sources</h2>\n"
            for node in knowledge {
                let borderColor = node.colorHex ?? "#5856d6"
                html += "<div class=\"component\" style=\"border-left-color:\(borderColor)\">\n"
                html += "  <span class=\"kind\">Knowledge</span>\n"
                html += "  <h3>\(escapeHTML(node.title))</h3>\(nodeBadgesHTML(node))\n"
                html += "  <div class=\"detail\">\(node.detail.isEmpty ? empty : markdownToHTML(node.detail))</div>\n"
                html += "  <ul style=\"list-style:none;padding:0;margin-top:8px;font-size:0.9em;color:var(--muted)\">"
                html += "<li><strong>Risk:</strong> \(escapeHTML(node.risk.displayName))</li>"
                html += "<li><strong>Data Formats:</strong> \(node.knowledgeDataFormats.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Size:</strong> \(node.knowledgeSizeQuantity.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Location:</strong> \(node.knowledgeLocation.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Access Method:</strong> \(node.knowledgeAccessMethod.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Sensitivity:</strong> \(node.knowledgeSensitivity.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Update Frequency:</strong> \(node.knowledgeUpdateFrequency.map { escapeHTML($0) } ?? empty)</li>"
                html += "<li><strong>Versioning:</strong> \(node.knowledgeVersioningMethod.map { escapeHTML($0) } ?? empty)</li>"
                html += "</ul>\n"
                html += commentsHTML(node.comments)
                html += "</div>\n"
            }
        }

        // Data Flow
        let graphEdges = document.edges.filter { edge in
            guard let source = document.node(for: edge.sourceNodeID),
                  let target = document.node(for: edge.targetNodeID) else { return false }
            return !source.kind.isShape && !target.kind.isShape
        }
        if !graphEdges.isEmpty {
            html += "<h2>Data Flow</h2>\n"
            for edge in graphEdges {
                if let source = document.node(for: edge.sourceNodeID),
                   let target = document.node(for: edge.targetNodeID) {
                    let arrowColor = edge.colorHex ?? "var(--muted)"
                    let arrowClass = edge.lineStyle == .dashed ? " dashed" : edge.lineStyle == .dotted ? " dotted" : ""
                    let arrowStyle = edge.colorHex != nil ? " style=\"background:\(arrowColor);\" " : ""
                    let afterStyle = edge.colorHex != nil ? " style=\"border-left-color:\(arrowColor)\"" : ""

                    // Find port labels
                    let sourcePort = source.ports.first(where: { $0.id == edge.sourcePortID })
                    let targetPort = target.ports.first(where: { $0.id == edge.targetPortID })

                    html += "<div class=\"flow-item\">"
                    html += "<span class=\"flow-node\">\(escapeHTML(source.title))</span>"
                    if let sp = sourcePort { html += " <span class=\"flow-port\">[\(escapeHTML(sp.label))]</span>" }
                    html += "<span class=\"flow-arrow\(arrowClass)\"\(arrowStyle)><span style=\"position:absolute;right:-1px;top:-4px;border:5px solid transparent;border-left-color:\(arrowColor)\"\(afterStyle)></span></span>"
                    html += "<span class=\"flow-node\">\(escapeHTML(target.title))</span>"
                    if let tp = targetPort { html += " <span class=\"flow-port\">[\(escapeHTML(tp.label))]</span>" }
                    if edge.lineStyle != .solid {
                        html += " <span class=\"flow-label\">\(escapeHTML(edge.lineStyle.displayName))</span>"
                    }
                    html += "</div>\n"
                    if let edgeComments = edge.comments, !edgeComments.isEmpty {
                        html += "<div class=\"flow-comment\">\(escapeHTML(edgeComments))</div>\n"
                    }
                }
            }
        }

        // Annotations
        if !comments.isEmpty {
            html += "<h2>Annotations</h2>\n"
            for node in comments {
                let commentBorder = node.colorHex ?? "#ffcc00"
                html += "<div class=\"annotation\" style=\"border-left-color:\(commentBorder)\">"
                html += "<strong>\(escapeHTML(node.title))</strong>"
                if !node.detail.isEmpty {
                    html += "<br>\(escapeHTML(node.detail))"
                }
                html += "</div>\n"
            }
        }

        html += """
        <div class="footer">
        Generated by Agentic Graph
        </div>
        </div>
        </body>
        </html>
        """

        return html
    }

    private static func commentsMarkdown(_ comments: String?) -> String {
        guard let comments, !comments.isEmpty else { return "" }
        let quoted = comments
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        return "**Comments:**\n\n\(quoted)\n\n"
    }

    private static func commentsHTML(_ comments: String?) -> String {
        guard let comments, !comments.isEmpty else { return "" }
        let escaped = escapeHTML(comments)
        return "<div class=\"comments\"><strong>Comments</strong><p>\(escaped)</p></div>\n"
    }

    private static func instructionsHTML(_ instructions: String?) -> String {
        guard let instructions, !instructions.isEmpty else { return "" }
        return "<div class=\"instructions\"><strong>Instructions</strong>\(markdownToHTML(instructions))</div>\n"
    }

    // MARK: - Markdown → HTML

    /// Renders a subset of CommonMark markdown to HTML for use in the project HTML report.
    /// Handles: fenced code blocks (```), inline code (`), bold (**/__), italic (*/_),
    /// headings (# through ######), bulleted/numbered lists, paragraphs (blank-line
    /// separated; single newlines become <br>), and [text](url) links. Non-markdown
    /// content is HTML-escaped.
    private static func markdownToHTML(_ text: String) -> String {
        if text.isEmpty { return "" }

        // Pass 1: lift fenced code blocks out of the stream and replace them with
        // single-line placeholders so the line-by-line pass below doesn't try to
        // interpret their contents.
        var codeBlocks: [String] = []
        var sourceLines: [String] = []
        let rawLines = text.components(separatedBy: "\n")
        var i = 0
        while i < rawLines.count {
            let line = rawLines[i]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                var contentLines: [String] = []
                i += 1
                while i < rawLines.count &&
                      !rawLines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    contentLines.append(rawLines[i])
                    i += 1
                }
                if i < rawLines.count { i += 1 } // skip closing ```
                let codeContent = contentLines.joined(separator: "\n")
                codeBlocks.append("<pre><code>\(escapeHTML(codeContent))</code></pre>")
                sourceLines.append("\u{0001}CB\(codeBlocks.count - 1)\u{0002}")
            } else {
                sourceLines.append(line)
                i += 1
            }
        }

        // Pass 2: walk line-by-line, emitting block-level HTML.
        var html = ""
        var paraBuffer: [String] = []

        func flushParagraph() {
            guard !paraBuffer.isEmpty else { return }
            html += "<p>\(paraBuffer.joined(separator: "<br>\n"))</p>\n"
            paraBuffer.removeAll()
        }

        var idx = 0
        while idx < sourceLines.count {
            let raw = sourceLines[idx]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Placeholder for a previously-extracted code block.
            if trimmed.hasPrefix("\u{0001}CB"), trimmed.hasSuffix("\u{0002}") {
                flushParagraph()
                let inside = trimmed.dropFirst(3).dropLast(1)
                if let n = Int(inside), n >= 0, n < codeBlocks.count {
                    html += codeBlocks[n] + "\n"
                }
                idx += 1
                continue
            }

            // Blank line: end paragraph.
            if trimmed.isEmpty {
                flushParagraph()
                idx += 1
                continue
            }

            // Heading: leading # through ###### followed by a space.
            if let (level, headingText) = headingMatch(trimmed) {
                flushParagraph()
                // Use h4–h6 inside the report so we don't clash with surrounding h2/h3.
                let tag = "h\(min(6, max(4, level + 3)))"
                html += "<\(tag)>\(markdownInline(headingText))</\(tag)>\n"
                idx += 1
                continue
            }

            // Bulleted list.
            if let prefix = bulletPrefix(of: trimmed) {
                flushParagraph()
                var items: [String] = []
                while idx < sourceLines.count {
                    let lt = sourceLines[idx].trimmingCharacters(in: .whitespaces)
                    guard let p = bulletPrefix(of: lt) else { break }
                    items.append(markdownInline(String(lt.dropFirst(p.count))))
                    idx += 1
                }
                _ = prefix // silence unused-let
                html += "<ul>\(items.map { "<li>\($0)</li>" }.joined())</ul>\n"
                continue
            }

            // Numbered list.
            if numberedPrefix(of: trimmed) != nil {
                flushParagraph()
                var items: [String] = []
                while idx < sourceLines.count {
                    let lt = sourceLines[idx].trimmingCharacters(in: .whitespaces)
                    guard let p = numberedPrefix(of: lt) else { break }
                    items.append(markdownInline(String(lt.dropFirst(p.count))))
                    idx += 1
                }
                html += "<ol>\(items.map { "<li>\($0)</li>" }.joined())</ol>\n"
                continue
            }

            // Otherwise, accumulate into the current paragraph.
            paraBuffer.append(markdownInline(raw))
            idx += 1
        }
        flushParagraph()

        return html
    }

    private static func headingMatch(_ line: String) -> (level: Int, text: String)? {
        var count = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", count < 7 {
            count += 1
            idx = line.index(after: idx)
        }
        guard count >= 1, count <= 6, idx < line.endIndex, line[idx] == " " else { return nil }
        let textStart = line.index(after: idx)
        return (count, String(line[textStart...]))
    }

    private static func bulletPrefix(of line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return marker
        }
        return nil
    }

    private static func numberedPrefix(of line: String) -> String? {
        var digits = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx].isNumber, digits < 9 {
            digits += 1
            idx = line.index(after: idx)
        }
        guard digits >= 1, idx < line.endIndex, line[idx] == "." else { return nil }
        let afterDot = line.index(after: idx)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return String(line[..<line.index(after: afterDot)])
    }

    /// Applies inline markdown (code, bold, italic, links) and HTML-escapes the rest.
    /// The order matters: inline code is processed first so its content is preserved
    /// without bold/italic interpretation; bold runs before italic so `**foo**` doesn't
    /// get eaten by the italic pattern.
    private static func markdownInline(_ text: String) -> String {
        var stash: [String] = []
        let mark = "\u{0003}MI"
        let endMark = "\u{0004}"

        func park(_ html: String) -> String {
            stash.append(html)
            return "\(mark)\(stash.count - 1)\(endMark)"
        }

        var s = text

        // Inline code first.
        while let r = s.range(of: #"`([^`\n]+)`"#, options: .regularExpression) {
            let match = String(s[r])
            let content = String(match.dropFirst().dropLast())
            s.replaceSubrange(r, with: park("<code>\(escapeHTML(content))</code>"))
        }

        // Links [text](url).
        while let r = s.range(of: #"\[([^\]\n]+)\]\(([^)\s]+)\)"#, options: .regularExpression) {
            let match = String(s[r])
            guard let labelEnd = match.firstIndex(of: "]"),
                  let urlClose = match.lastIndex(of: ")") else { break }
            let urlOpen = match.index(after: labelEnd)
            guard urlOpen < match.endIndex, match[urlOpen] == "(" else { break }
            let label = String(match[match.index(after: match.startIndex)..<labelEnd])
            let url = String(match[match.index(after: urlOpen)..<urlClose])
            s.replaceSubrange(r, with: park("<a href=\"\(escapeHTML(url))\">\(escapeHTML(label))</a>"))
        }

        // Bold (** or __) before italic so `**x**` is not split by italic.
        for pattern in [#"\*\*([^*\n]+)\*\*"#, #"__([^_\n]+)__"#] {
            while let r = s.range(of: pattern, options: .regularExpression) {
                let match = String(s[r])
                let content = String(match.dropFirst(2).dropLast(2))
                s.replaceSubrange(r, with: park("<strong>\(escapeHTML(content))</strong>"))
            }
        }

        // Italic (* or _).
        for pattern in [#"\*([^*\n]+)\*"#, #"_([^_\n]+)_"#] {
            while let r = s.range(of: pattern, options: .regularExpression) {
                let match = String(s[r])
                let content = String(match.dropFirst().dropLast())
                s.replaceSubrange(r, with: park("<em>\(escapeHTML(content))</em>"))
            }
        }

        // Escape any remaining HTML special characters outside the parked tags.
        s = escapeHTML(s)

        // Restore parked HTML in order.
        for (n, html) in stash.enumerated() {
            s = s.replacingOccurrences(of: "\(mark)\(n)\(endMark)", with: html)
        }
        return s
    }

    private static func nodeBadgesHTML(_ node: GraphNode) -> String {
        var badges = ""
        if node.risk != .none {
            let riskClass: String
            switch node.risk {
            case .high:   riskClass = "badge-risk badge-risk-high"
            case .medium: riskClass = "badge-risk badge-risk-medium"
            case .low:    riskClass = "badge-risk badge-risk-low"
            default:      riskClass = "badge-risk"
            }
            badges += " <span class=\"badge \(riskClass)\">\(escapeHTML(node.risk.displayName))</span>"
        }
        if node.lockState != .unlocked {
            badges += " <span class=\"badge badge-lock\">\(escapeHTML(node.lockState.displayName))</span>"
        }
        return badges.isEmpty ? "" : "<span class=\"badges\">\(badges)</span>"
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Per-Node Markdown

    private static func generateNodeMarkdown(node: GraphNode, document: GraphDocument) -> String {
        let np = "_Not provided_"
        var md = "# \(node.title)\n\n"
        md += "**Type**: \(node.kind.displayName)\n\n"

        // Agent configuration
        if node.kind == .agent {
            md += "## Configuration\n\n"
            md += "- **Framework**: \(node.agentFramework.displayName)\n"
            md += "- **Model**: \(node.agentModel ?? np)\n"
            md += "- **Role**: \(node.agentRole ?? np)\n"
            md += "- **Goal**: \(node.agentGoal ?? np)\n"
            md += "- **Instructions**: \(node.agentInstructions ?? np)\n"
            md += "- **Memory**: \(node.agentMemory.displayName)\n"
            md += "- **Max Iterations**: \(node.agentMaxIterations ?? np)\n"
            md += "- **Delegation**: \(node.agentCanDelegate ? "Enabled" : "Disabled")\n"
            md += "\n"
        }

        // Tool configuration
        if node.kind == .tool {
            md += "## Configuration\n\n"
            md += "- **Type**: \(node.toolType.displayName)\n"
            md += "- **Execution**: \(node.toolAsync ? "Async" : "Sync")\n"
            md += "- **Inputs**: \(node.toolInputs ?? np)\n"
            md += "- **Outputs**: \(node.toolOutputs ?? np)\n"
            md += "- **Auth Method**: \(node.toolAuthMethod.displayName)\n"
            md += "- **Endpoint**: \(node.toolEndpoint ?? np)\n"
            md += "- **Timeout**: \(node.toolTimeout ?? np)\n"
            md += "- **Error Handling**: \(node.toolErrorHandling.displayName)\n"
            md += "\n"
        }

        // Knowledge configuration
        if node.kind == .knowledge {
            md += "## Configuration\n\n"
            md += "- **Risk**: \(node.risk.displayName)\n"
            md += "- **Data Formats**: \(node.knowledgeDataFormats ?? np)\n"
            md += "- **Size**: \(node.knowledgeSizeQuantity ?? np)\n"
            md += "- **Location**: \(node.knowledgeLocation ?? np)\n"
            md += "- **Access Method**: \(node.knowledgeAccessMethod ?? np)\n"
            md += "- **Sensitivity**: \(node.knowledgeSensitivity ?? np)\n"
            md += "- **Update Frequency**: \(node.knowledgeUpdateFrequency ?? np)\n"
            md += "- **Versioning**: \(node.knowledgeVersioningMethod ?? np)\n"
            md += "\n"
        }

        md += "## Details\n\n"
        md += node.detail.isEmpty ? "_No details provided._\n" : node.detail + "\n"
        if let nodeComments = node.comments, !nodeComments.isEmpty {
            md += "\n## Comments\n\n\(nodeComments)\n"
        }
        md += "\n## Connections\n\n"
        let connected = document.edges(connectedTo: node.id)
        if connected.isEmpty {
            md += "_No connections._\n"
        } else {
            for edge in connected {
                let otherID = edge.sourceNodeID == node.id ? edge.targetNodeID : edge.sourceNodeID
                let direction = edge.sourceNodeID == node.id ? "outgoing" : "incoming"
                if let other = document.node(for: otherID) {
                    md += "- \(direction): **\(other.title)** (\(other.kind.displayName))\n"
                }
            }
        }
        return md
    }
}

// MARK: - Minimal ZIP Writer

struct ZIPWriter {
    private var entries: [(name: String, data: Data, offset: Int)] = []
    private var buffer = Data()

    mutating func addEntry(name: String, data: Data) {
        let nameData = Data(name.utf8)
        let offset = buffer.count
        let crc = computeCRC32(data)

        // Local file header
        buffer.appendUInt32(0x04034b50) // signature
        buffer.appendUInt16(20)          // version needed
        buffer.appendUInt16(0)           // flags
        buffer.appendUInt16(0)           // compression (stored)
        buffer.appendUInt16(0)           // mod time
        buffer.appendUInt16(0)           // mod date
        buffer.appendUInt32(crc)         // CRC-32
        buffer.appendUInt32(UInt32(data.count)) // compressed size
        buffer.appendUInt32(UInt32(data.count)) // uncompressed size
        buffer.appendUInt16(UInt16(nameData.count)) // name length
        buffer.appendUInt16(0)           // extra field length
        buffer.append(nameData)
        buffer.append(data)

        entries.append((name: name, data: data, offset: offset))
    }

    mutating func finalize() -> Data {
        let centralDirOffset = buffer.count

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = computeCRC32(entry.data)

            buffer.appendUInt32(0x02014b50) // central dir signature
            buffer.appendUInt16(20)          // version made by
            buffer.appendUInt16(20)          // version needed
            buffer.appendUInt16(0)           // flags
            buffer.appendUInt16(0)           // compression
            buffer.appendUInt16(0)           // mod time
            buffer.appendUInt16(0)           // mod date
            buffer.appendUInt32(crc)
            buffer.appendUInt32(UInt32(entry.data.count))
            buffer.appendUInt32(UInt32(entry.data.count))
            buffer.appendUInt16(UInt16(nameData.count))
            buffer.appendUInt16(0)           // extra length
            buffer.appendUInt16(0)           // comment length
            buffer.appendUInt16(0)           // disk number
            buffer.appendUInt16(0)           // internal attrs
            buffer.appendUInt32(0)           // external attrs
            buffer.appendUInt32(UInt32(entry.offset))
            buffer.append(nameData)
        }

        let centralDirSize = buffer.count - centralDirOffset

        // End of central directory
        buffer.appendUInt32(0x06054b50)
        buffer.appendUInt16(0)           // disk number
        buffer.appendUInt16(0)           // disk with CD
        buffer.appendUInt16(UInt16(entries.count))
        buffer.appendUInt16(UInt16(entries.count))
        buffer.appendUInt32(UInt32(centralDirSize))
        buffer.appendUInt32(UInt32(centralDirOffset))
        buffer.appendUInt16(0)           // comment length

        return buffer
    }

    private func computeCRC32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            let result = zlib.crc32(0, baseAddress.assumingMemoryBound(to: UInt8.self), uInt(data.count))
            return UInt32(result)
        }
    }
}

// MARK: - Minimal ZIP Reader (for import)

struct ZIPReader {
    struct Entry {
        let name: String
        let data: Data
    }

    static func readEntries(from zipData: Data) -> [Entry]? {
        var entries: [Entry] = []
        var offset = 0

        while offset + 30 <= zipData.count {
            let sig = zipData.readUInt32(at: offset)
            guard sig == 0x04034b50 else { break }

            let compressedSize = Int(zipData.readUInt32(at: offset + 18))
            let nameLen = Int(zipData.readUInt16(at: offset + 26))
            let extraLen = Int(zipData.readUInt16(at: offset + 28))

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd <= zipData.count else { return nil }
            let nameData = zipData[nameStart..<nameEnd]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            let dataStart = nameEnd + extraLen
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= zipData.count else { return nil }
            let fileData = zipData[dataStart..<dataEnd]

            entries.append(Entry(name: name, data: Data(fileData)))
            offset = dataEnd
        }

        return entries.isEmpty ? nil : entries
    }
}

// MARK: - Data Extensions

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    func readUInt16(at offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        guard range.upperBound <= count else { return 0 }
        return self[range].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        guard range.upperBound <= count else { return 0 }
        return self[range].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
    }
}
