import SwiftUI

struct InspectorView: View {
    @Bindable var document: GraphDocument
    @State private var isPortsExpanded = false
    @State private var isConnectionsExpanded = false
    @State private var isAppearanceExpanded = false
    @State private var isVersionsExpanded = false
    @State private var isOrphansExpanded = false
    @AppStorage("detailsEditorHeight") private var detailsHeight: Double = 200
    @AppStorage("instructionsEditorHeight") private var instructionsHeight: Double = 100

    // Project details section state
    @State private var isCoreInfoExpanded = true
    @State private var isTechScopeExpanded = false
    @State private var isRiskComplianceExpanded = false
    @State private var isDependenciesExpanded = false
    @AppStorage("projDescriptionHeight") private var projDescriptionHeight: Double = 100
    @AppStorage("projJustificationHeight") private var projJustificationHeight: Double = 100
    @AppStorage("projDependenciesHeight") private var projDependenciesHeight: Double = 100
    @AppStorage("projAssumptionsHeight") private var projAssumptionsHeight: Double = 100
    @AppStorage("projOpenQuestionsHeight") private var projOpenQuestionsHeight: Double = 100

    var body: some View {
        if document.totalSelectedCount >= 2 {
            MultiSelectInspectorView(document: document)
        } else if let index = document.selectedNodeIndex,
                  index < document.nodes.count {
            inspectorContent(index: index)
        } else if let edgeID = document.selectedEdgeID,
                  let edgeIndex = document.edges.firstIndex(where: { $0.id == edgeID }) {
            edgeInspectorContent(index: edgeIndex)
        } else {
            projectSettings
        }
    }

    private var projectSettings: some View {
        Form {
            Section {
                TextField("Name", text: $document.projectName)
            } header: {
                HStack(spacing: 6) {
                    Text("Project")
                    if document.isDirty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 7, height: 7)
                    }
                }
            }

