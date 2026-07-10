import Foundation
import AppKit

// MARK: - wxO Importer

/// Imports a watsonx Orchestrate project folder into an Agentic Graph document.
/// Scans for agent YAML specs, Python @tool functions, OpenAPI specs, and knowledge bases.
struct WxOImporter {

    // MARK: - Parsed Models

    struct AgentSpec {
        var name: String
        var description: String
        var instructions: String
        var llm: String
        var style: String
        var tools: [String]
        var collaborators: [String]
        var knowledgeBases: [String]
        var sourcePath: String = ""   // path relative to the import root
    }

    struct ToolSpec {
        var name: String          // function name or operationId
        var description: String
        var inputs: String?       // parameter signature
        var outputs: String?      // return type
        var source: ToolSource
        var aliases: [String] = []  // Additional names this tool is known by (e.g., OpenAPI info.title)
    }

    enum ToolSource {
        case python
        case openAPI(endpoint: String)
        case json(kind: String)   // a JSON-defined tool, e.g. a flow / agentic workflow
    }

    struct KnowledgeSpec {
        var name: String
        var description: String
        var sourcePath: String = ""   // path relative to the import root
    }

    // MARK: - Import Result

    struct WxOImportResult {
        var document: GraphDocument?
        var error: String?
    }

    // MARK: - Public Entry Point

    static func importFolder(at url: URL) -> WxOImportResult {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else {
            return WxOImportResult(error: "Could not read folder contents.")
        }

        var yamlFiles: [URL] = []
        var pyFiles: [URL] = []
        var jsonFiles: [URL] = []

        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "yaml" || ext == "yml" {
                yamlFiles.append(fileURL)
            } else if ext == "py" {
                pyFiles.append(fileURL)
            } else if ext == "json", fileURL.pathComponents.contains("tools") {
                // JSON tool specs (flow / agentic-workflow tools) live under tools/.
                jsonFiles.append(fileURL)
            }
        }

        // Parse each file type
        var agents: [AgentSpec] = []
        var tools: [ToolSpec] = []
        var knowledge: [KnowledgeSpec] = []

        for yamlURL in yamlFiles {
            guard let content = try? String(contentsOf: yamlURL, encoding: .utf8) else { continue }
            let rel = relativePath(of: yamlURL, from: url)

            if isAgentYAML(content) {
                if var spec = parseAgentYAML(content) {
                    spec.sourcePath = rel
                    agents.append(spec)
                }
            } else if isKnowledgeYAML(content) {
                if var spec = parseKnowledgeYAML(content) {
                    spec.sourcePath = rel
                    knowledge.append(spec)
                }
            } else if isOpenAPIYAML(content) {
                tools.append(contentsOf: parseOpenAPIYAML(content, sourceURL: yamlURL))
            }
        }

        for pyURL in pyFiles {
            guard let content = try? String(contentsOf: pyURL, encoding: .utf8) else { continue }
            if isWxOToolFile(content) {
                tools.append(contentsOf: parsePythonTools(
                    content, toolDirectory: toolDirectoryName(for: pyURL, importRoot: url)))
            }
        }

        for jsonURL in jsonFiles {
            guard let content = try? String(contentsOf: jsonURL, encoding: .utf8) else { continue }
            if let spec = parseJSONTool(content, fileURL: jsonURL, importRoot: url) {
                tools.append(spec)
            }
        }

        if agents.isEmpty && tools.isEmpty && knowledge.isEmpty {
            return WxOImportResult(error: "No watsonx Orchestrate agents, tools, or knowledge bases found in this folder.")
        }

