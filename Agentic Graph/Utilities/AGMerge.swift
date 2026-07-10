import Foundation
import AppKit

/// Combines another Agentic Graph (`.ag`) project into the current graph.
/// Nodes and edges are matched by UUID: shared items are refreshed from the
/// incoming file, items only in the incoming file are added, and items only
/// in the current graph are kept (never deleted) — but flagged for review
/// when the two files share lineage. A version snapshot brackets the merge.
enum AGMerge {

    struct Summary {
        var updated = 0
        var added = 0
        var stale = 0
    }

    // MARK: - Merge

    static func merge(incoming: GraphDocument, into doc: GraphDocument,
                      sourceName: String) -> Summary {
        doc.createVersion(
            name: String(localized: "Before merge"),
            note: String(localized: "Automatic snapshot taken before merging \(sourceName)")
        )

        var summary = Summary()

        let aIDs = Set(doc.nodes.map { $0.id })
        let bByID = Dictionary(incoming.nodes.map { ($0.id, $0) },
                               uniquingKeysWith: { first, _ in first })
        let bIDs = Set(bByID.keys)
        let related = !aIDs.isDisjoint(with: bIDs)

        // Nodes — keep the current graph's order. Shared nodes take the
        // incoming content but keep their existing canvas position; current-
        // only nodes are left untouched.
        var resultNodes: [GraphNode] = []
        for aNode in doc.nodes {
            if let bNode = bByID[aNode.id] {
                var merged = bNode
                merged.position = aNode.position
                resultNodes.append(merged)
                summary.updated += 1
            } else {
                resultNodes.append(aNode)
            }
        }

        // Incoming-only nodes — added as a cluster below the existing graph.
        var addedNodes = incoming.nodes.filter { !aIDs.contains($0.id) }
        summary.added = addedNodes.count
        positionNewNodes(&addedNodes, below: resultNodes)
        resultNodes.append(contentsOf: addedNodes)

        // Edges — shared (same UUID) take the incoming version, current-only
        // are kept, incoming-only are added.
        let aEdgeIDs = Set(doc.edges.map { $0.id })
        let bEdgesByID = Dictionary(incoming.edges.map { ($0.id, $0) },
                                    uniquingKeysWith: { first, _ in first })
        var resultEdges: [GraphEdge] = doc.edges.map { bEdgesByID[$0.id] ?? $0 }
        resultEdges.append(contentsOf: incoming.edges.filter { !aEdgeIDs.contains($0.id) })

        // Drop any edge whose endpoints / ports no longer resolve (e.g. a
        // shared node whose ports changed in the incoming file).
        var portsByNode: [UUID: Set<UUID>] = [:]
        for n in resultNodes {
            portsByNode[n.id] = Set(n.ports.map { $0.id })
        }
        resultEdges = resultEdges.filter { e in
            guard let s = portsByNode[e.sourceNodeID],
                  let t = portsByNode[e.targetNodeID] else { return false }
            return s.contains(e.sourcePortID) && t.contains(e.targetPortID)
        }

        // "Not in the merged file" only means something when the two files
        // share lineage; otherwise this is a plain additive combine.
        let staleIDs: [UUID] = related
            ? doc.nodes.map(\.id).filter { !bIDs.contains($0) }
            : []
        summary.stale = staleIDs.count

        // Apply.
        doc.nodes = resultNodes
        doc.edges = resultEdges
        doc.updateContentExtent()
        doc.isDirty = true
        doc.selectedEdgeID = nil
        doc.selectedEdgeIDs = []
        doc.selectedNodeIDs = Set(staleIDs)
        doc.selectedNodeID = staleIDs.first

        doc.createVersion(
            name: String(localized: "After merge"),
            note: String(localized: "Automatic snapshot taken after merging \(sourceName)")
        )
        return summary
    }

    // MARK: - Layout

    /// Translates the incoming-node cluster (keeping its relative layout) to
    /// sit just below the existing graph, left-aligned with it.
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

    // MARK: - Summary

    static func showSummary(_ s: Summary, sourceName: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Project merge complete")
        alert.informativeText = String(localized: "Merged “\(sourceName)” — \(s.updated) updated, \(s.added) added, \(s.stale) not in the merged file. Snapshots saved before and after; any nodes not in the merged file are selected for review.")
        alert.runModal()
    }
}
