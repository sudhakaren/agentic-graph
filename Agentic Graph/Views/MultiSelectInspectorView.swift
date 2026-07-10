import SwiftUI

struct MultiSelectInspectorView: View {
    @Bindable var document: GraphDocument
    @State private var formState = MultiSelectFormState()
    @State private var excludedKinds: Set<NodeKind> = []
    @State private var excludeEdges: Bool = false

    // MARK: - Selection Data

    private var selectedNodes: [GraphNode] {
        document.allSelectedNodeIDs.compactMap { document.node(for: $0) }
    }

    private var selectedKinds: Set<NodeKind> {
        Set(selectedNodes.map(\.kind))
    }

    private var selectedEdgeIDs: Set<UUID> {
        document.allSelectedEdgeIDs
    }

    // MARK: - Filtered (Active) Data

    private var activeKinds: Set<NodeKind> {
        selectedKinds.subtracting(excludedKinds)
    }

    private var activeNodeIDs: Set<UUID> {
        document.allSelectedNodeIDs.filter { id in
            guard let node = document.node(for: id) else { return false }
            return !excludedKinds.contains(node.kind)
        }
    }

    private var activeEdgeIDs: Set<UUID> {
        excludeEdges ? [] : selectedEdgeIDs
    }

    private var commonCategories: Set<InspectorFieldCategory> {
        InspectorFieldCategory.commonCategories(for: activeKinds)
    }

    private var lockedCount: Int {
        activeNodeIDs.compactMap { document.node(for: $0) }
            .filter { $0.isDetailsLocked }
            .count
    }

    private var allActiveLocked: Bool {
        let activeNodes = activeNodeIDs.compactMap { document.node(for: $0) }
        return !activeNodes.isEmpty && activeNodes.allSatisfy { $0.isDetailsLocked }
    }

    /// True when there are no active items to apply to
    private var nothingActive: Bool {
        activeNodeIDs.isEmpty && activeEdgeIDs.isEmpty
    }

