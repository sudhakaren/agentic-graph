import SwiftUI

struct CanvasView: View {
    @Bindable var document: GraphDocument
    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                ZStack {
                    // Canvas content layer — frame sized to cover all node positions
                    ZStack {
                        // Layer 1: Shapes (below edges)
                        ForEach(document.nodes.filter { $0.kind.isShape && !document.hiddenNodeKinds.contains($0.kind) }) { node in
                            NodeView(nodeID: node.id, document: document)
                        }

                        // Layer 2: Edges
                        EdgeLayerView(document: document)

                        // Layer 3: Graph nodes (above edges)
                        ForEach(document.nodes.filter { !$0.kind.isShape && !document.hiddenNodeKinds.contains($0.kind) }) { node in
                            NodeView(nodeID: node.id, document: document)
                        }
                    }
                    .frame(width: document.contentExtent,
                           height: document.contentExtent,
                           alignment: .topLeading)
                    .coordinateSpace(name: "canvas")
                    .scaleEffect(document.canvasScale, anchor: .topLeading)
                    .offset(document.canvasOffset)
                    .onPreferenceChange(PortPositionKey.self) { positions in
                        // Guard: @Observable always notifies on set, even
                        // when the value is identical.  Skipping the write
                        // prevents EdgeLayerView from re-rendering every
                        // zoom frame when port positions haven't moved.
                        if document.portPositions != positions {
                            document.portPositions = positions
                        }
                    }

                    // Marquee selection rectangle
                    if let rect = document.marqueeRect {
                        let scaledRect = CGRect(
                            x: rect.origin.x * document.canvasScale + document.canvasOffset.width,
                            y: rect.origin.y * document.canvasScale + document.canvasOffset.height,
                            width: rect.width * document.canvasScale,
                            height: rect.height * document.canvasScale
                        )
                        Rectangle()
                            .stroke(Color.accentColor, lineWidth: 1)
                            .background(Color.accentColor.opacity(0.08))
                            .frame(width: abs(scaledRect.width), height: abs(scaledRect.height))
                            .position(x: scaledRect.midX, y: scaledRect.midY)
                            .allowsHitTesting(false)
                    }

                    // NSView overlay handles ALL mouse interaction
                    CanvasMouseHandler(document: document)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    document.canvasViewportSize = geometry.size
                    // For new blank documents, center viewport on the canvas origin
                    if document.nodes.isEmpty && document.canvasOffset == .zero && document.canvasScale == 1.0 {
                        let ro = document.renderOffset
                        document.canvasOffset = CGSize(
                            width: geometry.size.width / 2 - ro,
                            height: geometry.size.height / 2 - ro
                        )
                    }
                    if document.needsZoomToFit {
                        document.needsZoomToFit = false
                        DispatchQueue.main.async {
                            document.zoomToFit()
                        }
                    }
                }
                .onChange(of: geometry.size) { _, newSize in
                    document.canvasViewportSize = newSize
                    if document.needsZoomToFit {
                        document.needsZoomToFit = false
                        DispatchQueue.main.async {
                            document.zoomToFit()
                        }
                    }
                }
                .dropDestination(for: NodeKind.self) { items, location in
                    let framePoint = screenToCanvas(location)
                    let modelPoint = CGPoint(x: framePoint.x - document.renderOffset,
                                             y: framePoint.y - document.renderOffset)
                    let allowedItems = items.filter { !document.hiddenNodeKinds.contains($0) }
                    guard !allowedItems.isEmpty else { return false }
                    for kind in allowedItems {
                        let node = GraphNode.make(kind: kind, at: modelPoint)
                        document.addNode(node)
                        document.selectedNodeID = node.id
                    }
                    return true
                } isTargeted: { targeted in
                    isDropTargeted = targeted
                }
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
            }
            .background(document.darkCanvas ? Color(white: 0.15) : Color(white: 0.88))

            // Floating Find panel (⌘F) — pinned top-leading, never scaled with the canvas.
            if document.showFindPanel {
                FindPanel(document: document)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity)
            }

            // ZoomBar lives outside the GeometryReader so it's never affected
            // by the canvas content size, scale, or offset transforms.
            ZoomBar(document: document)
                .padding(.bottom, 12)
        }
        .animation(.easeOut(duration: 0.12), value: document.showFindPanel)
    }

    private func screenToCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - document.canvasOffset.width) / document.canvasScale,
            y: (point.y - document.canvasOffset.height) / document.canvasScale
        )
    }

}

// MARK: - Zoom Controls Bar

struct ZoomBar: View {
    @Bindable var document: GraphDocument
    @AppStorage("zoomLocked") private var zoomLockedPersisted: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Button { document.zoomOut() } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)

            Text("\(Int(document.canvasScale * 100))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 42)

            Divider()
                .frame(height: 16)

            Button { document.zoomIn() } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)

            Button { document.zoomReset() } label: {
                Text("1:1")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)

            Button { document.zoomToFit() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)

            Button {
                zoomLockedPersisted.toggle()
                document.zoomLocked = zoomLockedPersisted
            } label: {
                Image(systemName: document.zoomLocked ? "lock.fill" : "lock.open")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(document.zoomLocked ? .orange : .primary)
            }
            .buttonStyle(.plain)
            .help(document.zoomLocked ? "Unlock scroll zoom" : "Lock scroll zoom")
            .onAppear { document.zoomLocked = zoomLockedPersisted }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - NSView Mouse Handler

/// Handles all mouse events for the canvas: node dragging, panning, selection, shape resizing.
/// Bypasses SwiftUI gesture system entirely to avoid ghosting artefacts.
struct CanvasMouseHandler: NSViewRepresentable {
    @Bindable var document: GraphDocument

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.document = document
        return view
    }

    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        nsView.document = document
    }
}

