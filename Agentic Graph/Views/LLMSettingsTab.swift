import SwiftUI

struct LLMSettingsTab: View {
    @Bindable var store: LLMProviderStore
    @State private var testResult: (success: Bool, message: String)?
    @State private var isTesting = false

    // Local editable copies of API key (Keychain-backed)
    @State private var apiKeyText = ""
    @State private var apiKeyLoaded = false

    // wxO agent discovery
    @State private var discoveredAgents: [WxOAgentInfo] = []
    @State private var isLoadingAgents = false
    @State private var agentListError: String?

    var body: some View {
        Form {
            providerSection
            configSection
            if !store.analysisDisabled {
                performanceSection
                connectionSection
            }
        }
        .formStyle(.grouped)
        .onAppear { loadApiKey() }
        .onChange(of: store.activeProvider) { _, _ in loadApiKey(); testResult = nil }
    }

    // MARK: - Provider Selection

    private var providerSection: some View {
        Section("LLM Provider") {
            Picker("Provider", selection: providerChoice) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Disabled")
                }
                .tag(LLMProviderType?.none)
                ForEach(LLMProviderType.allCases.filter { $0 != .apple }) { type in
                    HStack(spacing: 6) {
                        Image(systemName: type.sfSymbol)
                        Text(type.displayName)
                    }
                    .tag(LLMProviderType?.some(type))
                }
            }
        }
    }

    /// Picker selection — `nil` represents the "Disabled" choice.
    private var providerChoice: Binding<LLMProviderType?> {
        Binding(
            get: { store.analysisDisabled ? nil : store.activeProvider },
            set: { store.setProvider($0) }
        )
    }

    // MARK: - Per-Provider Config

    @ViewBuilder
    private var configSection: some View {
        if store.analysisDisabled {
            disabledSection
        } else {
            switch store.activeProvider {
            case .apple:
                appleSection
            case .openai:
                openaiSection
            case .ollama:
                ollamaSection
            case .watsonx:
                watsonxSection
            case .wxo:
                wxoSection
            }
        }
    }

    private var disabledSection: some View {
        Section("Disabled") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                    Text("AI analysis is turned off.")
                        .font(.callout.weight(.medium))
                }
                Text("The Analysis and Prompt Analysis tabs are hidden from the Inspector, and Analyze Architecture is unavailable. Choose a provider above to turn them back on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appleSection: some View {
        Section("Apple Intelligence") {
            HStack {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.secondary)
                Text("Uses the on-device Foundation Models framework. No configuration needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var openaiSection: some View {
        Section("OpenAI Compatible") {
            configField("API Base URL", placeholder: LLMProviderType.openai.defaultApiBase, keyPath: \.apiBase, provider: .openai)
            apiKeyField
            configField("Model", placeholder: LLMProviderType.openai.modelPlaceholder, keyPath: \.model, provider: .openai)

            reasoningToggle(provider: .openai)

            Text("Works with OpenAI, LM Studio, vLLM, LocalAI, or any OpenAI-compatible endpoint.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var ollamaSection: some View {
        Section("Ollama") {
            configField("API Base URL", placeholder: LLMProviderType.ollama.defaultApiBase, keyPath: \.apiBase, provider: .ollama)
            configField("Model", placeholder: LLMProviderType.ollama.modelPlaceholder, keyPath: \.model, provider: .ollama)
            reasoningToggle(provider: .ollama)

            Text("Connect to a local Ollama instance. Ensure Ollama is running before testing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var watsonxSection: some View {
        Section("watsonx.ai") {
            configField("API Base URL", placeholder: LLMProviderType.watsonx.defaultApiBase, keyPath: \.apiBase, provider: .watsonx)
            apiKeyField
            configField("Project ID", placeholder: "watsonx.ai project UUID", keyPath: \.projectId, provider: .watsonx)
            configField("Model", placeholder: LLMProviderType.watsonx.modelPlaceholder, keyPath: \.model, provider: .watsonx)
            reasoningToggle(provider: .watsonx)

            Text("Uses IBM Cloud IAM for authentication. API key is exchanged for a bearer token automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentWxOAuthType: WxOAuthType {
        store.settings(for: .wxo).authType ?? .local
    }

    private func wxoAuthConfig(for authType: WxOAuthType) -> WxOAuthConfig {
        store.settings(for: .wxo).wxoAuthConfigs?[authType.rawValue] ?? WxOAuthConfig(apiBase: authType.defaultApiBase)
    }

    private func updateWxOAuthConfig(for authType: WxOAuthType, _ block: (inout WxOAuthConfig) -> Void) {
        store.updateSettings(for: .wxo) { settings in
            var configs = settings.wxoAuthConfigs ?? [:]
            var config = configs[authType.rawValue] ?? WxOAuthConfig(apiBase: authType.defaultApiBase)
            block(&config)
            configs[authType.rawValue] = config
            settings.wxoAuthConfigs = configs
        }
    }

    private var wxoSection: some View {
        let authType = currentWxOAuthType
        let authConfig = wxoAuthConfig(for: authType)

        return Section("watsonx Orchestrate") {
            TextField("API Base URL", text: Binding(
                get: { wxoAuthConfig(for: .local).apiBase ?? WxOAuthType.local.defaultApiBase },
                set: { val in updateWxOAuthConfig(for: .local) { $0.apiBase = val.isEmpty ? nil : val } }
            ), prompt: Text(WxOAuthType.local.defaultApiBase))
            .textFieldStyle(.roundedBorder)

            // Selected agent display
            let currentAgentId = authConfig.agentId ?? ""
            if !currentAgentId.isEmpty {
                let agentLabel = discoveredAgents.first(where: { $0.id == currentAgentId })?.name
                    ?? authConfig.agentName
                HStack {
                    Text("Agent")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let name = agentLabel {
                            Text(name)
                                .fontWeight(.medium)
                        }
                        Text(currentAgentId)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
            }

            // Agent discovery
            HStack {
                Button {
                    Task { await loadAgents() }
                } label: {
                    HStack(spacing: 4) {
                        if isLoadingAgents {
                            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                        }
                        Text(isLoadingAgents ? "Loading..." : "List Agents")
                    }
                }
                .disabled(isLoadingAgents)

                if let error = agentListError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            if !discoveredAgents.isEmpty {
                ForEach(discoveredAgents) { agent in
                    Button {
                        updateWxOAuthConfig(for: authType) { $0.agentId = agent.id; $0.agentName = agent.name }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(agent.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if !agent.description.isEmpty {
                                    Text(agent.description)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if currentAgentId == agent.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Connects to a local ADK instance. Token is read from ~/.cache/orchestrate/credentials.yaml automatically. The agent defines the model and reasoning settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        let type = store.activeProvider
        let currentConcurrency = store.settings(for: type).concurrency ?? type.defaultConcurrency

        return Section("Performance") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Parallel Evaluations")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(store.settings(for: type).concurrency ?? type.defaultConcurrency) },
                        set: { val in store.updateSettings(for: type) { $0.concurrency = Int(val) } }
                    ), in: 1...8, step: 1)
                    .labelsHidden()
                    .frame(width: 150)

                    Text("\(currentConcurrency)")
                        .font(.title3.monospacedDigit())
                        .fontWeight(.medium)
                        .frame(width: 24, alignment: .trailing)
                }

                Text(concurrencyDescription(currentConcurrency))
                    .font(.caption)
                    .foregroundStyle(currentConcurrency > 5 ? .orange : .secondary)
            }
        }
    }

    private func concurrencyDescription(_ value: Int) -> String {
        switch value {
        case 1: "Sequential. Slowest but lowest resource usage."
        case 2...3: "Recommended. Good balance of speed and resource usage."
        case 4...5: "Faster. Diminishing returns beyond 3 for most providers."
        case 6...8: "High concurrency. May increase memory pressure without improving speed."
        default: ""
        }
    }

    private var canTestConnection: Bool {
        let type = store.activeProvider
        let settings = store.settings(for: type)
        switch type {
        case .apple: return true
        case .openai: return !(settings.model ?? "").isEmpty
        case .ollama: return !(settings.model ?? "").isEmpty
        case .watsonx: return !(settings.model ?? "").isEmpty && !store.apiKey(for: type).isEmpty
        case .wxo: return !settings.wxoAgentId.isEmpty
        }
    }

    // MARK: - Connection Test

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(isTesting || !canTestConnection)

                Spacer()

                if let result = testResult {
                    HStack(spacing: 4) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Reasoning Toggle

    private func reasoningToggle(provider: LLMProviderType) -> some View {
        Picker("Reasoning", selection: Binding(
            get: { store.settings(for: provider).reasoningLevel ?? .off },
            set: { val in store.updateSettings(for: provider) { $0.reasoningLevel = val } }
        )) {
            ForEach(ReasoningLevel.allCases, id: \.self) { level in
                Text(level.displayName).tag(level)
            }
        }
        .help("Off = fast/cheap. Low/Medium/High = increasing thinking depth, token budget, and temperature. Higher levels produce better analysis but are slower.")
    }

    // MARK: - Helpers

    private func configField(_ label: LocalizedStringKey, placeholder: String,
                              keyPath: WritableKeyPath<ProviderSettings, String?>,
                              provider: LLMProviderType) -> some View {
        // `placeholder` is typically a runtime value (URL/UUID), shown verbatim.
        TextField(label, text: Binding(
            get: { store.settings(for: provider)[keyPath: keyPath] ?? "" },
            set: { val in store.updateSettings(for: provider) { $0[keyPath: keyPath] = val.isEmpty ? nil : val } }
        ), prompt: Text(verbatim: placeholder))
        .textFieldStyle(.roundedBorder)
    }

    private var apiKeyField: some View {
        SecureField("API Key", text: $apiKeyText, prompt: Text("Enter API key"))
            .textFieldStyle(.roundedBorder)
            .onChange(of: apiKeyText) { _, newVal in
                store.setApiKey(newVal, for: store.activeProvider)
            }
    }

    private func loadApiKey() {
        apiKeyText = store.apiKey(for: store.activeProvider)
        apiKeyLoaded = true
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        let result = await LLMHealthCheck.test(store: store)
        isTesting = false
        testResult = result
    }

    private func loadAgents() async {
        isLoadingAgents = true
        agentListError = nil
        discoveredAgents = []

        do {
            let settings = store.settings(for: .wxo)
            let base = settings.wxoApiBase

            // Read local token using same approach as the provider
            let username = NSUserName()
            let candidates = [
                NSHomeDirectory() + "/.cache/orchestrate/credentials.yaml",
                "/Users/\(username)/.cache/orchestrate/credentials.yaml"
            ]
            var token: String?
            for path in candidates {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    var foundLocal = false
                    for line in content.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed == "local:" { foundLocal = true; continue }
                        if foundLocal && trimmed.hasPrefix("wxo_mcsp_token:") {
                            let val = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            if !val.isEmpty { token = val; break }
                        }
                    }
                    if token != nil { break }
                }
            }
            guard let token else { throw LLMError.authError("No local token found. Ensure the ADK instance is running.") }

            discoveredAgents = try await WxOAgentDiscovery.listAgents(apiBase: base, token: token)
            if discoveredAgents.isEmpty {
                agentListError = "No agents found"
            }
        } catch {
            agentListError = error.localizedDescription
        }

        isLoadingAgents = false
    }
}
