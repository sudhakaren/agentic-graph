import SwiftUI

struct CommentsInspectorView: View {
    @Bindable var document: GraphDocument
    @AppStorage("commentsEditorHeight") private var editorHeight: Double = 260

    var body: some View {
        Form {
            switch target {
            case .node(let index):
                nodeSection(index: index)
            case .edge(let index):
                edgeSection(index: index)
            case .project:
                projectSection
            case .multi(let count):
                multiSection(count: count)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
    }

    // MARK: - Target Resolution

    private enum Target {
        case node(Int)
        case edge(Int)
        case project
        case multi(Int)
    }

    private var target: Target {
        if document.totalSelectedCount >= 2 {
            return .multi(document.totalSelectedCount)
        }
        if let nodeIndex = document.selectedNodeIndex,
           nodeIndex < document.nodes.count {
            return .node(nodeIndex)
        }
        if let edgeID = document.selectedEdgeID,
           let edgeIndex = document.edges.firstIndex(where: { $0.id == edgeID }) {
            return .edge(edgeIndex)
        }
        return .project
    }

    // MARK: - Sections

    @ViewBuilder
    private func nodeSection(index: Int) -> some View {
        let node = document.nodes[index]
        Section {
            HStack(spacing: 6) {
                Image(systemName: node.kind.sfSymbol)
                    .foregroundStyle(node.kind.color)
                Text(node.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(node.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Comments") {
            commentsEditor(binding: Binding(
                get: { document.nodes[safe: index]?.comments ?? "" },
                set: {
                    guard index < document.nodes.count else { return }
                    document.nodes[index].comments = $0.isEmpty ? nil : $0
                    document.isDirty = true
                }
            ))
        }
    }

    @ViewBuilder
    private func edgeSection(index: Int) -> some View {
        let edge = document.edges[index]
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection")
                    .font(.headline)
                if let source = document.node(for: edge.sourceNodeID),
                   let target = document.node(for: edge.targetNodeID) {
                    HStack(spacing: 6) {
                        Label(source.title, systemImage: source.kind.sfSymbol)
                            .foregroundStyle(source.kind.color)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Label(target.title, systemImage: target.kind.sfSymbol)
                            .foregroundStyle(target.kind.color)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
            }
        }

        Section("Comments") {
            commentsEditor(binding: Binding(
                get: { document.edges[safe: index]?.comments ?? "" },
                set: {
                    guard index < document.edges.count else { return }
                    document.edges[index].comments = $0.isEmpty ? nil : $0
                    document.isDirty = true
                }
            ))
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        Section {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(document.projectName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Comments") {
            commentsEditor(binding: Binding(
                get: { document.projectComments ?? "" },
                set: {
                    document.projectComments = $0.isEmpty ? nil : $0
                    document.isDirty = true
                }
            ))
        }
    }

    @ViewBuilder
    private func multiSection(count: Int) -> some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "square.on.square.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("\(count) objects selected")
                    .foregroundStyle(.secondary)
                Text("Select a single node, edge, or nothing (project) to edit comments.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Editor

    private func commentsEditor(binding: Binding<String>) -> some View {
        VStack(spacing: 0) {
            TextEditor(text: binding)
                .font(.body)
                .scrollContentBackground(.visible)
                .frame(height: max(120, editorHeight))
            DragResizeHandle(height: $editorHeight, minHeight: 120)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
