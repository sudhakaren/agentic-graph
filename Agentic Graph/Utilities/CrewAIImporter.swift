import Foundation
import AppKit

// MARK: - CrewAI Importer

/// Imports a CrewAI project folder into an Agentic Graph document.
/// Parses `agents.yaml` / `tasks.yaml` config files plus `crew.py` and any
/// custom tool Python files. Agents become agent nodes, custom/built-in tools
/// become tool nodes, and the task flow (explicit `context` or sequential
/// order) becomes the edges between agents.
struct CrewAIImporter {

    // MARK: - Parsed Models

    struct AgentSpec {
        var key: String                 // YAML key, e.g. "researcher"
        var role: String
        var goal: String
        var backstory: String
        var llm: String
        var allowDelegation: Bool
        var maxIter: String?
        var tools: [String]              // tool class names wired in crew.py / agents.yaml
    }

    struct TaskSpec {
        var key: String                 // YAML key, e.g. "research_task"
        var description: String
        var expectedOutput: String
        var agent: String                // agent key that runs the task
        var context: [String]            // upstream task keys feeding this task
    }

    struct ToolSpec {
        var className: String            // identifier used in crew.py, e.g. "SerperDevTool"
        var name: String                 // display name (the tool's `name:` or humanised class)
        var description: String
    }

    enum CrewProcess {
        case sequential
        case hierarchical
        case unknown
    }

    // MARK: - Import Result

    struct CrewAIImportResult {
        var document: GraphDocument?
        var error: String?
    }

    // MARK: - Public Entry Point

    static func importFolder(at url: URL) -> CrewAIImportResult {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else {
            return CrewAIImportResult(error: "Could not read folder contents.")
        }

        var yamlFiles: [URL] = []
        var pyFiles: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "yaml" || ext == "yml" {
                yamlFiles.append(fileURL)
            } else if ext == "py" {
                pyFiles.append(fileURL)
            }
        }

        // --- Classify and parse YAML config files ---
        var agents: [AgentSpec] = []
        var tasks: [TaskSpec] = []

        for yamlURL in yamlFiles {
            guard let content = try? String(contentsOf: yamlURL, encoding: .utf8) else { continue }
            let parsed = parseNestedYAML(content)
            guard !parsed.isEmpty else { continue }

            if isAgentsFile(parsed) {
                for (key, fields) in parsed {
                    agents.append(AgentSpec(
                        key: key,
                        role: fields["role"] ?? "",
                        goal: fields["goal"] ?? "",
                        backstory: fields["backstory"] ?? "",
                        llm: fields["llm"] ?? "",
                        allowDelegation: (fields["allow_delegation"] ?? "false").lowercased() == "true",
                        maxIter: fields["max_iter"],
                        tools: splitList(fields["tools"])
                    ))
                }
            } else if isTasksFile(parsed) {
                for (key, fields) in parsed {
                    tasks.append(TaskSpec(
                        key: key,
                        description: fields["description"] ?? "",
                        expectedOutput: fields["expected_output"] ?? "",
                        agent: fields["agent"] ?? "",
                        context: splitList(fields["context"])
                    ))
                }
            }
        }

        guard !agents.isEmpty else {
            return CrewAIImportResult(error: "No CrewAI agents.yaml found in this folder. Expected a config file with agents defined by role / goal / backstory.")
        }

        // --- Parse crew.py: process type + per-agent tool wiring ---
        var process: CrewProcess = .unknown
        var crewToolWiring: [String: [String]] = [:]   // agent key → tool class names
        for pyURL in pyFiles {
            guard let content = try? String(contentsOf: pyURL, encoding: .utf8) else { continue }
            if content.contains("crew") || content.contains("Crew(") || content.contains("@agent") {
                if process == .unknown { process = detectProcess(content) }
                let wiring = parseAgentToolWiring(content)
                for (k, v) in wiring { crewToolWiring[k, default: []].append(contentsOf: v) }
            }
        }