enum ResizeHandle: CaseIterable {
    case topLeft, topCenter, topRight
    case leftCenter, rightCenter
    case bottomLeft, bottomCenter, bottomRight
}

class CanvasNSView: NSView {
    var document: GraphDocument?

    private enum DragMode {
        case none
        case movingNode(nodeIndex: Int, startPosition: CGPoint, mouseStart: CGPoint)
        case movingNodes(nodeStarts: [(index: Int, startPosition: CGPoint)], mouseStart: CGPoint)
        case panningCanvas(startOffset: CGSize, mouseStart: CGPoint)
        case draggingEdge(sourceNodeID: UUID, sourcePortID: UUID)
        case resizingShape(nodeID: UUID, handle: ResizeHandle,
                           startSize: CGSize, startPosition: CGPoint, mouseStart: CGPoint)
        case marqueeSelection(startPoint: CGPoint)
    }

    private var dragMode: DragMode = .none

    // Click-to-cycle: repeated clicks at the same spot cycle through overlapping nodes.
    // Cycling is deferred to mouseUp so that click-drag doesn't trigger it.
    private var lastClickCanvasPoint: CGPoint?
    private var cycleIndex: Int = 0
    private var pendingCycleHits: [Int] = []  // non-empty = cycle on mouseUp if no drag

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        // Backspace (51) or Forward Delete (117)
        if event.keyCode == 51 || event.keyCode == 117 {
            document?.deleteSelectedItem()
        } else if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c":
                document?.copySelectedNodes()
            case "v":
                document?.pasteNodes()
            case "a":
                guard let document else { return }
                document.selectedNodeIDs = Set(document.nodes.map(\.id))
                document.selectedNodeID = document.nodes.first?.id
                document.selectedEdgeIDs = Set(document.edges.map(\.id))
                document.selectedEdgeID = document.edges.first?.id
            case "g":
                if event.modifierFlags.contains(.shift) {
                    document?.ungroupSelectedNodes()
                } else {
                    document?.groupSelectedNodes()
                }
            default:
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let document else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = screenToCanvas(viewPoint, document: document)
        let shiftHeld = event.modifierFlags.contains(.shift)
        let optionHeld = event.modifierFlags.contains(.option)

        // 0. Hit test resize handles on selected shape (skip if position-locked)
        if let handle = hitTestResizeHandle(at: canvasPoint, in: document),
           let selectedID = document.selectedNodeID,
           let node = document.node(for: selectedID),
           !node.isPositionLocked {
            dragMode = .resizingShape(
                nodeID: selectedID, handle: handle,
                startSize: node.size, startPosition: node.position,
                mouseStart: canvasPoint
            )
            return
        }

        // 1. Hit test ports first (they're small targets on top of nodes)
        if let hitPort = hitTestPort(at: canvasPoint, in: document) {
            // If the port already has a connected edge, select that edge
            let connectedEdge = document.edges.first(where: {
                ($0.sourceNodeID == hitPort.nodeID && $0.sourcePortID == hitPort.portID) ||
                ($0.targetNodeID == hitPort.nodeID && $0.targetPortID == hitPort.portID)
            })
            if let edge = connectedEdge {
                document.selectedEdgeID = edge.id
                document.selectedEdgeIDs = []
                document.selectedNodeID = nil
                document.selectedNodeIDs = []
                dragMode = .none
            } else {
                // No edge connected — start new edge drag
                document.selectedEdgeID = nil
                document.selectedEdgeIDs = []
                document.dragSourceNodeID = hitPort.nodeID
                document.dragSourcePortID = hitPort.portID
                document.dragCurrentEndpoint = canvasPoint
                dragMode = .draggingEdge(sourceNodeID: hitPort.nodeID, sourcePortID: hitPort.portID)
            }
            return
        }

