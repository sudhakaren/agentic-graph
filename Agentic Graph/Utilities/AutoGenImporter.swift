import Foundation
import AppKit

// MARK: - AutoGen / AG2 Importer

/// Imports a Microsoft AutoGen (or AG2) project folder into an Agentic Graph
/// document. AutoGen has no config format — agents and group chats are Python
/// constructors — so this parses them:
/// - `AssistantAgent` / `ConversableAgent` / `GroupChatManager` → agent nodes
/// - `UserProxyAgent` → human nodes
/// - `GroupChat(agents=[…])` linked to a `GroupChatManager` → manager-to-member
///   edges; a 0.4 team (`RoundRobinGroupChat` / `SelectorGroupChat` / `Swarm`)
///   chains its participants
/// - `initiate_chat` calls → directed edges
/// - `tools=[…]` and `register_function(fn, caller=…)` → tool nodes + edges
struct AutoGenImporter {

    // MARK: - Parsed Models

    enum AgentKind { case agent, human, manager }

    struct AgentSpec {
        var variable: String
        var name: String
        var instructions: String
        var kind: AgentKind
        var groupChatVar: String?       // GroupChatManager(groupchat=…)
        var toolExprs: [String]
    }

    struct GroupChatSpec {
        var variable: String
        var agentVars: [String]
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

        var agents: [AgentSpec] = []
        var groupChats: [GroupChatSpec] = []
        var teams: [[String]] = []
        var chatEdges: [(from: String, to: String)] = []
        var registrations: [(tool: String, caller: String?)] = []
        var docstrings: [String: String] = [:]

        for source in pySources {
            agents.append(contentsOf: parseAgents(source))
            groupChats.append(contentsOf: parseGroupChats(source))
            teams.append(contentsOf: parseTeams(source))
            chatEdges.append(contentsOf: parseInitiateChats(source))
            registrations.append(contentsOf: parseRegisterFunctions(source))
            for (name, doc) in parseFunctionDocstrings(source) where docstrings[name] == nil {
                docstrings[name] = doc
            }
        }

        guard !agents.isEmpty else {
            return ImportResult(error: "No AutoGen agents found. Expected AssistantAgent / UserProxyAgent / GroupChatManager definitions.")
        }

        let doc = buildGraph(agents: agents, groupChats: groupChats, teams: teams,
                             chatEdges: chatEdges, registrations: registrations,
                             docstrings: docstrings, folderName: url.lastPathComponent)
        return ImportResult(document: doc)
    }

    // MARK: - Agent / Construct Parsing

    private static let agentClasses: [(name: String, kind: AgentKind)] = [
        ("AssistantAgent", .agent),
        ("UserProxyAgent", .human),
        ("GroupChatManager", .manager),
        ("ConversableAgent", .agent),
        ("RetrieveUserProxyAgent", .human),
    ]

    private static func parseAgents(_ source: String) -> [AgentSpec] {
        var specs: [AgentSpec] = []
        let chars = Array(source)
        for (className, kind) in agentClasses {
            for (variable, args) in assignedCalls(chars, callee: className) {
                guard let variable else { continue }
                specs.append(makeAgentSpec(variable: variable, args: args, kind: kind))
            }
        }
        return specs
    }

    private static func makeAgentSpec(variable: String, args: String, kind: AgentKind) -> AgentSpec {
        var spec = AgentSpec(variable: variable, name: variable, instructions: "",
                             kind: kind, groupChatVar: nil, toolExprs: [])
        var positionalIndex = 0
        for arg in splitArgs(args) {
            if let (key, value) = splitKwarg(arg) {
                switch key {
                case "name":
                    if let s = stringLiteralValue(value) { spec.name = s }
                case "system_message":
                    if let s = stringLiteralValue(value) { spec.instructions = s }
                case "groupchat":
                    spec.groupChatVar = identifierHead(value)
                case "tools", "functions":
                    spec.toolExprs = extractList(value)
                default:
                    break
                }
            } else {
                // First positional string literal is the agent name.
                if positionalIndex == 0, let s = stringLiteralValue(arg) {
                    spec.name = s
                }
                positionalIndex += 1
            }
        }
        return spec
    }

    private static func parseGroupChats(_ source: String) -> [GroupChatSpec] {
        var specs: [GroupChatSpec] = []
        let chars = Array(source)
        for (variable, args) in assignedCalls(chars, callee: "GroupChat") {
            guard let variable else { continue }
            var agentVars: [String] = []
            for arg in splitArgs(args) {
                if let (key, value) = splitKwarg(arg), key == "agents" {
                    agentVars = extractList(value).map { identifierHead($0) }
                }
            }
            specs.append(GroupChatSpec(variable: variable, agentVars: agentVars))
        }
        return specs
    }

