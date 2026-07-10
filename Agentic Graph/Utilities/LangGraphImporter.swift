import Foundation
import AppKit

// MARK: - LangGraph Importer

/// Imports a LangGraph project folder into an Agentic Graph document.
/// LangGraph has no config format — the graph lives in Python code — so this
/// parses `StateGraph` construction calls: `add_node`, `add_edge`, and
/// `add_conditional_edges`. Regular nodes become agent nodes; `ToolNode`
/// wrappers (or nodes named "tools" / "action") become tool nodes. `START`
/// and `END` are flow markers, not real nodes, so edges touching them are
/// dropped.
struct LangGraphImporter {

    // MARK: - Parsed Models

    struct NodeSpec {
        var name: String
        var isTool: Bool
        var detail: String          // docstring of the bound function, if found
    }

    struct EdgeSpec {
        var from: String
        var to: String
    }

    struct LangGraphImportResult {
        var document: GraphDocument?
        var error: String?
    }

    // MARK: - Public Entry Point

    static func importFolder(at url: URL) -> LangGraphImportResult {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else {
            return LangGraphImportResult(error: "Could not read folder contents.")
        }

        var pySources: [String] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "py",
               let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                pySources.append(content)
            }
        }

        guard !pySources.isEmpty else {
            return LangGraphImportResult(error: "No Python files found in this folder.")
        }

        // Build a function-name → docstring map across every file so node
        // functions defined separately from the graph can still be described.
        var docstrings: [String: String] = [:]
        for source in pySources {
            for (name, doc) in parseFunctionDocstrings(source) {
                if docstrings[name] == nil { docstrings[name] = doc }
            }
        }

        // Collect graph-construction calls from every file.
        var nodes: [String: NodeSpec] = [:]      // name → spec (preserves dedup)
        var nodeOrder: [String] = []
        var edges: [EdgeSpec] = []

        func ensureNode(_ name: String, isTool: Bool = false, detail: String = "") {
            if let existing = nodes[name] {
                // Upgrade to tool if any reference says so; keep first detail.
                if isTool && !existing.isTool {
                    nodes[name]?.isTool = true
                }
                if existing.detail.isEmpty && !detail.isEmpty {
                    nodes[name]?.detail = detail
                }
            } else {
                nodes[name] = NodeSpec(name: name, isTool: isTool, detail: detail)
                nodeOrder.append(name)
            }
        }

        for source in pySources {
            // add_node("name", fn)  /  add_node(fn)
            for args in extractCalls(in: source, method: "add_node") {
                guard !args.isEmpty else { continue }
                let nodeName: String
                let funcRef: String
                if args.count >= 2 {
                    nodeName = unquote(args[0])
                    funcRef = args[1]
                } else {
                    nodeName = unquote(args[0])
                    funcRef = args[0]
                }
                guard !nodeName.isEmpty, !isStart(nodeName), !isEnd(nodeName) else { continue }
                let isTool = funcRef.contains("ToolNode") ||
                    ["tools", "tool", "action"].contains(nodeName.lowercased())
                let funcName = identifierHead(funcRef)
                ensureNode(nodeName, isTool: isTool, detail: docstrings[funcName] ?? "")
            }

            // add_edge("a", "b")  /  add_edge(["a","b"], "c")
            for args in extractCalls(in: source, method: "add_edge") {
                guard args.count >= 2 else { continue }
                let sources = nodeRefList(args[0])
                let target = args[1]
                guard !isEnd(target) else { continue }
                for src in sources {
                    guard !isStart(src) else { continue }
                    let from = unquote(src)
                    let to = unquote(target)
                    if isStart(target) || isEnd(from) { continue }
                    edges.append(EdgeSpec(from: from, to: to))
                }
            }

            // add_conditional_edges("source", router, { "label": "dest", ... })
            for args in extractCalls(in: source, method: "add_conditional_edges") {
                guard args.count >= 1 else { continue }
                let sourceArg = args[0]
                guard !isStart(sourceArg), !isEnd(sourceArg) else { continue }
                let source = unquote(sourceArg)
                let destinations = args.count >= 3 ? pathMapDestinations(args[2]) : []
                for dest in destinations where !isStart(dest) && !isEnd(dest) {
                    edges.append(EdgeSpec(from: source, to: unquote(dest)))
                }
            }
        }

        guard !nodes.isEmpty else {
            return LangGraphImportResult(error: "No LangGraph nodes found. Expected a StateGraph with add_node calls.")
        }

        // Auto-create any node referenced by an edge but never add_node'd.
        for edge in edges {
            ensureNode(edge.from)
            ensureNode(edge.to)
        }

        let orderedNodes = nodeOrder.compactMap { nodes[$0] }
        let doc = buildGraph(nodes: orderedNodes, edges: edges, folderName: url.lastPathComponent)
        return LangGraphImportResult(document: doc)
    }

    // MARK: - Python Call Extraction

    /// Returns the top-level argument list for every `method(...)` call in `source`.
    private static func extractCalls(in source: String, method: String) -> [[String]] {
        var results: [[String]] = []
        let chars = Array(source)
        let needle = Array(method + "(")
        guard needle.count <= chars.count else { return [] }
        var i = 0
        while i <= chars.count - needle.count {
            if Array(chars[i..<i + needle.count]) == needle {
                let prevOK = i == 0 ||
                    !(chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
                if prevOK {
                    var depth = 0
                    var j = i + needle.count - 1   // points at the "("
                    var content = ""
                    var inString: Character? = nil
                    while j < chars.count {
                        let c = chars[j]
                        if let q = inString {
                            content.append(c)
                            if c == q { inString = nil }
                            j += 1
                            continue
                        }
                        if c == "\"" || c == "'" {
                            inString = c
                            if depth >= 1 { content.append(c) }
                            j += 1
                            continue
                        }
                        if c == "(" {
                            depth += 1
                            if depth == 1 { j += 1; continue }
                        }
                        if c == ")" {
                            depth -= 1
                            if depth == 0 { break }
                        }
                        content.append(c)
                        j += 1
                    }
                    results.append(splitTopLevelArgs(content))
                    i = j + 1
                    continue
                }
            }
            i += 1
        }
        return results
    }

    /// Splits a comma-separated argument string, respecting nested brackets and quotes.
    private static func splitTopLevelArgs(_ s: String) -> [String] {
        var args: [String] = []
        var current = ""
        var depth = 0
        var inString: Character? = nil
        for c in s {
            if let q = inString {
                current.append(c)
                if c == q { inString = nil }
                continue
            }
            if c == "\"" || c == "'" { inString = c; current.append(c); continue }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" { depth -= 1 }
            if c == "," && depth == 0 {
                args.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                continue
            }
            current.append(c)
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { args.append(last) }
        return args
    }

    /// Destination node names from a conditional-edge path map (`{...}` or `[...]`).
    private static func pathMapDestinations(_ arg: String) -> [String] {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let inner = String(trimmed.dropFirst().dropLast())
        let parts = splitTopLevelArgs(inner)
        if trimmed.hasPrefix("{") {
            // "label": dest  →  take the value side
            return parts.compactMap { part in
                let kv = splitTopLevelColon(part)
                return kv.count == 2 ? kv[1] : nil
            }
        } else if trimmed.hasPrefix("[") {
            return parts
        }
        return []
    }

    /// Splits a `key: value` pair at the top-level colon.
    private static func splitTopLevelColon(_ s: String) -> [String] {
        var depth = 0
        var inString: Character? = nil
        let chars = Array(s)
        for (idx, c) in chars.enumerated() {
            if let q = inString {
                if c == q { inString = nil }
                continue
            }
            if c == "\"" || c == "'" { inString = c; continue }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" { depth -= 1 }
            if c == ":" && depth == 0 {
                let key = String(chars[0..<idx]).trimmingCharacters(in: .whitespaces)
                let val = String(chars[(idx + 1)...]).trimmingCharacters(in: .whitespaces)
                return [key, val]
            }
        }
        return [s]
    }

    /// A node reference may be a single name or a list `["a", "b"]` (fan-in edge).
    private static func nodeRefList(_ arg: String) -> [String] {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return splitTopLevelArgs(String(trimmed.dropFirst().dropLast()))
        }
        return [trimmed]
    }

    // MARK: - Docstring Parsing

    private static func parseFunctionDocstrings(_ source: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = source.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("def "), let paren = trimmed.firstIndex(of: "(") {
                let name = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<paren])
                    .trimmingCharacters(in: .whitespaces)
                // Look for a docstring on the next non-empty line.
                var j = i + 1
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).isEmpty { j += 1 }
                if j < lines.count {
                    let doc = lines[j].trimmingCharacters(in: .whitespaces)
                    if doc.hasPrefix("\"\"\"") || doc.hasPrefix("'''") {
                        let quote = doc.hasPrefix("\"\"\"") ? "\"\"\"" : "'''"
                        let afterOpen = String(doc.dropFirst(3))
                        if let closeRange = afterOpen.range(of: quote) {
                            result[name] = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                        } else {
                            // Multi-line docstring — take the first content line.
                            var text = afterOpen.trimmingCharacters(in: .whitespaces)
                            var k = j + 1
                            while text.isEmpty && k < lines.count {
                                let l = lines[k].trimmingCharacters(in: .whitespaces)
                                if l.contains(quote) { break }
                                text = l
                                k += 1
                            }
                            result[name] = text
                        }
                    }
                }
            }
            i += 1
        }
        return result
    }

    // MARK: - Token Helpers

    private static func unquote(_ s: String) -> String {
        var v = s.trimmingCharacters(in: .whitespaces)
        if v.count >= 2, (v.hasPrefix("\"") && v.hasSuffix("\"")) ||
            (v.hasPrefix("'") && v.hasSuffix("'")) {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }

    private static func isStart(_ s: String) -> Bool {
        let a = unquote(s)
        return a == "START" || a.hasSuffix(".START") || a == "__start__"
    }

    private static func isEnd(_ s: String) -> Bool {
        let a = unquote(s)
        return a == "END" || a.hasSuffix(".END") || a == "__end__"
    }

    /// Leading identifier of an expression, e.g. `plan_research` from `plan_research`
    /// or `ToolNode` from `ToolNode(tools)`.
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

    private static func buildGraph(nodes: [NodeSpec], edges: [EdgeSpec],
                                    folderName: String) -> GraphDocument {
        let doc = GraphDocument()
        doc.projectName = humanise(folderName)

        var allNodes: [GraphNode] = []
        var indexByName: [String: Int] = [:]

        let agentColors = ["#4A90D9", "#E8A838", "#7B68EE", "#5BA55B", "#D95B5B",
                           "#D98BD9", "#5BC0DE", "#F0AD4E", "#8FBC8F", "#CD853F"]

        // Agent nodes first, then tool nodes — keeps the layout rows tidy.
        let agentSpecs = nodes.filter { !$0.isTool }
        let toolSpecs = nodes.filter { $0.isTool }

        for (idx, spec) in agentSpecs.enumerated() {
            let title = humanise(spec.name)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .agent,
                title: title,
                detail: spec.detail,
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                colorHex: agentColors[idx % agentColors.count],
                agentFramework: .langgraph
            )
            indexByName[spec.name] = allNodes.count
            allNodes.append(node)
        }

        for spec in toolSpecs {
            let title = humanise(spec.name)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .tool,
                title: title,
                detail: spec.detail,
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                toolType: .custom
            )
            indexByName[spec.name] = allNodes.count
            allNodes.append(node)
        }

        // Edges (deduped on the from→to pair).
        var seenPairs = Set<String>()
        var allEdges: [GraphEdge] = []
        for edge in edges {
            guard edge.from != edge.to else { continue }
            guard let srcIdx = indexByName[edge.from],
                  let dstIdx = indexByName[edge.to] else { continue }
            let pairKey = "\(edge.from)→\(edge.to)"
            guard seenPairs.insert(pairKey).inserted else { continue }
            let outPort = NodePort(label: humanise(edge.to), kind: .output)
            allNodes[srcIdx].ports.append(outPort)
            let inPort = NodePort(label: humanise(edge.from), kind: .input)
            allNodes[dstIdx].ports.append(inPort)
            allEdges.append(GraphEdge(
                sourceNodeID: allNodes[srcIdx].id, sourcePortID: outPort.id,
                targetNodeID: allNodes[dstIdx].id, targetPortID: inPort.id))
        }

        // Resize by port count.
        for i in allNodes.indices where !allNodes[i].ports.isEmpty {
            allNodes[i].size.height = nodeHeight(portCount: allNodes[i].ports.count)
        }

        // Layout: agent rows, then tool rows.
        let hGap: CGFloat = 40
        let vGap: CGFloat = 100
        var currentY: CGFloat = 100
        var rowMaxH: CGFloat = 0

        let agentIndices = Array(0..<agentSpecs.count)
        let toolIndices = Array(agentSpecs.count..<allNodes.count)

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
        let title = String(format: String(localized: "Imported from LangGraph: %@"), folderName)
        let detail = String(format: String(localized: "Agents: %lld, Tools: %lld, Edges: %lld"),
                            agentSpecs.count, toolSpecs.count, allEdges.count)
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
        if name.contains("_") || name.contains("-") {
            return name.split(whereSeparator: { $0 == "_" || $0 == "-" })
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