        // 2. Hit test nodes (before edges, so nodes take priority over edges passing under them)
        let allHits = hitTestAllNodes(at: canvasPoint, in: document)
        if let hitIndex = allHits.first {
            let hitNodeID = document.nodes[hitIndex].id

            // --- Click-to-cycle bookkeeping ---
            // Cycling is deferred to mouseUp (so click-drag doesn't trigger it).
            // Here we just decide whether a cycle COULD happen and record allHits.
            let isSameSpot: Bool = {
                guard let lastPt = lastClickCanvasPoint else { return false }
                return hypot(canvasPoint.x - lastPt.x, canvasPoint.y - lastPt.y) < 5
            }()

            if !shiftHeld && allHits.count > 1 && isSameSpot
                && document.allSelectedNodeIDs.count <= 1 {
                // Record pending cycle — will execute in mouseUp if no drag
                pendingCycleHits = allHits
            } else {
                pendingCycleHits = []
                if !isSameSpot || allHits.count <= 1 {
                    cycleIndex = 0
                }
            }
            lastClickCanvasPoint = canvasPoint

            // Always act on the topmost node at mouseDown time
            if shiftHeld {
                // Shift-click: toggle node in multi-selection
                if document.selectedNodeIDs.contains(hitNodeID) {
                    document.selectedNodeIDs.remove(hitNodeID)
                    if document.selectedNodeID == hitNodeID {
                        document.selectedNodeID = document.selectedNodeIDs.first
                    }
                } else {
                    // Promote single selection to multi-selection if needed
                    if let singleID = document.selectedNodeID, document.selectedNodeIDs.isEmpty {
                        document.selectedNodeIDs.insert(singleID)
                    }
                    document.selectedNodeIDs.insert(hitNodeID)
                    document.selectedNodeID = hitNodeID
                }
                pendingCycleHits = []
                // Start multi-node drag for all selected (expand groups, filter locked)
                var allIDs = document.allSelectedNodeIDs
                for id in document.allSelectedNodeIDs {
                    allIDs.formUnion(document.groupMembers(of: id))
                }
                if !allIDs.isEmpty {
                    let nodeStarts = allIDs.compactMap { id -> (index: Int, startPosition: CGPoint)? in
                        guard let idx = document.nodeIndex(for: id) else { return nil }
                        guard !document.nodes[idx].isPositionLocked else { return nil }
                        return (idx, document.nodes[idx].position)
                    }
                    document.isDraggingNode = true
                    dragMode = nodeStarts.isEmpty ? .none : .movingNodes(nodeStarts: nodeStarts, mouseStart: viewPoint)
                    if nodeStarts.isEmpty { document.isDraggingNode = false }
                }
            } else if document.allSelectedNodeIDs.contains(hitNodeID) && document.allSelectedNodeIDs.count > 1 {
                // Click on already-selected node in multi-selection: clear edges, start multi-node drag
                pendingCycleHits = []
                document.selectedEdgeID = nil
                document.selectedEdgeIDs = []
                var allIDs = document.allSelectedNodeIDs
                for id in document.allSelectedNodeIDs {
                    allIDs.formUnion(document.groupMembers(of: id))
                }
                let nodeStarts = allIDs.compactMap { id -> (index: Int, startPosition: CGPoint)? in
                    guard let idx = document.nodeIndex(for: id) else { return nil }
                    guard !document.nodes[idx].isPositionLocked else { return nil }
                    return (idx, document.nodes[idx].position)
                }
                document.isDraggingNode = true
                dragMode = nodeStarts.isEmpty ? .none : .movingNodes(nodeStarts: nodeStarts, mouseStart: viewPoint)
                if nodeStarts.isEmpty { document.isDraggingNode = false }
            } else {
                // Click on node (no shift): single select, clear edges
                document.selectedEdgeID = nil
                document.selectedEdgeIDs = []
                document.selectedNodeIDs = []
                document.selectedNodeID = hitNodeID

                // If node is in a group, drag all group members together
                let groupMembers = document.groupMembers(of: hitNodeID)
                if groupMembers.count > 1 {
                    pendingCycleHits = []
                    let nodeStarts = groupMembers.compactMap { id -> (index: Int, startPosition: CGPoint)? in
                        guard let idx = document.nodeIndex(for: id) else { return nil }
                        guard !document.nodes[idx].isPositionLocked else { return nil }
                        return (idx, document.nodes[idx].position)
                    }
                    if nodeStarts.isEmpty {
                        dragMode = .none
                        document.isDraggingNode = false
                    } else {
                        document.isDraggingNode = true
                        dragMode = .movingNodes(nodeStarts: nodeStarts, mouseStart: viewPoint)
                    }
                } else if document.nodes[hitIndex].isPositionLocked {
                    dragMode = .none
                    document.isDraggingNode = false
                } else {
                    document.isDraggingNode = true
                    dragMode = .movingNode(
                        nodeIndex: hitIndex,
                        startPosition: document.nodes[hitIndex].position,
                        mouseStart: viewPoint
                    )
                }
            }
        } else if let hitEdgeID = hitTestEdge(at: canvasPoint, in: document) {
            // 3. Hit test edges (only if no node was hit) — reset cycle
            lastClickCanvasPoint = nil
            cycleIndex = 0
            if shiftHeld {
                // Shift-click: toggle edge in multi-selection
                if document.selectedEdgeIDs.contains(hitEdgeID) {
                    document.selectedEdgeIDs.remove(hitEdgeID)
                    if document.selectedEdgeID == hitEdgeID {
                        document.selectedEdgeID = document.selectedEdgeIDs.first
                    }
                } else {
                    if let singleID = document.selectedEdgeID, document.selectedEdgeIDs.isEmpty {
                        document.selectedEdgeIDs.insert(singleID)
                    }
                    document.selectedEdgeIDs.insert(hitEdgeID)
                    document.selectedEdgeID = hitEdgeID
                }
            } else {
                // Single click: select just this edge
                document.selectedEdgeID = hitEdgeID
                document.selectedEdgeIDs = []
                document.selectedNodeID = nil
                document.selectedNodeIDs = []
            }
            dragMode = .none
        } else {
            // 4. Click on empty canvas
            if optionHeld || event.buttonNumber == 1 {
                // Option+click or right-click: pan canvas
                if !shiftHeld {
                    document.selectedNodeID = nil
                    document.selectedNodeIDs = []
                    document.selectedEdgeID = nil
                    document.selectedEdgeIDs = []
                }
                dragMode = .panningCanvas(
                    startOffset: document.canvasOffset,
                    mouseStart: viewPoint
                )
            } else {
                // Regular click on empty: start marquee selection
                if !shiftHeld {
                    document.selectedNodeID = nil
                    document.selectedNodeIDs = []
                    document.selectedEdgeID = nil
                    document.selectedEdgeIDs = []
                }
                dragMode = .marqueeSelection(startPoint: canvasPoint)
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let document else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)

        switch dragMode {
        case .movingNode(let nodeIndex, let startPosition, let mouseStart):
            guard nodeIndex < document.nodes.count else { return }
            guard !document.nodes[nodeIndex].isPositionLocked else { return }
            let dx = (viewPoint.x - mouseStart.x) / document.canvasScale
            let dy = (viewPoint.y - mouseStart.y) / document.canvasScale
            document.nodes[nodeIndex].position = CGPoint(
                x: startPosition.x + dx,
                y: startPosition.y + dy
            )

        case .movingNodes(let nodeStarts, let mouseStart):
            let dx = (viewPoint.x - mouseStart.x) / document.canvasScale
            let dy = (viewPoint.y - mouseStart.y) / document.canvasScale
            for (nodeIndex, startPosition) in nodeStarts {
                guard nodeIndex < document.nodes.count else { continue }
                document.nodes[nodeIndex].position = CGPoint(
                    x: startPosition.x + dx,
                    y: startPosition.y + dy
                )
            }

        case .panningCanvas(let startOffset, let mouseStart):
            let dx = viewPoint.x - mouseStart.x
            let dy = viewPoint.y - mouseStart.y
            document.canvasOffset = CGSize(
                width: startOffset.width + dx,
                height: startOffset.height + dy
            )

        case .draggingEdge:
            let canvasPoint = screenToCanvas(viewPoint, document: document)
            document.dragCurrentEndpoint = canvasPoint

        case .marqueeSelection(let startPoint):
            let canvasPoint = screenToCanvas(viewPoint, document: document)
            document.marqueeRect = normalizedRect(from: startPoint, to: canvasPoint)

        case .resizingShape(let nodeID, let handle, let startSize, let startPosition, let mouseStart):
            guard let idx = document.nodeIndex(for: nodeID) else { return }
            guard !document.nodes[idx].isPositionLocked else { return }
            let canvasPoint = screenToCanvas(viewPoint, document: document)
            let dx = canvasPoint.x - mouseStart.x
            let dy = canvasPoint.y - mouseStart.y
            let minSize: CGFloat = 30

            var newW = startSize.width
            var newH = startSize.height
            var newCX = startPosition.x
            var newCY = startPosition.y

            switch handle {
            case .topLeft:
                newW = max(minSize, startSize.width - dx)
                newH = max(minSize, startSize.height - dy)
                newCX = startPosition.x + (startSize.width - newW) / 2
                newCY = startPosition.y + (startSize.height - newH) / 2
            case .topRight:
                newW = max(minSize, startSize.width + dx)
                newH = max(minSize, startSize.height - dy)
                newCX = startPosition.x + (newW - startSize.width) / 2
                newCY = startPosition.y + (startSize.height - newH) / 2
            case .bottomLeft:
                newW = max(minSize, startSize.width - dx)
                newH = max(minSize, startSize.height + dy)
                newCX = startPosition.x + (startSize.width - newW) / 2
                newCY = startPosition.y + (newH - startSize.height) / 2
            case .bottomRight:
                newW = max(minSize, startSize.width + dx)
                newH = max(minSize, startSize.height + dy)
                newCX = startPosition.x + (newW - startSize.width) / 2
                newCY = startPosition.y + (newH - startSize.height) / 2
            case .topCenter:
                newH = max(minSize, startSize.height - dy)
                newCY = startPosition.y + (startSize.height - newH) / 2
            case .bottomCenter:
                newH = max(minSize, startSize.height + dy)
                newCY = startPosition.y + (newH - startSize.height) / 2
            case .leftCenter:
                newW = max(minSize, startSize.width - dx)
                newCX = startPosition.x + (startSize.width - newW) / 2
            case .rightCenter:
                newW = max(minSize, startSize.width + dx)
                newCX = startPosition.x + (newW - startSize.width) / 2
            }

            document.nodes[idx].size = CGSize(width: newW, height: newH)
            document.nodes[idx].position = CGPoint(x: newCX, y: newCY)

        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let document else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)

        switch dragMode {
        case .draggingEdge(let dragNodeID, let dragPortID):
            pendingCycleHits = []
            let canvasPoint = screenToCanvas(viewPoint, document: document)

            // Determine if we dragged from an input or output port
            let dragNode = document.node(for: dragNodeID)
            let dragPort = dragNode?.ports.first(where: { $0.id == dragPortID })
            let draggedFromInput = dragPort?.kind == .input

            // 1. Try to find a matching port of the opposite kind nearby
            let requiredKind: PortKind = draggedFromInput ? .output : .input
            if let targetAddr = findNearestPort(at: canvasPoint, excludingNode: dragNodeID,
                                                 requiredKind: requiredKind, in: document) {
                if draggedFromInput {
                    let edge = GraphEdge(sourceNodeID: targetAddr.nodeID, sourcePortID: targetAddr.portID,
                                         targetNodeID: dragNodeID, targetPortID: dragPortID)
                    document.addEdge(edge)
                } else {
                    let edge = GraphEdge(sourceNodeID: dragNodeID, sourcePortID: dragPortID,
                                         targetNodeID: targetAddr.nodeID, targetPortID: targetAddr.portID)
                    document.addEdge(edge)
                }
            }
            // 2. No matching port found — try dropping on a node to auto-create
            else if let targetIndex = hitTestNode(at: canvasPoint, in: document),
                    document.nodes[targetIndex].id != dragNodeID {
                let targetNode = document.nodes[targetIndex]

                if draggedFromInput {
                    document.createConnection(fromNode: targetNode.id, toNode: dragNodeID,
                                              targetPortID: dragPortID)
                } else {
                    let inputPort: NodePort
                    if let firstInput = targetNode.ports.first(where: { $0.kind == .input }) {
                        inputPort = firstInput
                    } else {
                        // No input ports — auto-create one, labeled with source node's title
                        let sourceTitle = document.nodes.first(where: { $0.id == dragNodeID })?.title ?? "In 1"
                        let newInput = NodePort(label: sourceTitle, kind: .input)
                        document.nodes[targetIndex].ports.append(newInput)
                        inputPort = newInput
                    }
                    let edge = GraphEdge(sourceNodeID: dragNodeID, sourcePortID: dragPortID,
                                         targetNodeID: targetNode.id, targetPortID: inputPort.id)
                    document.addEdge(edge)
                }
            }

        case .movingNode(let nodeIndex, let startPosition, _):
            // Register undo for single node move
            guard nodeIndex < document.nodes.count else { break }
            let nodeID = document.nodes[nodeIndex].id
            let finalPosition = document.nodes[nodeIndex].position
            if finalPosition != startPosition {
                // Node was dragged — cancel any pending cycle
                pendingCycleHits = []
                document.undoManager?.registerUndo(withTarget: document) { [startPosition] doc in
                    guard let i = doc.nodeIndex(for: nodeID) else { return }
                    let curPos = doc.nodes[i].position
                    doc.nodes[i].position = startPosition
                    doc.updateContentExtent()
                    doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                        guard let j = doc2.nodeIndex(for: nodeID) else { return }
                        doc2.nodes[j].position = curPos
                        doc2.updateContentExtent()
                        doc2.undoManager?.setActionName("Move Node")
                    }
                    doc.isDirty = true
                    doc.undoManager?.setActionName("Move Node")
                }
                document.updateContentExtent()
                document.isDirty = true
                document.undoManager?.setActionName("Move Node")
            }

        case .movingNodes(let nodeStarts, _):
            pendingCycleHits = []
            // Register undo for multi-node move
            let hasMoved = nodeStarts.contains { (index, startPos) in
                guard index < document.nodes.count else { return false }
                return document.nodes[index].position != startPos
            }
            if hasMoved {
                // Capture by node ID for robust undo (indices may shift)
                let startByID: [(id: UUID, position: CGPoint)] = nodeStarts.compactMap { (index, startPos) in
                    guard index < document.nodes.count else { return nil }
                    return (document.nodes[index].id, startPos)
                }
                let endByID: [(id: UUID, position: CGPoint)] = nodeStarts.compactMap { (index, _) in
                    guard index < document.nodes.count else { return nil }
                    return (document.nodes[index].id, document.nodes[index].position)
                }
                document.undoManager?.registerUndo(withTarget: document) { doc in
                    for (id, pos) in startByID {
                        if let idx = doc.nodeIndex(for: id) {
                            doc.nodes[idx].position = pos
                        }
                    }
                    doc.updateContentExtent()
                    doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                        for (id, pos) in endByID {
                            if let idx = doc2.nodeIndex(for: id) {
                                doc2.nodes[idx].position = pos
                            }
                        }
                        doc2.updateContentExtent()
                        doc2.undoManager?.setActionName("Move Nodes")
                    }
                    doc.isDirty = true
                    doc.undoManager?.setActionName("Move Nodes")
                }
                document.updateContentExtent()
                document.isDirty = true
                document.undoManager?.setActionName("Move Nodes")
            }

