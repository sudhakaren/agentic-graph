import SwiftUI

/// Renders all edges in a single Canvas draw call.
/// Much faster than per-edge Shape views during zoom because Canvas
/// is a single rasterised layer — no SwiftUI view diffing overhead.
/// The Canvas inherits its size from the inner content ZStack, so it
/// covers the full contentExtent. On Retina displays, textures larger
/// than ~8 192 pt may silently clip, but that only affects edges between
/// extremely far-apart nodes (well beyond a practical 30 % zoom view).
struct EdgeLayerView: View {
    @Bindable var document: GraphDocument

    var body: some View {
        Canvas { context, size in
            drawEdges(in: &context)
            drawDragEdge(in: &context)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Draw Committed Edges

    private func drawEdges(in context: inout GraphicsContext) {
        for edge in document.edges {
            // Skip edges connected to hidden node kinds
            if let sourceNode = document.node(for: edge.sourceNodeID),
               document.hiddenNodeKinds.contains(sourceNode.kind) { continue }
            if let targetNode = document.node(for: edge.targetNodeID),
               document.hiddenNodeKinds.contains(targetNode.kind) { continue }

            guard let from = portPosition(nodeID: edge.sourceNodeID, portID: edge.sourcePortID),
                  let to = portPosition(nodeID: edge.targetNodeID, portID: edge.targetPortID)
            else { continue }

            let isSelected = document.selectedEdgeID == edge.id
                || document.selectedEdgeIDs.contains(edge.id)
            let baseColor: Color = edge.colorHex.map { Color(hex: $0) }
                ?? .secondary.opacity(0.7)
            let edgeColor: Color = isSelected ? Color.accentColor : baseColor

            // Bezier curve path
            var curvePath = Path()
            curvePath.move(to: from)
            let midX = (from.x + to.x) / 2
            curvePath.addCurve(
                to: to,
                control1: CGPoint(x: midX, y: from.y),
                control2: CGPoint(x: midX, y: to.y)
            )

            // Glow behind selected edge
            if isSelected {
                context.stroke(
                    curvePath,
                    with: .color(Color.accentColor.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
            }

            // Edge line (with optional dash pattern)
            context.stroke(
                curvePath,
                with: .color(edgeColor),
                style: StrokeStyle(
                    lineWidth: isSelected ? 3 : 2,
                    lineCap: .round, lineJoin: .round,
                    dash: edge.lineStyle.dashPattern
                )
            )

            // Arrowhead
            let angle = atan2(to.y - from.y, to.x - from.x)
            let arrowLength: CGFloat = 10
            let arrowAngle: CGFloat = .pi / 6

            var arrowPath = Path()
            arrowPath.move(to: to)
            arrowPath.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowAngle),
                y: to.y - arrowLength * sin(angle - arrowAngle)
            ))
            arrowPath.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowAngle),
                y: to.y - arrowLength * sin(angle + arrowAngle)
            ))
            arrowPath.closeSubpath()
            context.fill(arrowPath, with: .color(edgeColor))
        }
    }

    // MARK: - Draw Temporary Drag Edge

    private func drawDragEdge(in context: inout GraphicsContext) {
        guard let sourceNodeID = document.dragSourceNodeID,
              let sourcePortID = document.dragSourcePortID,
              let sourcePos = portPosition(nodeID: sourceNodeID, portID: sourcePortID),
              let endPos = document.dragCurrentEndpoint
        else { return }

        var path = Path()
        path.move(to: sourcePos)
        let midX = (sourcePos.x + endPos.x) / 2
        path.addCurve(
            to: endPos,
            control1: CGPoint(x: midX, y: sourcePos.y),
            control2: CGPoint(x: midX, y: endPos.y)
        )
        context.stroke(
            path,
            with: .color(Color.accentColor),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        )
    }

    // MARK: - Port Position (preference-based or computed fallback)

    private func portPosition(nodeID: UUID, portID: UUID) -> CGPoint? {
        if let pos = document.portPositions[PortAddress(nodeID: nodeID, portID: portID)] {
            return pos
        }
        return computedPortPosition(nodeID: nodeID, portID: portID)
    }

    private func computedPortPosition(nodeID: UUID, portID: UUID) -> CGPoint? {
        guard let node = document.node(for: nodeID),
              !node.kind.isShape,
              node.kind != .comment,
              let portIndex = node.ports.firstIndex(where: { $0.id == portID })
        else {
            return document.node(for: nodeID).map { CGPoint(x: $0.position.x, y: $0.position.y) }
        }

        let port = node.ports[portIndex]
        let halfW = node.size.width / 2
        let halfH = node.size.height / 2

        let bannerHeight: CGFloat = 30
        let portTopPad: CGFloat = 6
        let portRowCenter: CGFloat = 7
        let portRowStride: CGFloat = 16
        let portDotInset: CGFloat = 10

        let y = node.position.y - halfH + bannerHeight + portTopPad + portRowCenter + CGFloat(portIndex) * portRowStride
        let x: CGFloat = port.kind == .input
            ? node.position.x - halfW + portDotInset
            : node.position.x + halfW - portDotInset

        return CGPoint(x: x, y: y)
    }
}
