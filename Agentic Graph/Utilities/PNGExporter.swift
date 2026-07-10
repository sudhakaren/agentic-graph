import SwiftUI

struct PNGExporter {

    // MARK: - Port Position Estimation

    /// Estimated banner height for standard nodes (icon + title with padding)
    private static let bannerHeight: CGFloat = 30
    /// Top padding of the port VStack area
    private static let portTopPad: CGFloat = 6
    /// Approximate height per port row (12pt dot + VStack spacing of 2)
    private static let portRowHeight: CGFloat = 16
    /// Port dot inset from node edge (4pt horizontal padding + 6pt half of 12pt dot)
    private static let portDotInset: CGFloat = 10

    /// Compute approximate port positions for all nodes, used for edge endpoint rendering.
    private static func computePortPositions(nodes: [GraphNode], offsetX: CGFloat, offsetY: CGFloat) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        for node in nodes {
            guard !node.kind.isShape, node.kind != .comment else { continue }
            let nodeX = node.position.x + offsetX
            let nodeY = node.position.y + offsetY
            let halfW = node.size.width / 2
            let halfH = node.size.height / 2

            for (idx, port) in node.ports.enumerated() {
                let y = nodeY - halfH + bannerHeight + portTopPad + CGFloat(idx) * portRowHeight + portRowHeight / 2
                let x: CGFloat
                if port.kind == .input {
                    x = nodeX - halfW + portDotInset
                } else {
                    x = nodeX + halfW - portDotInset
                }
                positions[port.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    // MARK: - Export

    static func export(document: GraphDocument) -> Data? {
        let nodes = document.nodes
        guard !nodes.isEmpty else { return nil }

        let bounds = computeBoundingBox(for: nodes)
        let padding: CGFloat = 60
        let width = bounds.width + padding * 2
        let height = bounds.height + padding * 2
        let offsetX = -bounds.minX + padding
        let offsetY = -bounds.minY + padding

        // Pre-compute port positions for edge endpoint rendering
        let portPositions = computePortPositions(nodes: nodes, offsetX: offsetX, offsetY: offsetY)

        // Build a standalone view for rendering
        let exportView = ZStack {
            // Layer 1: Shapes (below edges)
            ForEach(nodes.filter { $0.kind.isShape }) { node in
                exportShapeView(node)
                    .position(x: node.position.x + offsetX,
                             y: node.position.y + offsetY)
            }

            // Layer 2: Edges with proper colors, styles, arrowheads, and port positions
            Canvas { context, size in
                for edge in document.edges {
                    // Use port positions for accurate endpoints, fall back to node center
                    let from = portPositions[edge.sourcePortID]
                        ?? nodeCenterPos(edge.sourceNodeID, nodes: nodes, offsetX: offsetX, offsetY: offsetY)
                    let to = portPositions[edge.targetPortID]
                        ?? nodeCenterPos(edge.targetNodeID, nodes: nodes, offsetX: offsetX, offsetY: offsetY)

                    // Use edge's custom color or default gray
                    let edgeColor: Color = edge.colorHex.map { Color(hex: $0) }
                        ?? Color(white: 0.55)

                    // Draw bezier curve with proper line style
                    let path = bezierPath(from: from, to: to)
                    context.stroke(path, with: .color(edgeColor),
                                  style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round,
                                                     dash: edge.lineStyle.dashPattern))

                    // Draw arrowhead at target
                    drawArrowhead(context: &context, to: to, from: from, color: edgeColor)
                }
            }

            // Layer 3: Graph nodes (above edges)
            ForEach(nodes.filter { !$0.kind.isShape }) { node in
                exportNodeView(node, document: document)
                    .position(x: node.position.x + offsetX,
                             y: node.position.y + offsetY)
            }
        }
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: width, height: height)

        guard let cgImage = renderer.cgImage else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }

        return pngData
    }

    // MARK: - Edge Helpers

