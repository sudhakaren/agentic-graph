import Foundation
import AppKit

/// Re-imports a watsonx Orchestrate project into an existing graph: matched
/// nodes have their imported fields refreshed, new nodes are added, nodes no
/// longer present in the source are removed, and edges among the imported
/// subgraph are re-derived. A version snapshot is taken before any change.
enum WxOMerge {

    struct Summary {
        var updated = 0
        var added = 0
        var removed = 0
    }

    // MARK: - Merge

    static func merge(incoming: GraphDocument, into doc: GraphDocument,
                      sourceName: String) -> Summary {
        // Snapshot first, so the user can compare against or revert to the
        // pre-merge state from File ▸ Versions.
        doc.createVersion(
            name: String(localized: "Before wxO merge"),
            note: String(localized: "Automatic snapshot taken before merging \(sourceName)")
        )

        var summary = Summary()

        // Incoming managed nodes — agents/tools/knowledge carry an importSourceKey;
        // the importer's comment node does not and is ignored.
        let incomingManaged = incoming.nodes.filter { $0.importSourceKey != nil }
        let incomingKeys = Set(incomingManaged.compactMap { $0.importSourceKey })

        // Existing keyed nodes indexed by key.
        var existingIndexByKey: [String: Int] = [:]
        for (i, n) in doc.nodes.enumerated() {
            if let k = n.importSourceKey { existingIndexByKey[k] = i }
        }

        // Match each incoming managed node to a doc-node index — by key, then by
        // kind+title adoption (for graphs imported before keys existed).
        var matchIndex: [UUID: Int] = [:]
        var adopted: Set<Int> = []
        for inNode in incomingManaged {
            let key = inNode.importSourceKey!
            if let idx = existingIndexByKey[key] {
                matchIndex[inNode.id] = idx
            } else if let idx = adoptIndex(for: inNode, in: doc.nodes, claimed: adopted) {
                adopted.insert(idx)
                matchIndex[inNode.id] = idx
            }
        }
        let matchedIndices = Set(matchIndex.values)

        // Existing keyed nodes whose key is gone from the source → delete.
        var deletedIndices: Set<Int> = []
        for (i, n) in doc.nodes.enumerated() {
            if let k = n.importSourceKey, !incomingKeys.contains(k) {
                deletedIndices.insert(i)
            }
        }
        let deletedIDs = Set(deletedIndices.map { doc.nodes[$0].id })

        // Doc-node IDs that are "managed" after the merge: matched/adopted
        // existing nodes + brand-new incoming nodes.
        var managedDocIDs: Set<UUID> = []
        for inNode in incomingManaged {
            if let idx = matchIndex[inNode.id] {
                managedDocIDs.insert(doc.nodes[idx].id)
            } else {
                managedDocIDs.insert(inNode.id)
            }
        }

        // Keep existing edges that aren't wxO-derived and don't touch a deleted
        // node. wxO edges (both endpoints managed) are re-derived from the source.
        var keptUserEdges: [GraphEdge] = []
        for e in doc.edges {
            if deletedIDs.contains(e.sourceNodeID) || deletedIDs.contains(e.targetNodeID) {
                continue
            }
            let bothManaged = managedDocIDs.contains(e.sourceNodeID)
                           && managedDocIDs.contains(e.targetNodeID)
            if bothManaged { continue }
            keptUserEdges.append(e)
        }
        // Ports those kept edges still depend on, grouped by node.
        var portsToKeep: [UUID: Set<UUID>] = [:]
        for e in keptUserEdges {
            portsToKeep[e.sourceNodeID, default: []].insert(e.sourcePortID)
            portsToKeep[e.targetNodeID, default: []].insert(e.targetPortID)
        }

        // Build the new node list: surviving existing nodes, then merged matches,
        // then new nodes.
        var resultNodes: [GraphNode] = []
        for (i, n) in doc.nodes.enumerated() {
            if deletedIndices.contains(i) { summary.removed += 1; continue }
            if matchedIndices.contains(i) { continue }   // replaced by a merged node below
            resultNodes.append(n)
        }

        var nodeIDRemap: [UUID: UUID] = [:]   // incoming node id → final doc node id
        var addedNodes: [GraphNode] = []
        for inNode in incomingManaged {
            if let idx = matchIndex[inNode.id] {
                let existing = doc.nodes[idx]
                resultNodes.append(mergedNode(incoming: inNode, existing: existing,
                                              keepPortIDs: portsToKeep[existing.id] ?? []))
                nodeIDRemap[inNode.id] = existing.id
                summary.updated += 1
            } else {
                nodeIDRemap[inNode.id] = inNode.id
                addedNodes.append(inNode)
                summary.added += 1
            }
        }

        // Place the new nodes below the existing graph so the existing layout
        // is left undisturbed.
        positionNewNodes(&addedNodes, below: resultNodes)
        resultNodes.append(contentsOf: addedNodes)

        // Build the new edge list: kept user edges + re-derived wxO edges.
        var resultEdges: [GraphEdge] = keptUserEdges
        for e in incoming.edges {
            guard let s = nodeIDRemap[e.sourceNodeID],
                  let t = nodeIDRemap[e.targetNodeID] else { continue }
            resultEdges.append(GraphEdge(
                sourceNodeID: s, sourcePortID: e.sourcePortID,
                targetNodeID: t, targetPortID: e.targetPortID,
                colorHex: e.colorHex, lineStyle: e.lineStyle, comments: e.comments
            ))
        }

        // Apply atomically.
        doc.selectedNodeID = nil
        doc.selectedNodeIDs = []
        doc.selectedEdgeID = nil
        doc.selectedEdgeIDs = []
        doc.nodes = resultNodes
        doc.edges = resultEdges
        doc.updateContentExtent()
        doc.isDirty = true

        // Snapshot the merged result too, so the version list brackets the
        // merge with both a before and an after.
        doc.createVersion(
            name: String(localized: "After wxO merge"),
            note: String(localized: "Automatic snapshot taken after merging \(sourceName)")
        )
        return summary
    }

