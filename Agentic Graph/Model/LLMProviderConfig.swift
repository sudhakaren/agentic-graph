import Foundation
import Security

// MARK: - Provider Type

enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
    case apple
    case openai
    case ollama
    case watsonx
    case wxo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: String(localized: "Apple Intelligence")
        case .openai: String(localized: "OpenAI Compatible")
        case .ollama: String(localized: "Ollama")
        case .watsonx: String(localized: "watsonx.ai")
        case .wxo: String(localized: "watsonx Orchestrate (ADK)")
        }
    }

    var sfSymbol: String {
        switch self {
        case .apple: "apple.intelligence"
        case .openai: "globe"
        case .ollama: "desktopcomputer"
        case .watsonx: "cloud"
        case .wxo: "server.rack"
        }
    }

    var defaultApiBase: String {
        switch self {
        case .apple: ""
        case .openai: "http://localhost:1234/v1"
        case .ollama: "http://localhost:11434"
        case .watsonx: "https://us-south.ml.cloud.ibm.com"
        case .wxo: "http://localhost:4321"
        }
    }

    var defaultConcurrency: Int {
        switch self {
        case .openai, .ollama: 1
        case .apple, .watsonx, .wxo: 3
        }
    }

    var needsApiKey: Bool {
        switch self {
        case .apple, .ollama: false
        case .openai, .watsonx, .wxo: true
        }
    }

    var needsModel: Bool {
        switch self {
        case .apple, .wxo: false
        default: true
        }
    }

    var modelPlaceholder: String {
        switch self {
        case .apple: ""
        case .openai: "e.g. gpt-4o, local-model"
        case .ollama: "e.g. llama3.2, mistral"
        case .watsonx: "e.g. ibm/granite-3-8b-instruct"
        case .wxo: "e.g. ibm/granite-3-8b-instruct"
        }
    }
}

// MARK: - WxO Auth Type

enum WxOAuthType: String, Codable, CaseIterable {
    case local

    var displayName: String {
        switch self {
        case .local: String(localized: "Local Token")
        }
    }

    var defaultApiBase: String {
        switch self {
        case .local: "http://localhost:4321"
        }
    }
}

// MARK: - Provider Settings

enum ReasoningLevel: String, Codable, CaseIterable {
    case off
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .off: String(localized: "Off")
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    /// Maps to provider-appropriate parameters.
    var openAIEffort: String {
        switch self {
        case .off: "low"
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        }
    }

    var maxTokens: Int {
        switch self {
        case .off: 1024
        case .low: 4096
        case .medium: 16384
        case .high: 32768
        }
    }

    var temperature: Double {
        switch self {
        case .off: 0.1
        case .low: 0.2
        case .medium: 0.4
        case .high: 0.7
        }
    }

    var isEnabled: Bool { self != .off }
}

struct ProviderSettings: Codable {
    var model: String?
    var apiBase: String?
    var projectId: String?          // watsonx.ai
    var agentId: String?            // wxO
    var authType: WxOAuthType?      // wxO only
    var reasoningLevel: ReasoningLevel?
    var concurrency: Int?           // Parallel evaluations (default 3)
    // API key stored in Keychain, not here

    // Per-auth-type settings for wxO (each auth type has its own base URL and agent)
    var wxoAuthConfigs: [String: WxOAuthConfig]?
}

struct WxOAuthConfig: Codable {
    var apiBase: String?
    var agentId: String?
    var agentName: String?  // Display name, persisted alongside ID
}

extension ProviderSettings {
    /// Get the effective API base for wxO (local auth).
    var wxoApiBase: String {
        // Check per-auth config first
        if let config = wxoAuthConfigs?[WxOAuthType.local.rawValue], let base = config.apiBase, !base.isEmpty {
            return base
        }
        // Then check top-level apiBase
        if let base = apiBase, !base.isEmpty {
            return base
        }
        return WxOAuthType.local.defaultApiBase
    }

    /// Get the effective agent ID for wxO (local auth).
    var wxoAgentId: String {
        if let config = wxoAuthConfigs?[WxOAuthType.local.rawValue], let id = config.agentId, !id.isEmpty {
            return id
        }
        return agentId ?? ""
    }

    /// Get the persisted agent display name for wxO.
    var wxoAgentName: String? {
        wxoAuthConfigs?[WxOAuthType.local.rawValue]?.agentName
    }
}

// MARK: - LLM Config (persisted)

struct LLMConfig: Codable {
    var activeProvider: LLMProviderType = .openai
    var providers: [String: ProviderSettings] = [:]
    var analysisDisabled: Bool = false
}

// MARK: - LLM Provider Store

@Observable
class LLMProviderStore {
    var config: LLMConfig = LLMConfig()

    var activeProvider: LLMProviderType {
        get { config.activeProvider }
        set { config.activeProvider = newValue; save() }
    }

    /// True when the user has turned AI analysis off (provider set to "Disabled").
    var analysisDisabled: Bool { config.analysisDisabled }

    /// Selects a provider, or turns AI analysis off entirely when `provider` is nil.
    func setProvider(_ provider: LLMProviderType?) {
        if let provider {
            config.analysisDisabled = false
            config.activeProvider = provider
        } else {
            config.analysisDisabled = true
        }
        save()
    }

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Agentic Graph", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("llmConfig.json")
    }

    init() {
        load()
    }

    func settings(for provider: LLMProviderType) -> ProviderSettings {
        config.providers[provider.rawValue] ?? ProviderSettings(apiBase: provider.defaultApiBase)
    }

    func updateSettings(for provider: LLMProviderType, _ block: (inout ProviderSettings) -> Void) {
        var s = settings(for: provider)
        block(&s)
        config.providers[provider.rawValue] = s
        save()
    }

    // MARK: - API Key (Keychain)

    func apiKey(for provider: LLMProviderType) -> String {
        // For wxO, use per-auth-type key
        if provider == .wxo {
            let authType = settings(for: .wxo).authType ?? .local
            return wxoApiKey(for: authType)
        }
        return KeychainHelper.load(service: "com.agentic-graph.llm.\(provider.rawValue)") ?? ""
    }

    func setApiKey(_ key: String, for provider: LLMProviderType) {
        // For wxO, store per-auth-type key
        if provider == .wxo {
            let authType = settings(for: .wxo).authType ?? .local
            setWxOApiKey(key, for: authType)
            return
        }
        if key.isEmpty {
            KeychainHelper.delete(service: "com.agentic-graph.llm.\(provider.rawValue)")
        } else {
            KeychainHelper.save(key: key, service: "com.agentic-graph.llm.\(provider.rawValue)")
        }
    }

    func wxoApiKey(for authType: WxOAuthType) -> String {
        KeychainHelper.load(service: "com.agentic-graph.llm.wxo.\(authType.rawValue)") ?? ""
    }

    func setWxOApiKey(_ key: String, for authType: WxOAuthType) {
        if key.isEmpty {
            KeychainHelper.delete(service: "com.agentic-graph.llm.wxo.\(authType.rawValue)")
        } else {
            KeychainHelper.save(key: key, service: "com.agentic-graph.llm.wxo.\(authType.rawValue)")
        }
    }

    // MARK: - Persistence

    private func load() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LLMConfig.self, from: data)
        else { return }
        config = decoded
        // Apple Intelligence is no longer offered in the UI — migrate any saved selection.
        if config.activeProvider == .apple {
            config.activeProvider = .openai
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: Self.storageURL, options: .atomic)
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, service: String) {
        let data = Data(key.utf8)
        // Delete existing first
        delete(service: service)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