    private static func bezierPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        let midX = (from.x + to.x) / 2
        path.addCurve(to: to,
                      control1: CGPoint(x: midX, y: from.y),
                      control2: CGPoint(x: midX, y: to.y))
        return path
    }

    private static func drawArrowhead(context: inout GraphicsContext, to: CGPoint, from: CGPoint, color: Color) {
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
        context.fill(arrowPath, with: .color(color))
    }

    private static func nodeCenterPos(_ nodeID: UUID, nodes: [GraphNode], offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        guard let node = nodes.first(where: { $0.id == nodeID }) else {
            return .zero
        }
        return CGPoint(x: node.position.x + offsetX, y: node.position.y + offsetY)
    }

    // MARK: - Shape Export Views

    @ViewBuilder
    private static func exportShapeView(_ node: GraphNode) -> some View {
        switch node.kind {
        case .shapeRectangle:
            exportShape(node, shape: Rectangle())
        case .shapeRoundedRect:
            exportShape(node, shape: RoundedRectangle(cornerRadius: 12))
        case .shapeOval:
            exportShape(node, shape: Ellipse())
        case .shapeText:
            exportTextShape(node)
        default:
            EmptyView()
        }
    }

    private static func exportShape<S: Shape>(_ node: GraphNode, shape: S) -> some View {
        let strokeColor: Color = {
            if let hex = node.strokeColorHex { return Color(hex: hex) }
            return Color.gray
        }()
        let fillColor: Color = {
            if let hex = node.fillColorHex { return Color(hex: hex) }
            return .blue
        }()

        return ZStack {
            if node.fillEnabled {
                shape.fill(fillColor)
            }
            shape.stroke(strokeColor, lineWidth: 2)
        }
        .frame(width: node.size.width, height: node.size.height)
    }

    private static func exportTextShape(_ node: GraphNode) -> some View {
        let fontColor: Color = {
            if let hex = node.fontColorHex { return Color(hex: hex) }
            return Color(white: 0.5)
        }()
        let fontSize: CGFloat = node.fontSize ?? 14

        return Text(node.title)
            .font(.system(size: fontSize))
            .foregroundStyle(fontColor)
            .frame(width: node.size.width, height: node.size.height)
    }

    // MARK: - Graph Node Export Views

    @ViewBuilder
    private static func exportNodeView(_ node: GraphNode, document: GraphDocument) -> some View {
        if node.kind == .comment {
            exportCommentView(node)
        } else {
            exportStandardNode(node, document: document)
        }
    }

    private static func exportCommentView(_ node: GraphNode) -> some View {
        let baseColor: Color = {
            if let hex = node.colorHex { return Color(hex: hex) }
            return .yellow
        }()

        return VStack(alignment: .leading, spacing: 4) {
            Text(node.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            if !node.detail.isEmpty {
                Text(node.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }
        }
        .padding(10)
        .frame(width: node.size.width, alignment: .leading)
        .background(baseColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(baseColor.opacity(0.4), lineWidth: 1)
        )
    }

    private static func exportStandardNode(_ node: GraphNode, document: GraphDocument) -> some View {
        let bannerColor: Color = {
            if let hex = node.colorHex { return Color(hex: hex) }
            return node.kind.color
        }()
        let titleFontSize: CGFloat = node.fontSize ?? 13
        let titleFontColor: Color = {
            if let hex = node.fontColorHex { return Color(hex: hex) }
            return .white
        }()

        return VStack(spacing: 0) {
            // Banner
            HStack(spacing: 6) {
                Image(systemName: node.kind.sfSymbol)
                    .font(.system(size: 12))
                Text(node.title)
                    .fontWeight(.semibold)
                    .font(.system(size: titleFontSize))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if node.risk != .none {
                    Text(node.risk.letter)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(titleFontColor.opacity(0.85))
                }
                if node.lockState != .unlocked {
                    Image(systemName: node.lockState.sfSymbol)
                        .font(.system(size: 9))
                        .foregroundStyle(titleFontColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(bannerColor)
            .foregroundStyle(titleFontColor)

            // Port list
            VStack(spacing: 2) {
                ForEach(node.ports) { port in
                    exportPortRow(port: port, node: node, document: document)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .frame(width: node.size.width)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    /// Renders a port row matching the canvas NodePortView appearance
    private static func exportPortRow(port: NodePort, node: GraphNode, document: GraphDocument) -> some View {
        let dotColor = portDotColor(port: port, document: document)
        let labelColor = portLabelColor(port: port, document: document)

        return HStack(spacing: 4) {
            if port.kind == .input {
                Circle().fill(dotColor).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                Text(port.label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer()
                Text(port.label).font(.system(size: 11)).foregroundStyle(labelColor)
                Circle().fill(dotColor).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 4)
    }

    /// Matches NodePortView.portDotColor
    private static func portDotColor(port: NodePort, document: GraphDocument) -> Color {
        if port.kind == .input {
            return Color.blue.opacity(0.8)
        }
        // Output port: use connected target node's kind color, or default green
        if let edge = document.edges.first(where: { $0.sourcePortID == port.id }),
           let targetNode = document.node(for: edge.targetNodeID) {
            return targetNode.kind.color
        }
        return Color.green.opacity(0.8)
    }

    /// Matches NodePortView output label color
    private static func portLabelColor(port: NodePort, document: GraphDocument) -> Color {
        if port.kind == .input { return .secondary }
        if let edge = document.edges.first(where: { $0.sourcePortID == port.id }),
           let targetNode = document.node(for: edge.targetNodeID) {
            return targetNode.kind.color
        }
        return .secondary
    }

    // MARK: - Bounding Box

    private static func computeBoundingBox(for nodes: [GraphNode]) -> CGRect {
        guard let first = nodes.first else { return .zero }
        var minX = first.position.x - first.size.width / 2
        var minY = first.position.y - first.size.height / 2
        var maxX = first.position.x + first.size.width / 2
        var maxY = first.position.y + first.size.height / 2
        for node in nodes.dropFirst() {
            minX = min(minX, node.position.x - node.size.width / 2)
            minY = min(minY, node.position.y - node.size.height / 2)
            maxX = max(maxX, node.position.x + node.size.width / 2)
            maxY = max(maxY, node.position.y + node.size.height / 2)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