    // MARK: - Node merge

    /// A matched node: start from the existing node so every user-owned value
    /// (position, size, colour, lock, fonts, comments, expected duration, and
    /// any metadata the importer doesn't produce) is preserved, then refresh
    /// only the fields the wxO importer owns.
    private static func mergedNode(incoming: GraphNode, existing: GraphNode,
                                   keepPortIDs: Set<UUID>) -> GraphNode {
        var n = existing
        n.title = incoming.title
        n.detail = incoming.detail
        n.importSourceKey = incoming.importSourceKey   // also stamps adopted nodes
        switch existing.kind {
        case .agent:
            n.agentFramework = incoming.agentFramework
            n.agentModel = incoming.agentModel
            n.agentRole = incoming.agentRole
            n.agentInstructions = incoming.agentInstructions
            n.agentCanDelegate = incoming.agentCanDelegate
        case .tool:
            n.toolType = incoming.toolType
            n.toolInputs = incoming.toolInputs
            n.toolOutputs = incoming.toolOutputs
            n.toolEndpoint = incoming.toolEndpoint
        default:
            break   // knowledge: title + detail only
        }
        // Imported ports + any existing ports still used by a kept user edge.
        let keptPorts = existing.ports.filter { keepPortIDs.contains($0.id) }
        n.ports = incoming.ports + keptPorts
        n.size.height = nodeHeight(portCount: n.ports.count)
        return n
    }

    /// An existing un-keyed node matching by kind + title — lets a merge adopt a
    /// graph that was imported before source keys existed.
    private static func adoptIndex(for inNode: GraphNode, in nodes: [GraphNode],
                                   claimed: Set<Int>) -> Int? {
        for (i, n) in nodes.enumerated() {
            if n.importSourceKey == nil, !claimed.contains(i),
               n.kind == inNode.kind, n.title == inNode.title {
                return i
            }
        }
        return nil
    }

    // MARK: - Layout

    /// Translates the new-node cluster (keeping the importer's relative layout)
    /// to sit just below the existing graph, left-aligned with it.
    private static func positionNewNodes(_ added: inout [GraphNode],
                                         below existing: [GraphNode]) {
        guard !added.isEmpty, !existing.isEmpty else { return }
        let exMinX = existing.map { $0.position.x - $0.size.width / 2 }.min() ?? 0
        let exMaxY = existing.map { $0.position.y + $0.size.height / 2 }.max() ?? 0
        let adMinX = added.map { $0.position.x - $0.size.width / 2 }.min() ?? 0
        let adMinY = added.map { $0.position.y - $0.size.height / 2 }.min() ?? 0
        let dx = exMinX - adMinX
        let dy = (exMaxY + 120) - adMinY
        for i in added.indices {
            added[i].position.x += dx
            added[i].position.y += dy
        }
    }

    private static func nodeHeight(portCount: Int) -> CGFloat {
        max(80, 40 + CGFloat(portCount) * 22 + 10)
    }

    // MARK: - Summary

    static func showSummary(_ s: Summary, sourceName: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "watsonx Orchestrate merge complete")
        alert.informativeText = String(localized: "Merged “\(sourceName)” — \(s.updated) updated, \(s.added) added, \(s.removed) removed. A version snapshot was saved first.")
        alert.runModal()
    }
}