    var body: some View {
        Form {
            // MARK: - Selection Summary
            selectionSummary

            // MARK: - Universal Fields
            if !activeKinds.isEmpty, commonCategories.contains(.universal) {
                Section("Common Properties") {
                    toggleTextField("Title", key: "title", text: $formState.title)
                    toggleTextField("Detail", key: "detail", text: $formState.detail, isMultiLine: true)

                    togglePicker("Lock", key: "lockState", selection: $formState.lockState) {
                        ForEach(LockState.allCases, id: \.self) { state in
                            Text(state.displayName).tag(state)
                        }
                    }

                    toggleColorField("Color", key: "colorHex", hex: $formState.colorHex)
                }
            }

            // MARK: - Risk
            if commonCategories.contains(.riskEnabled) {
                Section("Risk") {
                    togglePicker("Risk Level", key: "risk", selection: $formState.risk) {
                        ForEach(RiskLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }
            }

            // MARK: - Agent
            if commonCategories.contains(.agent) {
                Section("Agent") {
                    togglePicker("Framework", key: "agentFramework", selection: $formState.agentFramework) {
                        ForEach(AgentFramework.allCases, id: \.self) { fw in
                            Text(fw.displayName).tag(fw)
                        }
                    }
                    toggleTextField("Model", key: "agentModel", text: $formState.agentModel,
                                    prompt: "e.g. gpt-4o, claude-3.5-sonnet")
                    toggleTextField("Role", key: "agentRole", text: $formState.agentRole,
                                    prompt: "e.g. Research Analyst")
                    toggleTextField("Goal", key: "agentGoal", text: $formState.agentGoal,
                                    prompt: "e.g. Find and summarise key findings")
                    toggleTextField("Instructions", key: "agentInstructions", text: $formState.agentInstructions,
                                    isMultiLine: true)
                    togglePicker("Memory", key: "agentMemory", selection: $formState.agentMemory) {
                        ForEach(AgentMemoryType.allCases, id: \.self) { mem in
                            Text(mem.displayName).tag(mem)
                        }
                    }
                    toggleTextField("Max Iterations", key: "agentMaxIterations", text: $formState.agentMaxIterations,
                                    prompt: "e.g. 10")
                    toggleBoolPicker("Can Delegate", key: "agentCanDelegate", value: $formState.agentCanDelegate)
                }
            }

            // MARK: - Tool
            if commonCategories.contains(.tool) {
                Section("Tool") {
                    togglePicker("Type", key: "toolType", selection: $formState.toolType) {
                        ForEach(ToolType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    toggleBoolPicker("Async", key: "toolAsync", value: $formState.toolAsync)
                    toggleTextField("Inputs", key: "toolInputs", text: $formState.toolInputs,
                                    prompt: "e.g. query: String, limit: Int")
                    toggleTextField("Outputs", key: "toolOutputs", text: $formState.toolOutputs,
                                    prompt: "e.g. results: [Document]")
                    togglePicker("Auth Method", key: "toolAuthMethod", selection: $formState.toolAuthMethod) {
                        ForEach(ToolAuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    toggleTextField("Endpoint", key: "toolEndpoint", text: $formState.toolEndpoint,
                                    prompt: "e.g. https://api.example.com/v1")
                    toggleTextField("Timeout", key: "toolTimeout", text: $formState.toolTimeout,
                                    prompt: "e.g. 30 (seconds)")
                    togglePicker("Error Handling", key: "toolErrorHandling", selection: $formState.toolErrorHandling) {
                        ForEach(ToolErrorHandling.allCases, id: \.self) { handling in
                            Text(handling.displayName).tag(handling)
                        }
                    }
                }
            }

            // MARK: - Knowledge
            if commonCategories.contains(.knowledge) {
                Section("Knowledge") {
                    toggleTextField("Data Formats", key: "knowledgeDataFormats",
                                    text: $formState.knowledgeDataFormats, prompt: "e.g. PDF, JSON, SQL, CSV")
                    toggleTextField("Size / Quantity", key: "knowledgeSizeQuantity",
                                    text: $formState.knowledgeSizeQuantity, prompt: "e.g. 50 GB, 10k documents")
                    toggleTextField("Location", key: "knowledgeLocation",
                                    text: $formState.knowledgeLocation, prompt: "e.g. S3 bucket, Postgres")
                    toggleTextField("Access Method", key: "knowledgeAccessMethod",
                                    text: $formState.knowledgeAccessMethod, prompt: "e.g. REST API, SQL query")
                    toggleTextField("Sensitivity", key: "knowledgeSensitivity",
                                    text: $formState.knowledgeSensitivity, prompt: "e.g. Public, Confidential")
                    toggleTextField("Update Frequency", key: "knowledgeUpdateFrequency",
                                    text: $formState.knowledgeUpdateFrequency, prompt: "e.g. Real-time, Daily")
                    toggleTextField("Versioning", key: "knowledgeVersioningMethod",
                                    text: $formState.knowledgeVersioningMethod, prompt: "e.g. Git, timestamped")
                }
            }

            // MARK: - Shape
            if commonCategories.contains(.shape) {
                Section("Shape") {
                    toggleColorField("Line Color", key: "strokeColorHex", hex: $formState.strokeColorHex)
                    toggleBoolPicker("Fill", key: "fillEnabled", value: $formState.fillEnabled)
                    toggleColorField("Fill Color", key: "fillColorHex", hex: $formState.fillColorHex)
                }
            }

            // MARK: - Text Shape
            if commonCategories.contains(.textShape) {
                Section("Text") {
                    toggleTextField("Font Size", key: "fontSize", text: $formState.fontSize, prompt: "e.g. 14")
                    toggleColorField("Text Color", key: "fontColorHex", hex: $formState.fontColorHex)
                }
            }

            // MARK: - Edges
            if !activeEdgeIDs.isEmpty {
                Section("Edges (\(activeEdgeIDs.count))") {
                    toggleColorField("Edge Color", key: "edgeColorHex", hex: $formState.edgeColorHex)
                    togglePicker("Line Style", key: "edgeLineStyle", selection: $formState.edgeLineStyle) {
                        ForEach(EdgeLineStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }
            }

            // MARK: - Actions
            Section {
                HStack {
                    Button("Reset") {
                        formState.reset()
                    }
                    .disabled(!formState.hasChanges)

                    Spacer()

                    Button("Apply") {
                        applyChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!formState.hasChanges || nothingActive || (activeEdgeIDs.isEmpty && allActiveLocked && !formState.enabledFields.contains("lockState")))
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
        .onChange(of: document.allSelectedNodeIDs) { _, _ in
            formState.reset()
            excludedKinds = []
            excludeEdges = false
        }
        .onChange(of: document.allSelectedEdgeIDs) { _, _ in
            formState.reset()
            excludedKinds = []
            excludeEdges = false
        }
    }

    // MARK: - Selection Summary

    @ViewBuilder
    private var selectionSummary: some View {
        Section {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(.secondary)
                let totalItems = selectedNodes.count + selectedEdgeIDs.count
                Text("\(totalItems) items selected")
                    .font(.headline)
            }

            // Node kind rows with toggles
            let kindCounts = Dictionary(grouping: selectedNodes, by: \.kind)
            ForEach(Array(kindCounts.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                let count = kindCounts[kind]?.count ?? 0
                let isExcluded = excludedKinds.contains(kind)
                summaryToggleRow(
                    label: "\(count) \(kind.displayName)",
                    systemImage: kind.sfSymbol,
                    color: kind.color,
                    isExcluded: isExcluded,
                    canExclude: canExcludeKind(kind)
                ) {
                    if isExcluded {
                        excludedKinds.remove(kind)
                    } else {
                        excludedKinds.insert(kind)
                    }
                }
            }

            // Edge row with toggle
            if !selectedEdgeIDs.isEmpty {
                summaryToggleRow(
                    label: "\(selectedEdgeIDs.count) \(selectedEdgeIDs.count == 1 ? "Edge" : "Edges")",
                    systemImage: "line.diagonal",
                    color: .secondary,
                    isExcluded: excludeEdges,
                    canExclude: canExcludeEdges
                ) {
                    excludeEdges.toggle()
                }
            }

            if lockedCount > 0 {
                Label("\(lockedCount) details-locked (will skip)",
                      systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// A row in the selection summary with an include/exclude toggle
    @ViewBuilder
    private func summaryToggleRow(
        label: String,
        systemImage: String,
        color: Color,
        isExcluded: Bool,
        canExclude: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Button(action: action) {
                Image(systemName: isExcluded ? "square" : "checkmark.square.fill")
                    .foregroundColor(isExcluded ? .secondary : .accentColor)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canExclude && !isExcluded)

            Label(label, systemImage: systemImage)
                .foregroundStyle(isExcluded ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                .font(.caption)
                .strikethrough(isExcluded)
        }
    }

    /// Can only exclude a kind if at least one other kind or edges will remain active
    private func canExcludeKind(_ kind: NodeKind) -> Bool {
        let otherActiveKinds = activeKinds.subtracting([kind])
        let hasOtherNodes = !otherActiveKinds.isEmpty
        let hasEdges = !activeEdgeIDs.isEmpty
        return hasOtherNodes || hasEdges
    }

    /// Can only exclude edges if at least one node kind is still active
    private var canExcludeEdges: Bool {
        !activeKinds.isEmpty
    }

    // MARK: - Apply

    private func applyChanges() {
        // Apply node changes if there are active nodes
        if !activeNodeIDs.isEmpty {
            document.batchApplyMultiSelectChanges(
                nodeIDs: activeNodeIDs,
                formState: formState,
                commonCategories: commonCategories
            )
        }

        // Apply edge changes if there are active edges
        if !activeEdgeIDs.isEmpty {
            document.batchApplyEdgeChanges(
                edgeIDs: activeEdgeIDs,
                formState: formState
            )
        }

        formState.reset()
    }

    // MARK: - Reusable Toggle Field Builders

    /// A text field with a checkbox toggle on the left. Disabled until toggled on.
    @ViewBuilder
    private func toggleTextField(
        _ label: LocalizedStringKey,
        key: String,
        text: Binding<String>,
        prompt: LocalizedStringKey = "Enter value",
        isMultiLine: Bool = false
    ) -> some View {
        let isEnabled = formState.enabledFields.contains(key)
        HStack(alignment: .top, spacing: 6) {
            Button {
                if isEnabled {
                    formState.enabledFields.remove(key)
                } else {
                    formState.enabledFields.insert(key)
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .padding(.top, isMultiLine ? 4 : 0)

            VStack(alignment: .leading, spacing: 2) {
                if isMultiLine {
                    Text(label)
                        .foregroundStyle(isEnabled ? .primary : .tertiary)
                        .font(.caption)
                    TextEditor(text: text)
                        .font(.body)
                        .scrollContentBackground(.visible)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .disabled(!isEnabled)
                        .opacity(isEnabled ? 1 : 0.4)
                } else {
                    TextField(label, text: text, prompt: Text(prompt))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isEnabled)
                        .opacity(isEnabled ? 1 : 0.4)
                }
            }
        }
    }

    /// A picker with a checkbox toggle on the left. Disabled until toggled on.
    @ViewBuilder
    private func togglePicker<SelectionValue: Hashable, Content: View>(
        _ label: LocalizedStringKey,
        key: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isEnabled = formState.enabledFields.contains(key)
        HStack(spacing: 6) {
            Button {
                if isEnabled {
                    formState.enabledFields.remove(key)
                } else {
                    formState.enabledFields.insert(key)
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            Picker(label, selection: selection, content: content)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }

    /// A bool picker (Yes/No) with a checkbox toggle.
    @ViewBuilder
    private func toggleBoolPicker(
        _ label: LocalizedStringKey,
        key: String,
        value: Binding<Bool>
    ) -> some View {
        let isEnabled = formState.enabledFields.contains(key)
        HStack(spacing: 6) {
            Button {
                if isEnabled {
                    formState.enabledFields.remove(key)
                } else {
                    formState.enabledFields.insert(key)
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            Picker(label, selection: value) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
        }
    }

    /// A color picker with a checkbox toggle. Shows the color swatch only when enabled.
    @ViewBuilder
    private func toggleColorField(
        _ label: LocalizedStringKey,
        key: String,
        hex: Binding<String>
    ) -> some View {
        let isEnabled = formState.enabledFields.contains(key)
        HStack(spacing: 6) {
            Button {
                if isEnabled {
                    formState.enabledFields.remove(key)
                } else {
                    formState.enabledFields.insert(key)
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            if isEnabled {
                PopoverColorPicker(label: label, color: Binding(
                    get: { Color(hex: hex.wrappedValue) },
                    set: { hex.wrappedValue = $0.hexString }
                ))
            } else {
                LabeledContent(label) {
                    Text("Not set")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .opacity(0.4)
            }
        }
    }
}
