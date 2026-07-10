import SwiftUI

@Observable
class GraphDocument {
    var projectName: String = String(localized: "Project Name")

    // Project metadata — Core Info
    var projectDescription: String?
    var businessJustification: String?
    var targetCompletionDate: String?
    var estimatedEffort: String?
    var teamSize: String?

    // Project metadata — Technical Scope
    var integrationPoints: String?
    var deploymentTarget: DeploymentTarget?

    // Project metadata — Risk & Compliance
    var overallRiskLevel: RiskLevel = .none
    var complianceRequirements: String?
    var dataClassification: String?
    var regulatoryConstraints: String?

    // Project metadata — Dependencies & Blockers
    var criticalDependencies: String?
    var keyAssumptions: String?
    var openQuestions: String?

    // Project-level user comments (surfaced in reports)
    var projectComments: String?

    /// Per-agent prompt analysis drafts, keyed by agent UUID string. Persisted in the .ag file.
    var promptAnalysisDrafts: [String: String] = [:]

    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var selectedNodeID: UUID? = nil
    var selectedNodeIDs: Set<UUID> = []
    var selectedEdgeID: UUID? = nil
    var selectedEdgeIDs: Set<UUID> = []

    // Marquee selection rectangle (canvas coordinates)
    var marqueeRect: CGRect? = nil

    // Clipboard for copy/paste
    var clipboard: [(node: GraphNode, edges: [GraphEdge])] = []

    // Canvas viewport
    var canvasOffset: CGSize = .zero
    var canvasScale: CGFloat = 1.0
    var canvasViewportSize: CGSize = CGSize(width: 800, height: 600)
    var needsZoomToFit: Bool = false
    var zoomLocked: Bool = false

    /// Offset that centers the model coordinate origin within the canvas frame.
    /// Model coordinate (0,0) renders at frame position (renderOffset, renderOffset).
    var renderOffset: CGFloat { contentExtent / 2 }
    var darkCanvas: Bool = true

    /// Cached content extent for the canvas frame. Updated when nodes are
    /// added, removed, or repositioned — NOT during zoom, so layout stays
    /// cheap while the user is scrolling/zooming.
    var contentExtent: CGFloat = 10000

    // Version snapshots
    var versions: [VersionSnapshot] = []

    // File tracking
    var fileURL: URL? = nil
    var isDirty: Bool = false

    // Undo support
    var undoManager: UndoManager?

    // Remembered shape defaults per kind (persisted via UserDefaults)
    var nodeDefaults: [String: NodeDefaults] = NodeDefaults.loadAll()

    // Visibility filtering (runtime only, not persisted)
    var hiddenNodeKinds: Set<NodeKind> = []

    // Inspector tab (runtime only)
    enum InspectorTab { case properties, analysis, sizing, promptAnalysis, loadSimulation, comments }
    var inspectorTab: InspectorTab = .properties

    // View mode (runtime only)
    enum ViewMode { case workspace, settings }
    var viewMode: ViewMode = .workspace
    var settingsTab: String = NodeKind.agent.rawValue

    // Find panel visibility (runtime only) — toggled by ⌘F
    var showFindPanel: Bool = false

    // Last analysis result (persisted in .ag file)
    var lastAnalysisResult: AnalysisResult?

    // Interaction state
    var isDraggingNode: Bool = false
    var dragSourceNodeID: UUID? = nil
    var dragSourcePortID: UUID? = nil
    var dragCurrentEndpoint: CGPoint? = nil

    var isInteracting: Bool {
        isDraggingNode || dragSourceNodeID != nil
    }

    // Port positions (populated by preference key)
    var portPositions: [PortAddress: CGPoint] = [:]

    // MARK: - Edge Selection

    /// Node IDs highlighted because their edge is selected
    var highlightedNodeIDs: Set<UUID> {
        guard let edgeID = selectedEdgeID,
              let edge = edges.first(where: { $0.id == edgeID }) else {
            return []
        }
        return [edge.sourceNodeID, edge.targetNodeID]
    }

    // MARK: - Project Stats (auto-calculated)

    var agentCount: Int { nodes.filter { $0.kind == .agent }.count }
    var dataSourceCount: Int { nodes.filter { $0.kind == .knowledge }.count }
    var toolCount: Int { nodes.filter { $0.kind == .tool }.count }
    var humanCount: Int { nodes.filter { $0.kind == .human }.count }

    // MARK: - Lookups

    var selectedNodeIndex: Int? {
        guard let id = selectedNodeID else { return nil }
        return nodes.firstIndex(where: { $0.id == id })
    }

    func node(for id: UUID) -> GraphNode? {
        nodes.first(where: { $0.id == id })
    }

    func nodeIndex(for id: UUID) -> Int? {
        nodes.firstIndex(where: { $0.id == id })
    }

    func edges(connectedTo nodeID: UUID) -> [GraphEdge] {
        edges.filter { $0.sourceNodeID == nodeID || $0.targetNodeID == nodeID }
    }

    // MARK: - Content Extent

    /// Recomputes `contentExtent` from current node positions.
    /// Call after adding/removing/moving nodes or loading a document.
    func updateContentExtent() {
        let oldRenderOffset = renderOffset
        var extent: CGFloat = 10000
        for node in nodes {
            let right = abs(node.position.x) + node.size.width + 2000
            let bottom = abs(node.position.y) + node.size.height + 2000
            extent = max(extent, right * 2, bottom * 2)
        }
        contentExtent = extent
        // Compensate canvasOffset when renderOffset changes so nodes
        // don't visually jump when contentExtent grows or shrinks.
        let delta = renderOffset - oldRenderOffset
        if delta != 0 {
            canvasOffset.width -= delta * canvasScale
            canvasOffset.height -= delta * canvasScale
        }
    }

    // MARK: - Document Lifecycle

    func markClean() {
        isDirty = false
        undoManager?.removeAllActions()
    }

    func resetToNew() {
        nodes = []
        edges = []
        selectedNodeID = nil
        selectedNodeIDs = []
        selectedEdgeID = nil
        selectedEdgeIDs = []
        canvasOffset = .zero
        canvasScale = 1.0
        projectName = String(localized: "Project Name")
        // Clear project metadata
        projectDescription = nil
        businessJustification = nil
        targetCompletionDate = nil
        estimatedEffort = nil
        teamSize = nil
        integrationPoints = nil
        deploymentTarget = nil
        overallRiskLevel = .none
        complianceRequirements = nil
        dataClassification = nil
        regulatoryConstraints = nil
        criticalDependencies = nil
        keyAssumptions = nil
        openQuestions = nil
        projectComments = nil
        promptAnalysisDrafts = [:]
        versions = []
        contentExtent = 10000
        fileURL = nil
        markClean()
    }

    // MARK: - Version Snapshots