        // --- Parse custom tool definitions from Python files ---
        var toolSpecs: [ToolSpec] = []
        for pyURL in pyFiles {
            guard let content = try? String(contentsOf: pyURL, encoding: .utf8) else { continue }
            toolSpecs.append(contentsOf: parseToolDefinitions(content))
        }

        // Merge crew.py tool wiring into agent specs
        for i in agents.indices {
            if let wired = crewToolWiring[agents[i].key] {
                agents[i].tools = Array(Set(agents[i].tools + wired))
            }
        }

        let doc = buildGraph(agents: agents, tasks: tasks, toolSpecs: toolSpecs,
                             process: process, folderName: url.lastPathComponent)
        return CrewAIImportResult(document: doc)
    }

    // MARK: - File Classification

    private static func isAgentsFile(_ parsed: [String: [String: String]]) -> Bool {
        parsed.values.contains { $0["role"] != nil || $0["backstory"] != nil }
    }

    private static func isTasksFile(_ parsed: [String: [String: String]]) -> Bool {
        parsed.values.contains { $0["expected_output"] != nil ||
            ($0["description"] != nil && $0["agent"] != nil) }
    }

    // MARK: - Nested YAML Parsing

    /// Parses a YAML file keyed by top-level names, each with an indented field block.
    /// Returns [topLevelKey: [fieldName: value]]. Handles `>`, `>-`, `|`, `|-` block
    /// scalars and `- item` lists (lists are stored newline-joined).
    private static func parseNestedYAML(_ content: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        let lines = content.components(separatedBy: "\n")
        var i = 0
        var currentKey: String? = nil

        func indentOf(_ s: String) -> Int { s.prefix(while: { $0 == " " }).count }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { i += 1; continue }
            let indent = indentOf(line)

            if indent == 0 {
                // Top-level key (agent/task name)
                if let colon = line.range(of: ":") {
                    let key = String(line[line.startIndex..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
                    currentKey = key
                    result[key] = [:]
                }
                i += 1
                continue
            }

            guard let curKey = currentKey else { i += 1; continue }
            guard let colon = trimmed.range(of: ":") else { i += 1; continue }
            let field = String(trimmed[trimmed.startIndex..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(trimmed[colon.upperBound...]).trimmingCharacters(in: .whitespaces)

            if afterColon == "|" || afterColon == "|-" || afterColon == ">" || afterColon == ">-" {
                let isFolded = afterColon.hasPrefix(">")
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
                    let bIndent = indentOf(bLine)
                    if bIndent <= indent { break }
                    if blockIndent < 0 { blockIndent = bIndent }
                    blockLines.append(bLine.count > blockIndent ? String(bLine.dropFirst(blockIndent)) : "")
                    i += 1
                }
                if isFolded {
                    var folded = ""
                    for part in blockLines {
                        let p = part.trimmingCharacters(in: .whitespaces)
                        if p.isEmpty { folded += "\n" }
                        else if folded.isEmpty || folded.hasSuffix("\n") { folded += p }
                        else { folded += " " + p }
                    }
                    result[curKey]?[field] = folded.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    result[curKey]?[field] = blockLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if afterColon.isEmpty {
                // Possible list value — collect deeper-indented `- item` lines
                i += 1
                var items: [String] = []
                while i < lines.count {
                    let lLine = lines[i]
                    if lLine.trimmingCharacters(in: .whitespaces).isEmpty { i += 1; continue }
                    let lTrimmed = lLine.trimmingCharacters(in: .whitespaces)
                    if indentOf(lLine) > indent && lTrimmed.hasPrefix("- ") {
                        items.append(stripQuotes(String(lTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty { result[curKey]?[field] = items.joined(separator: "\n") }
            } else {
                result[curKey]?[field] = stripQuotes(afterColon)
                i += 1
            }
        }
        return result
    }

    // MARK: - crew.py Parsing

    private static func detectProcess(_ content: String) -> CrewProcess {
        if content.contains("Process.hierarchical") { return .hierarchical }
        if content.contains("Process.sequential") { return .sequential }
        return .unknown
    }

    /// Maps agent config key → tool class names from `@agent` methods in crew.py.
    /// Looks for `config=self.agents_config['key']` and `tools=[ClassA(), ClassB()]`.
    private static func parseAgentToolWiring(_ content: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        let lines = content.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            guard lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("@agent") else { i += 1; continue }
            // Collect the method body until the next decorator / def at the same level.
            var block = ""
            var j = i + 1
            var sawDef = false
            while j < lines.count {
                let t = lines[j].trimmingCharacters(in: .whitespaces)
                if sawDef && (t.hasPrefix("@") && !t.hasPrefix("@agent")) { break }
                if t.hasPrefix("def ") { sawDef = true }
                if sawDef && (t.hasPrefix("@agent") || t.hasPrefix("@task") || t.hasPrefix("@crew")) && j > i + 1 { break }
                block += lines[j] + "\n"
                // Stop once we have a closed Agent(...) return.
                if sawDef && block.contains(")") && block.contains("Agent(") &&
                    balancedParens(block) { break }
                j += 1
            }
            let key = firstMatch(in: block, pattern: #"agents_config\[\s*['\"]([^'\"]+)['\"]\s*\]"#)
            let configKey = key ?? methodName(in: block)
            if let configKey {
                result[configKey] = extractToolClassNames(from: block)
            }
            i = j
        }
        return result
    }

    /// Extracts class-name identifiers from a `tools=[A(), B()]` assignment.
    private static func extractToolClassNames(from block: String) -> [String] {
        guard let range = block.range(of: "tools") else { return [] }
        let after = block[range.upperBound...]
        guard let openBracket = after.firstIndex(of: "[") else { return [] }
        var depth = 0
        var listText = ""
        for ch in after[openBracket...] {
            if ch == "[" { depth += 1; if depth == 1 { continue } }
            if ch == "]" { depth -= 1; if depth == 0 { break } }
            listText.append(ch)
        }
        // Identifiers immediately followed by "(" are tool constructors.
        var names: [String] = []
        let scanner = listText
        var current = ""
        var prevWasIdentChar = false
        for ch in scanner {
            if ch.isLetter || ch.isNumber || ch == "_" {
                current.append(ch)
                prevWasIdentChar = true
            } else {
                if ch == "(" && prevWasIdentChar && !current.isEmpty {
                    names.append(current)
                }
                current = ""
                prevWasIdentChar = false
            }
        }
        return names
    }

    /// Parses CrewAI custom tool definitions: `class XxxTool(BaseTool)` and `@tool("...")` functions.
    private static func parseToolDefinitions(_ content: String) -> [ToolSpec] {
        var specs: [ToolSpec] = []
        let lines = content.components(separatedBy: "\n")

        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // class XxxTool(BaseTool):
            if trimmed.hasPrefix("class "), trimmed.contains("BaseTool") {
                let afterClass = trimmed.dropFirst(6)
                let className = String(afterClass.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }))
                var name = humanise(className)
                var description = ""
                // Scan the class body for `name:` and `description:` string defaults.
                var j = i + 1
                while j < lines.count {
                    let body = lines[j].trimmingCharacters(in: .whitespaces)
                    if !body.isEmpty && !lines[j].hasPrefix(" ") && !lines[j].hasPrefix("\t") { break }
                    if body.hasPrefix("name:") || body.hasPrefix("name =") || body.hasPrefix("name=") {
                        if let v = stringAssignmentValue(body) { name = v }
                    } else if body.hasPrefix("description:") || body.hasPrefix("description =") || body.hasPrefix("description=") {
                        if let v = stringAssignmentValue(body) { description = v }
                    }
                    if body.hasPrefix("def ") { break }
                    j += 1
                }
                specs.append(ToolSpec(className: className, name: name, description: description))
                i = j
                continue
            }

            // @tool("Tool Name")
            if trimmed.hasPrefix("@tool") {
                var name = ""
                if let open = trimmed.firstIndex(of: "("), let close = trimmed.lastIndex(of: ")") {
                    name = stripQuotes(String(trimmed[trimmed.index(after: open)..<close])
                        .trimmingCharacters(in: .whitespaces))
                }
                var description = ""
                var funcName = ""
                var j = i + 1
                while j < lines.count {
                    let body = lines[j].trimmingCharacters(in: .whitespaces)
                    if body.hasPrefix("def ") {
                        if let paren = body.firstIndex(of: "(") {
                            funcName = String(body[body.index(body.startIndex, offsetBy: 4)..<paren])
                                .trimmingCharacters(in: .whitespaces)
                        }
                        // Docstring on the following line(s)
                        if j + 1 < lines.count {
                            let doc = lines[j + 1].trimmingCharacters(in: .whitespaces)
                            if doc.hasPrefix("\"\"\"") || doc.hasPrefix("'''") {
                                description = doc.replacingOccurrences(of: "\"\"\"", with: "")
                                    .replacingOccurrences(of: "'''", with: "")
                                    .trimmingCharacters(in: .whitespaces)
                            }
                        }
                        break
                    }
                    j += 1
                }
                let display = name.isEmpty ? humanise(funcName) : name
                specs.append(ToolSpec(className: funcName.isEmpty ? display : funcName,
                                      name: display, description: description))
                i = j
                continue
            }
            i += 1
        }
        return specs
    }

    // MARK: - Graph Construction

    private static let portRowHeight: CGFloat = 22
    private static let nodeTitleHeight: CGFloat = 40

    private static func nodeHeight(portCount: Int) -> CGFloat {
        max(80, nodeTitleHeight + CGFloat(portCount) * portRowHeight + 10)
    }

    private static func buildGraph(agents: [AgentSpec], tasks: [TaskSpec],
                                    toolSpecs: [ToolSpec], process: CrewProcess,
                                    folderName: String) -> GraphDocument {
        let doc = GraphDocument()
        doc.projectName = humanise(folderName)

        var allNodes: [GraphNode] = []
        var allEdges: [GraphEdge] = []
        var agentByKey: [String: Int] = [:]
        var toolByClass: [String: Int] = [:]

        let agentColors = ["#4A90D9", "#E8A838", "#7B68EE", "#5BA55B", "#D95B5B",
                           "#D98BD9", "#5BC0DE", "#F0AD4E", "#8FBC8F", "#CD853F"]

        // Agent nodes
        for (idx, agent) in agents.enumerated() {
            let w = max(200, GraphNode.idealWidth(for: humanise(agent.key)))
            let node = makeAgentNode(agent, colorHex: agentColors[idx % agentColors.count],
                                     size: CGSize(width: w, height: 80))
            agentByKey[agent.key] = allNodes.count
            allNodes.append(node)
        }

        // Tool nodes — every tool referenced by an agent or defined in a file.
        var toolNameByClass: [String: ToolSpec] = [:]
        for spec in toolSpecs { toolNameByClass[spec.className] = spec }

        var referencedToolClasses: [String] = []
        for agent in agents {
            for t in agent.tools where !referencedToolClasses.contains(t) {
                referencedToolClasses.append(t)
            }
        }
        // Include defined tools even if not wired, so nothing is silently dropped.
        for spec in toolSpecs where !referencedToolClasses.contains(spec.className) {
            referencedToolClasses.append(spec.className)
        }

        for toolClass in referencedToolClasses {
            let spec = toolNameByClass[toolClass]
            let title = spec?.name ?? humanise(toolClass)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .tool,
                title: title,
                detail: spec?.description ?? "",
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                toolType: .custom
            )
            toolByClass[toolClass] = allNodes.count
            allNodes.append(node)
        }

        // --- Edges: agent → tool ---
        var agentToolPairs = Set<String>()
        for agent in agents {
            guard let agentIdx = agentByKey[agent.key] else { continue }
            for toolClass in agent.tools {
                guard let toolIdx = toolByClass[toolClass] else { continue }
                let pairKey = "\(agent.key)|\(toolClass)"
                guard agentToolPairs.insert(pairKey).inserted else { continue }
                let outPort = NodePort(label: toolNameByClass[toolClass]?.name ?? humanise(toolClass), kind: .output)
                allNodes[agentIdx].ports.append(outPort)
                let inPort = NodePort(label: humanise(agent.key), kind: .input)
                allNodes[toolIdx].ports.append(inPort)
                allEdges.append(GraphEdge(
                    sourceNodeID: allNodes[agentIdx].id, sourcePortID: outPort.id,
                    targetNodeID: allNodes[toolIdx].id, targetPortID: inPort.id))
            }
        }

        // --- Edges: agent → agent (task flow) ---
        let taskByKey = Dictionary(tasks.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var agentFlowPairs = Set<String>()

        func addAgentEdge(from sourceKey: String, to targetKey: String) {
            guard sourceKey != targetKey,
                  let srcIdx = agentByKey[sourceKey],
                  let dstIdx = agentByKey[targetKey] else { return }
            let pairKey = "\(sourceKey)→\(targetKey)"
            guard agentFlowPairs.insert(pairKey).inserted else { return }
            let outPort = NodePort(label: humanise(targetKey), kind: .output)
            allNodes[srcIdx].ports.append(outPort)
            let inPort = NodePort(label: humanise(sourceKey), kind: .input)
            allNodes[dstIdx].ports.append(inPort)
            allEdges.append(GraphEdge(
                sourceNodeID: allNodes[srcIdx].id, sourcePortID: outPort.id,
                targetNodeID: allNodes[dstIdx].id, targetPortID: inPort.id))
        }

        var hasExplicitContext = false
        for task in tasks where !task.context.isEmpty {
            hasExplicitContext = true
            for ctxKey in task.context {
                if let ctxTask = taskByKey[ctxKey] {
                    addAgentEdge(from: ctxTask.agent, to: task.agent)
                }
            }
        }
        // Sequential crew with no explicit context → chain task agents in order.
        if !hasExplicitContext, process != .hierarchical, tasks.count > 1 {
            for i in 0..<(tasks.count - 1) {
                addAgentEdge(from: tasks[i].agent, to: tasks[i + 1].agent)
            }
        }

        // --- Resize nodes by port count ---
        for i in allNodes.indices where !allNodes[i].ports.isEmpty {
            allNodes[i].size.height = nodeHeight(portCount: allNodes[i].ports.count)
        }

        // --- Layout: agents row(s), then tools row(s) ---
        let hGap: CGFloat = 40
        let vGap: CGFloat = 100
        var currentY: CGFloat = 100
        var rowMaxH: CGFloat = 0

        let agentIndices = Array(0..<agents.count)
        let toolIndices = Array(agents.count..<allNodes.count)

        layoutRows(indices: agentIndices, nodes: &allNodes, y: &currentY,
                   rowMaxH: &rowMaxH, hGap: hGap, vGap: vGap, maxPerRow: 5, firstRow: true)
        layoutRows(indices: toolIndices, nodes: &allNodes, y: &currentY,
                   rowMaxH: &rowMaxH, hGap: hGap, vGap: vGap, maxPerRow: 6, firstRow: false)

        // Centre the layout on a generous canvas.
        let idxRange = 0..<allNodes.count
        let minX = idxRange.map { allNodes[$0].position.x - allNodes[$0].size.width / 2 }.min() ?? 0
        let maxX = idxRange.map { allNodes[$0].position.x + allNodes[$0].size.width / 2 }.max() ?? 0
        let minY = idxRange.map { allNodes[$0].position.y - allNodes[$0].size.height / 2 }.min() ?? 0
        let maxY = idxRange.map { allNodes[$0].position.y + allNodes[$0].size.height / 2 }.max() ?? 0
        let canvasWidth = max(3000, (maxX - minX) + 800)
        let canvasHeight = max(2000, (maxY - minY) + 600)
        let offsetX = canvasWidth / 2 - (minX + maxX) / 2
        let offsetY = canvasHeight / 2 - (minY + maxY) / 2
        for i in allNodes.indices {
            allNodes[i].position.x += offsetX
            allNodes[i].position.y += offsetY
        }

        // Comment node above the layout
        let processName: String
        switch process {
        case .sequential: processName = "sequential"
        case .hierarchical: processName = "hierarchical"
        case .unknown: processName = "unknown"
        }
        let topY = allNodes.map { $0.position.y - $0.size.height / 2 }.min() ?? 100
        let title = String(format: String(localized: "Imported from CrewAI: %@"), folderName)
        let detail = String(format: String(localized: "Agents: %lld, Tools: %lld, Process: %@"),
                            agents.count, toolIndices.count, processName)
        allNodes.append(GraphNode(
            kind: .comment,
            title: title,
            detail: detail,
            position: CGPoint(x: canvasWidth / 2, y: topY - 50),
            size: CGSize(width: GraphNode.idealWidth(for: title, isComment: true), height: 80),
            colorHex: "AAAAAA"
        ))

        doc.nodes = allNodes
        doc.edges = allEdges
        doc.updateContentExtent()
        return doc
    }

    private static func layoutRows(indices: [Int], nodes: inout [GraphNode],
                                    y: inout CGFloat, rowMaxH: inout CGFloat,
                                    hGap: CGFloat, vGap: CGFloat, maxPerRow: Int,
                                    firstRow: Bool) {
        guard !indices.isEmpty else { return }
        if !firstRow {
            y += rowMaxH + vGap
            rowMaxH = 0
        }
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
            if chunkIdx < chunks.count - 1 {
                y += chunkMaxH + vGap
                rowMaxH = 0
            }
        }
    }

    private static func makeAgentNode(_ spec: AgentSpec, colorHex: String, size: CGSize) -> GraphNode {
        // CrewAI backstory is the richest free-text description of the agent.
        var detailParts: [String] = []
        if !spec.backstory.isEmpty { detailParts.append(spec.backstory) }
        let detail = detailParts.joined(separator: "\n\n")

        return GraphNode(
            kind: .agent,
            title: humanise(spec.key),
            detail: detail,
            position: .zero,
            size: size,
            ports: [],
            colorHex: colorHex,
            agentFramework: .crewai,
            agentModel: spec.llm,
            agentRole: spec.role.isEmpty ? nil : spec.role,
            agentGoal: spec.goal.isEmpty ? nil : spec.goal,
            agentMaxIterations: spec.maxIter,
            agentCanDelegate: spec.allowDelegation
        )
    }

    // MARK: - Helpers

    private static func splitList(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        // Stored newline-joined by parseNestedYAML; also tolerate comma-separated.
        let parts = value.contains("\n")
            ? value.components(separatedBy: "\n")
            : value.components(separatedBy: ",")
        return parts.map { stripQuotes($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    private static func stripQuotes(_ s: String) -> String {
        var v = s
        if (v.hasPrefix("\"") && v.hasSuffix("\"")) ||
           (v.hasPrefix("'") && v.hasSuffix("'")), v.count >= 2 {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }

    /// Converts `snake_case` or `CamelCase` to `Title Case`.
    private static func humanise(_ name: String) -> String {
        if name.contains("_") || name.contains("-") {
            return name.split(whereSeparator: { $0 == "_" || $0 == "-" })
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        // CamelCase → spaced
        var result = ""
        for (idx, ch) in name.enumerated() {
            if idx > 0 && ch.isUppercase { result += " " }
            result.append(ch)
        }
        return result.isEmpty ? name : result.prefix(1).uppercased() + result.dropFirst()
    }

    private static func stringAssignmentValue(_ line: String) -> String? {
        // Matches `name: str = "value"` / `description = 'value'` etc.
        guard let eq = line.range(of: "=") else { return nil }
        let rhs = String(line[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
        let unquoted = stripQuotes(rhs)
        return unquoted.isEmpty ? nil : unquoted
    }

    private static func methodName(in block: String) -> String? {
        guard let defRange = block.range(of: "def ") else { return nil }
        let after = block[defRange.upperBound...]
        guard let paren = after.firstIndex(of: "(") else { return nil }
        let name = String(after[after.startIndex..<paren]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func balancedParens(_ s: String) -> Bool {
        var depth = 0
        for ch in s {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth -= 1 }
        }
        return depth <= 0
    }
}