        case .marqueeSelection:
            pendingCycleHits = []
            if let rect = document.marqueeRect, rect.width > 2 || rect.height > 2 {
                let selectedNodes = nodesInRect(rect, in: document)
                let selectedEdges = edgesInRect(rect, in: document)
                if event.modifierFlags.contains(.shift) {
                    // Shift: add to existing selection
                    document.selectedNodeIDs.formUnion(selectedNodes)
                    document.selectedEdgeIDs.formUnion(selectedEdges)
                } else {
                    document.selectedNodeIDs = selectedNodes
                    document.selectedEdgeIDs = selectedEdges
                }
                document.selectedNodeID = document.selectedNodeIDs.first
                document.selectedEdgeID = document.selectedEdgeIDs.first
            }
            document.marqueeRect = nil

        case .resizingShape(let nodeID, _, let startSize, let startPosition, _):
            pendingCycleHits = []
            if let idx = document.nodeIndex(for: nodeID) {
                let finalSize = document.nodes[idx].size
                let finalPos = document.nodes[idx].position
                if finalSize != startSize || finalPos != startPosition {
                    document.undoManager?.registerUndo(withTarget: document) { [startSize, startPosition] doc in
                        guard let i = doc.nodeIndex(for: nodeID) else { return }
                        let curSize = doc.nodes[i].size
                        let curPos = doc.nodes[i].position
                        doc.nodes[i].size = startSize
                        doc.nodes[i].position = startPosition
                        doc.updateContentExtent()
                        doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                            guard let j = doc2.nodeIndex(for: nodeID) else { return }
                            doc2.nodes[j].size = curSize
                            doc2.nodes[j].position = curPos
                            doc2.updateContentExtent()
                            doc2.undoManager?.setActionName("Resize Shape")
                        }
                        doc.undoManager?.setActionName("Resize Shape")
                    }
                    document.updateContentExtent()
                    document.undoManager?.setActionName("Resize Shape")
                }
            }

        default:
            break
        }

        // Execute deferred click-to-cycle if this was a click (no drag)
        if !pendingCycleHits.isEmpty {
            cycleIndex = (cycleIndex + 1) % pendingCycleHits.count
            let cycledIndex = pendingCycleHits[cycleIndex]
            if cycledIndex < document.nodes.count {
                document.selectedNodeID = document.nodes[cycledIndex].id
                document.selectedNodeIDs = []
            }
        }

        // Always clear drag state and pending cycle — must be outside the switch
        pendingCycleHits = []
        document.dragSourceNodeID = nil
        document.dragSourcePortID = nil
        document.dragCurrentEndpoint = nil
        document.isDraggingNode = false
        document.marqueeRect = nil
        dragMode = .none
    }

    // MARK: - Right-Click Context Menu / Panning

    override func rightMouseDown(with event: NSEvent) {
        guard let document else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = screenToCanvas(viewPoint, document: document)

        // Hit-test for a node
        if let hitIndex = hitTestNode(at: canvasPoint, in: document) {
            let hitNodeID = document.nodes[hitIndex].id

            // Ensure clicked node is selected
            if !document.allSelectedNodeIDs.contains(hitNodeID) {
                document.selectedNodeID = hitNodeID
                document.selectedNodeIDs = []
            }

            // Build context menu
            let menu = NSMenu()

            let cutItem = NSMenuItem(title: "Cut", action: #selector(contextCut), keyEquivalent: "")
            cutItem.target = self
            menu.addItem(cutItem)

            let copyItem = NSMenuItem(title: "Copy", action: #selector(contextCopy), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            let pasteItem = NSMenuItem(title: "Paste", action: #selector(contextPaste), keyEquivalent: "")
            pasteItem.target = self
            pasteItem.isEnabled = !document.clipboard.isEmpty
            menu.addItem(pasteItem)

            let deleteItem = NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)

            // Align submenu (2+ nodes)
            if document.canAlign {
                menu.addItem(NSMenuItem.separator())

                let alignMenu = NSMenu()
                for (title, sel) in [
                    ("Left", #selector(alignLeft)),
                    ("Center", #selector(alignCenterH)),
                    ("Right", #selector(alignRight))
                ] {
                    let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
                    item.target = self
                    alignMenu.addItem(item)
                }
                alignMenu.addItem(NSMenuItem.separator())
                for (title, sel) in [
                    ("Top", #selector(alignTop)),
                    ("Middle", #selector(alignCenterV)),
                    ("Bottom", #selector(alignBottom))
                ] {
                    let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
                    item.target = self
                    alignMenu.addItem(item)
                }

                let alignItem = NSMenuItem(title: "Align", action: nil, keyEquivalent: "")
                alignItem.submenu = alignMenu
                menu.addItem(alignItem)
            }

            // Distribute submenu (3+ nodes)
            if document.canDistribute {
                let distMenu = NSMenu()
                let hItem = NSMenuItem(title: "Horizontally", action: #selector(distributeHorizontal), keyEquivalent: "")
                hItem.target = self
                distMenu.addItem(hItem)
                let vItem = NSMenuItem(title: "Vertically", action: #selector(distributeVertical), keyEquivalent: "")
                vItem.target = self
                distMenu.addItem(vItem)

                let distItem = NSMenuItem(title: "Distribute", action: nil, keyEquivalent: "")
                distItem.submenu = distMenu
                menu.addItem(distItem)
            }

            // Z-order for shapes
            let node = document.nodes[hitIndex]
            if node.kind.isShape {
                let shapeCount = document.nodes.filter { $0.kind.isShape }.count
                if shapeCount > 1 {
                    menu.addItem(NSMenuItem.separator())
                    for (title, sel) in [
                        ("Bring Forward", #selector(shapeBringForward)),
                        ("Send Backward", #selector(shapeSendBackward)),
                        ("Bring to Front", #selector(shapeBringToFront)),
                        ("Send to Back", #selector(shapeSendToBack))
                    ] {
                        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
                        item.target = self
                        menu.addItem(item)
                    }
                }
            }

            // Group / Ungroup
            if document.canGroup || document.canUngroup {
                menu.addItem(NSMenuItem.separator())
                if document.canGroup {
                    let groupItem = NSMenuItem(title: "Group Selection", action: #selector(contextGroup), keyEquivalent: "")
                    groupItem.target = self
                    menu.addItem(groupItem)
                }
                if document.canUngroup {
                    let ungroupItem = NSMenuItem(title: "Ungroup", action: #selector(contextUngroup), keyEquivalent: "")
                    ungroupItem.target = self
                    menu.addItem(ungroupItem)
                }
            }

            // Select submenu — shows all overlapping nodes at the click point
            let allHits = hitTestAllNodes(at: canvasPoint, in: document)
            if allHits.count > 1 {
                menu.addItem(NSMenuItem.separator())
                let selectMenu = NSMenu()
                for idx in allHits {
                    let node = document.nodes[idx]
                    let label = node.title.isEmpty ? node.kind.rawValue : node.title
                    let isCurrentlySelected = document.allSelectedNodeIDs.contains(node.id)
                    let item = NSMenuItem(
                        title: label,
                        action: #selector(contextSelectNode(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.representedObject = node.id
                    if isCurrentlySelected { item.state = .on }
                    selectMenu.addItem(item)
                }
                let selectItem = NSMenuItem(title: "Select", action: nil, keyEquivalent: "")
                selectItem.submenu = selectMenu
                menu.addItem(selectItem)
            }

            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }

        // No node hit — pan canvas
        dragMode = .panningCanvas(
            startOffset: document.canvasOffset,
            mouseStart: viewPoint
        )
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard let document else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        if case .panningCanvas(let startOffset, let mouseStart) = dragMode {
            let dx = viewPoint.x - mouseStart.x
            let dy = viewPoint.y - mouseStart.y
            document.canvasOffset = CGSize(
                width: startOffset.width + dx,
                height: startOffset.height + dy
            )
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        dragMode = .none
    }

    // MARK: - Context Menu Actions

    @objc private func contextCut() {
        document?.copySelectedNodes()
        document?.deleteSelectedItem()
    }

    @objc private func contextCopy() {
        document?.copySelectedNodes()
    }

    @objc private func contextPaste() {
        document?.pasteNodes()
    }

    @objc private func contextDelete() {
        document?.deleteSelectedItem()
    }

    @objc private func alignLeft() { document?.alignSelectedNodes(.left) }
    @objc private func alignCenterH() { document?.alignSelectedNodes(.centerH) }
    @objc private func alignRight() { document?.alignSelectedNodes(.right) }
    @objc private func alignTop() { document?.alignSelectedNodes(.top) }
    @objc private func alignCenterV() { document?.alignSelectedNodes(.centerV) }
    @objc private func alignBottom() { document?.alignSelectedNodes(.bottom) }

    @objc private func distributeHorizontal() { document?.distributeSelectedNodes(.horizontal) }
    @objc private func distributeVertical() { document?.distributeSelectedNodes(.vertical) }

    @objc private func contextGroup() { document?.groupSelectedNodes() }
    @objc private func contextUngroup() { document?.ungroupSelectedNodes() }

    @objc private func shapeBringForward() {
        guard let id = document?.selectedNodeID else { return }
        document?.bringShapeForward(id: id)
    }
    @objc private func shapeSendBackward() {
        guard let id = document?.selectedNodeID else { return }
        document?.sendShapeBackward(id: id)
    }
    @objc private func shapeBringToFront() {
        guard let id = document?.selectedNodeID else { return }
        document?.bringShapeToFront(id: id)
    }
    @objc private func shapeSendToBack() {
        guard let id = document?.selectedNodeID else { return }
        document?.sendShapeToBack(id: id)
    }

    @objc private func contextSelectNode(_ sender: NSMenuItem) {
        guard let nodeID = sender.representedObject as? UUID else { return }
        document?.selectedNodeID = nodeID
        document?.selectedNodeIDs = []
        document?.selectedEdgeID = nil
        document?.selectedEdgeIDs = []
    }

    override func scrollWheel(with event: NSEvent) {
        guard let document else { return }
        // Don't pan/zoom while dragging/resizing
        if case .none = dragMode {} else { return }

        // Distinguish a trackpad two-finger drag from a mouse wheel scroll.
        // Trackpad gestures carry a non-zero `phase` (during the drag) or
        // `momentumPhase` (during inertial scrolling); mouse wheels have neither.
        let isTrackpadGesture = event.phase != [] || event.momentumPhase != []

        if isTrackpadGesture {
            // Two-finger drag on trackpad → pan the canvas.
            // scrollingDeltaX/Y are already in the correct direction.
            document.canvasOffset = CGSize(
                width: document.canvasOffset.width + event.scrollingDeltaX,
                height: document.canvasOffset.height + event.scrollingDeltaY
            )
            return
        }

        // Traditional mouse wheel → zoom (respects zoom lock).
        if document.zoomLocked { return }
        let delta = event.scrollingDeltaY
        let factor: CGFloat = delta > 0 ? 1.02 : 0.98
        let newScale = min(max(document.canvasScale * factor, 0.2), 3.0)

        // Zoom toward cursor: keep the canvas point under the mouse fixed
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = screenToCanvas(viewPoint, document: document)

        document.canvasScale = newScale

        // Adjust offset so canvasPoint still maps to viewPoint
        document.canvasOffset = CGSize(
            width: viewPoint.x - canvasPoint.x * newScale,
            height: viewPoint.y - canvasPoint.y * newScale
        )
    }

    override func magnify(with event: NSEvent) {
        guard let document else { return }
        // Don't zoom while dragging/resizing or when zoom is locked
        if case .none = dragMode {} else { return }
        if document.zoomLocked { return }

        // `magnification` is a delta (positive = zoom in, negative = zoom out).
        // Add 1.0 to convert to a multiplier.
        let factor: CGFloat = 1.0 + event.magnification
        let newScale = min(max(document.canvasScale * factor, 0.2), 3.0)

        // Zoom toward gesture center: keep the canvas point under the gesture fixed
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = screenToCanvas(viewPoint, document: document)

        document.canvasScale = newScale

        document.canvasOffset = CGSize(
            width: viewPoint.x - canvasPoint.x * newScale,
            height: viewPoint.y - canvasPoint.y * newScale
        )
    }

    // MARK: - Coordinate Conversion

    private func screenToCanvas(_ point: CGPoint, document: GraphDocument) -> CGPoint {
        CGPoint(
            x: (point.x - document.canvasOffset.width) / document.canvasScale,
            y: (point.y - document.canvasOffset.height) / document.canvasScale
        )
    }

    // MARK: - Hit Testing

    private func hitTestResizeHandle(at canvasPoint: CGPoint, in document: GraphDocument) -> ResizeHandle? {
        guard let selectedID = document.selectedNodeID,
              let node = document.node(for: selectedID),
              node.kind.isShape else { return nil }

        let threshold: CGFloat = 8
        let halfW = node.size.width / 2
        let halfH = node.size.height / 2
        let ro = document.renderOffset
        let cx = node.position.x + ro
        let cy = node.position.y + ro

        let handles: [(ResizeHandle, CGPoint)] = [
            (.topLeft,      CGPoint(x: cx - halfW, y: cy - halfH)),
            (.topCenter,    CGPoint(x: cx,         y: cy - halfH)),
            (.topRight,     CGPoint(x: cx + halfW, y: cy - halfH)),
            (.leftCenter,   CGPoint(x: cx - halfW, y: cy)),
            (.rightCenter,  CGPoint(x: cx + halfW, y: cy)),
            (.bottomLeft,   CGPoint(x: cx - halfW, y: cy + halfH)),
            (.bottomCenter, CGPoint(x: cx,         y: cy + halfH)),
            (.bottomRight,  CGPoint(x: cx + halfW, y: cy + halfH)),
        ]

        for (handle, pos) in handles {
            if abs(canvasPoint.x - pos.x) < threshold && abs(canvasPoint.y - pos.y) < threshold {
                return handle
            }
        }
        return nil
    }

    private func hitTestPort(at canvasPoint: CGPoint, in document: GraphDocument) -> PortAddress? {
        let portRadius: CGFloat = 10
        var bestDist: CGFloat = .infinity
        var bestAddr: PortAddress? = nil

        for (addr, pos) in document.portPositions {
            // Skip ports on hidden node kinds
            if let node = document.node(for: addr.nodeID),
               document.hiddenNodeKinds.contains(node.kind) { continue }
            let dist = hypot(pos.x - canvasPoint.x, pos.y - canvasPoint.y)
            if dist < portRadius && dist < bestDist {
                bestDist = dist
                bestAddr = addr
            }
        }
        return bestAddr
    }

    private func findNearestPort(at canvasPoint: CGPoint, excludingNode: UUID,
                                 requiredKind: PortKind? = nil, in document: GraphDocument) -> PortAddress? {
        let threshold: CGFloat = 20
        var bestDist: CGFloat = .infinity
        var bestAddr: PortAddress? = nil

        for (addr, pos) in document.portPositions {
            guard addr.nodeID != excludingNode else { continue }
            if let required = requiredKind {
                guard let node = document.node(for: addr.nodeID),
                      let port = node.ports.first(where: { $0.id == addr.portID }),
                      port.kind == required else { continue }
            }
            let dist = hypot(pos.x - canvasPoint.x, pos.y - canvasPoint.y)
            if dist < threshold && dist < bestDist {
                bestDist = dist
                bestAddr = addr
            }
        }
        return bestAddr
    }

    private func hitTestEdge(at canvasPoint: CGPoint, in document: GraphDocument) -> UUID? {
        let threshold: CGFloat = 8
        for edge in document.edges {
            guard let fromPos = document.portPositions[PortAddress(nodeID: edge.sourceNodeID, portID: edge.sourcePortID)],
                  let toPos = document.portPositions[PortAddress(nodeID: edge.targetNodeID, portID: edge.targetPortID)]
            else { continue }
            let samples = EdgeGeometry.sampleBezier(from: fromPos, to: toPos)
            for point in samples {
                if hypot(point.x - canvasPoint.x, point.y - canvasPoint.y) < threshold {
                    return edge.id
                }
            }
        }
        return nil
    }

    private func hitTestNode(at canvasPoint: CGPoint, in document: GraphDocument) -> Int? {
        // Iterate in reverse so topmost (last-added) nodes are checked first
        let ro = document.renderOffset
        for i in document.nodes.indices.reversed() {
            let node = document.nodes[i]
            guard !document.hiddenNodeKinds.contains(node.kind) else { continue }
            let halfW = node.size.width / 2
            let halfH = node.size.height / 2
            let rect = CGRect(
                x: node.position.x + ro - halfW,
                y: node.position.y + ro - halfH,
                width: node.size.width,
                height: node.size.height
            )
            if rect.contains(canvasPoint) {
                return i
            }
        }
        return nil
    }

    /// Returns ALL node indices whose bounding box contains the point,
    /// ordered topmost-first (reverse array order).
    private func hitTestAllNodes(at canvasPoint: CGPoint, in document: GraphDocument) -> [Int] {
        var hits: [Int] = []
        let ro = document.renderOffset
        for i in document.nodes.indices.reversed() {
            let node = document.nodes[i]
            guard !document.hiddenNodeKinds.contains(node.kind) else { continue }
            let halfW = node.size.width / 2
            let halfH = node.size.height / 2
            let rect = CGRect(
                x: node.position.x + ro - halfW,
                y: node.position.y + ro - halfH,
                width: node.size.width,
                height: node.size.height
            )
            if rect.contains(canvasPoint) {
                hits.append(i)
            }
        }
        return hits
    }

    // MARK: - Marquee Helpers

    private func normalizedRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }

    private func nodesInRect(_ rect: CGRect, in document: GraphDocument) -> Set<UUID> {
        var result: Set<UUID> = []
        let ro = document.renderOffset
        for node in document.nodes {
            let halfW = node.size.width / 2
            let halfH = node.size.height / 2
            let nodeRect = CGRect(
                x: node.position.x + ro - halfW,
                y: node.position.y + ro - halfH,
                width: node.size.width,
                height: node.size.height
            )
            if rect.intersects(nodeRect) {
                result.insert(node.id)
            }
        }
        return result
    }

    /// Returns edges whose bezier path intersects the given canvas rectangle.
    private func edgesInRect(_ rect: CGRect, in document: GraphDocument) -> Set<UUID> {
        let expandedRect = rect.insetBy(dx: -6, dy: -6)
        var result: Set<UUID> = []
        for edge in document.edges {
            guard let fromPos = document.portPositions[PortAddress(nodeID: edge.sourceNodeID, portID: edge.sourcePortID)],
                  let toPos = document.portPositions[PortAddress(nodeID: edge.targetNodeID, portID: edge.targetPortID)]
            else { continue }
            let samples = EdgeGeometry.sampleBezier(from: fromPos, to: toPos)
            for point in samples {
                if expandedRect.contains(point) {
                    result.insert(edge.id)
                    break
                }
            }
        }
        return result
    }
}

// MARK: - Grid Pattern

// MARK: - CGFloat Clamped

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