    func createVersion(name: String, note: String? = nil) {
        let snapshot = VersionSnapshot(name: name, note: note, document: self)
        versions.append(snapshot)
        isDirty = true

        let snapshotID = snapshot.id
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.versions.removeAll { $0.id == snapshotID }
            doc.isDirty = true
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.versions.append(snapshot)
                doc2.isDirty = true
            }
        }
        undoManager?.setActionName("Create Version \"\(name)\"")
    }

    func revertToVersion(_ snapshot: VersionSnapshot) {
        // Capture current state for undo
        let currentManifest = ProjectManifest.from(document: self)
        let currentVersions = versions

        // Apply the snapshot's manifest (replaces nodes, edges, metadata)
        snapshot.manifest.apply(to: self)
        // Preserve the version list — it's file-level metadata, not graph state
        versions = currentVersions

        isDirty = true
        selectedNodeID = nil
        selectedNodeIDs = []
        selectedEdgeID = nil
        selectedEdgeIDs = []

        undoManager?.registerUndo(withTarget: self) { doc in
            currentManifest.apply(to: doc)
            doc.versions = currentVersions
            doc.isDirty = true
            doc.selectedNodeID = nil
            doc.selectedNodeIDs = []
            doc.selectedEdgeID = nil
            doc.selectedEdgeIDs = []

            doc.undoManager?.registerUndo(withTarget: doc) { [snapshot] doc2 in
                snapshot.manifest.apply(to: doc2)
                doc2.versions = currentVersions
                doc2.isDirty = true
                doc2.selectedNodeID = nil
                doc2.selectedNodeIDs = []
                doc2.selectedEdgeID = nil
                doc2.selectedEdgeIDs = []
            }
            doc.undoManager?.setActionName("Revert to \"\(snapshot.name)\"")
        }
        undoManager?.setActionName("Revert to \"\(snapshot.name)\"")
    }

    func deleteVersion(id: UUID) {
        guard let idx = versions.firstIndex(where: { $0.id == id }) else { return }
        let removed = versions.remove(at: idx)
        isDirty = true

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.versions.insert(removed, at: min(idx, doc.versions.count))
            doc.isDirty = true
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.versions.removeAll { $0.id == removed.id }
                doc2.isDirty = true
            }
            doc.undoManager?.setActionName("Delete Version \"\(removed.name)\"")
        }
        undoManager?.setActionName("Delete Version \"\(removed.name)\"")
    }

    // MARK: - Zoom

    /// Bounding box of all nodes in canvas coordinates
    private var nodesBoundingBox: CGRect? {
        guard !nodes.isEmpty else { return nil }
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for node in nodes {
            let halfW = node.size.width / 2
            let halfH = node.size.height / 2
            minX = min(minX, node.position.x - halfW)
            minY = min(minY, node.position.y - halfH)
            maxX = max(maxX, node.position.x + halfW)
            maxY = max(maxY, node.position.y + halfH)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func zoomToFit() {
        guard let bb = nodesBoundingBox, bb.width > 0, bb.height > 0 else { return }
        let vp = canvasViewportSize
        let scaleX = vp.width / bb.width
        let scaleY = vp.height / bb.height
        let scale = min(min(scaleX, scaleY) * 0.85, 3.0)  // 85% padding, clamp max
        let clampedScale = max(scale, 0.2)                  // clamp min

        let ro = renderOffset
        canvasScale = clampedScale
        canvasOffset = CGSize(
            width: vp.width / 2 - (bb.midX + ro) * clampedScale,
            height: vp.height / 2 - (bb.midY + ro) * clampedScale
        )
    }

    func panToNode(_ nodeID: UUID) {
        guard let node = node(for: nodeID) else { return }
        let vp = canvasViewportSize
        let ro = renderOffset
        canvasOffset = CGSize(
            width: vp.width / 2 - (node.position.x + ro) * canvasScale,
            height: vp.height / 2 - (node.position.y + ro) * canvasScale
        )
    }

    /// Centers the viewport on the midpoint of an edge's two endpoint nodes.
    func panToEdge(_ edgeID: UUID) {
        guard let edge = edges.first(where: { $0.id == edgeID }),
              let source = node(for: edge.sourceNodeID),
              let target = node(for: edge.targetNodeID) else { return }
        let midX = (source.position.x + target.position.x) / 2
        let midY = (source.position.y + target.position.y) / 2
        let vp = canvasViewportSize
        let ro = renderOffset
        canvasOffset = CGSize(
            width: vp.width / 2 - (midX + ro) * canvasScale,
            height: vp.height / 2 - (midY + ro) * canvasScale
        )
    }

    func zoomIn() {
        let newScale = min(canvasScale * 1.2, 3.0)
        zoomFromCenter(to: newScale)
    }

    func zoomOut() {
        let newScale = max(canvasScale / 1.2, 0.2)
        zoomFromCenter(to: newScale)
    }

    func zoomReset() {
        // 1:1 zoom, centered on node bounding box (or origin if no nodes)
        let center = nodesBoundingBox.map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero
        let ro = renderOffset
        canvasScale = 1.0
        canvasOffset = CGSize(
            width: canvasViewportSize.width / 2 - (center.x + ro),
            height: canvasViewportSize.height / 2 - (center.y + ro)
        )
    }

    private func zoomFromCenter(to newScale: CGFloat) {
        let vp = canvasViewportSize
        // Canvas point at viewport center
        let cx = (vp.width / 2 - canvasOffset.width) / canvasScale
        let cy = (vp.height / 2 - canvasOffset.height) / canvasScale

        canvasScale = newScale
        canvasOffset = CGSize(
            width: vp.width / 2 - cx * newScale,
            height: vp.height / 2 - cy * newScale
        )
    }

    // MARK: - Mutations

    func addNode(_ node: GraphNode) {
        var node = node // mutable copy for applying defaults

        // Apply remembered defaults for this specific kind
        NodeDefaults.loadAll()[node.kind.rawValue]?.apply(to: &node)

        // Insert shapes before first non-shape node to maintain layer ordering
        if node.kind.isShape {
            let insertIndex = nodes.firstIndex(where: { !$0.kind.isShape }) ?? nodes.count
            nodes.insert(node, at: insertIndex)
        } else {
            nodes.append(node)
        }

        undoManager?.registerUndo(withTarget: self) { [node] doc in
            doc.nodes.removeAll { $0.id == node.id }
            if doc.selectedNodeID == node.id { doc.selectedNodeID = nil }
            doc.updateContentExtent()
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.addNode(node)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Add Node")
        }
        updateContentExtent()
        isDirty = true
        undoManager?.setActionName("Add Node")
    }

    func removeNode(id: UUID) {
        let connectedEdges = edges.filter { $0.sourceNodeID == id || $0.targetNodeID == id }
        edges.removeAll { $0.sourceNodeID == id || $0.targetNodeID == id }
        for edge in connectedEdges {
            let otherNodeID = edge.sourceNodeID == id ? edge.targetNodeID : edge.sourceNodeID
            let otherPortID = edge.sourceNodeID == id ? edge.targetPortID : edge.sourcePortID
            guard let otherIdx = nodeIndex(for: otherNodeID),
                  let portIdx = nodes[otherIdx].ports.firstIndex(where: { $0.id == otherPortID })
            else { continue }
            if nodes[otherIdx].ports[portIdx].isAutoCreated {
                // Remove auto-created port if no longer connected
                if !edges.contains(where: { $0.sourcePortID == otherPortID || $0.targetPortID == otherPortID }) {
                    nodes[otherIdx].ports.remove(at: portIdx)
                }
            } else {
                // Revert renamed port back to "Connect"
                nodes[otherIdx].ports[portIdx].label = "Connect"
            }
        }
        nodes.removeAll { $0.id == id }
        updateContentExtent()
        if selectedNodeID == id { selectedNodeID = nil }
        if let eid = selectedEdgeID, !edges.contains(where: { $0.id == eid }) {
            selectedEdgeID = nil
        }
    }

    func addEdge(_ edge: GraphEdge) {
        // Prevent self-connections
        guard edge.sourceNodeID != edge.targetNodeID else { return }
        // Prevent duplicate edges between the same node pair
        guard !hasEdgeBetween(edge.sourceNodeID, edge.targetNodeID) else { return }
        // Prevent cycles
        guard !wouldCreateCycle(from: edge.sourceNodeID, to: edge.targetNodeID) else { return }

        // Block if source output port already has a connection
        let sourcePortBusy = edges.contains { $0.sourcePortID == edge.sourcePortID }
        if sourcePortBusy { return }

        edges.append(edge)

        // Track label changes for undo
        var labelChanges: [(nodeID: UUID, portID: UUID, oldLabel: String)] = []

        // Rename default "Connect" ports to the connected node's title
        if let sourceIdx = nodeIndex(for: edge.sourceNodeID),
           let portIdx = nodes[sourceIdx].ports.firstIndex(where: { $0.id == edge.sourcePortID }),
           nodes[sourceIdx].ports[portIdx].label == "Connect",
           let targetNode = node(for: edge.targetNodeID) {
            labelChanges.append((edge.sourceNodeID, edge.sourcePortID, "Connect"))
            nodes[sourceIdx].ports[portIdx].label = targetNode.title
        }
        if let targetIdx = nodeIndex(for: edge.targetNodeID),
           let portIdx = nodes[targetIdx].ports.firstIndex(where: { $0.id == edge.targetPortID }),
           nodes[targetIdx].ports[portIdx].label == "Connect",
           let sourceNode = node(for: edge.sourceNodeID) {
            labelChanges.append((edge.targetNodeID, edge.targetPortID, "Connect"))
            nodes[targetIdx].ports[portIdx].label = sourceNode.title
        }

        // Register undo
        undoManager?.registerUndo(withTarget: self) { [labelChanges] doc in
            doc.edges.removeAll { $0.id == edge.id }
            for change in labelChanges {
                if let nidx = doc.nodeIndex(for: change.nodeID),
                   let pidx = doc.nodes[nidx].ports.firstIndex(where: { $0.id == change.portID }) {
                    doc.nodes[nidx].ports[pidx].label = change.oldLabel
                }
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.addEdge(edge)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Add Connection")
        }
        isDirty = true
        undoManager?.setActionName("Add Connection")
    }

    /// When a node's title changes, update port labels on connected nodes.
    func propagateNodeTitle(_ nodeID: UUID, newTitle: String) {
        for edge in edges {
            if edge.sourceNodeID == nodeID {
                // This node is the source → update the target node's input port label
                if let targetIdx = nodeIndex(for: edge.targetNodeID),
                   let portIdx = nodes[targetIdx].ports.firstIndex(where: { $0.id == edge.targetPortID }),
                   nodes[targetIdx].ports[portIdx].label != "Connect" {
                    nodes[targetIdx].ports[portIdx].label = newTitle
                }
            }
            if edge.targetNodeID == nodeID {
                // This node is the target → update the source node's output port label
                if let sourceIdx = nodeIndex(for: edge.sourceNodeID),
                   let portIdx = nodes[sourceIdx].ports.firstIndex(where: { $0.id == edge.sourcePortID }),
                   nodes[sourceIdx].ports[portIdx].label != "Connect" {
                    nodes[sourceIdx].ports[portIdx].label = newTitle
                }
            }
        }
    }

    // MARK: - Undo-Aware Deletion

    func deleteSelectedItem() {
        if !selectedNodeIDs.isEmpty {
            // Delete all multi-selected nodes
            let ids = selectedNodeIDs
            for id in ids {
                removeNodeWithUndo(id: id)
            }
            selectedNodeIDs = []
            selectedNodeID = nil
        } else if let nodeID = selectedNodeID {
            removeNodeWithUndo(id: nodeID)
        } else if let edgeID = selectedEdgeID {
            removeEdgeWithUndo(id: edgeID)
        }
    }

    // MARK: - Copy / Paste

    func copySelectedNodes() {
        let ids = allSelectedNodeIDs
        guard !ids.isEmpty else { return }

        clipboard = ids.compactMap { id -> (node: GraphNode, edges: [GraphEdge])? in
            guard let node = node(for: id) else { return nil }
            let nodeEdges = edges.filter { ids.contains($0.sourceNodeID) && ids.contains($0.targetNodeID) }
                .filter { $0.sourceNodeID == id || $0.targetNodeID == id }
            return (node, nodeEdges)
        }
    }

    func pasteNodes() {
        guard !clipboard.isEmpty else { return }
        let offset: CGFloat = 30

        // Map old IDs to new IDs
        var idMap: [UUID: UUID] = [:]
        var groupMap: [UUID: UUID] = [:]
        for item in clipboard {
            idMap[item.node.id] = UUID()
            for port in item.node.ports {
                idMap[port.id] = UUID()
            }
            if let gid = item.node.groupID, groupMap[gid] == nil {
                groupMap[gid] = UUID()
            }
        }

        // Create new nodes
        var newNodeIDs: Set<UUID> = []
        for item in clipboard {
            var newNode = item.node
            newNode.id = idMap[item.node.id]!
            newNode.position = CGPoint(x: newNode.position.x + offset, y: newNode.position.y + offset)
            newNode.ports = newNode.ports.map { port in
                var p = port
                p.id = idMap[port.id]!
                return p
            }
            newNode.groupID = item.node.groupID.flatMap { groupMap[$0] }
            addNode(newNode)
            newNodeIDs.insert(newNode.id)
        }

        // Re-create edges between pasted nodes
        var addedEdges: Set<UUID> = []
        for item in clipboard {
            for edge in item.edges {
                guard !addedEdges.contains(edge.id),
                      let newSourceNode = idMap[edge.sourceNodeID],
                      let newTargetNode = idMap[edge.targetNodeID],
                      let newSourcePort = idMap[edge.sourcePortID],
                      let newTargetPort = idMap[edge.targetPortID]
                else { continue }
                let newEdge = GraphEdge(sourceNodeID: newSourceNode, sourcePortID: newSourcePort,
                                        targetNodeID: newTargetNode, targetPortID: newTargetPort)
                addEdge(newEdge)
                addedEdges.insert(edge.id)
            }
        }

        // Select the pasted nodes
        selectedNodeIDs = newNodeIDs
        selectedNodeID = newNodeIDs.first
        selectedEdgeID = nil
    }

    /// All selected node IDs (union of single + multi selection)
    var allSelectedNodeIDs: Set<UUID> {
        var ids = selectedNodeIDs
        if let single = selectedNodeID { ids.insert(single) }
        return ids
    }

    /// All selected edge IDs (union of single + multi selection)
    var allSelectedEdgeIDs: Set<UUID> {
        var ids = selectedEdgeIDs
        if let single = selectedEdgeID { ids.insert(single) }
        return ids
    }

    /// Total number of selected items (nodes + edges)
    var totalSelectedCount: Int {
        allSelectedNodeIDs.count + allSelectedEdgeIDs.count
    }

    func removeNodeWithUndo(id: UUID) {
        guard let idx = nodeIndex(for: id) else { return }
        let node = nodes[idx]
        let connectedEdges = edges(connectedTo: id)

        // Capture state that will change on other nodes
        var orphanedPorts: [(UUID, NodePort)] = []
        var renamedLabels: [(UUID, UUID, String)] = [] // (nodeID, portID, oldLabel)
        let connectedEdgeIDs = Set(connectedEdges.map(\.id))
        for edge in connectedEdges {
            let otherNodeID = edge.sourceNodeID == id ? edge.targetNodeID : edge.sourceNodeID
            let otherPortID = edge.sourceNodeID == id ? edge.targetPortID : edge.sourcePortID
            if let otherIdx = nodeIndex(for: otherNodeID),
               let port = nodes[otherIdx].ports.first(where: { $0.id == otherPortID }) {
                if port.isAutoCreated {
                    let stillUsed = edges.contains {
                        !connectedEdgeIDs.contains($0.id) &&
                        ($0.sourcePortID == otherPortID || $0.targetPortID == otherPortID)
                    }
                    if !stillUsed {
                        orphanedPorts.append((otherNodeID, port))
                    }
                } else if port.label != "Connect" {
                    renamedLabels.append((otherNodeID, otherPortID, port.label))
                }
            }
        }

        // Perform the deletion
        removeNode(id: id)

        // Register undo
        undoManager?.registerUndo(withTarget: self) { [connectedEdges, node, orphanedPorts, renamedLabels] doc in
            // Restore the node
            doc.nodes.append(node)
            // Restore orphaned ports on other nodes
            for (nodeID, port) in orphanedPorts {
                if let pidx = doc.nodeIndex(for: nodeID) {
                    doc.nodes[pidx].ports.append(port)
                }
            }
            // Restore renamed port labels
            for (nodeID, portID, label) in renamedLabels {
                if let nidx = doc.nodeIndex(for: nodeID),
                   let pidx = doc.nodes[nidx].ports.firstIndex(where: { $0.id == portID }) {
                    doc.nodes[nidx].ports[pidx].label = label
                }
            }
            // Restore edges
            for edge in connectedEdges {
                doc.edges.append(edge)
            }
            doc.updateContentExtent()
            doc.selectedNodeID = id

            // Register redo
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.selectedNodeID = id
                doc2.removeNodeWithUndo(id: id)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Delete Node")
        }
        isDirty = true
        undoManager?.setActionName("Delete Node")
    }

    func removeEdgeWithUndo(id: UUID) {
        guard let edge = edges.first(where: { $0.id == id }) else { return }

        // Capture state that will change
        var orphanedPort: (UUID, NodePort)? = nil
        var renamedLabels: [(UUID, UUID, String)] = []

        // Check source port
        if let sourceIdx = nodeIndex(for: edge.sourceNodeID),
           let port = nodes[sourceIdx].ports.first(where: { $0.id == edge.sourcePortID }) {
            if port.isAutoCreated {
                let otherEdges = edges.filter {
                    $0.id != id && ($0.sourcePortID == port.id || $0.targetPortID == port.id)
                }
                if otherEdges.isEmpty {
                    orphanedPort = (edge.sourceNodeID, port)
                }
            } else if port.label != "Connect" {
                renamedLabels.append((edge.sourceNodeID, edge.sourcePortID, port.label))
            }
        }
        // Check target port
        if let targetIdx = nodeIndex(for: edge.targetNodeID),
           let port = nodes[targetIdx].ports.first(where: { $0.id == edge.targetPortID }),
           !port.isAutoCreated, port.label != "Connect" {
            renamedLabels.append((edge.targetNodeID, edge.targetPortID, port.label))
        }

        // Perform the deletion
        removeEdge(id: id)

        // Register undo
        undoManager?.registerUndo(withTarget: self) { [edge, orphanedPort, renamedLabels] doc in
            // Restore orphaned port
            if let (nodeID, port) = orphanedPort, let pidx = doc.nodeIndex(for: nodeID) {
                doc.nodes[pidx].ports.append(port)
            }
            // Restore renamed port labels
            for (nodeID, portID, label) in renamedLabels {
                if let nidx = doc.nodeIndex(for: nodeID),
                   let pidx = doc.nodes[nidx].ports.firstIndex(where: { $0.id == portID }) {
                    doc.nodes[nidx].ports[pidx].label = label
                }
            }
            // Restore edge
            doc.edges.append(edge)
            doc.selectedEdgeID = id

            // Register redo
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.selectedEdgeID = id
                doc2.removeEdgeWithUndo(id: id)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Delete Connection")
        }
        isDirty = true
        undoManager?.setActionName("Delete Connection")
    }

    func removePortWithUndo(nodeID: UUID, portID: UUID) {
        guard let nodeIdx = nodeIndex(for: nodeID),
              let portIdx = nodes[nodeIdx].ports.firstIndex(where: { $0.id == portID })
        else { return }

        let port = nodes[nodeIdx].ports[portIdx]
        let originalPortIdx = portIdx

        // Collect edges connected to this port (before removing anything)
        let connectedEdges = edges.filter { $0.sourcePortID == portID || $0.targetPortID == portID }

        // Also capture any auto-created ports on the OTHER side that removeEdge will clean up,
        // so undo can restore them too
        var removedAutoPortsByEdge: [(GraphEdge, UUID, NodePort, Int)] = [] // edge, nodeID, port, index
        for edge in connectedEdges {
            let otherPortID = edge.sourcePortID == portID ? edge.targetPortID : edge.sourcePortID
            let otherNodeID = edge.sourcePortID == portID ? edge.targetNodeID : edge.sourceNodeID
            if let otherNodeIdx = nodeIndex(for: otherNodeID),
               let otherPortIdx = nodes[otherNodeIdx].ports.firstIndex(where: { $0.id == otherPortID }),
               nodes[otherNodeIdx].ports[otherPortIdx].isAutoCreated {
                removedAutoPortsByEdge.append((edge, otherNodeID, nodes[otherNodeIdx].ports[otherPortIdx], otherPortIdx))
            }
        }

        // Remove all edges connected to this port (may also remove auto-created ports on other nodes)
        for edge in connectedEdges {
            edges.removeAll { $0.id == edge.id }
            if selectedEdgeID == edge.id { selectedEdgeID = nil }
            selectedEdgeIDs.remove(edge.id)
        }

        // Remove the port itself (re-find index since edge cleanup may have shifted things)
        if let currentIdx = nodes[nodeIdx].ports.firstIndex(where: { $0.id == portID }) {
            nodes[nodeIdx].ports.remove(at: currentIdx)
        }

        // Clean up auto-created ports on connected nodes
        for (_, otherNodeID, _, _) in removedAutoPortsByEdge {
            if let otherIdx = nodeIndex(for: otherNodeID) {
                nodes[otherIdx].ports.removeAll { port in
                    port.isAutoCreated && !edges.contains { $0.sourcePortID == port.id || $0.targetPortID == port.id }
                }
            }
        }

        // Register undo
        undoManager?.registerUndo(withTarget: self) { [port, originalPortIdx, connectedEdges, removedAutoPortsByEdge] doc in
            // Re-insert auto-created ports on other nodes first
            for (_, otherNodeID, autoPort, autoIdx) in removedAutoPortsByEdge {
                if let otherIdx = doc.nodeIndex(for: otherNodeID) {
                    let insertAt = min(autoIdx, doc.nodes[otherIdx].ports.count)
                    doc.nodes[otherIdx].ports.insert(autoPort, at: insertAt)
                }
            }
            // Re-insert the deleted port
            if let nIdx = doc.nodeIndex(for: nodeID) {
                let insertAt = min(originalPortIdx, doc.nodes[nIdx].ports.count)
                doc.nodes[nIdx].ports.insert(port, at: insertAt)
            }
            // Re-add connected edges
            for edge in connectedEdges {
                doc.edges.append(edge)
            }
            // Register redo
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.removePortWithUndo(nodeID: nodeID, portID: portID)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Delete Port")
        }
        isDirty = true
        undoManager?.setActionName("Delete Port")
    }

    func removeEdge(id: UUID) {
        guard let edge = edges.first(where: { $0.id == id }) else { return }
        edges.removeAll { $0.id == id }
        if selectedEdgeID == id { selectedEdgeID = nil }
        selectedEdgeIDs.remove(id)
        // Clean up source port
        if let sourceIdx = nodeIndex(for: edge.sourceNodeID),
           let portIdx = nodes[sourceIdx].ports.firstIndex(where: { $0.id == edge.sourcePortID }) {
            if nodes[sourceIdx].ports[portIdx].isAutoCreated &&
               !edges.contains(where: { $0.sourcePortID == edge.sourcePortID || $0.targetPortID == edge.sourcePortID }) {
                nodes[sourceIdx].ports.remove(at: portIdx)
            } else if !nodes[sourceIdx].ports[portIdx].isAutoCreated {
                nodes[sourceIdx].ports[portIdx].label = "Connect"
            }
        }
        // Clean up target port label
        if let targetIdx = nodeIndex(for: edge.targetNodeID),
           let portIdx = nodes[targetIdx].ports.firstIndex(where: { $0.id == edge.targetPortID }),
           !nodes[targetIdx].ports[portIdx].isAutoCreated {
            nodes[targetIdx].ports[portIdx].label = "Connect"
        }
    }

    // MARK: - Connection Helpers

    /// Creates an edge with an auto-created output port on the source node.
    /// - sourceNodeID: the node that will get the output port (the "user" of the target)
    /// - targetNodeID: the node being used
    /// - targetPortID: the input port on the target
    func createConnection(fromNode sourceNodeID: UUID, toNode targetNodeID: UUID, targetPortID: UUID) {
        guard let sourceIndex = nodeIndex(for: sourceNodeID),
              let targetNode = node(for: targetNodeID) else { return }

        // Source must support outputs
        guard nodes[sourceIndex].kind.canHaveOutput else { return }
        // No duplicate node pair
        guard !hasEdgeBetween(sourceNodeID, targetNodeID) else { return }
        // No cycles
        guard !wouldCreateCycle(from: sourceNodeID, to: targetNodeID) else { return }

        // Create auto output port labeled with the target node's title
        let outputPort = NodePort(label: targetNode.title, kind: .output, isAutoCreated: true)
        nodes[sourceIndex].ports.append(outputPort)

        let edge = GraphEdge(
            sourceNodeID: sourceNodeID,
            sourcePortID: outputPort.id,
            targetNodeID: targetNodeID,
            targetPortID: targetPortID
        )
        edges.append(edge)

        // Rename target input port from "Connect" to the source node's title
        var targetLabelChanged = false
        if let targetIdx = nodeIndex(for: targetNodeID),
           let portIdx = nodes[targetIdx].ports.firstIndex(where: { $0.id == targetPortID }),
           nodes[targetIdx].ports[portIdx].label == "Connect" {
            nodes[targetIdx].ports[portIdx].label = nodes[sourceIndex].title
            targetLabelChanged = true
        }

        // Capture ports that will be removed before removing them
        let removedPorts = nodes[sourceIndex].ports.filter { port in
            port.kind == .output && port.id != outputPort.id
                && !edges.contains(where: { $0.sourcePortID == port.id })
        }

        // Remove unconnected output ports on the source node (e.g. the default "Connect" port)
        for rp in removedPorts {
            nodes[sourceIndex].ports.removeAll { $0.id == rp.id }
        }

        // Register undo
        undoManager?.registerUndo(withTarget: self) { [edge, outputPort, removedPorts, targetLabelChanged] doc in
            // Remove the edge
            doc.edges.removeAll { $0.id == edge.id }
            // Remove the auto-created output port
            if let srcIdx = doc.nodeIndex(for: sourceNodeID) {
                doc.nodes[srcIdx].ports.removeAll { $0.id == outputPort.id }
                // Restore removed ports
                doc.nodes[srcIdx].ports.append(contentsOf: removedPorts)
            }
            // Revert target port label
            if targetLabelChanged,
               let tIdx = doc.nodeIndex(for: targetNodeID),
               let pIdx = doc.nodes[tIdx].ports.firstIndex(where: { $0.id == targetPortID }) {
                doc.nodes[tIdx].ports[pIdx].label = "Connect"
            }
            // Register redo
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.createConnection(fromNode: sourceNodeID, toNode: targetNodeID, targetPortID: targetPortID)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Add Connection")
        }
        isDirty = true
        undoManager?.setActionName("Add Connection")
    }

    func hasEdgeBetween(_ nodeA: UUID, _ nodeB: UUID) -> Bool {
        edges.contains {
            ($0.sourceNodeID == nodeA && $0.targetNodeID == nodeB) ||
            ($0.sourceNodeID == nodeB && $0.targetNodeID == nodeA)
        }
    }

    /// BFS from targetNode: if it can reach sourceNode, adding source→target would create a cycle.
    func wouldCreateCycle(from sourceNodeID: UUID, to targetNodeID: UUID) -> Bool {
        var visited = Set<UUID>()
        var queue = [targetNodeID]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == sourceNodeID { return true }
            guard !visited.contains(current) else { continue }
            visited.insert(current)
            for edge in edges where edge.sourceNodeID == current {
                queue.append(edge.targetNodeID)
            }
        }
        return false
    }

    // MARK: - Shape Z-Ordering

    func bringShapeForward(id: UUID) {
        let shapes = nodes.indices.filter { nodes[$0].kind.isShape }
        guard let posInShapes = shapes.firstIndex(where: { nodes[$0].id == id }),
              posInShapes < shapes.count - 1 else { return }
        let currentIdx = shapes[posInShapes]
        let nextIdx = shapes[posInShapes + 1]
        let old = nodes
        nodes.swapAt(currentIdx, nextIdx)
        registerArrayUndo(old: old, actionName: "Bring Forward")
    }

    func sendShapeBackward(id: UUID) {
        let shapes = nodes.indices.filter { nodes[$0].kind.isShape }
        guard let posInShapes = shapes.firstIndex(where: { nodes[$0].id == id }),
              posInShapes > 0 else { return }
        let currentIdx = shapes[posInShapes]
        let prevIdx = shapes[posInShapes - 1]
        let old = nodes
        nodes.swapAt(currentIdx, prevIdx)
        registerArrayUndo(old: old, actionName: "Send Backward")
    }

    func bringShapeToFront(id: UUID) {
        let shapes = nodes.indices.filter { nodes[$0].kind.isShape }
        guard let posInShapes = shapes.firstIndex(where: { nodes[$0].id == id }),
              posInShapes < shapes.count - 1 else { return }
        let old = nodes
        // Move to last shape position (just before first non-shape)
        guard let node = nodes.first(where: { $0.id == id }) else { return }
        nodes.removeAll { $0.id == id }
        let insertIndex = nodes.firstIndex(where: { !$0.kind.isShape }) ?? nodes.count
        nodes.insert(node, at: insertIndex)
        registerArrayUndo(old: old, actionName: "Bring to Front")
    }

    func sendShapeToBack(id: UUID) {
        let shapes = nodes.indices.filter { nodes[$0].kind.isShape }
        guard let posInShapes = shapes.firstIndex(where: { nodes[$0].id == id }),
              posInShapes > 0 else { return }
        let old = nodes
        guard let node = nodes.first(where: { $0.id == id }) else { return }
        nodes.removeAll { $0.id == id }
        nodes.insert(node, at: 0)
        registerArrayUndo(old: old, actionName: "Send to Back")
    }

    private func registerArrayUndo(old: [GraphNode], actionName: String) {
        undoManager?.registerUndo(withTarget: self) { [old] doc in
            let current = doc.nodes
            doc.nodes = old
            doc.isDirty = true
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                doc2.nodes = current
                doc2.isDirty = true
                doc2.undoManager?.setActionName(actionName)
            }
            doc.undoManager?.setActionName(actionName)
        }
        isDirty = true
        undoManager?.setActionName(actionName)
    }

    // MARK: - Alignment & Distribution

    enum AlignmentAxis {
        case left, centerH, right, top, centerV, bottom
    }

    enum DistributionAxis {
        case horizontal, vertical
    }

    var canAlign: Bool { allSelectedNodeIDs.count >= 2 }
    var canDistribute: Bool { allSelectedNodeIDs.count >= 3 }

    /// Moves multiple nodes to new positions in a single undoable step.
    private func batchMoveNodes(_ moves: [(id: UUID, newPosition: CGPoint)], actionName: String) {
        // Filter out position-locked nodes
        let filteredMoves = moves.filter { (id, _) in
            guard let idx = nodeIndex(for: id) else { return false }
            return !nodes[idx].isPositionLocked
        }
        guard !filteredMoves.isEmpty else { return }

        let oldPositions: [(id: UUID, position: CGPoint)] = filteredMoves.compactMap { (id, _) in
            guard let idx = nodeIndex(for: id) else { return nil }
            return (id, nodes[idx].position)
        }

        for (id, newPos) in filteredMoves {
            guard let idx = nodeIndex(for: id) else { continue }
            nodes[idx].position = newPos
        }

        undoManager?.registerUndo(withTarget: self) { [oldPositions, filteredMoves] doc in
            for (id, pos) in oldPositions {
                if let idx = doc.nodeIndex(for: id) {
                    doc.nodes[idx].position = pos
                }
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                for (id, newPos) in filteredMoves {
                    if let idx = doc2.nodeIndex(for: id) {
                        doc2.nodes[idx].position = newPos
                    }
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName(actionName)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName(actionName)
        }
        isDirty = true
        undoManager?.setActionName(actionName)
    }

    func alignSelectedNodes(_ axis: AlignmentAxis) {
        let ids = allSelectedNodeIDs
        guard ids.count >= 2 else { return }

        let selected: [(id: UUID, node: GraphNode)] = ids.compactMap { id in
            guard let n = node(for: id) else { return nil }
            return (id, n)
        }
        guard selected.count >= 2 else { return }

        let minLeft   = selected.map { $0.node.position.x - $0.node.size.width / 2 }.min()!
        let maxRight  = selected.map { $0.node.position.x + $0.node.size.width / 2 }.max()!
        let minTop    = selected.map { $0.node.position.y - $0.node.size.height / 2 }.min()!
        let maxBottom = selected.map { $0.node.position.y + $0.node.size.height / 2 }.max()!

        let moves: [(id: UUID, newPosition: CGPoint)] = selected.map { (id, node) in
            var pos = node.position
            switch axis {
            case .left:
                pos.x = minLeft + node.size.width / 2
            case .right:
                pos.x = maxRight - node.size.width / 2
            case .centerH:
                pos.x = (minLeft + maxRight) / 2
            case .top:
                pos.y = minTop + node.size.height / 2
            case .bottom:
                pos.y = maxBottom - node.size.height / 2
            case .centerV:
                pos.y = (minTop + maxBottom) / 2
            }
            return (id, pos)
        }

        batchMoveNodes(moves, actionName: "Align Nodes")
    }

    func distributeSelectedNodes(_ axis: DistributionAxis) {
        let ids = allSelectedNodeIDs
        guard ids.count >= 3 else { return }

        var selected: [(id: UUID, node: GraphNode)] = ids.compactMap { id in
            guard let n = node(for: id) else { return nil }
            return (id, n)
        }
        guard selected.count >= 3 else { return }

        var moves: [(id: UUID, newPosition: CGPoint)] = []

        switch axis {
        case .horizontal:
            selected.sort { $0.node.position.x < $1.node.position.x }
            let totalNodeWidth = selected.map(\.node.size.width).reduce(0, +)
            let leftEdge = selected.first!.node.position.x - selected.first!.node.size.width / 2
            let rightEdge = selected.last!.node.position.x + selected.last!.node.size.width / 2
            let gap = (rightEdge - leftEdge - totalNodeWidth) / CGFloat(selected.count - 1)

            var currentX = leftEdge
            for (id, node) in selected {
                let newCenterX = currentX + node.size.width / 2
                moves.append((id, CGPoint(x: newCenterX, y: node.position.y)))
                currentX += node.size.width + gap
            }

        case .vertical:
            selected.sort { $0.node.position.y < $1.node.position.y }
            let totalNodeHeight = selected.map(\.node.size.height).reduce(0, +)
            let topEdge = selected.first!.node.position.y - selected.first!.node.size.height / 2
            let bottomEdge = selected.last!.node.position.y + selected.last!.node.size.height / 2
            let gap = (bottomEdge - topEdge - totalNodeHeight) / CGFloat(selected.count - 1)

            var currentY = topEdge
            for (id, node) in selected {
                let newCenterY = currentY + node.size.height / 2
                moves.append((id, CGPoint(x: node.position.x, y: newCenterY)))
                currentY += node.size.height + gap
            }
        }

        batchMoveNodes(moves, actionName: "Distribute Nodes")
    }

    // MARK: - Grouping

    var canGroup: Bool { allSelectedNodeIDs.count >= 2 }

    var canUngroup: Bool {
        allSelectedNodeIDs.contains { id in
            guard let idx = nodeIndex(for: id) else { return false }
            return nodes[idx].groupID != nil
        }
    }

    /// Returns all node IDs in the same group as the given node.
    func groupMembers(of nodeID: UUID) -> Set<UUID> {
        guard let idx = nodeIndex(for: nodeID),
              let gid = nodes[idx].groupID else { return [] }
        return Set(nodes.filter { $0.groupID == gid }.map(\.id))
    }

    func groupSelectedNodes() {
        let ids = allSelectedNodeIDs
        guard ids.count >= 2 else { return }
        let newGroupID = UUID()

        let oldGroupIDs: [(id: UUID, groupID: UUID?)] = ids.compactMap { id in
            guard let idx = nodeIndex(for: id) else { return nil }
            return (id, nodes[idx].groupID)
        }

        for id in ids {
            guard let idx = nodeIndex(for: id) else { continue }
            nodes[idx].groupID = newGroupID
        }

        undoManager?.registerUndo(withTarget: self) { [oldGroupIDs, ids, newGroupID] doc in
            for (id, oldGroup) in oldGroupIDs {
                if let idx = doc.nodeIndex(for: id) {
                    doc.nodes[idx].groupID = oldGroup
                }
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                for id in ids {
                    if let idx = doc2.nodeIndex(for: id) {
                        doc2.nodes[idx].groupID = newGroupID
                    }
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName("Group Nodes")
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Group Nodes")
        }
        isDirty = true
        undoManager?.setActionName("Group Nodes")
    }

    func ungroupSelectedNodes() {
        let ids = allSelectedNodeIDs
        guard !ids.isEmpty else { return }

        // Gather all groupIDs from selected nodes, then find ALL nodes in those groups
        let groupIDs = Set(ids.compactMap { id -> UUID? in
            guard let idx = nodeIndex(for: id) else { return nil }
            return nodes[idx].groupID
        })
        guard !groupIDs.isEmpty else { return }

        let affectedIndices = nodes.indices.filter { idx in
            guard let gid = nodes[idx].groupID else { return false }
            return groupIDs.contains(gid)
        }

        let oldGroupIDs: [(id: UUID, groupID: UUID?)] = affectedIndices.map { idx in
            (nodes[idx].id, nodes[idx].groupID)
        }

        for idx in affectedIndices {
            nodes[idx].groupID = nil
        }

        undoManager?.registerUndo(withTarget: self) { [oldGroupIDs] doc in
            for (id, oldGroup) in oldGroupIDs {
                if let idx = doc.nodeIndex(for: id) {
                    doc.nodes[idx].groupID = oldGroup
                }
            }
            doc.undoManager?.registerUndo(withTarget: doc) { [oldGroupIDs] doc2 in
                for (id, _) in oldGroupIDs {
                    if let idx = doc2.nodeIndex(for: id) {
                        doc2.nodes[idx].groupID = nil
                    }
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName("Ungroup Nodes")
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Ungroup Nodes")
        }
        isDirty = true
        undoManager?.setActionName("Ungroup Nodes")
    }

    // MARK: - Lock State

    func setLockState(_ state: LockState, for nodeID: UUID) {
        guard let idx = nodeIndex(for: nodeID) else { return }
        let oldState = nodes[idx].lockState
        guard oldState != state else { return }

        nodes[idx].lockState = state

        undoManager?.registerUndo(withTarget: self) { [oldState] doc in
            if let i = doc.nodeIndex(for: nodeID) {
                doc.nodes[i].lockState = oldState
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                if let j = doc2.nodeIndex(for: nodeID) {
                    doc2.nodes[j].lockState = state
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName("Change Lock State")
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Change Lock State")
        }
        isDirty = true
        undoManager?.setActionName("Change Lock State")
    }

    // MARK: - Edge Styling

    func setEdgeColor(_ colorHex: String?, for edgeID: UUID) {
        guard let idx = edges.firstIndex(where: { $0.id == edgeID }) else { return }
        let oldColor = edges[idx].colorHex
        guard oldColor != colorHex else { return }
        edges[idx].colorHex = colorHex

        undoManager?.registerUndo(withTarget: self) { [oldColor] doc in
            if let i = doc.edges.firstIndex(where: { $0.id == edgeID }) {
                doc.edges[i].colorHex = oldColor
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                if let j = doc2.edges.firstIndex(where: { $0.id == edgeID }) {
                    doc2.edges[j].colorHex = colorHex
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName("Change Edge Color")
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Change Edge Color")
        }
        isDirty = true
        undoManager?.setActionName("Change Edge Color")
    }

    func setEdgeLineStyle(_ style: EdgeLineStyle, for edgeID: UUID) {
        guard let idx = edges.firstIndex(where: { $0.id == edgeID }) else { return }
        let oldStyle = edges[idx].lineStyle
        guard oldStyle != style else { return }
        edges[idx].lineStyle = style

        undoManager?.registerUndo(withTarget: self) { [oldStyle] doc in
            if let i = doc.edges.firstIndex(where: { $0.id == edgeID }) {
                doc.edges[i].lineStyle = oldStyle
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                if let j = doc2.edges.firstIndex(where: { $0.id == edgeID }) {
                    doc2.edges[j].lineStyle = style
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName("Change Edge Style")
            }
            doc.isDirty = true
            doc.undoManager?.setActionName("Change Edge Style")
        }
        isDirty = true
        undoManager?.setActionName("Change Edge Style")
    }

    /// Batch apply edge changes from multi-select inspector
    func batchApplyEdgeChanges(edgeIDs: Set<UUID>, formState: MultiSelectFormState) {
        guard !edgeIDs.isEmpty else { return }

        let oldSnapshots: [(id: UUID, edge: GraphEdge)] = edgeIDs.compactMap { id in
            guard let idx = edges.firstIndex(where: { $0.id == id }) else { return nil }
            return (id, edges[idx])
        }
        guard !oldSnapshots.isEmpty else { return }

        for id in edgeIDs {
            guard let idx = edges.firstIndex(where: { $0.id == id }) else { continue }
            if formState.enabledFields.contains("edgeColorHex") {
                edges[idx].colorHex = formState.edgeColorHex
            }
            if formState.enabledFields.contains("edgeLineStyle") {
                edges[idx].lineStyle = formState.edgeLineStyle
            }
        }

        let newSnapshots: [(id: UUID, edge: GraphEdge)] = edgeIDs.compactMap { id in
            guard let idx = edges.firstIndex(where: { $0.id == id }) else { return nil }
            return (id, edges[idx])
        }

        let actionName = "Apply to \(edgeIDs.count) Edges"
        undoManager?.registerUndo(withTarget: self) { [oldSnapshots, newSnapshots] doc in
            for (id, oldEdge) in oldSnapshots {
                if let idx = doc.edges.firstIndex(where: { $0.id == id }) {
                    doc.edges[idx] = oldEdge
                }
            }
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                for (id, newEdge) in newSnapshots {
                    if let idx = doc2.edges.firstIndex(where: { $0.id == id }) {
                        doc2.edges[idx] = newEdge
                    }
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName(actionName)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName(actionName)
        }
        isDirty = true
        undoManager?.setActionName(actionName)
    }

    // MARK: - Multi-Select Batch Apply

    /// Applies form state from the multi-select inspector to all selected nodes
    /// in a single undoable step. Only fields that are enabled AND have content are applied.
    func batchApplyMultiSelectChanges(
        nodeIDs: Set<UUID>,
        formState: MultiSelectFormState,
        commonCategories: Set<InspectorFieldCategory>
    ) {
        let changingLock = formState.enabledFields.contains("lockState")

        // Filter out details-locked nodes — but always allow lock state changes
        let editableIDs: Set<UUID>
        if changingLock {
            editableIDs = nodeIDs  // Lock changes apply to all nodes
        } else {
            editableIDs = nodeIDs.filter { id in
                guard let idx = nodeIndex(for: id) else { return false }
                return !nodes[idx].isDetailsLocked
            }
        }
        guard !editableIDs.isEmpty else { return }

        // Snapshot old state (GraphNode is a struct — value copy)
        let oldSnapshots: [(id: UUID, node: GraphNode)] = editableIDs.compactMap { id in
            guard let idx = nodeIndex(for: id) else { return nil }
            return (id, nodes[idx])
        }

        // Apply enabled fields to each node
        for id in editableIDs {
            guard let idx = nodeIndex(for: id) else { continue }

            // Lock state always applies regardless of current lock
            if changingLock {
                nodes[idx].lockState = formState.lockState
            }

            // Skip remaining fields for nodes that are still details-locked
            // (lock change was already applied above, so check updated state)
            let stillLocked = nodes[idx].isDetailsLocked
            if stillLocked && !changingLock { continue }

            // --- Universal ---
            if !stillLocked {
                if formState.enabledFields.contains("title"),
                   formState.hasContent(formState.title) {
                    nodes[idx].title = formState.title
                    let n = nodes[idx]
                    nodes[idx].size.width = GraphNode.idealWidth(
                        for: formState.title, fontSize: n.fontSize ?? 13,
                        risk: n.risk, lockState: n.lockState,
                        isComment: n.kind == .comment)
                    propagateNodeTitle(id, newTitle: formState.title)
                }

                if formState.enabledFields.contains("detail"),
                   formState.hasContent(formState.detail) {
                    nodes[idx].detail = formState.detail
                }
            }

            // All remaining fields require unlocked details
            if !stillLocked {
                if formState.enabledFields.contains("colorHex") {
                    nodes[idx].colorHex = formState.colorHex
                }

                // --- Risk ---
                if commonCategories.contains(.riskEnabled),
                   formState.enabledFields.contains("risk") {
                    nodes[idx].risk = formState.risk
                    let n = nodes[idx]
                    nodes[idx].size.width = GraphNode.idealWidth(
                        for: n.title, fontSize: n.fontSize ?? 13,
                        risk: formState.risk, lockState: n.lockState)
                }

                // --- Agent ---
                if commonCategories.contains(.agent) {
                    if formState.enabledFields.contains("agentFramework") {
                        nodes[idx].agentFramework = formState.agentFramework
                    }
                    if formState.enabledFields.contains("agentModel"),
                       formState.hasContent(formState.agentModel) {
                        nodes[idx].agentModel = formState.agentModel
                    }
                    if formState.enabledFields.contains("agentRole"),
                       formState.hasContent(formState.agentRole) {
                        nodes[idx].agentRole = formState.agentRole
                    }
                    if formState.enabledFields.contains("agentGoal"),
                       formState.hasContent(formState.agentGoal) {
                        nodes[idx].agentGoal = formState.agentGoal
                    }
                    if formState.enabledFields.contains("agentInstructions"),
                       formState.hasContent(formState.agentInstructions) {
                        nodes[idx].agentInstructions = formState.agentInstructions
                    }
                    if formState.enabledFields.contains("agentMemory") {
                        nodes[idx].agentMemory = formState.agentMemory
                    }
                    if formState.enabledFields.contains("agentMaxIterations"),
                       formState.hasContent(formState.agentMaxIterations) {
                        nodes[idx].agentMaxIterations = formState.agentMaxIterations
                    }
                    if formState.enabledFields.contains("agentCanDelegate") {
                        nodes[idx].agentCanDelegate = formState.agentCanDelegate
                    }
                }

                // --- Tool ---
                if commonCategories.contains(.tool) {
                    if formState.enabledFields.contains("toolType") {
                        nodes[idx].toolType = formState.toolType
                    }
                    if formState.enabledFields.contains("toolAsync") {
                        nodes[idx].toolAsync = formState.toolAsync
                    }
                    if formState.enabledFields.contains("toolInputs"),
                       formState.hasContent(formState.toolInputs) {
                        nodes[idx].toolInputs = formState.toolInputs
                    }
                    if formState.enabledFields.contains("toolOutputs"),
                       formState.hasContent(formState.toolOutputs) {
                        nodes[idx].toolOutputs = formState.toolOutputs
                    }
                    if formState.enabledFields.contains("toolAuthMethod") {
                        nodes[idx].toolAuthMethod = formState.toolAuthMethod
                    }
                    if formState.enabledFields.contains("toolEndpoint"),
                       formState.hasContent(formState.toolEndpoint) {
                        nodes[idx].toolEndpoint = formState.toolEndpoint
                    }
                    if formState.enabledFields.contains("toolTimeout"),
                       formState.hasContent(formState.toolTimeout) {
                        nodes[idx].toolTimeout = formState.toolTimeout
                    }
                    if formState.enabledFields.contains("toolErrorHandling") {
                        nodes[idx].toolErrorHandling = formState.toolErrorHandling
                    }
                }

                // --- Knowledge ---
                if commonCategories.contains(.knowledge) {
                    if formState.enabledFields.contains("knowledgeDataFormats"),
                       formState.hasContent(formState.knowledgeDataFormats) {
                        nodes[idx].knowledgeDataFormats = formState.knowledgeDataFormats
                    }
                    if formState.enabledFields.contains("knowledgeSizeQuantity"),
                       formState.hasContent(formState.knowledgeSizeQuantity) {
                        nodes[idx].knowledgeSizeQuantity = formState.knowledgeSizeQuantity
                    }
                    if formState.enabledFields.contains("knowledgeLocation"),
                       formState.hasContent(formState.knowledgeLocation) {
                        nodes[idx].knowledgeLocation = formState.knowledgeLocation
                    }
                    if formState.enabledFields.contains("knowledgeAccessMethod"),
                       formState.hasContent(formState.knowledgeAccessMethod) {
                        nodes[idx].knowledgeAccessMethod = formState.knowledgeAccessMethod
                    }
                    if formState.enabledFields.contains("knowledgeSensitivity"),
                       formState.hasContent(formState.knowledgeSensitivity) {
                        nodes[idx].knowledgeSensitivity = formState.knowledgeSensitivity
                    }
                    if formState.enabledFields.contains("knowledgeUpdateFrequency"),
                       formState.hasContent(formState.knowledgeUpdateFrequency) {
                        nodes[idx].knowledgeUpdateFrequency = formState.knowledgeUpdateFrequency
                    }
                    if formState.enabledFields.contains("knowledgeVersioningMethod"),
                       formState.hasContent(formState.knowledgeVersioningMethod) {
                        nodes[idx].knowledgeVersioningMethod = formState.knowledgeVersioningMethod
                    }
                }

                // --- Shape ---
                if commonCategories.contains(.shape) {
                    if formState.enabledFields.contains("strokeColorHex") {
                        nodes[idx].strokeColorHex = formState.strokeColorHex
                    }
                    if formState.enabledFields.contains("fillEnabled") {
                        nodes[idx].fillEnabled = formState.fillEnabled
                    }
                    if formState.enabledFields.contains("fillColorHex") {
                        nodes[idx].fillColorHex = formState.fillColorHex
                    }
                }

                // --- Text Shape ---
                if commonCategories.contains(.textShape) {
                    if formState.enabledFields.contains("fontSize"),
                       formState.hasContent(formState.fontSize),
                       let size = Double(formState.fontSize) {
                        nodes[idx].fontSize = CGFloat(size)
                    }
                    if formState.enabledFields.contains("fontColorHex") {
                        nodes[idx].fontColorHex = formState.fontColorHex
                    }
                }
            }
        }

        // Snapshot new state for redo
        let newSnapshots: [(id: UUID, node: GraphNode)] = editableIDs.compactMap { id in
            guard let idx = nodeIndex(for: id) else { return nil }
            return (id, nodes[idx])
        }

        let actionName = "Apply to \(editableIDs.count) Nodes"
        undoManager?.registerUndo(withTarget: self) { [oldSnapshots, newSnapshots] doc in
            // Undo: restore old state
            for (id, oldNode) in oldSnapshots {
                if let idx = doc.nodeIndex(for: id) {
                    doc.nodes[idx] = oldNode
                }
            }
            // Register redo: restore new state
            doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                for (id, newNode) in newSnapshots {
                    if let idx = doc2.nodeIndex(for: id) {
                        doc2.nodes[idx] = newNode
                    }
                }
                doc2.isDirty = true
                doc2.undoManager?.setActionName(actionName)
            }
            doc.isDirty = true
            doc.undoManager?.setActionName(actionName)
        }
        isDirty = true
        undoManager?.setActionName(actionName)
    }
}

// MARK: - Port Position Tracking

struct PortAddress: Hashable {
    let nodeID: UUID
    let portID: UUID
}

struct PortPositionKey: PreferenceKey {
    static let defaultValue: [PortAddress: CGPoint] = [:]
    static func reduce(value: inout [PortAddress: CGPoint],
                       nextValue: () -> [PortAddress: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