        let doc = buildGraph(agents: agents, tools: tools, knowledge: knowledge,
                             folderName: url.lastPathComponent)
        return WxOImportResult(document: doc)
    }

    // MARK: - File Classification

    private static func isAgentYAML(_ content: String) -> Bool {
        return content.contains("spec_version:") &&
               (content.contains("kind: native") || content.contains("kind:native"))
    }

    private static func isKnowledgeYAML(_ content: String) -> Bool {
        return content.contains("spec_version:") &&
               (content.contains("kind: knowledge_base") || content.contains("kind:knowledge_base"))
    }

    private static func isOpenAPIYAML(_ content: String) -> Bool {
        return content.contains("openapi:")
    }

    private static func isWxOToolFile(_ content: String) -> Bool {
        return content.contains("ibm_watsonx_orchestrate") && content.contains("@tool")
    }

    // MARK: - YAML Parsing (Lightweight, wxO-specific)

    private static func parseAgentYAML(_ content: String) -> AgentSpec? {
        let fields = parseTopLevelYAML(content)
        guard let name = fields["name"] else { return nil }

        // Guidelines are conditional-behaviour rules — fold them into the
        // instructions so they travel with the agent's prompt.
        var instructions = fields["instructions"] ?? ""
        let guidelines = parseGuidelines(content)
        if !guidelines.isEmpty {
            instructions = instructions.isEmpty
                ? guidelines
                : instructions + "\n\n" + guidelines
        }

        return AgentSpec(
            name: name,
            description: fields["description"] ?? "",
            instructions: instructions,
            llm: fields["llm"] ?? "",
            style: fields["style"] ?? "default",
            tools: parseYAMLList(content, key: "tools"),
            collaborators: parseYAMLList(content, key: "collaborators"),
            knowledgeBases: parseYAMLList(content, key: "knowledge_base")
        )
    }

    /// Extracts the `guidelines:` list from a wxO native agent spec and renders
    /// it as a plain-text block to append to the agent's instructions. Each
    /// guideline is a mapping with `condition`, `action`, and/or `tool` fields
    /// (`display_name` is deprecated and omitted). Returns "" when there are none.
    private static func parseGuidelines(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var i = 0
        // Find the top-level `guidelines:` key.
        while i < lines.count {
            let l = lines[i]
            if !l.hasPrefix(" "), !l.hasPrefix("\t"),
               l.trimmingCharacters(in: .whitespaces).hasPrefix("guidelines:") {
                break
            }
            i += 1
        }
        guard i < lines.count else { return "" }
        i += 1

        // Collect the list of guideline mappings.
        var items: [[String: String]] = []
        var current: [String: String]?

        func commit() {
            if let c = current, !c.isEmpty { items.append(c) }
            current = nil
        }

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            let indented = raw.hasPrefix(" ") || raw.hasPrefix("\t")

            // A non-indented line that isn't a list item ends the list.
            if !indented, !trimmed.hasPrefix("-") {
                if !trimmed.isEmpty { break }
                i += 1
                continue
            }
            if trimmed.isEmpty { i += 1; continue }

            var pair = trimmed
            if trimmed == "-" {
                commit(); current = [:]
                i += 1
                continue
            } else if trimmed.hasPrefix("- ") {
                commit(); current = [:]
                pair = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            if current != nil, let colon = pair.range(of: ":") {
                let key = String(pair[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
                var value = String(pair[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
                if value.count >= 2,
                   (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                if !value.isEmpty { current?[key] = value }
            }
            i += 1
        }
        commit()

        guard !items.isEmpty else { return "" }

        var out = "Guidelines:"
        for item in items {
            var parts: [String] = []
            if let condition = item["condition"] { parts.append("Condition: \(condition)") }
            if let action = item["action"] { parts.append("Action: \(action)") }
            if let tool = item["tool"] { parts.append("Tool: \(tool)") }
            guard !parts.isEmpty else { continue }
            out += "\n- " + parts.joined(separator: "\n  ")
        }
        return out == "Guidelines:" ? "" : out
    }

    private static func parseKnowledgeYAML(_ content: String) -> KnowledgeSpec? {
        let fields = parseTopLevelYAML(content)
        guard let name = fields["name"] else { return nil }
        return KnowledgeSpec(name: name, description: fields["description"] ?? "")
    }

    /// If `afterColon` is a YAML block scalar header, returns its style — "|"
    /// (literal) or ">" (folded). Accepts every header form: `|`, `|-`, `|+`,
    /// `|2`, `|2-`, `>-`, `>+`, and so on. The chomping (+/-) and indentation
    /// (1-9) indicators are recognised but need no special handling here — the
    /// block's indentation is auto-detected from its first content line and the
    /// result is trimmed, so chomping has no visible effect. Returns nil for a
    /// plain value.
    private static func blockScalarStyle(_ afterColon: String) -> Character? {
        guard let first = afterColon.first, first == "|" || first == ">" else { return nil }
        for ch in afterColon.dropFirst() {
            // A space, tab, or # ends the header — anything past it is a comment.
            if ch == " " || ch == "\t" || ch == "#" { break }
            guard ch == "+" || ch == "-" || ch.isNumber else { return nil }
        }
        return first
    }

    /// Parses top-level scalar fields from a wxO YAML file. Handles plain values
    /// (including ones that wrap onto following indented lines) and `|` / `>`
    /// block scalars in all of their header forms.
    private static func parseTopLevelYAML(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            // Skip empty lines, comments, list items at top level
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(" "), !line.hasPrefix("-") else {
                i += 1
                continue
            }

            // Match "key: value" or "key:" (for block scalars / lists)
            guard let colonRange = line.range(of: ":") else {
                i += 1
                continue
            }
            let key = String(line[line.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let blockStyle = blockScalarStyle(afterColon)

            if blockStyle == "|" {
                // Literal block: collect indented lines, preserving newlines
                i += 1
                var blockLines: [String] = []
                var blockIndent = -1
                while i < lines.count {
                    let bLine = lines[i]
                    if bLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        blockLines.append("")
                        i += 1
                        continue
                    }
                    guard bLine.hasPrefix(" ") || bLine.hasPrefix("\t") else { break }
                    if blockIndent < 0 {
                        blockIndent = bLine.prefix(while: { $0 == " " || $0 == "\t" }).count
                    }
                    let stripped = bLine.count > blockIndent ? String(bLine.dropFirst(blockIndent)) : ""
                    blockLines.append(stripped)
                    i += 1
                }
                result[key] = blockLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if blockStyle == ">" {
                // Folded block: collect indented lines, join with spaces
                i += 1
                var blockParts: [String] = []
                while i < lines.count {
                    let bLine = lines[i]
                    if bLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        blockParts.append("")
                        i += 1
                        continue
                    }
                    guard bLine.hasPrefix(" ") || bLine.hasPrefix("\t") else { break }
                    blockParts.append(bLine.trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                // Folded: consecutive non-empty lines join with space, empty lines become newlines
                var folded = ""
                for part in blockParts {
                    if part.isEmpty {
                        folded += "\n"
                    } else if folded.isEmpty || folded.hasSuffix("\n") {
                        folded += part
                    } else {
                        folded += " " + part
                    }
                }
                result[key] = folded.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if afterColon.isEmpty {
                // Could be a list or nested object — skip for scalar extraction
                i += 1
            } else {
                // Plain scalar — may wrap onto following indented lines, which
                // YAML joins with spaces. A blank line or a new key ends it.
                var parts = [afterColon]
                i += 1
                while i < lines.count {
                    let cont = lines[i]
                    if cont.trimmingCharacters(in: .whitespaces).isEmpty { break }
                    guard cont.hasPrefix(" ") || cont.hasPrefix("\t") else { break }
                    parts.append(cont.trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                var value = parts.joined(separator: " ")
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                result[key] = value
            }
        }

        return result
    }

    /// Parses a top-level YAML list like `tools:` or `collaborators:`.
    private static func parseYAMLList(_ content: String, key: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false

        for line in lines {
            if !line.hasPrefix(" ") && !line.hasPrefix("-") && line.hasPrefix("\(key):") {
                inList = true
                continue
            }
            if inList {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") {
                    var item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    // Strip quotes
                    if (item.hasPrefix("\"") && item.hasSuffix("\"")) ||
                       (item.hasPrefix("'") && item.hasSuffix("'")) {
                        item = String(item.dropFirst().dropLast())
                    }
                    result.append(item)
                } else if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                    // New top-level key — end of list
                    break
                }
            }
        }
        return result
    }

    // MARK: - Python Tool Parsing

    private static func parsePythonTools(_ content: String, toolDirectory: String?) -> [ToolSpec] {
        var tools: [ToolSpec] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Look for a @tool decorator.
            if line.hasPrefix("@tool") {
                // The decorator may span several lines, e.g.
                //   @tool(
                //       name="x",
                //       permission=ToolPermission.READ_ONLY,
                //   )
                // Gather lines until the parentheses balance.
                var decorator = line
                while unbalancedParens(decorator), i + 1 < lines.count {
                    i += 1
                    decorator += " " + lines[i].trimmingCharacters(in: .whitespaces)
                }
                // An explicit name= in the decorator wins; otherwise the tool
                // takes the decorated function's name.
                let explicitName = toolDecoratorName(decorator)

                // Find the function definition (plain `def` or `async def`).
                i += 1
                while i < lines.count {
                    let defLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if defLine.hasPrefix("def ") || defLine.hasPrefix("async def ") {
                        if let spec = parsePythonDef(defLine: defLine, lines: lines,
                                                     defIndex: i, explicitName: explicitName) {
                            tools.append(spec)
                        }
                        break
                    }
                    i += 1
                }
            }
            i += 1
        }
        // wxO agent YAML references a tool by its directory name (e.g.
        // `create_an_incident_3a220`), which differs from the decorated function's
        // name — record the directory as an alias so agent → tool links resolve.
        if let dir = toolDirectory {
            for idx in tools.indices where tools[idx].name != dir
                  && !tools[idx].aliases.contains(dir) {
                tools[idx].aliases.append(dir)
            }
        }
        return tools
    }

    /// True when a string has more "(" than ")" — an unclosed decorator call.
    private static func unbalancedParens(_ s: String) -> Bool {
        s.filter { $0 == "(" }.count > s.filter { $0 == ")" }.count
    }

    /// Extracts the `name=` argument from a `@tool(...)` decorator, if present.
    /// Returns nil for a bare `@tool`, `@tool()`, or a decorator with no `name=`.
    private static func toolDecoratorName(_ decorator: String) -> String? {
        // Match `name = "` / `name='` with a word boundary so `display_name=` etc. don't match.
        guard let nameRange = decorator.range(of: #"\bname\s*=\s*['"]"#,
                                              options: .regularExpression) else { return nil }
        let quoteChar = decorator[decorator.index(before: nameRange.upperBound)]
        let afterQuote = decorator[nameRange.upperBound...]
        guard let endQuote = afterQuote.firstIndex(of: quoteChar) else { return nil }
        let value = String(afterQuote[..<endQuote]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func parsePythonDef(defLine rawDefLine: String, lines: [String],
                                       defIndex: Int, explicitName: String?) -> ToolSpec? {
        // A tool may be a coroutine — normalize "async def ..." to "def ..." first.
        let defLine = rawDefLine.hasPrefix("async ") ? String(rawDefLine.dropFirst(6)) : rawDefLine

        // Extract function name: "def func_name(params) -> ReturnType:"
        guard let parenStart = defLine.firstIndex(of: "(") else { return nil }
        let nameStart = defLine.index(defLine.startIndex, offsetBy: 4)
        let funcName = String(defLine[nameStart..<parenStart]).trimmingCharacters(in: .whitespaces)
        guard !funcName.isEmpty else { return nil }

        // Extract parameters
        var inputs: String? = nil
        if let parenEnd = defLine.firstIndex(of: ")") {
            let params = String(defLine[defLine.index(after: parenStart)..<parenEnd])
                .trimmingCharacters(in: .whitespaces)
            if !params.isEmpty && params != "self" {
                inputs = params
            }
        }

        // Extract return type
        var outputs: String? = nil
        if let arrowRange = defLine.range(of: "->") {
            let returnPart = String(defLine[arrowRange.upperBound...])
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !returnPart.isEmpty {
                outputs = returnPart
            }
        }

        // Extract docstring (first line)
        var description = ""
        let nextLine = defIndex + 1 < lines.count ? lines[defIndex + 1].trimmingCharacters(in: .whitespaces) : ""
        if nextLine.hasPrefix("\"\"\"") || nextLine.hasPrefix("'''") {
            let quote = nextLine.hasPrefix("\"\"\"") ? "\"\"\"" : "'''"
            let afterQuote = String(nextLine.dropFirst(3))
            if afterQuote.contains(quote) {
                // Single-line docstring
                description = afterQuote.replacingOccurrences(of: quote, with: "").trimmingCharacters(in: .whitespaces)
            } else {
                // Multi-line docstring — take first non-empty line
                description = afterQuote.trimmingCharacters(in: .whitespaces)
                if description.isEmpty {
                    var j = defIndex + 2
                    while j < lines.count {
                        let docLine = lines[j].trimmingCharacters(in: .whitespaces)
                        if docLine.contains(quote) { break }
                        if !docLine.isEmpty && description.isEmpty {
                            description = docLine
                        }
                        j += 1
                    }
                }
            }
        }

        return ToolSpec(
            name: explicitName ?? funcName,
            description: description,
            inputs: inputs,
            outputs: outputs,
            source: .python
        )
    }

    // MARK: - OpenAPI Parsing

    private static func parseOpenAPIYAML(_ content: String, sourceURL: URL) -> [ToolSpec] {
        var tools: [ToolSpec] = []
        let lines = content.components(separatedBy: "\n")

        // Extract info.title and server URL
        var infoTitle = ""
        var serverURL = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("title:") && infoTitle.isEmpty {
                infoTitle = trimmed.components(separatedBy: "title:").last?
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) ?? ""
            }
            if trimmed.hasPrefix("url:") && serverURL.isEmpty {
                serverURL = trimmed.components(separatedBy: "url:").last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
            }
        }

        // Build aliases from info.title — wxO registers OpenAPI tools under transformed title names
        var titleAliases: [String] = []
        if !infoTitle.isEmpty {
            // "Get Cat Facts" → ["Get Cat Facts", "Get_Cat_Facts", "get_cat_facts"]
            titleAliases.append(infoTitle)
            let underscored = infoTitle.replacingOccurrences(of: " ", with: "_")
            titleAliases.append(underscored)
            titleAliases.append(underscored.lowercased())
        }

        // Find operations under paths
        var inPaths = false
        var currentPath = ""
        var currentMethod = ""
        var currentOperationId = ""
        var currentSummary = ""
        var currentDescription = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " }).count

            if trimmed == "paths:" {
                inPaths = true
                continue
            }

            guard inPaths else { continue }

            // Top-level key after paths ends the paths section
            if indent == 0 && !trimmed.isEmpty && trimmed != "paths:" {
                inPaths = false
                continue
            }

            // Path like "  /foo/bar:"
            if indent == 2 && trimmed.hasSuffix(":") && trimmed.hasPrefix("/") {
                currentPath = String(trimmed.dropLast())
                continue
            }

            // HTTP method like "    get:" or "    post:"
            let methods = ["get", "post", "put", "delete", "patch"]
            if indent == 4 && trimmed.hasSuffix(":") {
                let method = String(trimmed.dropLast())
                if methods.contains(method) {
                    // Save previous operation if any
                    if !currentMethod.isEmpty {
                        let name = !currentOperationId.isEmpty ? currentOperationId :
                                   (!currentSummary.isEmpty ? currentSummary : "\(currentMethod.uppercased()) \(currentPath)")
                        tools.append(ToolSpec(
                            name: name,
                            description: currentDescription.isEmpty ? currentSummary : currentDescription,
                            inputs: nil,
                            outputs: nil,
                            source: .openAPI(endpoint: serverURL + currentPath),
                            aliases: titleAliases
                        ))
                    }
                    currentMethod = method
                    currentOperationId = ""
                    currentSummary = ""
                    currentDescription = ""
                    continue
                }
            }

            // operationId, summary, description within a method block
            if indent >= 6 {
                if trimmed.hasPrefix("operationId:") {
                    currentOperationId = trimmed.components(separatedBy: "operationId:").last?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                } else if trimmed.hasPrefix("summary:") {
                    currentSummary = trimmed.components(separatedBy: "summary:").last?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                } else if trimmed.hasPrefix("description:") {
                    currentDescription = trimmed.components(separatedBy: "description:").last?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                }
            }
        }

        // Don't forget the last operation
        if !currentMethod.isEmpty {
            let name = !currentOperationId.isEmpty ? currentOperationId :
                       (!currentSummary.isEmpty ? currentSummary : "\(currentMethod.uppercased()) \(currentPath)")
            tools.append(ToolSpec(
                name: name,
                description: currentDescription.isEmpty ? currentSummary : currentDescription,
                inputs: nil,
                outputs: nil,
                source: .openAPI(endpoint: serverURL + currentPath),
                aliases: titleAliases
            ))
        }

        return tools
    }

    // MARK: - Graph Construction

    /// Height per port row in a node (title bar ~30 + each port ~22)
    private static let portRowHeight: CGFloat = 22
    private static let nodeTitleHeight: CGFloat = 40

    /// Calculate node height based on port count
    private static func nodeHeight(portCount: Int) -> CGFloat {
        max(80, nodeTitleHeight + CGFloat(portCount) * portRowHeight + 10)
    }

    private static func buildGraph(agents: [AgentSpec], tools: [ToolSpec],
                                    knowledge: [KnowledgeSpec], folderName: String) -> GraphDocument {
        let doc = GraphDocument()
        doc.projectName = snakeToTitle(folderName)

        // --- Pass 1: Create nodes, edges, and ports (positions are placeholders) ---

        var allNodes: [GraphNode] = []
        var allEdges: [GraphEdge] = []
        var agentByName: [String: Int] = [:]
        var toolByName: [String: Int] = [:]

        // Identify orchestrator: agent with the most tools + collaborators
        let orchestratorIdx = agents.indices.max(by: {
            (agents[$0].tools.count + agents[$0].collaborators.count) <
            (agents[$1].tools.count + agents[$1].collaborators.count)
        })

        let agentColors = ["#4A90D9", "#E8A838", "#7B68EE", "#5BA55B", "#D95B5B",
                           "#D98BD9", "#5BC0DE", "#F0AD4E", "#8FBC8F", "#CD853F"]

        // Create all agent nodes (position = origin for now)
        for (idx, agent) in agents.enumerated() {
            let colorIdx = (idx == orchestratorIdx ? 0 : (idx % agentColors.count))
            let w = max(200, GraphNode.idealWidth(for: snakeToTitle(agent.name)))
            var node = makeAgentNode(agent, position: .zero,
                                     size: CGSize(width: w, height: 80),
                                     colorHex: agentColors[colorIdx])
            node.importSourceKey = "agent:" + agent.sourcePath + ":" + agent.name
            agentByName[agent.name] = allNodes.count
            allNodes.append(node)
        }

        // Deduplicate tools
        var seenToolNames: Set<String> = []
        var uniqueTools: [ToolSpec] = []
        for tool in tools {
            if seenToolNames.insert(tool.name).inserted {
                uniqueTools.append(tool)
            }
        }

        // Create all tool nodes
        for tool in uniqueTools {
            let w = max(200, GraphNode.idealWidth(for: snakeToTitle(tool.name)))
            var node = makeToolNode(tool, position: .zero,
                                    size: CGSize(width: w, height: 80))
            node.importSourceKey = "tool:" + tool.name
            let nodeIdx = allNodes.count
            toolByName[tool.name] = nodeIdx
            for alias in tool.aliases {
                toolByName[alias] = nodeIdx
            }
            allNodes.append(node)
        }

        // Create all knowledge nodes + lookup
        var kbByName: [String: Int] = [:]
        for kb in knowledge {
            let w = max(200, GraphNode.idealWidth(for: snakeToTitle(kb.name)))
            var node = makeKnowledgeNode(kb, position: .zero,
                                         size: CGSize(width: w, height: 80))
            node.importSourceKey = "knowledge:" + kb.sourcePath + ":" + kb.name
            let nodeIdx = allNodes.count
            kbByName[kb.name] = nodeIdx
            allNodes.append(node)
        }

        // Build normalized tool lookup for fuzzy matching
        var toolByNormalized: [String: Int] = [:]
        for (name, idx) in toolByName {
            let normalized = name.lowercased()
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
            toolByNormalized[normalized] = idx
        }

        // Create edges + ports
        for agent in agents {
            guard let agentIdx = agentByName[agent.name] else { continue }

            for toolRef in agent.tools {
                let resolvedIdx: Int?
                if let exact = toolByName[toolRef] {
                    resolvedIdx = exact
                } else {
                    let normalized = toolRef.lowercased()
                        .replacingOccurrences(of: "_", with: "")
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "-", with: "")
                    resolvedIdx = toolByNormalized[normalized]
                }
                guard let toolIdx = resolvedIdx else { continue }

                // Output port on agent
                let outputPort = NodePort(label: snakeToTitle(toolRef), kind: .output)
                allNodes[agentIdx].ports.append(outputPort)

                // Each connection gets its own input port on the tool (labeled with source agent)
                let inputPort = NodePort(label: snakeToTitle(agent.name), kind: .input)
                allNodes[toolIdx].ports.append(inputPort)

                allEdges.append(GraphEdge(
                    sourceNodeID: allNodes[agentIdx].id,
                    sourcePortID: outputPort.id,
                    targetNodeID: allNodes[toolIdx].id,
                    targetPortID: inputPort.id
                ))
            }

            for collabRef in agent.collaborators {
                guard let collabIdx = agentByName[collabRef] else { continue }

                let outputPort = NodePort(label: snakeToTitle(collabRef), kind: .output)
                allNodes[agentIdx].ports.append(outputPort)

                let inputPort = NodePort(label: snakeToTitle(agent.name), kind: .input)
                allNodes[collabIdx].ports.append(inputPort)

                allEdges.append(GraphEdge(
                    sourceNodeID: allNodes[agentIdx].id,
                    sourcePortID: outputPort.id,
                    targetNodeID: allNodes[collabIdx].id,
                    targetPortID: inputPort.id
                ))
            }

            for kbRef in agent.knowledgeBases {
                guard let kbIdx = kbByName[kbRef] else { continue }

                let outputPort = NodePort(label: snakeToTitle(kbRef), kind: .output)
                allNodes[agentIdx].ports.append(outputPort)

                let inputPort = NodePort(label: snakeToTitle(agent.name), kind: .input)
                allNodes[kbIdx].ports.append(inputPort)

                allEdges.append(GraphEdge(
                    sourceNodeID: allNodes[agentIdx].id,
                    sourcePortID: outputPort.id,
                    targetNodeID: allNodes[kbIdx].id,
                    targetPortID: inputPort.id
                ))
            }
        }

        // --- Pass 2: Resize nodes based on port count ---

        for i in allNodes.indices {
            let portCount = allNodes[i].ports.count
            if portCount > 0 {
                allNodes[i].size.height = nodeHeight(portCount: portCount)
            }
        }

        // --- Pass 3: Layout rows with actual sizes ---

        let hGap: CGFloat = 40
        let vGap: CGFloat = 100
        let startY: CGFloat = 100

        // Categorize node indices by role
        var orchestratorNodeIdx: Int? = nil
        var otherAgentIndices: [Int] = []
        for (specIdx, agent) in agents.enumerated() {
            if let nodeIdx = agentByName[agent.name] {
                if specIdx == orchestratorIdx {
                    orchestratorNodeIdx = nodeIdx
                } else {
                    otherAgentIndices.append(nodeIdx)
                }
            }
        }

        let toolStartIdx = agents.count
        let toolEndIdx = toolStartIdx + uniqueTools.count
        let toolIndices = Array(toolStartIdx..<toolEndIdx)

        let kbStartIdx = toolEndIdx
        let kbEndIdx = kbStartIdx + knowledge.count
        let kbIndices = Array(kbStartIdx..<kbEndIdx)

        // Layout all rows centered around x=0, then shift to canvas center afterward

        // Row 1: Orchestrator (center-based: position is the node center)
        var currentY = startY
        var rowMaxH: CGFloat = 0
        if let orchIdx = orchestratorNodeIdx {
            allNodes[orchIdx].position = CGPoint(x: 0, y: currentY + allNodes[orchIdx].size.height / 2)
            rowMaxH = allNodes[orchIdx].size.height
        }

        // Row 2: Other agents
        currentY += rowMaxH + vGap
        rowMaxH = 0
        if !otherAgentIndices.isEmpty {
            let rowWidth = otherAgentIndices.reduce(CGFloat(0)) { $0 + allNodes[$1].size.width }
                + CGFloat(otherAgentIndices.count - 1) * hGap
            var x = -rowWidth / 2
            for nodeIdx in otherAgentIndices {
                let w = allNodes[nodeIdx].size.width
                let h = allNodes[nodeIdx].size.height
                allNodes[nodeIdx].position = CGPoint(x: x + w / 2, y: currentY + h / 2)
                rowMaxH = max(rowMaxH, h)
                x += w + hGap
            }
        }

        // Row 3+: Tools (split into rows of maxPerRow to avoid excessive width)
        layoutRows(indices: toolIndices, nodes: &allNodes, y: &currentY,
                   rowMaxH: &rowMaxH, hGap: hGap, vGap: vGap, maxPerRow: 6)

        // Row N+: Knowledge
        layoutRows(indices: kbIndices, nodes: &allNodes, y: &currentY,
                   rowMaxH: &rowMaxH, hGap: hGap, vGap: vGap, maxPerRow: 6)

        // Find bounding box of all laid-out nodes (center-based: position is center)
        let nodeIndices = 0..<allNodes.count
        let minX = nodeIndices.map { allNodes[$0].position.x - allNodes[$0].size.width / 2 }.min() ?? 0
        let maxX = nodeIndices.map { allNodes[$0].position.x + allNodes[$0].size.width / 2 }.max() ?? 0
        let minY = nodeIndices.map { allNodes[$0].position.y - allNodes[$0].size.height / 2 }.min() ?? 0
        let maxY = nodeIndices.map { allNodes[$0].position.y + allNodes[$0].size.height / 2 }.max() ?? 0
        let layoutWidth = maxX - minX
        let layoutHeight = maxY - minY

        // Target: center the layout around (canvasCenterX, canvasCenterY)
        // Use a generous canvas — at least 2x the layout size so edges have room
        let canvasWidth = max(3000, layoutWidth + 800)
        let canvasHeight = max(2000, layoutHeight + 600)
        let layoutMidX = (minX + maxX) / 2
        let layoutMidY = (minY + maxY) / 2
        let offsetX = canvasWidth / 2 - layoutMidX
        let offsetY = canvasHeight / 2 - layoutMidY

        // Shift all nodes to center of canvas
        for i in allNodes.indices {
            allNodes[i].position.x += offsetX
            allNodes[i].position.y += offsetY
        }

        // Comment node above the layout
        let topY = allNodes.filter({ $0.kind != .comment }).map { $0.position.y - $0.size.height / 2 }.min() ?? 100
        let commentNode = GraphNode(
            kind: .comment,
            title: "Imported from watsonx Orchestrate: \(folderName)",
            detail: "Agents: \(agents.count), Tools: \(uniqueTools.count), Knowledge: \(knowledge.count)",
            position: CGPoint(x: canvasWidth / 2, y: topY - 50),
            size: CGSize(width: GraphNode.idealWidth(for: "Imported from watsonx Orchestrate: \(folderName)",
                                                     isComment: true),
                         height: 80),
            colorHex: "AAAAAA"
        )
        allNodes.append(commentNode)

        // Set project description from orchestrator
        if let orchSpecIdx = orchestratorIdx {
            doc.projectDescription = agents[orchSpecIdx].description
        }

        doc.nodes = allNodes
        doc.edges = allEdges
        doc.updateContentExtent()
        return doc
    }

    /// Lay out a set of node indices into centered rows of `maxPerRow`, advancing `y` and tracking `rowMaxH`.
    private static func layoutRows(indices: [Int], nodes: inout [GraphNode],
                                    y: inout CGFloat, rowMaxH: inout CGFloat,
                                    hGap: CGFloat, vGap: CGFloat, maxPerRow: Int) {
        guard !indices.isEmpty else { return }

        // Advance past previous row
        y += rowMaxH + vGap
        rowMaxH = 0

        let chunks = stride(from: 0, to: indices.count, by: maxPerRow).map {
            Array(indices[$0..<min($0 + maxPerRow, indices.count)])
        }

        for (chunkIdx, chunk) in chunks.enumerated() {
            let rowWidth = chunk.reduce(CGFloat(0)) { $0 + nodes[$1].size.width }
                + CGFloat(chunk.count - 1) * hGap
            var x = -rowWidth / 2
            var chunkMaxH: CGFloat = 0

            for nodeIdx in chunk {
                let w = nodes[nodeIdx].size.width
                let h = nodes[nodeIdx].size.height
                nodes[nodeIdx].position = CGPoint(x: x + w / 2, y: y + h / 2)
                chunkMaxH = max(chunkMaxH, h)
                x += w + hGap
            }

            rowMaxH = chunkMaxH
            // If more chunks follow, advance to next row
            if chunkIdx < chunks.count - 1 {
                y += chunkMaxH + vGap
                rowMaxH = 0
            }
        }
    }

    // MARK: - Node Factories

    private static func makeAgentNode(_ spec: AgentSpec, position: CGPoint,
                                       size: CGSize, colorHex: String) -> GraphNode {
        // Detect framework from LLM string
        let framework: AgentFramework = spec.llm.contains("watsonx") ? .watsonx : .custom

        return GraphNode(
            kind: .agent,
            title: snakeToTitle(spec.name),
            detail: spec.description,
            position: position,
            size: size,
            ports: [],  // Ports added during edge creation
            colorHex: colorHex,
            agentFramework: framework,
            agentModel: spec.llm,
            agentRole: spec.style,
            agentInstructions: spec.instructions,
            agentCanDelegate: !spec.collaborators.isEmpty
        )
    }

    private static func makeToolNode(_ spec: ToolSpec, position: CGPoint,
                                      size: CGSize) -> GraphNode {
        let toolType: ToolType
        let endpoint: String?

        switch spec.source {
        case .python:
            toolType = .python
            endpoint = nil
        case .openAPI(let ep):
            toolType = .api
            endpoint = ep
        case .json(let kind):
            toolType = (kind == "flow") ? .flow : .custom
            endpoint = nil
        }

        return GraphNode(
            kind: .tool,
            title: snakeToTitle(spec.name),
            detail: spec.description,
            position: position,
            size: size,
            ports: [],  // Ports added during edge creation
            toolType: toolType,
            toolInputs: spec.inputs,
            toolOutputs: spec.outputs,
            toolEndpoint: endpoint
        )
    }

    private static func makeKnowledgeNode(_ spec: KnowledgeSpec, position: CGPoint,
                                           size: CGSize) -> GraphNode {
        return GraphNode(
            kind: .knowledge,
            title: snakeToTitle(spec.name),
            detail: spec.description,
            position: position,
            size: size,
            ports: []  // Ports added during edge creation
        )
    }

    // MARK: - Helpers

    /// Path of `fileURL` relative to the import root, e.g. "agents/researcher.yaml".
    /// This disambiguates same-named specs that appear in different folders
    /// (e.g. an archived copy) when building a node's stable identity key.
    private static func relativePath(of fileURL: URL, from root: URL) -> String {
        let rootParts = root.standardizedFileURL.pathComponents
        let fileParts = fileURL.standardizedFileURL.pathComponents
        if fileParts.count > rootParts.count,
           Array(fileParts.prefix(rootParts.count)) == rootParts {
            return fileParts.dropFirst(rootParts.count).joined(separator: "/")
        }
        return fileURL.lastPathComponent
    }

    /// The directory directly under `tools/` that contains `fileURL`. wxO agent
    /// YAML references a tool by this directory name (e.g. `create_an_incident_3a220`),
    /// which differs from the Python function name or a JSON tool's display name.
    private static func toolDirectoryName(for fileURL: URL, importRoot: URL) -> String? {
        let parts = relativePath(of: fileURL, from: importRoot)
            .split(separator: "/").map(String.init)
        guard let toolsIdx = parts.firstIndex(of: "tools"), toolsIdx + 1 < parts.count else {
            return nil
        }
        let next = parts[toolsIdx + 1]
        // nil when the tool file sits directly in tools/ (no per-tool subdirectory).
        return (next.hasSuffix(".py") || next.hasSuffix(".json")) ? nil : next
    }

    /// Parses a wxO tool defined as JSON — e.g. a flow / agentic-workflow tool.
    /// Returns nil for JSON files that aren't tool specs.
    private static func parseJSONTool(_ content: String, fileURL: URL, importRoot: URL) -> ToolSpec? {
        guard let data = content.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let spec = root["spec"] as? [String: Any],
              let kind = (spec["kind"] as? String), !kind.isEmpty
        else { return nil }

        let dirName = toolDirectoryName(for: fileURL, importRoot: importRoot)
        let fileBase = fileURL.deletingPathExtension().lastPathComponent
        let displayName = (spec["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let name = displayName ?? dirName ?? fileBase
        var description = (spec["description"] as? String) ?? ""
        if description == "No description" { description = "" }

        var toolSpec = ToolSpec(
            name: name,
            description: description,
            inputs: nil,
            outputs: nil,
            source: .json(kind: kind)
        )
        // wxO agent YAML references the tool by its directory / file name.
        for alias in [dirName, fileBase].compactMap({ $0 }) where alias != name {
            if !toolSpec.aliases.contains(alias) { toolSpec.aliases.append(alias) }
        }
        return toolSpec
    }

    /// Converts `snake_case_name` to `Title Case Name`.
    private static func snakeToTitle(_ name: String) -> String {
        name.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