    /// 0.4-style teams take their participants as the first positional list arg
    /// (or a `participants=` / `agents=` keyword).
    private static func parseTeams(_ source: String) -> [[String]] {
        var teams: [[String]] = []
        let chars = Array(source)
        for className in ["RoundRobinGroupChat", "SelectorGroupChat", "Swarm", "MagenticOneGroupChat"] {
            for (_, args) in assignedCalls(chars, callee: className) {
                var members: [String] = []
                for (idx, arg) in splitArgs(args).enumerated() {
                    if let (key, value) = splitKwarg(arg) {
                        if key == "participants" || key == "agents" {
                            members = extractList(value).map { identifierHead($0) }
                        }
                    } else if idx == 0 {
                        members = extractList(arg).map { identifierHead($0) }
                    }
                }
                if !members.isEmpty { teams.append(members) }
            }
        }
        return teams
    }

    /// `<receiver>.initiate_chat(<target>, …)` → directed edge receiver → target.
    private static func parseInitiateChats(_ source: String) -> [(from: String, to: String)] {
        var edges: [(String, String)] = []
        let chars = Array(source)
        let needle = Array("initiate_chat(")
        guard needle.count <= chars.count else { return [] }
        var i = 0
        while i <= chars.count - needle.count {
            guard Array(chars[i..<i + needle.count]) == needle else { i += 1; continue }
            // Receiver: identifier immediately before ".initiate_chat".
            var k = i - 1
            guard k >= 0, chars[k] == "." else { i += 1; continue }
            k -= 1
            var recv: [Character] = []
            while k >= 0, chars[k].isLetter || chars[k].isNumber || chars[k] == "_" {
                recv.insert(chars[k], at: 0); k -= 1
            }
            let receiver = String(recv)
            let (content, end) = balancedContent(chars, openParen: i + needle.count - 1)
            let args = splitArgs(content)
            if !receiver.isEmpty, let first = args.first {
                // The target may be positional or `recipient=`.
                let target: String
                if let (key, value) = splitKwarg(first), key == "recipient" {
                    target = identifierHead(value)
                } else {
                    target = identifierHead(first)
                }
                if !target.isEmpty { edges.append((receiver, target)) }
            }
            i = end
        }
        return edges
    }