            // Core Info
            Section {
                DisclosureGroup(isExpanded: $isCoreInfoExpanded) {
                    projectMultiLineField(
                        label: "Description",
                        binding: optionalStringBinding(\.projectDescription),
                        height: $projDescriptionHeight
                    )
                    projectMultiLineField(
                        label: "Business Justification",
                        binding: optionalStringBinding(\.businessJustification),
                        height: $projJustificationHeight
                    )
                    projectTextField("Target Completion",
                        prompt: "e.g. 2026-06-30",
                        binding: optionalStringBinding(\.targetCompletionDate))
                    projectTextField("Estimated Effort",
                        prompt: "e.g. 40 person-days",
                        binding: optionalStringBinding(\.estimatedEffort))
                    projectTextField("Team Size",
                        prompt: "e.g. 5",
                        binding: optionalStringBinding(\.teamSize))
                } label: {
                    Text("Core Info")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isCoreInfoExpanded.toggle() }
                }
            }

            // Technical Scope
            Section {
                DisclosureGroup(isExpanded: $isTechScopeExpanded) {
                    LabeledContent("Agents") {
                        Text("\(document.agentCount)")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Data Sources") {
                        Text("\(document.dataSourceCount)")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Tools") {
                        Text("\(document.toolCount)")
                            .foregroundStyle(.secondary)
                    }
                    projectTextField("Integration Points",
                        prompt: "e.g. Salesforce, SAP, Slack",
                        binding: optionalStringBinding(\.integrationPoints))
                    Picker("Deployment", selection: Binding(
                        get: { document.deploymentTarget ?? .cloud },
                        set: { document.deploymentTarget = $0 }
                    )) {
                        ForEach(DeploymentTarget.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                } label: {
                    Text("Technical Scope")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isTechScopeExpanded.toggle() }
                }
            }

            // Risk & Compliance
            Section {
                DisclosureGroup(isExpanded: $isRiskComplianceExpanded) {
                    Picker("Overall Risk", selection: $document.overallRiskLevel) {
                        ForEach(RiskLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    projectTextField("Compliance",
                        prompt: "e.g. GDPR, SOC2",
                        binding: optionalStringBinding(\.complianceRequirements))
                    projectTextField("Data Classification",
                        prompt: "e.g. Confidential",
                        binding: optionalStringBinding(\.dataClassification))
                    projectTextField("Regulatory Constraints",
                        prompt: "e.g. Financial services regulations",
                        binding: optionalStringBinding(\.regulatoryConstraints))
                } label: {
                    Text("Risk & Compliance")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isRiskComplianceExpanded.toggle() }
                }
            }

            // Dependencies & Blockers
            Section {
                DisclosureGroup(isExpanded: $isDependenciesExpanded) {
                    projectMultiLineField(
                        label: "Critical Dependencies",
                        binding: optionalStringBinding(\.criticalDependencies),
                        height: $projDependenciesHeight
                    )
                    projectMultiLineField(
                        label: "Key Assumptions",
                        binding: optionalStringBinding(\.keyAssumptions),
                        height: $projAssumptionsHeight
                    )
                    projectMultiLineField(
                        label: "Open Questions / Blockers",
                        binding: optionalStringBinding(\.openQuestions),
                        height: $projOpenQuestionsHeight
                    )
                } label: {
                    Text("Dependencies & Blockers")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isDependenciesExpanded.toggle() }
                }
            }

            // Orphans
            Section {
                DisclosureGroup(isExpanded: $isOrphansExpanded) {
                    let orphans = document.nodes.filter { node in
                        !node.kind.isShape && node.kind != .comment &&
                        document.edges(connectedTo: node.id).isEmpty
                    }
                    if orphans.isEmpty {
                        Text("All nodes are connected.")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    } else {
                        ForEach(orphans) { node in
                            Button {
                                document.selectedNodeIDs.removeAll()
                                document.selectedEdgeID = nil
                                document.selectedEdgeIDs.removeAll()
                                document.selectedNodeID = node.id
                                document.panToNode(node.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: node.kind.sfSymbol)
                                        .foregroundStyle(node.kind.color)
                                        .font(.caption)
                                    Text(node.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(node.kind.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } label: {
                    let count = document.nodes.filter { !$0.kind.isShape && $0.kind != .comment && document.edges(connectedTo: $0.id).isEmpty }.count
                    HStack {
                        Text("Orphans")
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(count > 0 ? .orange : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isOrphansExpanded.toggle() }
                }
            }

            // Versions
            Section {
                DisclosureGroup(isExpanded: $isVersionsExpanded) {
                    if document.versions.isEmpty {
                        Text("No versions saved.")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    } else {
                        ForEach(Array(document.versions.suffix(5).reversed().enumerated()), id: \.element.id) { idx, snapshot in
                            if idx > 0 {
                                Divider()
                            }
                            HStack {
                                Text(snapshot.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(snapshot.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if document.versions.count > 5 {
                            Divider()
                            Text("\(document.versions.count - 5) more...")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } label: {
                    HStack {
                        Text("Versions")
                        Spacer()
                        Text("\(document.versions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isVersionsExpanded.toggle() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
    }

    // MARK: - Project Field Helpers

    private func optionalStringBinding(
        _ keyPath: ReferenceWritableKeyPath<GraphDocument, String?>
    ) -> Binding<String> {
        Binding(
            get: { document[keyPath: keyPath] ?? "" },
            set: { document[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func projectTextField(
        _ label: LocalizedStringKey, prompt: LocalizedStringKey, binding: Binding<String>
    ) -> some View {
        TextField(label, text: binding, prompt: Text(prompt))
            .textFieldStyle(.roundedBorder)
    }

    private func projectMultiLineField(
        label: LocalizedStringKey, binding: Binding<String>, height: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                TextEditor(text: binding)
                    .font(.body)
                    .scrollContentBackground(.visible)
                    .frame(height: max(80, height.wrappedValue))
                DragResizeHandle(height: height, minHeight: 80)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func inspectorContent(index: Int) -> some View {
        let node = document.nodes[index]
        let nodeID = node.id
        Form {
            // Lock control — always interactive
            Section {
                HStack {
                    Text("Lock")
                    Spacer()
                    Button {
                        document.setLockState(node.lockState.next, for: nodeID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: node.lockState.sfSymbol)
                            Text(node.lockState.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(node.lockState == .unlocked ? .secondary : .orange)
                    }
                    .buttonStyle(.plain)
                }
            }

            // All editable content — disabled when fully locked
            Group {

            // Title section — not for shapes (text shape edits title inline)
            if !node.kind.isShape {
                Section("Node") {
                    TextField("Title", text: Binding(
                        get: { document.nodes[safe: index]?.title ?? "" },
                        set: {
                            if index < document.nodes.count {
                                document.nodes[index].title = $0
                                let n = document.nodes[index]
                                document.nodes[index].size.width = GraphNode.idealWidth(
                                    for: $0, fontSize: n.fontSize ?? 13,
                                    risk: n.risk, lockState: n.lockState,
                                    isComment: n.kind == .comment)
                                document.propagateNodeTitle(document.nodes[index].id, newTitle: $0)
                            }
                        }
                    ))
                    LabeledContent("Type") {
                        Label(node.kind.displayName, systemImage: node.kind.sfSymbol)
                            .foregroundStyle(node.kind.color)
                    }
                    if node.kind != .comment {
                        Picker("Risk", selection: Binding(
                            get: { document.nodes[safe: index]?.risk ?? .none },
                            set: {
                                if index < document.nodes.count {
                                    document.nodes[index].risk = $0
                                    let n = document.nodes[index]
                                    document.nodes[index].size.width = GraphNode.idealWidth(
                                        for: n.title, fontSize: n.fontSize ?? 13,
                                        risk: $0, lockState: n.lockState)
                                }
                            }
                        )) {
                            ForEach(RiskLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                    }
                }
            }

            // Color picker for comment nodes
            if node.kind == .comment {
                Section("Appearance") {
                    PopoverColorPicker(label: "Color", color: Binding(
                        get: {
                            if let hex = document.nodes[safe: index]?.colorHex {
                                return Color(hex: hex)
                            }
                            return .yellow
                        },
                        set: {
                            if index < document.nodes.count {
                                document.nodes[index].colorHex = $0.hexString
                            }
                        }
                    ))
                }
            }

            // Shape appearance controls (not for text — text has its own section)
            if node.kind.isShape && node.kind != .shapeText {
                shapeAppearanceSection(index: index, node: node)
            }

            // Text shape controls
            if node.kind == .shapeText {
                textShapeSection(index: index, node: node)
            }

            // Knowledge metadata fields
            if node.kind == .knowledge {
                knowledgeSection(index: index)
            }

            // Agent metadata fields
            if node.kind == .agent {
                agentSection(index: index)
            }

            // Tool metadata fields
            if node.kind == .tool {
                toolSection(index: index)
            }

            // Human metadata fields
            if node.kind == .human {
                humanSection(index: index)
            }

            // Details section (not for shapes)
            if !node.kind.isShape {
                Section("Details") {
                    VStack(spacing: 0) {
                        TextEditor(text: Binding(
                            get: { document.nodes[safe: index]?.detail ?? "" },
                            set: { if index < document.nodes.count { document.nodes[index].detail = $0 } }
                        ))
                        .font(.body)
                        .scrollContentBackground(.visible)
                        .frame(height: max(80, detailsHeight))

                        DragResizeHandle(height: $detailsHeight, minHeight: 80)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if node.kind.hasPorts {
                Section {
                    DisclosureGroup(isExpanded: $isPortsExpanded) {
                        List {
                            ForEach(Array(node.ports.enumerated()), id: \.element.id) { portIndex, port in
                                HStack(spacing: 4) {
                                    Image(systemName: port.kind == .input ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                                        .foregroundStyle(port.kind == .input ? .blue : .green)
                                    TextField("Label", text: Binding(
                                        get: { document.nodes[safe: index]?.ports[safe: portIndex]?.label ?? "" },
                                        set: {
                                            if index < document.nodes.count,
                                               portIndex < document.nodes[index].ports.count {
                                                document.nodes[index].ports[portIndex].label = $0
                                            }
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    Button(role: .destructive) {
                                        document.removePortWithUndo(nodeID: nodeID, portID: port.id)
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .onMove { source, destination in
                                guard index < document.nodes.count else { return }
                                let oldPorts = document.nodes[index].ports
                                document.nodes[index].ports.move(fromOffsets: source, toOffset: destination)
                                let newPorts = document.nodes[index].ports
                                document.isDirty = true
                                document.undoManager?.registerUndo(withTarget: document) { [nodeID] doc in
                                    guard let i = doc.nodeIndex(for: nodeID) else { return }
                                    doc.nodes[i].ports = oldPorts
                                    doc.isDirty = true
                                    doc.undoManager?.registerUndo(withTarget: doc) { doc2 in
                                        guard let j = doc2.nodeIndex(for: nodeID) else { return }
                                        doc2.nodes[j].ports = newPorts
                                        doc2.isDirty = true
                                    }
                                }
                                document.undoManager?.setActionName("Reorder Ports")
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(max(node.ports.count, 1)) * 30)
                        HStack {
                            Button("Add Input") {
                                guard index < document.nodes.count else { return }
                                let count = document.nodes[index].ports.filter { $0.kind == .input }.count
                                document.nodes[index].ports.append(
                                    NodePort(label: "In \(count + 1)", kind: .input)
                                )
                            }
                            if node.kind.canHaveOutput {
                                Button("Add Output") {
                                    guard index < document.nodes.count else { return }
                                    let count = document.nodes[index].ports.filter { $0.kind == .output }.count
                                    document.nodes[index].ports.append(
                                        NodePort(label: "Out \(count + 1)", kind: .output)
                                    )
                                }
                            }
                        }
                    } label: {
                        Text("Ports (\(node.ports.count))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { isPortsExpanded.toggle() }
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $isConnectionsExpanded) {
                        let connected = document.edges(connectedTo: nodeID)
                        if connected.isEmpty {
                            Text("No connections")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(connected) { edge in
                                let otherID = edge.sourceNodeID == nodeID ? edge.targetNodeID : edge.sourceNodeID
                                let direction = edge.sourceNodeID == nodeID ? "arrow.right" : "arrow.left"
                                HStack {
                                    Button {
                                        document.selectedNodeID = otherID
                                        document.panToNode(otherID)
                                    } label: {
                                        HStack {
                                            Image(systemName: direction)
                                                .foregroundStyle(.secondary)
                                            if let other = document.node(for: otherID) {
                                                Label(other.title, systemImage: other.kind.sfSymbol)
                                                    .foregroundStyle(other.kind.color)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled({
                                        if let other = document.node(for: otherID) {
                                            return document.hiddenNodeKinds.contains(other.kind)
                                        }
                                        return false
                                    }())
                                    Spacer()
                                    Button(role: .destructive) {
                                        document.removeEdge(id: edge.id)
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } label: {
                        let count = document.edges(connectedTo: nodeID).count
                        Text("Connections (\(count))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { isConnectionsExpanded.toggle() }
                    }
                }
            }

            // Appearance for agent / tool / knowledge nodes
            if node.kind == .agent || node.kind == .tool || node.kind == .knowledge || node.kind == .human {
                Section {
                    DisclosureGroup(isExpanded: $isAppearanceExpanded) {
                        PopoverColorPicker(label: "Banner Color", color: Binding(
                            get: {
                                if let hex = document.nodes[safe: index]?.colorHex {
                                    return Color(hex: hex)
                                }
                                return node.kind.color
                            },
                            set: {
                                if index < document.nodes.count {
                                    document.nodes[index].colorHex = $0.hexString
                                }
                            }
                        ))

                        HStack {
                            Text("Title Font Size")
                            Spacer()
                            TextField("", value: Binding<Double>(
                                get: { Double(document.nodes[safe: index]?.fontSize ?? 13) },
                                set: {
                                    if index < document.nodes.count {
                                        document.nodes[index].fontSize = CGFloat($0)
                                    }
                                }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        }

                        PopoverColorPicker(label: "Title Font Color", color: Binding(
                            get: {
                                if let hex = document.nodes[safe: index]?.fontColorHex {
                                    return Color(hex: hex)
                                }
                                return .white
                            },
                            set: {
                                if index < document.nodes.count {
                                    document.nodes[index].fontColorHex = $0.hexString
                                }
                            }
                        ))
                    } label: {
                        Text("Appearance")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { isAppearanceExpanded.toggle() }
                    }
                }
            }

            // Shape z-ordering
            if node.kind.isShape {
                Section("Order") {
                    HStack {
                        Button {
                            document.sendShapeBackward(id: nodeID)
                        } label: {
                            Label("Backward", systemImage: "square.2.layers.3d.bottom.filled")
                        }
                        Spacer()
                        Button {
                            document.bringShapeForward(id: nodeID)
                        } label: {
                            Label("Forward", systemImage: "square.2.layers.3d.top.filled")
                        }
                    }
                    .buttonStyle(.borderless)
                    HStack {
                        Button {
                            document.sendShapeToBack(id: nodeID)
                        } label: {
                            Label("To Back", systemImage: "square.3.layers.3d.bottom.filled")
                        }
                        Spacer()
                        Button {
                            document.bringShapeToFront(id: nodeID)
                        } label: {
                            Label("To Front", systemImage: "square.3.layers.3d.top.filled")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            } // end Group
            .disabled(node.isDetailsLocked)
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
    }

    // MARK: - Edge Inspector

    @ViewBuilder
    private func edgeInspectorContent(index: Int) -> some View {
        let edge = document.edges[index]
        let edgeID = edge.id
        Form {
            Section("Connection") {
                if let sourceNode = document.node(for: edge.sourceNodeID) {
                    let sourceHidden = document.hiddenNodeKinds.contains(sourceNode.kind)
                    LabeledContent("From") {
                        Button {
                            document.selectedEdgeID = nil
                            document.selectedEdgeIDs = []
                            document.selectedNodeIDs = []
                            document.selectedNodeID = sourceNode.id
                            document.panToNode(sourceNode.id)
                        } label: {
                            Label(sourceNode.title, systemImage: sourceNode.kind.sfSymbol)
                                .foregroundStyle(sourceNode.kind.color)
                        }
                        .buttonStyle(.plain)
                        .disabled(sourceHidden)
                        .onHover { hovering in
                            if hovering && !sourceHidden {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                if let targetNode = document.node(for: edge.targetNodeID) {
                    let targetHidden = document.hiddenNodeKinds.contains(targetNode.kind)
                    LabeledContent("To") {
                        Button {
                            document.selectedEdgeID = nil
                            document.selectedEdgeIDs = []
                            document.selectedNodeIDs = []
                            document.selectedNodeID = targetNode.id
                            document.panToNode(targetNode.id)
                        } label: {
                            Label(targetNode.title, systemImage: targetNode.kind.sfSymbol)
                                .foregroundStyle(targetNode.kind.color)
                        }
                        .buttonStyle(.plain)
                        .disabled(targetHidden)
                        .onHover { hovering in
                            if hovering && !targetHidden {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    document.selectedEdgeID = nil
                    document.selectedEdgeIDs = []
                    document.selectedNodeID = edge.sourceNodeID
                    document.selectedNodeIDs = [edge.sourceNodeID, edge.targetNodeID]
                } label: {
                    Label("Select Connected Nodes", systemImage: "rectangle.connected.to.line.below")
                }
                .buttonStyle(.plain)
                .disabled({
                    if let src = document.node(for: edge.sourceNodeID),
                       document.hiddenNodeKinds.contains(src.kind) { return true }
                    if let tgt = document.node(for: edge.targetNodeID),
                       document.hiddenNodeKinds.contains(tgt.kind) { return true }
                    return false
                }())
            }

            Section("Appearance") {
                PopoverColorPicker(label: "Color", color: Binding(
                    get: {
                        if let hex = document.edges[safe: index]?.colorHex {
                            return Color(hex: hex)
                        }
                        return Color.secondary.opacity(0.7)
                    },
                    set: {
                        document.setEdgeColor($0.hexString, for: edgeID)
                    }
                ))

                Button("Reset to Default") {
                    document.setEdgeColor(nil, for: edgeID)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(document.edges[safe: index]?.colorHex == nil)

                Picker("Line Style", selection: Binding(
                    get: { document.edges[safe: index]?.lineStyle ?? .solid },
                    set: { document.setEdgeLineStyle($0, for: edgeID) }
                )) {
                    ForEach(EdgeLineStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            }

            Section {
                Button("Delete Connection", role: .destructive) {
                    document.removeEdgeWithUndo(id: edgeID)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
    }

    // MARK: - Knowledge Metadata

    @ViewBuilder
    private func knowledgeSection(index: Int) -> some View {
        Section("Knowledge") {
            knowledgeField(index: index, label: "Data Formats",
                           prompt: "e.g. PDF, JSON, SQL, CSV",
                           keyPath: \.knowledgeDataFormats)
            knowledgeField(index: index, label: "Size / Quantity",
                           prompt: "e.g. 50 GB, 10k documents",
                           keyPath: \.knowledgeSizeQuantity)
            knowledgeField(index: index, label: "Location",
                           prompt: "e.g. S3 bucket, Postgres, SharePoint",
                           keyPath: \.knowledgeLocation)
            knowledgeField(index: index, label: "Access Method",
                           prompt: "e.g. REST API, SQL query, RAG pipeline",
                           keyPath: \.knowledgeAccessMethod)
            knowledgeField(index: index, label: "Sensitivity",
                           prompt: "e.g. Public, Internal, Confidential, PII",
                           keyPath: \.knowledgeSensitivity)
            knowledgeField(index: index, label: "Update Frequency",
                           prompt: "e.g. Real-time, Daily, Weekly, Static",
                           keyPath: \.knowledgeUpdateFrequency)
            knowledgeField(index: index, label: "Versioning",
                           prompt: "e.g. Git, timestamped snapshots, none",
                           keyPath: \.knowledgeVersioningMethod)

            Picker("Retrieval Strategy", selection: Binding(
                get: { document.nodes[safe: index]?.knowledgeRetrievalStrategy ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].knowledgeRetrievalStrategy = $0 } }
            )) {
                ForEach(RetrievalStrategy.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            knowledgeField(index: index, label: "Chunking Strategy",
                           prompt: "e.g. 512 tokens, by paragraph, semantic",
                           keyPath: \.knowledgeChunkingStrategy)
            knowledgeField(index: index, label: "Content Type",
                           prompt: "e.g. Legal, Technical, FAQ, Policy",
                           keyPath: \.knowledgeContentType)
        }
    }

    private func knowledgeField(index: Int, label: LocalizedStringKey, prompt: LocalizedStringKey,
                                keyPath: WritableKeyPath<GraphNode, String?>) -> some View {
        TextField(label, text: Binding(
            get: { document.nodes[safe: index]?[keyPath: keyPath] ?? "" },
            set: { if index < document.nodes.count { document.nodes[index][keyPath: keyPath] = $0.isEmpty ? nil : $0 } }
        ), prompt: Text(prompt))
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Tool Metadata

    @ViewBuilder
    private func agentSection(index: Int) -> some View {
        Section("Agent") {
            Picker("Type", selection: Binding(
                get: { document.nodes[safe: index]?.agentType ?? .worker },
                set: { if index < document.nodes.count { document.nodes[index].agentType = $0 } }
            )) {
                ForEach(AgentType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Framework", selection: Binding(
                get: { document.nodes[safe: index]?.agentFramework ?? .custom },
                set: { if index < document.nodes.count { document.nodes[index].agentFramework = $0 } }
            )) {
                ForEach(AgentFramework.allCases, id: \.self) { fw in
                    Text(fw.displayName).tag(fw)
                }
            }

            agentField(index: index, label: "Model",
                        prompt: "e.g. gpt-4o, claude-3.5-sonnet",
                        keyPath: \.agentModel)
            agentField(index: index, label: "Role",
                        prompt: "e.g. Research Analyst",
                        keyPath: \.agentRole)
            agentField(index: index, label: "Goal",
                        prompt: "e.g. Find and summarise key findings",
                        keyPath: \.agentGoal)
            VStack(alignment: .leading, spacing: 4) {
                Text("Instructions")
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    TextEditor(text: Binding(
                        get: { document.nodes[safe: index]?.agentInstructions ?? "" },
                        set: { if index < document.nodes.count {
                            document.nodes[index].agentInstructions = $0.isEmpty ? nil : $0
                        }}
                    ))
                    .font(.body)
                    .scrollContentBackground(.visible)
                    .frame(height: max(80, instructionsHeight))

                    DragResizeHandle(height: $instructionsHeight, minHeight: 80)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Picker("Memory", selection: Binding(
                get: { document.nodes[safe: index]?.agentMemory ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].agentMemory = $0 } }
            )) {
                ForEach(AgentMemoryType.allCases, id: \.self) { mem in
                    Text(mem.displayName).tag(mem)
                }
            }

            agentField(index: index, label: "Max Iterations",
                        prompt: "e.g. 10",
                        keyPath: \.agentMaxIterations)

            Picker("Delegation", selection: Binding(
                get: { document.nodes[safe: index]?.agentCanDelegate ?? false },
                set: { if index < document.nodes.count { document.nodes[index].agentCanDelegate = $0 } }
            )) {
                Text("Disabled").tag(false)
                Text("Enabled").tag(true)
            }

            Picker("Complexity", selection: Binding(
                get: { document.nodes[safe: index]?.agentComplexity ?? .reasoning },
                set: { if index < document.nodes.count { document.nodes[index].agentComplexity = $0 } }
            )) {
                ForEach(AgentComplexity.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Prompt Mgmt", selection: Binding(
                get: { document.nodes[safe: index]?.agentPromptManagement ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].agentPromptManagement = $0 } }
            )) {
                ForEach(AgentPromptManagement.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Context Strategy", selection: Binding(
                get: { document.nodes[safe: index]?.agentContextStrategy ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].agentContextStrategy = $0 } }
            )) {
                ForEach(AgentContextStrategy.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Observability", selection: Binding(
                get: { document.nodes[safe: index]?.agentObservability ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].agentObservability = $0 } }
            )) {
                ForEach(ObservabilityLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            agentField(index: index, label: "Latency Budget",
                        prompt: "e.g. 300ms, 3s, 5-8s",
                        keyPath: \.agentLatencyBudget)
            agentField(index: index, label: "Expected Duration",
                        prompt: "e.g. 2s, 5s",
                        keyPath: \.expectedDuration)
            agentField(index: index, label: "Cost Budget",
                        prompt: "e.g. $0.10/call, 1000 tokens",
                        keyPath: \.agentCostBudget)
        }
    }

    private func agentField(index: Int, label: LocalizedStringKey, prompt: LocalizedStringKey,
                             keyPath: WritableKeyPath<GraphNode, String?>) -> some View {
        TextField(label, text: Binding(
            get: { document.nodes[safe: index]?[keyPath: keyPath] ?? "" },
            set: { if index < document.nodes.count { document.nodes[index][keyPath: keyPath] = $0.isEmpty ? nil : $0 } }
        ), prompt: Text(prompt))
        .textFieldStyle(.roundedBorder)
    }

    private func toolSection(index: Int) -> some View {
        Section("Tool") {
            Picker("Type", selection: Binding(
                get: { document.nodes[safe: index]?.toolType ?? .custom },
                set: { if index < document.nodes.count { document.nodes[index].toolType = $0 } }
            )) {
                ForEach(ToolType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Category", selection: Binding(
                get: { document.nodes[safe: index]?.toolCategory ?? .general },
                set: { if index < document.nodes.count { document.nodes[index].toolCategory = $0 } }
            )) {
                ForEach(ToolCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Execution", selection: Binding(
                get: { document.nodes[safe: index]?.toolAsync ?? false },
                set: { if index < document.nodes.count { document.nodes[index].toolAsync = $0 } }
            )) {
                Text("Sync").tag(false)
                Text("Async").tag(true)
            }

            toolField(index: index, label: "Inputs",
                       prompt: "e.g. query: String, limit: Int",
                       keyPath: \.toolInputs)
            toolField(index: index, label: "Outputs",
                       prompt: "e.g. results: [Document]",
                       keyPath: \.toolOutputs)

            Picker("Auth Method", selection: Binding(
                get: { document.nodes[safe: index]?.toolAuthMethod ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].toolAuthMethod = $0 } }
            )) {
                ForEach(ToolAuthMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }

            toolField(index: index, label: "Endpoint",
                       prompt: "e.g. https://api.example.com/v1",
                       keyPath: \.toolEndpoint)
            toolField(index: index, label: "Timeout",
                       prompt: "e.g. 30 (seconds)",
                       keyPath: \.toolTimeout)
            toolField(index: index, label: "Expected Duration",
                       prompt: "e.g. 800ms, 1.5s",
                       keyPath: \.expectedDuration)

            Picker("Error Handling", selection: Binding(
                get: { document.nodes[safe: index]?.toolErrorHandling ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].toolErrorHandling = $0 } }
            )) {
                ForEach(ToolErrorHandling.allCases, id: \.self) { handling in
                    Text(handling.displayName).tag(handling)
                }
            }

            Picker("Idempotent", selection: Binding(
                get: { document.nodes[safe: index]?.toolIdempotent ?? false },
                set: { if index < document.nodes.count { document.nodes[index].toolIdempotent = $0 } }
            )) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }

            toolField(index: index, label: "Data Volume",
                       prompt: "e.g. Small, Large, Paginated",
                       keyPath: \.toolDataVolume)
        }
    }

    private func toolField(index: Int, label: LocalizedStringKey, prompt: LocalizedStringKey,
                            keyPath: WritableKeyPath<GraphNode, String?>) -> some View {
        TextField(label, text: Binding(
            get: { document.nodes[safe: index]?[keyPath: keyPath] ?? "" },
            set: { if index < document.nodes.count { document.nodes[index][keyPath: keyPath] = $0.isEmpty ? nil : $0 } }
        ), prompt: Text(prompt))
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Human Section

    private func humanSection(index: Int) -> some View {
        Section("Human") {
            Picker("Input Channel", selection: Binding(
                get: { document.nodes[safe: index]?.humanInputChannel ?? .none },
                set: { if index < document.nodes.count { document.nodes[index].humanInputChannel = $0 } }
            )) {
                ForEach(HumanChannel.allCases, id: \.self) { channel in
                    Text(channel.displayName).tag(channel)
                }
            }

            Picker("Output Channel", selection: Binding(
                get: { document.nodes[safe: index]?.humanChannel ?? .email },
                set: { if index < document.nodes.count { document.nodes[index].humanChannel = $0 } }
            )) {
                ForEach(HumanChannel.allCases, id: \.self) { channel in
                    Text(channel.displayName).tag(channel)
                }
            }

            humanField(index: index, label: "Role",
                       prompt: "e.g. Customer, Admin, Analyst",
                       keyPath: \.humanRole)
            humanField(index: index, label: "Language",
                       prompt: "e.g. English, Spanish",
                       keyPath: \.humanLanguage)
            humanField(index: index, label: "Timezone",
                       prompt: "e.g. UTC, EST, GMT+1",
                       keyPath: \.humanTimezone)
            humanField(index: index, label: "Auth Method",
                       prompt: "e.g. SSO, MFA, API Key",
                       keyPath: \.humanAuthMethod)
            humanField(index: index, label: "Access Level",
                       prompt: "e.g. Read-only, Full access, Admin",
                       keyPath: \.humanAccessLevel)
            humanField(index: index, label: "SLA / Response",
                       prompt: "e.g. 4h response, real-time",
                       keyPath: \.humanSLA)
            humanField(index: index, label: "Expected Behaviors",
                       prompt: "e.g. Submits forms, approves requests",
                       keyPath: \.humanBehaviors)
        }
    }

    private func humanField(index: Int, label: LocalizedStringKey, prompt: LocalizedStringKey,
                             keyPath: WritableKeyPath<GraphNode, String?>) -> some View {
        TextField(label, text: Binding(
            get: { document.nodes[safe: index]?[keyPath: keyPath] ?? "" },
            set: { if index < document.nodes.count { document.nodes[index][keyPath: keyPath] = $0.isEmpty ? nil : $0 } }
        ), prompt: Text(prompt))
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Shape Appearance

    @ViewBuilder
    private func shapeAppearanceSection(index: Int, node: GraphNode) -> some View {
        let kindKey = "\(node.kind)"
        Section("Appearance") {
            // Line color
            PopoverColorPicker(label: "Line Color", color: Binding(
                get: {
                    if let hex = document.nodes[safe: index]?.strokeColorHex {
                        return Color(hex: hex)
                    }
                    return .gray
                },
                set: {
                    if index < document.nodes.count {
                        document.nodes[index].strokeColorHex = $0.hexString
                        document.nodeDefaults[kindKey, default: NodeDefaults()].strokeColorHex = $0.hexString
                        NodeDefaults.saveAll(document.nodeDefaults)
                    }
                }
            ))

            // Fill toggle + color
            Toggle("Fill", isOn: Binding(
                get: { document.nodes[safe: index]?.fillEnabled ?? false },
                set: {
                    if index < document.nodes.count {
                        document.nodes[index].fillEnabled = $0
                        document.nodeDefaults[kindKey, default: NodeDefaults()].fillEnabled = $0
                        NodeDefaults.saveAll(document.nodeDefaults)
                    }
                }
            ))

            if node.fillEnabled {
                PopoverColorPicker(label: "Fill Color", color: Binding(
                    get: {
                        if let hex = document.nodes[safe: index]?.fillColorHex {
                            return Color(hex: hex)
                        }
                        return .blue
                    },
                    set: {
                        if index < document.nodes.count {
                            document.nodes[index].fillColorHex = $0.hexString
                            document.nodeDefaults[kindKey, default: NodeDefaults()].fillColorHex = $0.hexString
                            NodeDefaults.saveAll(document.nodeDefaults)
                        }
                    }
                ))
            }

            if document.nodeDefaults[kindKey]?.hasOverrides == true {
                Button("Reset Defaults") {
                    document.nodeDefaults.removeValue(forKey: kindKey)
                    NodeDefaults.saveAll(document.nodeDefaults)
                    if index < document.nodes.count {
                        document.nodes[index].strokeColorHex = nil
                        document.nodes[index].fillColorHex = nil
                        document.nodes[index].fillEnabled = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Text Shape

    @ViewBuilder
    private func textShapeSection(index: Int, node: GraphNode) -> some View {
        let kindKey = "\(node.kind)"
        Section("Text") {
            TextField("Content", text: Binding(
                get: { document.nodes[safe: index]?.title ?? "" },
                set: { if index < document.nodes.count { document.nodes[index].title = $0 } }
            ))

            HStack {
                Text("Font Size")
                Spacer()
                TextField("", value: Binding<Double>(
                    get: { Double(document.nodes[safe: index]?.fontSize ?? 14) },
                    set: {
                        if index < document.nodes.count {
                            document.nodes[index].fontSize = CGFloat($0)
                            document.nodeDefaults[kindKey, default: NodeDefaults()].fontSize = CGFloat($0)
                            NodeDefaults.saveAll(document.nodeDefaults)
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            }

            PopoverColorPicker(label: "Text Color", color: Binding(
                get: {
                    if let hex = document.nodes[safe: index]?.fontColorHex {
                        return Color(hex: hex)
                    }
                    return Color(white: 0.5)
                },
                set: {
                    if index < document.nodes.count {
                        document.nodes[index].fontColorHex = $0.hexString
                        document.nodeDefaults[kindKey, default: NodeDefaults()].fontColorHex = $0.hexString
                        NodeDefaults.saveAll(document.nodeDefaults)
                    }
                }
            ))

            if document.nodeDefaults[kindKey]?.hasOverrides == true {
                Button("Reset Defaults") {
                    document.nodeDefaults.removeValue(forKey: kindKey)
                    NodeDefaults.saveAll(document.nodeDefaults)
                    if index < document.nodes.count {
                        document.nodes[index].fontSize = 14
                        document.nodes[index].fontColorHex = "808080"
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Resize Handle (NSView-based to avoid ghosting)

struct DragResizeHandle: NSViewRepresentable {
    @Binding var height: Double
    var minHeight: Double = 80

    func makeNSView(context: Context) -> ResizeHandleNSView {
        let view = ResizeHandleNSView()
        view.onDrag = { delta in
            height = max(minHeight, height + delta)
        }
        return view
    }

    func updateNSView(_ nsView: ResizeHandleNSView, context: Context) {
        nsView.onDrag = { delta in
            height = max(minHeight, height + delta)
        }
    }
}

class ResizeHandleNSView: NSView {
    var onDrag: ((Double) -> Void)?
    private var lastY: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 8)
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                  owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeUpDown.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        lastY = event.locationInWindow.y
    }

    override func mouseDragged(with event: NSEvent) {
        let currentY = event.locationInWindow.y
        // Window coords are flipped (0 at bottom), so dragging down = negative delta
        let delta = -(currentY - lastY)
        lastY = currentY
        onDrag?(delta)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Background
        NSColor.secondaryLabelColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(rect: bounds).fill()

        // Center pill
        let pillW: CGFloat = 36
        let pillH: CGFloat = 4
        let pillRect = NSRect(
            x: (bounds.width - pillW) / 2,
            y: (bounds.height - pillH) / 2,
            width: pillW, height: pillH
        )
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 2, yRadius: 2).fill()
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
