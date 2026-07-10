import Foundation
import AppKit

// MARK: - OpenAI Agents SDK Importer

/// Imports an OpenAI Agents SDK project folder into an Agentic Graph document.
/// The SDK has no config format — agents are Python `Agent(...)` constructors —
/// so this parses those calls. `handoffs=[...]` becomes agent-to-agent edges,
/// `tools=[...]` becomes tool nodes, and `<agent>.as_tool(...)` references
/// become agent-to-agent edges (an agent used as another agent's tool).
struct OpenAIAgentsImporter {

    // MARK: - Parsed Models

    struct AgentSpec {
        var variable: String              // Python variable, e.g. "triage_agent"
        var name: String                  // display name from name=
        var instructions: String
        var model: String
        var handoffDescription: String
        var handoffVars: [String]         // variable names of handoff targets
        var toolExprs: [String]           // raw expressions from tools=[...]
    }

    struct ImportResult {
        var document: GraphDocument?
        var error: String?
    }

    // MARK: - Public Entry Point

    static func importFolder(at url: URL) -> ImportResult {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else {
            return ImportResult(error: "Could not read folder contents.")
        }

        var pySources: [String] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "py",
               let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                pySources.append(content)
            }
        }
        guard !pySources.isEmpty else {
            return ImportResult(error: "No Python files found in this folder.")
        }

        // Collect agent definitions and @function_tool docstrings across files.
        var agents: [AgentSpec] = []
        var functionToolDocs: [String: String] = [:]
        for source in pySources {
            agents.append(contentsOf: parseAgents(source))
            for (name, doc) in parseFunctionTools(source) where functionToolDocs[name] == nil {
                functionToolDocs[name] = doc
            }
        }

        guard !agents.isEmpty else {
            return ImportResult(error: "No OpenAI Agents SDK agents found. Expected Python Agent(name=…) definitions.")
        }

        let doc = buildGraph(agents: agents, functionToolDocs: functionToolDocs,
                             folderName: url.lastPathComponent)
        return ImportResult(document: doc)
    }

    // MARK: - Agent Parsing

    /// Finds every `<var> = Agent(...)` definition in a source file.
    private static func parseAgents(_ source: String) -> [AgentSpec] {
        var specs: [AgentSpec] = []
        let chars = Array(source)
        let needle = Array("Agent(")
        guard needle.count <= chars.count else { return [] }
        var i = 0
        while i <= chars.count - needle.count {
            guard Array(chars[i..<i + needle.count]) == needle else { i += 1; continue }
            let prevOK = i == 0 ||
                !(chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
            guard prevOK else { i += 1; continue }

            // Backward scan for "<identifier> =".
            var k = i - 1
            while k >= 0, chars[k] == " " || chars[k] == "\t" || chars[k] == "\n" { k -= 1 }
            guard k >= 0, chars[k] == "=", k == 0 || chars[k - 1] != "=" else { i += 1; continue }
            k -= 1
            while k >= 0, chars[k] == " " || chars[k] == "\t" || chars[k] == "\n" { k -= 1 }
            var nameChars: [Character] = []
            while k >= 0, chars[k].isLetter || chars[k].isNumber || chars[k] == "_" {
                nameChars.insert(chars[k], at: 0)
                k -= 1
            }
            let variable = String(nameChars)
            guard !variable.isEmpty else { i += 1; continue }

            let (content, end) = balancedContent(chars, openParen: i + needle.count - 1)
            specs.append(makeAgentSpec(variable: variable, args: content))
            i = end
        }
        return specs
    }

    private static func makeAgentSpec(variable: String, args: String) -> AgentSpec {
        var spec = AgentSpec(variable: variable, name: variable, instructions: "",
                             model: "", handoffDescription: "", handoffVars: [], toolExprs: [])
        for arg in splitArgs(args) {
            guard let (key, value) = splitKwarg(arg) else { continue }
            switch key {
            case "name":
                if let s = stringLiteralValue(value) { spec.name = s }
            case "instructions":
                if let s = stringLiteralValue(value) { spec.instructions = s }
            case "model":
                if let s = stringLiteralValue(value) { spec.model = s }
            case "handoff_description":
                if let s = stringLiteralValue(value) { spec.handoffDescription = s }
            case "handoffs":
                spec.handoffVars = extractList(value).map { handoffTargetVar($0) }
            case "tools":
                spec.toolExprs = extractList(value)
            default:
                break
            }
        }
        return spec
    }

    /// A handoff entry is either a bare agent variable or `handoff(agent, ...)`.
    private static func handoffTargetVar(_ expr: String) -> String {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("handoff(") {
            let inner = String(trimmed.dropFirst("handoff(".count).dropLast())
            return identifierHead(splitArgs(inner).first ?? "")
        }
        return identifierHead(trimmed)
    }

    // MARK: - Function Tool Parsing

    /// Maps `@function_tool`-decorated function names → first docstring line.
    private static func parseFunctionTools(_ source: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = source.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@function_tool") {
                var j = i + 1
                while j < lines.count {
                    let defLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if defLine.hasPrefix("def "), let paren = defLine.firstIndex(of: "(") {
                        let name = String(defLine[defLine.index(defLine.startIndex, offsetBy: 4)..<paren])
                            .trimmingCharacters(in: .whitespaces)
                        var doc = ""
                        if j + 1 < lines.count {
                            let docLine = lines[j + 1].trimmingCharacters(in: .whitespaces)
                            if docLine.hasPrefix("\"\"\"") || docLine.hasPrefix("'''") {
                                let q = docLine.hasPrefix("\"\"\"") ? "\"\"\"" : "'''"
                                doc = docLine.replacingOccurrences(of: q, with: "")
                                    .trimmingCharacters(in: .whitespaces)
                            }
                        }
                        result[name] = doc
                        break
                    }
                    // Stop if we hit a blank gap with no def.
                    if !defLine.isEmpty && !defLine.hasPrefix("@") && !defLine.hasPrefix("def ") { break }
                    j += 1
                }
            }
            i += 1
        }
        return result
    }

    // MARK: - Python Tokenising Helpers

    /// Returns the index just past a string literal that starts at `chars[start]`.
    /// Handles single, double, and triple quotes plus backslash escapes.
    private static func skipString(_ chars: [Character], _ start: Int) -> Int {
        let q = chars[start]
        let isTriple = start + 2 < chars.count && chars[start + 1] == q && chars[start + 2] == q
        if isTriple {
            var i = start + 3
            while i + 2 < chars.count + 1 && i < chars.count {
                if chars[i] == q, i + 2 < chars.count, chars[i + 1] == q, chars[i + 2] == q {
                    return i + 3
                }
                i += 1
            }
            return chars.count
        }
        var i = start + 1
        while i < chars.count {
            if chars[i] == "\\" { i += 2; continue }
            if chars[i] == q { return i + 1 }
            i += 1
        }
        return chars.count
    }

    /// Given `chars[openParen] == "("`, returns the content between the matching
    /// parens and the index just past the closing `)`.
    private static func balancedContent(_ chars: [Character], openParen: Int) -> (String, Int) {
        var depth = 0
        var i = openParen
        var out: [Character] = []
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                let end = skipString(chars, i)
                out.append(contentsOf: chars[i..<min(end, chars.count)])
                i = end
                continue
            }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" {
                depth -= 1
                if depth == 0 && c == ")" {
                    return (String(out.dropFirst()), i + 1)
                }
            }
            out.append(c)
            i += 1
        }
        return (String(out.dropFirst()), i)
    }

    /// Splits a comma-separated list at the top level, ignoring commas inside
    /// nested brackets or string literals.
    private static func splitArgs(_ s: String) -> [String] {
        let chars = Array(s)
        var args: [String] = []
        var cur: [Character] = []
        var depth = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                let end = skipString(chars, i)
                cur.append(contentsOf: chars[i..<min(end, chars.count)])
                i = end
                continue
            }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" { depth -= 1 }
            if c == "," && depth == 0 {
                args.append(String(cur).trimmingCharacters(in: .whitespacesAndNewlines))
                cur = []
                i += 1
                continue
            }
            cur.append(c)
            i += 1
        }
        let last = String(cur).trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { args.append(last) }
        return args
    }

    /// Splits a `key=value` keyword argument at the top-level `=`.
    private static func splitKwarg(_ arg: String) -> (key: String, value: String)? {
        let chars = Array(arg)
        var depth = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" { i = skipString(chars, i); continue }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" { depth -= 1 }
            if c == "=" && depth == 0 {
                let prev = i > 0 ? chars[i - 1] : " "
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if prev != "=" && prev != "!" && prev != "<" && prev != ">" && prev != ":" && next != "=" {
                    let key = String(chars[0..<i]).trimmingCharacters(in: .whitespaces)
                    let value = String(chars[(i + 1)...]).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                        return (key, value)
                    }
                }
            }
            i += 1
        }
        return nil
    }

    /// Strips `[...]` and returns the top-level elements.
    private static func extractList(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return [] }
        return splitArgs(String(trimmed.dropFirst().dropLast()))
    }

    /// Returns the literal text of a Python string value, or nil if it is not a
    /// string literal. Handles triple quotes and parenthesised implicit concat.
    private static func stringLiteralValue(_ value: String) -> String? {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Unwrap a parenthesised group: instructions=( "a" "b" )
        if v.hasPrefix("(") && v.hasSuffix(")") {
            v = String(v.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let chars = Array(v)
        guard let first = chars.first, first == "\"" || first == "'" else { return nil }

        // Concatenate one or more adjacent string literals.
        var pieces: [String] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                let end = skipString(chars, i)
                let literal = Array(chars[i..<min(end, chars.count)])
                pieces.append(stripQuotes(String(literal)))
                i = end
            } else if c == " " || c == "\n" || c == "\t" || c == "\r" {
                i += 1
            } else {
                // Non-string token — not a pure string literal value.
                return pieces.isEmpty ? nil : pieces.joined()
            }
        }
        return pieces.isEmpty ? nil : pieces.joined()
    }

    private static func stripQuotes(_ s: String) -> String {
        var v = s
        for triple in ["\"\"\"", "'''"] {
            if v.hasPrefix(triple) && v.hasSuffix(triple) && v.count >= 6 {
                return String(v.dropFirst(3).dropLast(3))
            }
        }
        if v.count >= 2, (v.hasPrefix("\"") && v.hasSuffix("\"")) ||
            (v.hasPrefix("'") && v.hasSuffix("'")) {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }

    /// Leading identifier of an expression: `get_weather` from `get_weather`,
    /// `WebSearchTool` from `WebSearchTool()`, `faq_agent` from `faq_agent.as_tool()`.
    private static func identifierHead(_ expr: String) -> String {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }))
    }

    // MARK: - Graph Construction

    private static let portRowHeight: CGFloat = 22
    private static let nodeTitleHeight: CGFloat = 40

    private static func nodeHeight(portCount: Int) -> CGFloat {
        max(80, nodeTitleHeight + CGFloat(portCount) * portRowHeight + 10)
    }

    private static func buildGraph(agents: [AgentSpec], functionToolDocs: [String: String],
                                    folderName: String) -> GraphDocument {
        let doc = GraphDocument()
        doc.projectName = humanise(folderName)

        var allNodes: [GraphNode] = []
        var agentIndexByVar: [String: Int] = [:]
        var toolIndexByKey: [String: Int] = [:]

        let agentColors = ["#4A90D9", "#E8A838", "#7B68EE", "#5BA55B", "#D95B5B",
                           "#D98BD9", "#5BC0DE", "#F0AD4E", "#8FBC8F", "#CD853F"]

        // Agent nodes.
        for (idx, agent) in agents.enumerated() {
            let title = humanise(agent.name)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .agent,
                title: title,
                detail: agent.handoffDescription,
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                colorHex: agentColors[idx % agentColors.count],
                agentFramework: .openaiAgents,
                agentModel: agent.model.isEmpty ? nil : agent.model,
                agentInstructions: agent.instructions.isEmpty ? nil : agent.instructions,
                agentCanDelegate: !agent.handoffVars.isEmpty
            )
            agentIndexByVar[agent.variable] = allNodes.count
            allNodes.append(node)
        }

        // Resolve tool expressions. A tool is either a function/hosted tool, or
        // another agent referenced via `.as_tool(...)`.
        struct ResolvedTool { var key: String; var isFunction: Bool }
        var agentToolKeys: [String: [String]] = [:]      // agent var → tool keys
        var agentAsToolEdges: [(from: String, to: String)] = []
        var toolMeta: [String: ResolvedTool] = [:]

        for agent in agents {
            for expr in agent.toolExprs {
                let trimmed = expr.trimmingCharacters(in: .whitespaces)
                let head = identifierHead(trimmed)
                if trimmed.contains(".as_tool"), agentIndexByVar[head] != nil {
                    agentAsToolEdges.append((from: agent.variable, to: head))
                    continue
                }
                let isFunction = functionToolDocs[head] != nil
                toolMeta[head] = ResolvedTool(key: head, isFunction: isFunction)
                agentToolKeys[agent.variable, default: []].append(head)
            }
        }

        // Tool nodes (deduped, in first-seen order).
        var toolOrder: [String] = []
        for agent in agents {
            for key in agentToolKeys[agent.variable] ?? [] where !toolOrder.contains(key) {
                toolOrder.append(key)
            }
        }
        for key in toolOrder {
            let isFunction = toolMeta[key]?.isFunction ?? false
            let title = humanise(key)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .tool,
                title: title,
                detail: functionToolDocs[key] ?? "",
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                toolType: isFunction ? .python : .openai
            )
            toolIndexByKey[key] = allNodes.count
            allNodes.append(node)
        }

        // Edges.
        var allEdges: [GraphEdge] = []
        var seenPairs = Set<String>()

        func addEdge(fromIdx: Int, toIdx: Int, fromLabel: String, toLabel: String, pairKey: String) {
            guard seenPairs.insert(pairKey).inserted else { return }
            let outPort = NodePort(label: toLabel, kind: .output)
            allNodes[fromIdx].ports.append(outPort)
            let inPort = NodePort(label: fromLabel, kind: .input)
            allNodes[toIdx].ports.append(inPort)
            allEdges.append(GraphEdge(
                sourceNodeID: allNodes[fromIdx].id, sourcePortID: outPort.id,
                targetNodeID: allNodes[toIdx].id, targetPortID: inPort.id))
        }

        // Handoff edges (agent → agent).
        for agent in agents {
            guard let srcIdx = agentIndexByVar[agent.variable] else { continue }
            for targetVar in agent.handoffVars {
                guard targetVar != agent.variable,
                      let dstIdx = agentIndexByVar[targetVar] else { continue }
                addEdge(fromIdx: srcIdx, toIdx: dstIdx,
                        fromLabel: humanise(agent.variable), toLabel: humanise(targetVar),
                        pairKey: "h:\(agent.variable)→\(targetVar)")
            }
        }
        // Agent-as-tool edges (agent → agent).
        for edge in agentAsToolEdges {
            guard edge.from != edge.to,
                  let srcIdx = agentIndexByVar[edge.from],
                  let dstIdx = agentIndexByVar[edge.to] else { continue }
            addEdge(fromIdx: srcIdx, toIdx: dstIdx,
                    fromLabel: humanise(edge.from), toLabel: humanise(edge.to),
                    pairKey: "h:\(edge.from)→\(edge.to)")
        }
        // Tool edges (agent → tool).
        for agent in agents {
            guard let srcIdx = agentIndexByVar[agent.variable] else { continue }
            for key in agentToolKeys[agent.variable] ?? [] {
                guard let toolIdx = toolIndexByKey[key] else { continue }
                addEdge(fromIdx: srcIdx, toIdx: toolIdx,
                        fromLabel: humanise(agent.variable), toLabel: humanise(key),
                        pairKey: "t:\(agent.variable)→\(key)")
            }
        }

        // Resize by port count.
        for i in allNodes.indices where !allNodes[i].ports.isEmpty {
            allNodes[i].size.height = nodeHeight(portCount: allNodes[i].ports.count)
        }

        // Layout: agent rows, tool rows.
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

        let topY = allNodes.map { $0.position.y - $0.size.height / 2 }.min() ?? 100
        let title = String(format: String(localized: "Imported from OpenAI Agents SDK: %@"), folderName)
        let detail = String(format: String(localized: "Agents: %lld, Tools: %lld, Edges: %lld"),
                            agents.count, toolIndices.count, allEdges.count)
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

    /// Converts `snake_case` or `CamelCase` to `Title Case`.
    private static func humanise(_ name: String) -> String {
        if name.contains("_") || name.contains("-") || name.contains(" ") {
            return name.split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " })
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        var result = ""
        for (idx, ch) in name.enumerated() {
            if idx > 0 && ch.isUppercase { result += " " }
            result.append(ch)
        }
        return result.isEmpty ? name : result.prefix(1).uppercased() + result.dropFirst()
    }
}