    /// `register_function(fn, caller=agent, …)` → tool `fn` used by `caller`.
    private static func parseRegisterFunctions(_ source: String) -> [(tool: String, caller: String?)] {
        var result: [(String, String?)] = []
        let chars = Array(source)
        let needle = Array("register_function(")
        guard needle.count <= chars.count else { return [] }
        var i = 0
        while i <= chars.count - needle.count {
            guard Array(chars[i..<i + needle.count]) == needle else { i += 1; continue }
            let prevOK = i == 0 ||
                !(chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
            guard prevOK else { i += 1; continue }
            let (content, end) = balancedContent(chars, openParen: i + needle.count - 1)
            let args = splitArgs(content)
            var tool: String?
            var caller: String?
            for (idx, arg) in args.enumerated() {
                if let (key, value) = splitKwarg(arg) {
                    if key == "caller" { caller = identifierHead(value) }
                    if key == "function" { tool = identifierHead(value) }
                } else if idx == 0 {
                    tool = identifierHead(arg)
                }
            }
            if let tool, !tool.isEmpty { result.append((tool, caller)) }
            i = end
        }
        return result
    }

    private static func parseFunctionDocstrings(_ source: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = source.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("def "), let paren = trimmed.firstIndex(of: "(") {
                let name = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<paren])
                    .trimmingCharacters(in: .whitespaces)
                var j = i + 1
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).isEmpty { j += 1 }
                if j < lines.count {
                    let doc = lines[j].trimmingCharacters(in: .whitespaces)
                    if doc.hasPrefix("\"\"\"") || doc.hasPrefix("'''") {
                        let q = doc.hasPrefix("\"\"\"") ? "\"\"\"" : "'''"
                        let afterOpen = String(doc.dropFirst(3))
                        if let close = afterOpen.range(of: q) {
                            result[name] = String(afterOpen[afterOpen.startIndex..<close.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                        } else {
                            result[name] = afterOpen.trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
            i += 1
        }
        return result
    }

    // MARK: - Call Extraction

    /// Finds every `<var> = [module.]callee(...)` call, returning the assigned
    /// variable (if any) and the raw argument string.
    private static func assignedCalls(_ chars: [Character], callee: String) -> [(String?, String)] {
        var results: [(String?, String)] = []
        let needle = Array(callee + "(")
        guard needle.count <= chars.count else { return [] }
        var i = 0
        while i <= chars.count - needle.count {
            guard Array(chars[i..<i + needle.count]) == needle else { i += 1; continue }
            let prevOK = i == 0 ||
                !(chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
            guard prevOK else { i += 1; continue }
            let variable = precedingAssignedVar(chars, classStart: i)
            let (content, end) = balancedContent(chars, openParen: i + needle.count - 1)
            results.append((variable, content))
            i = end
        }
        return results
    }

    /// Scans backward for an `<identifier> =` assignment, skipping an optional
    /// `module.` (possibly multi-level) qualifier before the class name.
    private static func precedingAssignedVar(_ chars: [Character], classStart: Int) -> String? {
        var k = classStart - 1
        func skipWS() {
            while k >= 0, chars[k] == " " || chars[k] == "\t" || chars[k] == "\n" { k -= 1 }
        }
        skipWS()
        while k >= 0, chars[k] == "." {
            k -= 1
            skipWS()
            while k >= 0, chars[k].isLetter || chars[k].isNumber || chars[k] == "_" { k -= 1 }
            skipWS()
        }
        guard k >= 0, chars[k] == "=", k == 0 || chars[k - 1] != "=" else { return nil }
        k -= 1
        skipWS()
        var nameChars: [Character] = []
        while k >= 0, chars[k].isLetter || chars[k].isNumber || chars[k] == "_" {
            nameChars.insert(chars[k], at: 0); k -= 1
        }
        let name = String(nameChars)
        return name.isEmpty ? nil : name
    }

    // MARK: - Python Tokenising Helpers

    private static func skipString(_ chars: [Character], _ start: Int) -> Int {
        let q = chars[start]
        let isTriple = start + 2 < chars.count && chars[start + 1] == q && chars[start + 2] == q
        if isTriple {
            var i = start + 3
            while i < chars.count {
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
                if depth == 0 && c == ")" { return (String(out.dropFirst()), i + 1) }
            }
            out.append(c)
            i += 1
        }
        return (String(out.dropFirst()), i)
    }

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

    private static func extractList(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return [] }
        return splitArgs(String(trimmed.dropFirst().dropLast()))
    }

    private static func stringLiteralValue(_ value: String) -> String? {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("(") && v.hasSuffix(")") {
            v = String(v.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let chars = Array(v)
        guard let first = chars.first, first == "\"" || first == "'" else { return nil }
        var pieces: [String] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                let end = skipString(chars, i)
                pieces.append(stripQuotes(String(chars[i..<min(end, chars.count)])))
                i = end
            } else if c == " " || c == "\n" || c == "\t" || c == "\r" {
                i += 1
            } else {
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

    private static func buildGraph(agents: [AgentSpec], groupChats: [GroupChatSpec],
                                    teams: [[String]], chatEdges: [(from: String, to: String)],
                                    registrations: [(tool: String, caller: String?)],
                                    docstrings: [String: String], folderName: String) -> GraphDocument {
        let doc = GraphDocument()
        doc.projectName = humanise(folderName)

        var allNodes: [GraphNode] = []
        var agentIndexByVar: [String: Int] = [:]
        var toolIndexByKey: [String: Int] = [:]

        let agentColors = ["#4A90D9", "#E8A838", "#7B68EE", "#5BA55B", "#D95B5B",
                           "#D98BD9", "#5BC0DE", "#F0AD4E", "#8FBC8F", "#CD853F"]

        // Agent / human nodes.
        var colorIdx = 0
        for agent in agents {
            let title = humanise(agent.name)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node: GraphNode
            if agent.kind == .human {
                node = GraphNode(
                    kind: .human,
                    title: title,
                    detail: agent.instructions,
                    position: .zero,
                    size: CGSize(width: w, height: 80),
                    ports: []
                )
            } else {
                node = GraphNode(
                    kind: .agent,
                    title: title,
                    detail: "",
                    position: .zero,
                    size: CGSize(width: w, height: 80),
                    ports: [],
                    colorHex: agentColors[colorIdx % agentColors.count],
                    agentFramework: .autogen,
                    agentInstructions: agent.instructions.isEmpty ? nil : agent.instructions,
                    agentCanDelegate: agent.kind == .manager
                )
                colorIdx += 1
            }
            agentIndexByVar[agent.variable] = allNodes.count
            allNodes.append(node)
        }

        // Resolve tool references: tools=[…] on agents + register_function calls.
        var toolOrder: [String] = []
        var agentToolPairs: [(agent: String, tool: String)] = []

        func noteTool(_ key: String) {
            guard !key.isEmpty else { return }
            if !toolOrder.contains(key) { toolOrder.append(key) }
        }
        for agent in agents {
            for expr in agent.toolExprs {
                let key = identifierHead(expr)
                noteTool(key)
                agentToolPairs.append((agent.variable, key))
            }
        }
        for reg in registrations {
            noteTool(reg.tool)
            if let caller = reg.caller, !caller.isEmpty {
                agentToolPairs.append((caller, reg.tool))
            }
        }

        for key in toolOrder {
            let title = humanise(key)
            let w = max(200, GraphNode.idealWidth(for: title))
            let node = GraphNode(
                kind: .tool,
                title: title,
                detail: docstrings[key] ?? "",
                position: .zero,
                size: CGSize(width: w, height: 80),
                ports: [],
                toolType: .python
            )
            toolIndexByKey[key] = allNodes.count
            allNodes.append(node)
        }

        // Edges.
        var allEdges: [GraphEdge] = []
        var seenPairs = Set<String>()

        func addEdge(_ fromVarOrKey: String, _ toVarOrKey: String,
                     fromIdx: Int, toIdx: Int) {
            guard fromIdx != toIdx else { return }
            let pairKey = "\(fromVarOrKey)→\(toVarOrKey)"
            guard seenPairs.insert(pairKey).inserted else { return }
            let outPort = NodePort(label: humanise(toVarOrKey), kind: .output)
            allNodes[fromIdx].ports.append(outPort)
            let inPort = NodePort(label: humanise(fromVarOrKey), kind: .input)
            allNodes[toIdx].ports.append(inPort)
            allEdges.append(GraphEdge(
                sourceNodeID: allNodes[fromIdx].id, sourcePortID: outPort.id,
                targetNodeID: allNodes[toIdx].id, targetPortID: inPort.id))
        }

        // GroupChat: a manager points to its group chat → manager → each member.
        var claimedGroupChats = Set<String>()
        for agent in agents where agent.kind == .manager {
            guard let gcVar = agent.groupChatVar,
                  let gc = groupChats.first(where: { $0.variable == gcVar }),
                  let mgrIdx = agentIndexByVar[agent.variable] else { continue }
            claimedGroupChats.insert(gcVar)
            for memberVar in gc.agentVars {
                guard let memberIdx = agentIndexByVar[memberVar] else { continue }
                addEdge(agent.variable, memberVar, fromIdx: mgrIdx, toIdx: memberIdx)
            }
        }
        // Unclaimed group chats → chain members.
        for gc in groupChats where !claimedGroupChats.contains(gc.variable) {
            chainAgents(gc.agentVars, agentIndexByVar: agentIndexByVar, addEdge: addEdge)
        }
        // 0.4 teams → chain participants.
        for team in teams {
            chainAgents(team, agentIndexByVar: agentIndexByVar, addEdge: addEdge)
        }
        // initiate_chat → directed edges.
        for edge in chatEdges {
            guard let fromIdx = agentIndexByVar[edge.from],
                  let toIdx = agentIndexByVar[edge.to] else { continue }
            addEdge(edge.from, edge.to, fromIdx: fromIdx, toIdx: toIdx)
        }
        // Agent → tool edges.
        for pair in agentToolPairs {
            guard let agentIdx = agentIndexByVar[pair.agent],
                  let toolIdx = toolIndexByKey[pair.tool] else { continue }
            addEdge(pair.agent, pair.tool, fromIdx: agentIdx, toIdx: toolIdx)
        }

        // Resize by port count.
        for i in allNodes.indices where !allNodes[i].ports.isEmpty {
            allNodes[i].size.height = nodeHeight(portCount: allNodes[i].ports.count)
        }

        // Layout: agent/human rows, then tool rows.
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
        let title = String(format: String(localized: "Imported from AutoGen: %@"), folderName)
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

    private static func chainAgents(_ vars: [String], agentIndexByVar: [String: Int],
                                     addEdge: (String, String, Int, Int) -> Void) {
        guard vars.count > 1 else { return }
        for i in 0..<(vars.count - 1) {
            guard let fromIdx = agentIndexByVar[vars[i]],
                  let toIdx = agentIndexByVar[vars[i + 1]] else { continue }
            addEdge(vars[i], vars[i + 1], fromIdx, toIdx)
        }
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
