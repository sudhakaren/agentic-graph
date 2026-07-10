import SwiftUI

struct NodeView: View {
    let nodeID: UUID
    @Bindable var document: GraphDocument

    private var node: GraphNode? { document.node(for: nodeID) }

    var body: some View {
        if let node {
            nodeBody(node)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.size) { _, newSize in
                                updateNodeSize(node, newSize)
                            }
                            .onAppear {
                                updateNodeSize(node, geo.size)
                            }
                    }
                )
                .position(x: node.position.x + document.renderOffset,
                          y: node.position.y + document.renderOffset)
        }
    }

    private func updateNodeSize(_ node: GraphNode, _ newSize: CGSize) {
        guard let idx = document.nodes.firstIndex(where: { $0.id == node.id }) else { return }
        // Only update height for dynamic-content nodes (standard + comment)
        // Shape nodes have user-resizable dimensions — don't override
        if !node.kind.isShape {
            if abs(document.nodes[idx].size.height - newSize.height) > 1 {
                document.nodes[idx].size.height = newSize.height
            }
        }
    }

    @ViewBuilder
    private func nodeBody(_ node: GraphNode) -> some View {
        switch node.kind {
        case .shapeRectangle:
            shapeView(node, shape: Rectangle())
        case .shapeRoundedRect:
            shapeView(node, shape: RoundedRectangle(cornerRadius: 12))
        case .shapeOval:
            shapeView(node, shape: Ellipse())
        case .shapeText:
            textShapeView(node)
        case .comment:
            commentView(node)
        default:
            standardNode(node)
        }
    }

    // MARK: - Shape Views

    private func shapeView<S: Shape>(_ node: GraphNode, shape: S) -> some View {
        let strokeColor: Color = {
            if isSelected(node) { return .accentColor }
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
            shape.stroke(strokeColor, lineWidth: isSelected(node) ? 3 : 2)
        }
        .frame(width: node.size.width, height: node.size.height)
        .shadow(color: isSelected(node) ? .accentColor.opacity(0.5) : .clear,
                radius: isSelected(node) ? 6 : 0)
        .overlay {
            if isSelected(node) {
                ResizeHandlesOverlay(size: node.size)
            }
        }
        .overlay(alignment: .topTrailing) {
            if node.lockState != .unlocked {
                Image(systemName: node.lockState.sfSymbol)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private func textShapeView(_ node: GraphNode) -> some View {
        let fontColor: Color = {
            if let hex = node.fontColorHex { return Color(hex: hex) }
            return Color(white: 0.5)
        }()
        let fontSize: CGFloat = node.fontSize ?? 14

        return Text(node.title)
            .font(.system(size: fontSize))
            .foregroundStyle(fontColor)
            .frame(width: node.size.width, height: node.size.height)
            .overlay {
                if isSelected(node) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .shadow(color: isSelected(node) ? .accentColor.opacity(0.5) : .clear,
                    radius: isSelected(node) ? 6 : 0)
            .overlay {
                if isSelected(node) {
                    ResizeHandlesOverlay(size: node.size)
                }
            }
            .overlay(alignment: .topTrailing) {
                if node.lockState != .unlocked {
                    Image(systemName: node.lockState.sfSymbol)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
    }

    // MARK: - Standard Node Views

    private func standardNode(_ node: GraphNode) -> some View {
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

            VStack(spacing: 2) {
                ForEach(node.ports) { port in
                    NodePortView(port: port, nodeID: node.id, document: document)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .frame(width: node.size.width)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor(node), lineWidth: isSelected(node) || isHighlighted(node) ? 2.5 : 1)
        )
        .shadow(color: isSelected(node) ? .accentColor.opacity(0.5) :
                       isHighlighted(node) ? .accentColor.opacity(0.6) : .black.opacity(0.15),
                radius: isSelected(node) ? 6 : isHighlighted(node) ? 8 : 3,
                y: (isSelected(node) || isHighlighted(node)) ? 0 : 1)
    }

    private func commentColor(_ node: GraphNode) -> Color {
        if let hex = node.colorHex { return Color(hex: hex) }
        return .yellow
    }

    private func commentView(_ node: GraphNode) -> some View {
        let baseColor = commentColor(node)
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
                .stroke(isSelected(node) ? Color.accentColor : baseColor.opacity(0.4),
                        lineWidth: isSelected(node) ? 2.5 : 1)
        )
        .shadow(color: isSelected(node) ? .accentColor.opacity(0.5) : .clear,
                radius: isSelected(node) ? 6 : 0)
        .overlay(alignment: .topTrailing) {
            if node.lockState != .unlocked {
                Image(systemName: node.lockState.sfSymbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(4)
            }
        }
    }

    // MARK: - Helpers

    private func isSelected(_ node: GraphNode) -> Bool {
        document.selectedNodeID == node.id || document.selectedNodeIDs.contains(node.id)
    }

    /// Node is highlighted because its connected edge is selected
    private func isHighlighted(_ node: GraphNode) -> Bool {
        document.highlightedNodeIDs.contains(node.id)
    }

    private func borderColor(_ node: GraphNode) -> Color {
        if isSelected(node) { return .accentColor }
        if isHighlighted(node) { return .accentColor.opacity(0.8) }
        return Color.gray.opacity(0.3)
    }

}

// MARK: - Resize Handles Overlay

struct ResizeHandlesOverlay: View {
    let size: CGSize
    private let handleSize: CGFloat = 8

    var body: some View {
        let halfW = size.width / 2
        let halfH = size.height / 2

        ZStack {
            ForEach(handlePositions(halfW: halfW, halfH: halfH), id: \.0) { _, pos in
                Circle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                    .position(x: halfW + pos.x, y: halfH + pos.y)
            }
        }
        .allowsHitTesting(false) // NSView handles the actual hit testing
    }

    private func handlePositions(halfW: CGFloat, halfH: CGFloat) -> [(Int, CGPoint)] {
        [
            (0, CGPoint(x: -halfW, y: -halfH)),  // topLeft
            (1, CGPoint(x: 0,      y: -halfH)),  // topCenter
            (2, CGPoint(x: halfW,  y: -halfH)),  // topRight
            (3, CGPoint(x: -halfW, y: 0)),        // leftCenter
            (4, CGPoint(x: halfW,  y: 0)),        // rightCenter
            (5, CGPoint(x: -halfW, y: halfH)),   // bottomLeft
            (6, CGPoint(x: 0,      y: halfH)),   // bottomCenter
            (7, CGPoint(x: halfW,  y: halfH)),   // bottomRight
        ]
    }
}
