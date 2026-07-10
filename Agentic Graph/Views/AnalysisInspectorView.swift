import SwiftUI

struct AnalysisInspectorView: View {
    @Bindable var document: GraphDocument
    @Bindable var engine: GraphAnalysisEngine
    let patternStore: AnalysisPatternStore
    let llmStore: LLMProviderStore
    @State private var filter: SeverityFilter = .all
    @State private var debugWindowFinding: AnalysisFinding?

    enum SeverityFilter: String, CaseIterable {
        case all = "All"
        case warnings = "Warnings"
        case recommendations = "Recommendations"
        case positive = "Positive"
        case info = "Info"
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .sheet(item: $debugWindowFinding) { finding in
            DiagnosticsWindow(finding: finding)
        }
        .onAppear {
            if case .idle = engine.state {
                engine.loadLastResult(from: document)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch engine.state {
        case .idle:
            idleView
        case .analyzing(let progress):
            analyzingView(progress: progress)
        case .completed(let result):
            resultView(result)
        case .failed(let message):
            failedView(message)
        case .unavailable(let reason):
            unavailableView(reason)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Architecture Analysis")
                .font(.title3)
            Text("Review your graph against \(patternStore.enabledPatterns.count) enabled patterns using \(llmStore.activeProvider.displayName).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Run Analysis") {
                engine.analyze(document: document, patternStore: patternStore, llmStore: llmStore)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Analyzing

    private func analyzingView(progress: AnalysisProgress) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(progress.completedCount) of \(progress.patterns.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { engine.cancel() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if progress.patterns.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Preparing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                let groups = progressGrouped(progress)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.category) { group in
                            progressCategorySection(group.category, patterns: group.patterns)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func progressGrouped(_ progress: AnalysisProgress) -> [(category: String, patterns: [PatternStatus])] {
        let byCategory = Dictionary(grouping: progress.patterns) { pattern in
            patternCatalog[pattern.id]?.category ?? "Other"
        }
        let order = AnalysisPatternStore.standardCategories + ["Other"]
        let extra = byCategory.keys.filter { !order.contains($0) }.sorted()
        return (order + extra).compactMap { cat in
            guard let items = byCategory[cat], !items.isEmpty else { return nil }
            return (category: cat, patterns: items)
        }
    }

    private func progressCategorySection(_ category: String, patterns: [PatternStatus]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(patterns) { pattern in
                patternStatusRow(pattern)
            }
        }
    }

    private func patternStatusRow(_ pattern: PatternStatus) -> some View {
        HStack(spacing: 5) {
            statusIcon(pattern.state)
                .frame(width: 14)

            Text(pattern.name)
                .font(.caption)
                .foregroundStyle(rowTextStyle(pattern.state))
                .lineLimit(1)

            Spacer()

            if case .done(let severity) = pattern.state, let severity {
                Image(systemName: severity.sfSymbol)
                    .font(.system(size: 9))
                    .foregroundStyle(severity.color)
            }
        }
        .padding(.vertical, 2)
    }

    private func rowTextStyle(_ state: PatternStatus.PatternRunState) -> some ShapeStyle {
        switch state {
        case .pending: return .tertiary
        case .running: return .primary
        case .done(let s): return s != nil ? .secondary : .quaternary
        }
    }

    @ViewBuilder
    private func statusIcon(_ state: PatternStatus.PatternRunState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        case .running:
            ProgressView()
                .scaleEffect(0.45)
                .frame(width: 14, height: 14)
        case .done(let severity):
            if severity != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Results

    private func resultView(_ result: AnalysisResult) -> some View {
        VStack(spacing: 0) {
            summaryBar(result)
            Divider()
            filterBar
            Divider()
            findingsList(result)
            Divider()
            footer(result)
        }
    }

    private func summaryBar(_ result: AnalysisResult) -> some View {
        HStack(spacing: 12) {
            severityCount(count: result.warnings.count, severity: .warning)
            severityCount(count: result.recommendations.count, severity: .recommendation)
            severityCount(count: result.positives.count, severity: .positive)
            severityCount(count: result.infos.count, severity: .info)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    private func severityCount(count: Int, severity: FindingSeverity) -> some View {
        HStack(spacing: 4) {
            Image(systemName: severity.sfSymbol)
                .foregroundStyle(severity.color)
                .font(.system(size: 13))
            Text("\(count)")
                .font(.system(size: 13).monospacedDigit())
            Text(severity.displayName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var filterBar: some View {
        Picker("Filter", selection: $filter) {
            ForEach(SeverityFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func filteredFindings(_ result: AnalysisResult) -> [AnalysisFinding] {
        switch filter {
        case .all: result.findings
        case .warnings: result.warnings
        case .recommendations: result.recommendations
        case .positive: result.positives
        case .info: result.infos
        }
    }

    private func findingsList(_ result: AnalysisResult) -> some View {
        let grouped = filteredGrouped(result)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if grouped.isEmpty {
                    Text("No findings for this filter")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                } else {
                    ForEach(grouped, id: \.category) { group in
                        categorySection(group.category, findings: group.findings)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func filteredGrouped(_ result: AnalysisResult) -> [(category: String, findings: [AnalysisFinding])] {
        let filtered = filteredFindings(result)
        let grouped = Dictionary(grouping: filtered) { $0.category }
        let order = AnalysisPatternStore.standardCategories
        let extra = grouped.keys.filter { !order.contains($0) }.sorted()
        return (order + extra).compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, findings: items.sorted { $0.severity.sortOrder < $1.severity.sortOrder })
        }
    }

    private func categorySection(_ category: String, findings: [AnalysisFinding]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            ForEach(findings) { finding in
                findingRow(finding)
            }
        }
    }

    // MARK: - Finding Row

    private func findingRow(_ finding: AnalysisFinding) -> some View {
        FindingRowView(finding: finding, document: document, onDebug: { debugWindowFinding = finding })
    }


    // MARK: - Footer

    private func footer(_ result: AnalysisResult) -> some View {
        HStack {
            Text("Analyzed on-device")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(result.timestamp, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Failed

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Analysis Failed")
                .font(.subheadline)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try Again") {
                engine.analyze(document: document, patternStore: patternStore, llmStore: llmStore)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Unavailable

    private func unavailableView(_ reason: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "apple.intelligence")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Apple Intelligence Required")
                .font(.subheadline)
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.AppleIntelligence") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flow Layout

// MARK: - Finding Row (isolated struct to prevent cascade re-renders)

private struct FindingRowView: View {
    let finding: AnalysisFinding
    let document: GraphDocument
    let onDebug: () -> Void
    @State private var isDetailExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: finding.severity.sfSymbol)
                    .foregroundStyle(finding.severity.color)
                    .font(.system(size: 15))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(finding.patternName)
                            .font(.system(size: 14, weight: .semibold))

                        Spacer()

                        if finding.diagnostics != nil {
                            Button { onDebug() } label: {
                                Image(systemName: "ladybug")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(finding.summary)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)

                    if !finding.detail.isEmpty {
                        DisclosureGroup(isExpanded: $isDetailExpanded) {
                            Text(finding.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Text("Details")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { isDetailExpanded.toggle() }
                        }
                        .padding(.top, 2)
                    }

                    if !finding.relatedNodeIDs.isEmpty {
                        nodeChips
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
    }

    private var nodeChips: some View {
        FlowLayout(spacing: 4) {
            ForEach(finding.relatedNodeIDs, id: \.self) { nodeID in
                if let node = document.node(for: nodeID) {
                    HStack(spacing: 3) {
                        Image(systemName: node.kind.sfSymbol)
                            .font(.system(size: 10))
                        Text(node.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(node.kind.color.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(node.kind.color.opacity(0.3), lineWidth: 0.5))
                    .contentShape(Capsule())
                    .onTapGesture(count: 2) {
                        selectAndInspectNode(nodeID)
                    }
                    .onTapGesture(count: 1) {
                        navigateToNode(nodeID)
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func navigateToNode(_ nodeID: UUID) {
        if !document.selectedNodeIDs.isEmpty { document.selectedNodeIDs.removeAll() }
        if document.selectedEdgeID != nil { document.selectedEdgeID = nil }
        if !document.selectedEdgeIDs.isEmpty { document.selectedEdgeIDs.removeAll() }
        document.selectedNodeID = nodeID
        DispatchQueue.main.async {
            document.panToNode(nodeID)
        }
    }

    private func selectAndInspectNode(_ nodeID: UUID) {
        navigateToNode(nodeID)
        DispatchQueue.main.async {
            document.inspectorTab = .properties
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (size: CGSize(width: maxX, height: y + rowHeight), positions: positions)
    }
}

// MARK: - Diagnostics Window

struct DiagnosticsWindow: View {
    let finding: AnalysisFinding
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ladybug")
                    .foregroundStyle(.secondary)
                Text("Diagnostics — #\(finding.patternNumber) \(finding.patternName)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let diag = finding.diagnostics {
                        // Summary row
                        HStack(spacing: 16) {
                            diagPill(label: "Severity", value: finding.severity.displayName,
                                     icon: finding.severity.sfSymbol, iconColor: finding.severity.color)
                            diagPill(label: "Duration", value: String(format: "%.2fs", diag.duration),
                                     icon: "clock", iconColor: .secondary)
                        }

                        if !diag.resolvedNodeNames.isEmpty {
                            diagSection("Resolved Nodes") {
                                Text(diag.resolvedNodeNames.joined(separator: ", "))
                            }
                        }

                        diagSection("Prompt Sent") {
                            Text(diag.promptForDisplay)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                        }

                        diagSection("Response") {
                            responseFields(diag.rawResponse)
                        }
                    } else {
                        Text("No diagnostics available for this finding.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 560)
    }

    private func diagSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func diagPill(label: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.caption)
                Text(value)
                    .font(.body)
            }
        }
    }

    /// Parse the raw response string "key=value, key=value" into a key/value layout.
    private func responseFields(_ raw: String) -> some View {
        let pairs = parseResponsePairs(raw)
        return VStack(spacing: 0) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                HStack(alignment: .top, spacing: 8) {
                    Text(pair.key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text(pair.value)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                if idx < pairs.count - 1 {
                    Divider()
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
    }

    private func parseResponsePairs(_ raw: String) -> [(key: String, value: String)] {
        // Format: "applies=true, severity=warning, summary=..., detail=..., nodes=..."
        var pairs: [(key: String, value: String)] = []
        let segments = raw.components(separatedBy: ", ")
        var currentKey = ""
        var currentValue = ""

        for segment in segments {
            if let eqRange = segment.range(of: "=") {
                let key = String(segment[segment.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(segment[eqRange.upperBound...])
                // Known keys signal a new pair
                let knownKeys = ["applies", "severity", "summary", "detail", "nodes"]
                if knownKeys.contains(key) {
                    if !currentKey.isEmpty {
                        pairs.append((key: currentKey, value: currentValue))
                    }
                    currentKey = key
                    currentValue = value
                } else {
                    // Continuation of previous value
                    currentValue += ", \(segment)"
                }
            } else {
                // Continuation of previous value
                currentValue += ", \(segment)"
            }
        }
        if !currentKey.isEmpty {
            pairs.append((key: currentKey, value: currentValue))
        }
        return pairs
    }
}
