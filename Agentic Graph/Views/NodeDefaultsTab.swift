import SwiftUI

struct NodeDefaultsTab: View {
    let kind: NodeKind
    @Binding var defaults: [String: NodeDefaults]

    private var kindKey: String { kind.rawValue }

    private var current: NodeDefaults {
        defaults[kindKey] ?? NodeDefaults()
    }

    private func update(_ block: (inout NodeDefaults) -> Void) {
        var d = defaults[kindKey] ?? NodeDefaults()
        block(&d)
        defaults[kindKey] = d
        NodeDefaults.saveAll(defaults)
    }

    var body: some View {
        Form {
            switch kind {
            case .agent:
                agentFields
            case .tool:
                toolFields
            case .knowledge:
                knowledgeFields
            case .human:
                humanFields
            case .comment:
                commentFields
            case .shapeRectangle, .shapeRoundedRect, .shapeOval:
                shapeFields
            case .shapeText:
                textShapeFields
            }

            Section {
                Button("Reset to Built-in Defaults") {
                    defaults.removeValue(forKey: kindKey)
                    NodeDefaults.saveAll(defaults)
                }
                .disabled(!current.hasOverrides)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Agent

    @ViewBuilder
    private var agentFields: some View {
        Section("Agent Defaults") {
            Picker("Type", selection: enumBinding(\.agentType, default: .worker)) {
                ForEach(AgentType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Framework", selection: enumBinding(\.agentFramework, default: .custom)) {
                ForEach(AgentFramework.allCases, id: \.self) { fw in
                    Text(fw.displayName).tag(fw)
                }
            }

            optionalTextField("Model", prompt: "e.g. gpt-4o, claude-3.5-sonnet", keyPath: \.agentModel)
            optionalTextField("Role", prompt: "e.g. Research Analyst", keyPath: \.agentRole)
            optionalTextField("Goal", prompt: "e.g. Find and summarise key findings", keyPath: \.agentGoal)
            VStack(alignment: .leading, spacing: 4) {
                Text("Instructions")
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { current.agentInstructions ?? "" },
                    set: { newValue in
                        update { $0.agentInstructions = newValue.isEmpty ? nil : newValue }
                    }
                ))
                .font(.system(size: 12))
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            Picker("Memory", selection: enumBinding(\.agentMemory, default: .none)) {
                ForEach(AgentMemoryType.allCases, id: \.self) { mem in
                    Text(mem.displayName).tag(mem)
                }
            }

            optionalTextField("Max Iterations", prompt: "e.g. 10", keyPath: \.agentMaxIterations)

            Picker("Delegation", selection: boolBinding(\.agentCanDelegate, default: false)) {
                Text("Disabled").tag(false)
                Text("Enabled").tag(true)
            }

            Picker("Complexity", selection: enumBinding(\.agentComplexity, default: .reasoning)) {
                ForEach(AgentComplexity.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Prompt Mgmt", selection: enumBinding(\.agentPromptManagement, default: .none)) {
                ForEach(AgentPromptManagement.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Context Strategy", selection: enumBinding(\.agentContextStrategy, default: .none)) {
                ForEach(AgentContextStrategy.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Observability", selection: enumBinding(\.agentObservability, default: .none)) {
                ForEach(ObservabilityLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }

        nodeAppearanceSection
    }

    // MARK: - Tool

    @ViewBuilder
    private var toolFields: some View {
        Section("Tool Defaults") {
            Picker("Type", selection: enumBinding(\.toolType, default: .custom)) {
                ForEach(ToolType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Category", selection: enumBinding(\.toolCategory, default: .general)) {
                ForEach(ToolCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Execution", selection: boolBinding(\.toolAsync, default: false)) {
                Text("Sync").tag(false)
                Text("Async").tag(true)
            }

            optionalTextField("Inputs", prompt: "e.g. query: String, limit: Int", keyPath: \.toolInputs)
            optionalTextField("Outputs", prompt: "e.g. results: [Document]", keyPath: \.toolOutputs)

            Picker("Auth Method", selection: enumBinding(\.toolAuthMethod, default: .none)) {
                ForEach(ToolAuthMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }

            optionalTextField("Endpoint", prompt: "e.g. https://api.example.com/v1", keyPath: \.toolEndpoint)
            optionalTextField("Timeout", prompt: "e.g. 30 (seconds)", keyPath: \.toolTimeout)

            Picker("Error Handling", selection: enumBinding(\.toolErrorHandling, default: .none)) {
                ForEach(ToolErrorHandling.allCases, id: \.self) { handling in
                    Text(handling.displayName).tag(handling)
                }
            }
        }

        nodeAppearanceSection
    }

    // MARK: - Knowledge

    @ViewBuilder
    private var knowledgeFields: some View {
        Section("Knowledge Defaults") {
            Picker("Risk", selection: enumBinding(\.risk, default: .none)) {
                ForEach(RiskLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }

            optionalTextField("Data Formats", prompt: "e.g. PDF, JSON, CSV", keyPath: \.knowledgeDataFormats)
            optionalTextField("Size / Quantity", prompt: "e.g. 50 GB", keyPath: \.knowledgeSizeQuantity)
            optionalTextField("Location", prompt: "e.g. S3 bucket, SharePoint", keyPath: \.knowledgeLocation)
            optionalTextField("Access Method", prompt: "e.g. REST API, SDK", keyPath: \.knowledgeAccessMethod)
            optionalTextField("Sensitivity", prompt: "e.g. Confidential, Public", keyPath: \.knowledgeSensitivity)
            optionalTextField("Update Frequency", prompt: "e.g. Daily, Weekly", keyPath: \.knowledgeUpdateFrequency)
            optionalTextField("Versioning", prompt: "e.g. Git, Timestamped", keyPath: \.knowledgeVersioningMethod)

            Picker("Retrieval Strategy", selection: enumBinding(\.knowledgeRetrievalStrategy, default: .none)) {
                ForEach(RetrievalStrategy.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }

        nodeAppearanceSection
    }

    // MARK: - Human

    @ViewBuilder
    private var humanFields: some View {
        Section("Human Defaults") {
            Picker("Input Channel", selection: enumBinding(\.humanInputChannel, default: .none)) {
                ForEach(HumanChannel.allCases, id: \.self) { channel in
                    Text(channel.displayName).tag(channel)
                }
            }

            Picker("Output Channel", selection: enumBinding(\.humanChannel, default: .email)) {
                ForEach(HumanChannel.allCases, id: \.self) { channel in
                    Text(channel.displayName).tag(channel)
                }
            }

            optionalTextField("Role", prompt: "e.g. Customer, Admin", keyPath: \.humanRole)
            optionalTextField("Language", prompt: "e.g. English", keyPath: \.humanLanguage)
            optionalTextField("Timezone", prompt: "e.g. UTC, EST", keyPath: \.humanTimezone)
            optionalTextField("Auth Method", prompt: "e.g. SSO, MFA", keyPath: \.humanAuthMethod)
            optionalTextField("Access Level", prompt: "e.g. Read-only, Admin", keyPath: \.humanAccessLevel)
            optionalTextField("SLA / Response", prompt: "e.g. 4h response", keyPath: \.humanSLA)
            optionalTextField("Expected Behaviors", prompt: "e.g. Submits forms", keyPath: \.humanBehaviors)
        }

        nodeAppearanceSection
    }

    // MARK: - Comment

    @ViewBuilder
    private var commentFields: some View {
        Section("Comment Defaults") {
            PopoverColorPicker(label: "Color", color: colorBinding(
                hexKeyPath: \.colorHex,
                fallback: .yellow
            ))
        }
    }

    // MARK: - Shape (Rect, RoundedRect, Oval)

    @ViewBuilder
    private var shapeFields: some View {
        Section("Shape Defaults") {
            PopoverColorPicker(label: "Line Color", color: colorBinding(
                hexKeyPath: \.strokeColorHex,
                fallback: .gray
            ))

            Toggle("Fill", isOn: boolBinding(\.fillEnabled, default: false))

            if current.fillEnabled == true {
                PopoverColorPicker(label: "Fill Color", color: colorBinding(
                    hexKeyPath: \.fillColorHex,
                    fallback: .blue
                ))
            }
        }
    }

    // MARK: - Node Appearance (shared by Agent, Tool, Knowledge)

    @ViewBuilder
    private var nodeAppearanceSection: some View {
        Section("Appearance") {
            PopoverColorPicker(label: "Banner Color", color: colorBinding(
                hexKeyPath: \.colorHex,
                fallback: kind.color
            ))

            HStack {
                Text("Title Font Size")
                Spacer()
                TextField("", value: Binding<Double>(
                    get: { Double(current.fontSize ?? 13) },
                    set: { newVal in update { $0.fontSize = CGFloat(newVal) } }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            }

            PopoverColorPicker(label: "Title Font Color", color: colorBinding(
                hexKeyPath: \.fontColorHex,
                fallback: .white
            ))
        }
    }

    // MARK: - Text Shape

    @ViewBuilder
    private var textShapeFields: some View {
        Section("Text Defaults") {
            HStack {
                Text("Font Size")
                Spacer()
                TextField("", value: Binding<Double>(
                    get: { Double(current.fontSize ?? 14) },
                    set: { newVal in update { $0.fontSize = CGFloat(newVal) } }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            }

            PopoverColorPicker(label: "Text Color", color: colorBinding(
                hexKeyPath: \.fontColorHex,
                fallback: Color(white: 0.5)
            ))
        }
    }

    // MARK: - Binding Helpers

    /// Binding for an optional enum field. Stores nil when value equals the built-in default.
    private func enumBinding<T: Equatable>(
        _ keyPath: WritableKeyPath<NodeDefaults, T?>,
        default fallback: T
    ) -> Binding<T> {
        Binding(
            get: { current[keyPath: keyPath] ?? fallback },
            set: { newValue in
                update { $0[keyPath: keyPath] = (newValue == fallback) ? nil : newValue }
            }
        )
    }

    /// Binding for an optional Bool field. Stores nil when value equals the built-in default.
    private func boolBinding(
        _ keyPath: WritableKeyPath<NodeDefaults, Bool?>,
        default fallback: Bool
    ) -> Binding<Bool> {
        Binding(
            get: { current[keyPath: keyPath] ?? fallback },
            set: { newValue in
                update { $0[keyPath: keyPath] = (newValue == fallback) ? nil : newValue }
            }
        )
    }

    /// TextField for an optional String field. Empty string stores nil.
    private func optionalTextField(
        _ label: LocalizedStringKey,
        prompt: LocalizedStringKey,
        keyPath: WritableKeyPath<NodeDefaults, String?>
    ) -> some View {
        TextField(label, text: Binding(
            get: { current[keyPath: keyPath] ?? "" },
            set: { newValue in
                update { $0[keyPath: keyPath] = newValue.isEmpty ? nil : newValue }
            }
        ), prompt: Text(prompt))
        .textFieldStyle(.roundedBorder)
    }

    /// Binding<Color> for an optional hex string field.
    private func colorBinding(
        hexKeyPath: WritableKeyPath<NodeDefaults, String?>,
        fallback: Color
    ) -> Binding<Color> {
        Binding(
            get: {
                if let hex = current[keyPath: hexKeyPath] {
                    return Color(hex: hex)
                }
                return fallback
            },
            set: { newColor in
                update { $0[keyPath: hexKeyPath] = newColor.hexString }
            }
        )
    }
}
