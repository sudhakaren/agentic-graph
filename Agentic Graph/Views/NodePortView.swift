import SwiftUI

struct NodePortView: View {
    let port: NodePort
    let nodeID: UUID
    @Bindable var document: GraphDocument

    var body: some View {
        HStack(spacing: 4) {
            if port.kind == .input {
                portDot
                Text(port.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer()
                Text(port.label)
                    .font(.system(size: 11))
                    .foregroundStyle(connectedNodeColor ?? .secondary)
                portDot
            }
        }
        .padding(.horizontal, 4)
    }

    /// For output ports, look up the connected node's kind color
    private var connectedNodeColor: Color? {
        guard port.kind == .output else { return nil }
        // Find the edge that uses this port as its source
        guard let edge = document.edges.first(where: { $0.sourcePortID == port.id }),
              let targetNode = document.node(for: edge.targetNodeID) else { return nil }
        return targetNode.kind.color
    }

    private var portDotColor: Color {
        if port.kind == .input {
            return Color.blue.opacity(0.8)
        }
        // Output port: use connected node's color, or default green
        return connectedNodeColor ?? Color.green.opacity(0.8)
    }

    private var portDot: some View {
        Circle()
            .fill(portDotColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().stroke(Color.white, lineWidth: 1.5)
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: PortPositionKey.self,
                            value: [PortAddress(nodeID: nodeID, portID: port.id):
                                        CGPoint(x: geo.frame(in: .named("canvas")).midX,
                                                y: geo.frame(in: .named("canvas")).midY)]
                        )
                }
            )
    }
}
