import SwiftUI

/// Floating ⌘F search panel. Lists every node/edge attribute that matches the
/// query; clicking a result selects that item and pans the canvas onto it.
struct FindPanel: View {
    @Bindable var document: GraphDocument
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = GraphSearch.run(query: query, in: document)
        return VStack(spacing: 0) {
            searchRow(resultCount: results.count, first: results.first)
            if !query.isEmpty {
                Divider()
                resultsList(results)
            }
        }
        .frame(width: 320)
        .contentShape(Rectangle())
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .onExitCommand { close() }
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    // MARK: - Search row

    private func searchRow(resultCount: Int, first: FindResult?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Find in graph", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { if let first { go(to: first) } }
            if !query.isEmpty {
                Text(verbatim: "\(resultCount)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button { close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Close Find")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsList(_ results: [FindResult]) -> some View {
        if results.isEmpty {
            Text("No matches")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        FindResultRow(result: result, query: query) { go(to: result) }
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 340)
        }
    }

    // MARK: - Actions

    private func go(to result: FindResult) {
        document.selectedNodeIDs.removeAll()
        document.selectedEdgeIDs.removeAll()
        switch result.target {
        case .node(let id):
            document.selectedEdgeID = nil
            document.selectedNodeID = id
            DispatchQueue.main.async { document.panToNode(id) }
        case .edge(let id):
            document.selectedNodeID = nil
            document.selectedEdgeID = id
            DispatchQueue.main.async { document.panToEdge(id) }
        }
    }

    private func close() {
        document.showFindPanel = false
    }
}

// MARK: - Result row

private struct FindResultRow: View {
    let result: FindResult
    let query: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: result.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(result.iconColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: result.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    secondLine
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(hovering ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var secondLine: Text {
        let label = Text(result.attribute).foregroundStyle(.secondary)
        guard !result.snippet.isEmpty else { return label }
        return Text("\(label)  \(snippetText)")
    }

    /// The snippet with the matched substring bolded.
    private var snippetText: Text {
        let s = result.snippet
        guard !query.isEmpty,
              let r = s.range(of: query, options: .caseInsensitive) else {
            return Text(verbatim: s).foregroundStyle(.tertiary)
        }
        let prefix = Text(verbatim: String(s[s.startIndex..<r.lowerBound])).foregroundStyle(.tertiary)
        let match  = Text(verbatim: String(s[r])).foregroundStyle(.primary).bold()
        let suffix = Text(verbatim: String(s[r.upperBound...])).foregroundStyle(.tertiary)
        return Text("\(prefix)\(match)\(suffix)")
    }
}
