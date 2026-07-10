import Foundation
import FoundationModels

// MARK: - Protocol

protocol LLMProvider: Sendable {
    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult

    /// Plain chat: send a system + user message, return the raw text response.
    /// Used by features that need structured output other than PatternVerdictResult.
    func chat(systemInstructions: String, prompt: String) async throws -> String
}

/// Individual finding from a verdict.
struct VerdictFinding: Sendable {
    let severity: String
    let summary: String
    let detail: String
    let relatedNodeNames: String
}

/// Parsed result from any LLM provider — can contain both anti-pattern and positive findings.
struct PatternVerdictResult: Sendable {
    let findings: [VerdictFinding]
}

// MARK: - Factory

enum LLMProviderFactory {
    static func create(store: LLMProviderStore) -> LLMProvider {
        let type = store.activeProvider
        let settings = store.settings(for: type)
        let apiKey = store.apiKey(for: type)

        let reasoning = settings.reasoningLevel ?? .off

        switch type {
        case .apple:
            return AppleLLMProvider()
        case .openai:
            return OpenAICompatibleProvider(
                apiBase: settings.apiBase ?? type.defaultApiBase,
                apiKey: apiKey,
                model: settings.model ?? "gpt-4o",
                reasoning: reasoning
            )
        case .ollama:
            return OllamaProvider(
                apiBase: settings.apiBase ?? type.defaultApiBase,
                model: settings.model ?? "llama3.2",
                reasoning: reasoning
            )
        case .watsonx:
            return WatsonxProvider(
                apiBase: settings.apiBase ?? type.defaultApiBase,
                apiKey: apiKey,
                model: settings.model ?? "ibm/granite-3-8b-instruct",
                projectId: settings.projectId ?? "",
                reasoning: reasoning
            )
        case .wxo:
            return WxOProvider(
                apiBase: settings.wxoApiBase,
                apiKey: apiKey,
                model: settings.model ?? "",
                agentName: settings.wxoAgentId,
                authType: settings.authType ?? .local,
                reasoning: reasoning
            )
        }
    }
}

// MARK: - JSON Prompt Template

/// For non-Apple providers: wrap the prompt to request JSON output.
private func jsonWrappedPrompt(systemInstructions: String, prompt: String) -> (system: String, user: String) {
    let system = """
    \(systemInstructions)

    IMPORTANT: You MUST respond with ONLY a JSON object in this exact format, no other text:
    {"hasAntiPattern": true/false, "antiPatternSeverity": "warning|recommendation", "antiPatternSummary": "...", "antiPatternDetail": "...", "antiPatternNodes": "comma,separated,names", "hasPositive": true/false, "positiveSummary": "...", "positiveDetail": "...", "positiveNodes": "comma,separated,names"}
    Both hasAntiPattern and hasPositive can be true if the architecture shows both anti-pattern and positive signals for this pattern.
    """
    return (system: system, user: prompt)
}

/// Parse a JSON response string into PatternVerdictResult.
private func parseVerdictJSON(_ text: String) throws -> PatternVerdictResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw LLMError.invalidResponse("Empty response from model")
    }

    // Extract JSON object from response (model may wrap in markdown code block or extra text)
    var jsonStr = trimmed
    if let start = trimmed.range(of: "{"),
       let end = trimmed.range(of: "}", options: .backwards),
       start.lowerBound < end.lowerBound {
        jsonStr = String(trimmed[start.lowerBound...end.lowerBound])
    }

    guard let data = jsonStr.data(using: .utf8) else {
        throw LLMError.invalidResponse("Could not parse response as UTF-8")
    }

    struct RawVerdict: Decodable {
        let hasAntiPattern: Bool?
        let antiPatternSeverity: String?
        let antiPatternSummary: String?
        let antiPatternDetail: String?
        let antiPatternNodes: String?
        let hasPositive: Bool?
        let positiveSummary: String?
        let positiveDetail: String?
        let positiveNodes: String?
    }

    do {
        let raw = try JSONDecoder().decode(RawVerdict.self, from: data)
        var findings: [VerdictFinding] = []
        if raw.hasAntiPattern == true, let summary = raw.antiPatternSummary, !summary.isEmpty {
            findings.append(VerdictFinding(severity: raw.antiPatternSeverity ?? "warning",
                                            summary: summary, detail: raw.antiPatternDetail ?? "",
                                            relatedNodeNames: raw.antiPatternNodes ?? ""))
        }
        if raw.hasPositive == true, let summary = raw.positiveSummary, !summary.isEmpty {
            findings.append(VerdictFinding(severity: "positive", summary: summary,
                                            detail: raw.positiveDetail ?? "",
                                            relatedNodeNames: raw.positiveNodes ?? ""))
        }
        return PatternVerdictResult(findings: findings)
    } catch {
        // If JSON decode fails, return a descriptive error with what we received
        let preview = String(trimmed.prefix(200))
        throw LLMError.invalidResponse("Could not parse JSON from model response: \(preview)")
    }
}

enum LLMError: Error, LocalizedError {
    case invalidResponse(String)
    case networkError(String)
    case authError(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let msg): "Invalid response: \(msg)"
        case .networkError(let msg): "Network error: \(msg)"
        case .authError(let msg): "Authentication error: \(msg)"
        case .unavailable(let msg): msg
        }
    }
}

// MARK: - Apple Provider

struct AppleLLMProvider: LLMProvider {
    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available: break
        case .unavailable(.deviceNotEligible):
            throw LLMError.unavailable("Apple Intelligence not supported on this device.")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw LLMError.unavailable("Apple Intelligence is not enabled.")
        case .unavailable(.modelNotReady):
            throw LLMError.unavailable("On-device model is still downloading.")
        @unknown default:
            throw LLMError.unavailable("Apple Intelligence is not available.")
        }

        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: prompt, generating: PatternVerdict.self)
        let v = response.content
        var findings: [VerdictFinding] = []
        if v.hasAntiPattern && !v.antiPatternSummary.isEmpty {
            findings.append(VerdictFinding(severity: v.antiPatternSeverity, summary: v.antiPatternSummary,
                                            detail: v.antiPatternDetail, relatedNodeNames: v.antiPatternNodes))
        }
        if v.hasPositive && !v.positiveSummary.isEmpty {
            findings.append(VerdictFinding(severity: "positive", summary: v.positiveSummary,
                                            detail: v.positiveDetail, relatedNodeNames: v.positiveNodes))
        }
        return PatternVerdictResult(findings: findings)
    }

    func chat(systemInstructions: String, prompt: String) async throws -> String {
        try assertAvailable()
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private func assertAvailable() throws {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available: return
        case .unavailable(.deviceNotEligible):
            throw LLMError.unavailable("Apple Intelligence not supported on this device.")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw LLMError.unavailable("Apple Intelligence is not enabled.")
        case .unavailable(.modelNotReady):
            throw LLMError.unavailable("On-device model is still downloading.")
        @unknown default:
            throw LLMError.unavailable("Apple Intelligence is not available.")
        }
    }
}

// MARK: - OpenAI Compatible Provider

struct OpenAICompatibleProvider: LLMProvider {
    let apiBase: String
    let apiKey: String
    let model: String
    let reasoning: ReasoningLevel

    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult {
        let wrapped = jsonWrappedPrompt(systemInstructions: systemInstructions, prompt: prompt)

        // Try with json_object format first, fall back without it if unsupported
        var content = try await sendChatRequest(wrapped: wrapped, useJsonFormat: true)
        if content == nil {
            content = try await sendChatRequest(wrapped: wrapped, useJsonFormat: false)
        }

        guard let content else {
            throw LLMError.invalidResponse("No content in response")
        }
        return try parseVerdictJSON(content)
    }

    private func sendChatRequest(wrapped: (system: String, user: String), useJsonFormat: Bool) async throws -> String? {
        let url = URL(string: "\(apiBase)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": wrapped.system],
                ["role": "user", "content": wrapped.user]
            ],
            "temperature": reasoning.temperature,
            "max_tokens": reasoning.maxTokens
        ]
        if useJsonFormat {
            body["response_format"] = ["type": "json_object"]
        }
        if reasoning.isEnabled {
            body["reasoning_effort"] = reasoning.openAIEffort
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw LLMError.networkError("Invalid response")
        }

        // If json_object format is rejected, return nil to trigger fallback
        if useJsonFormat && httpResp.statusCode == 400 {
            return nil
        }

        guard httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("HTTP \(httpResp.statusCode): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Could not extract content from response")
        }

        return content
    }

    func chat(systemInstructions: String, prompt: String) async throws -> String {
        let wrapped = (system: systemInstructions, user: prompt)
        var content = try await sendChatRequest(wrapped: wrapped, useJsonFormat: true)
        if content == nil {
            content = try await sendChatRequest(wrapped: wrapped, useJsonFormat: false)
        }
        guard let content else {
            throw LLMError.invalidResponse("No content in response")
        }
        return content
    }
}

// MARK: - Ollama Provider

struct OllamaProvider: LLMProvider {
    let apiBase: String
    let model: String
    let reasoning: ReasoningLevel

    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult {
        let wrapped = jsonWrappedPrompt(systemInstructions: systemInstructions, prompt: prompt)
        let url = URL(string: "\(apiBase)/api/chat")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let options: [String: Any] = [
            "temperature": reasoning.temperature,
            "num_predict": reasoning.maxTokens
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": wrapped.system],
                ["role": "user", "content": wrapped.user]
            ],
            "stream": false,
            "format": "json",
            "options": options
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("Ollama error: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Could not extract content from Ollama response")
        }

        return try parseVerdictJSON(content)
    }

    func chat(systemInstructions: String, prompt: String) async throws -> String {
        let url = URL(string: "\(apiBase)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let options: [String: Any] = [
            "temperature": reasoning.temperature,
            "num_predict": reasoning.maxTokens
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemInstructions],
                ["role": "user", "content": prompt]
            ],
            "stream": false,
            "format": "json",
            "options": options
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("Ollama error: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Could not extract content from Ollama response")
        }
        return content
    }
}

// MARK: - watsonx.ai Provider

struct WatsonxProvider: LLMProvider {
    let apiBase: String
    let apiKey: String
    let model: String
    let projectId: String
    let reasoning: ReasoningLevel

    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult {
        // Exchange API key for IAM token
        let token = try await getIAMToken()
        let wrapped = jsonWrappedPrompt(systemInstructions: systemInstructions, prompt: prompt)

        let url = URL(string: "\(apiBase)/ml/v1/text/chat?version=2024-05-01")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model_id": model,
            "project_id": projectId,
            "messages": [
                ["role": "system", "content": wrapped.system],
                ["role": "user", "content": wrapped.user]
            ],
            "parameters": [
                "temperature": reasoning.temperature,
                "max_tokens": reasoning.maxTokens
            ] as [String: Any]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("watsonx error: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Could not extract content from watsonx response")
        }

        return try parseVerdictJSON(content)
    }

    func chat(systemInstructions: String, prompt: String) async throws -> String {
        let token = try await getIAMToken()
        let url = URL(string: "\(apiBase)/ml/v1/text/chat?version=2024-05-01")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model_id": model,
            "project_id": projectId,
            "messages": [
                ["role": "system", "content": systemInstructions],
                ["role": "user", "content": prompt]
            ],
            "parameters": [
                "temperature": reasoning.temperature,
                "max_tokens": reasoning.maxTokens
            ] as [String: Any]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("watsonx error: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Could not extract content from watsonx response")
        }
        return content
    }

    private func getIAMToken() async throws -> String {
        let url = URL(string: "https://iam.cloud.ibm.com/identity/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=\(apiKey)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String
        else {
            throw LLMError.authError("Failed to obtain IAM token")
        }
        return token
    }
}

// MARK: - watsonx Orchestrate Provider

struct WxOProvider: LLMProvider {
    let apiBase: String
    let apiKey: String
    let model: String
    let agentName: String  // This is the agent_id (UUID or name) from settings
    let authType: WxOAuthType
    let reasoning: ReasoningLevel

    func evaluate(systemInstructions: String, prompt: String) async throws -> PatternVerdictResult {
        let token = try await getToken()
        let wrapped = jsonWrappedPrompt(systemInstructions: systemInstructions, prompt: prompt)

        // wxO endpoint: /v1/orchestrate/runs/stream
        let base = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix("/") ? String(apiBase.trimmingCharacters(in: .whitespacesAndNewlines).dropLast())
            : apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let agentId = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "\(base)/v1/orchestrate/runs/stream")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // wxO uses { message: {role, content}, agent_id } format
        let combinedContent = "\(wrapped.system)\n\n\(wrapped.user)"
        let body: [String: Any] = [
            "message": ["role": "user", "content": combinedContent],
            "agent_id": agentId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use bytes for SSE streaming
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw LLMError.networkError("wxO: no HTTP response")
        }



        guard httpResp.statusCode == 200 else {
            // Read error body
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? ""
            throw LLMError.networkError("wxO HTTP \(httpResp.statusCode): \(errorBody)")
        }

        // Parse SSE stream
        var deltaText = ""
        var completedText = ""

        for try await line in bytes.lines {
            if line.contains("[DONE]") { break }
            if line.isEmpty || line.hasPrefix("event:") { continue }

            var jsonString = line
            if line.hasPrefix("data: ") { jsonString = String(line.dropFirst(6)) }
            else if line.hasPrefix("data:") { jsonString = String(line.dropFirst(5)) }

            guard jsonString.hasPrefix("{"),
                  let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            let eventType = json["event"] as? String ?? ""

            if let dataObj = json["data"] as? [String: Any] {
                // Collect deltas as fallback
                if eventType == "message.delta",
                   let delta = dataObj["delta"] as? [String: Any],
                   let c = wxoContentValue(delta["content"]) {
                    deltaText += c
                }
                // Prefer message.created — has the full assembled content
                if eventType == "message.created",
                   let msg = dataObj["message"] as? [String: Any],
                   let c = wxoContentValue(msg["content"]) {
                    completedText = c
                }
            }

            if eventType == "done" || eventType == "run.completed" { break }
        }

        // Prefer completed message over concatenated deltas
        let content = completedText.isEmpty ? deltaText : completedText

        guard !content.isEmpty else {
            throw LLMError.invalidResponse("No content in wxO response")
        }

        return try parseVerdictJSON(content)
    }

    func chat(systemInstructions: String, prompt: String) async throws -> String {
        let token = try await getToken()
        let base = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix("/") ? String(apiBase.trimmingCharacters(in: .whitespacesAndNewlines).dropLast())
            : apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let agentId = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "\(base)/v1/orchestrate/runs/stream")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let combinedContent = "\(systemInstructions)\n\n\(prompt)"
        let body: [String: Any] = [
            "message": ["role": "user", "content": combinedContent],
            "agent_id": agentId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw LLMError.networkError("wxO: no HTTP response")
        }

        guard httpResp.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? ""
            throw LLMError.networkError("wxO HTTP \(httpResp.statusCode): \(errorBody)")
        }

        var deltaText = ""
        var completedText = ""

        for try await line in bytes.lines {
            if line.contains("[DONE]") { break }
            if line.isEmpty || line.hasPrefix("event:") { continue }

            var jsonString = line
            if line.hasPrefix("data: ") { jsonString = String(line.dropFirst(6)) }
            else if line.hasPrefix("data:") { jsonString = String(line.dropFirst(5)) }

            guard jsonString.hasPrefix("{"),
                  let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            let eventType = json["event"] as? String ?? ""

            if let dataObj = json["data"] as? [String: Any] {
                if eventType == "message.delta",
                   let delta = dataObj["delta"] as? [String: Any],
                   let c = wxoContentValue(delta["content"]) {
                    deltaText += c
                }
                if eventType == "message.created",
                   let msg = dataObj["message"] as? [String: Any],
                   let c = wxoContentValue(msg["content"]) {
                    completedText = c
                }
            }

            if eventType == "done" || eventType == "run.completed" { break }
        }

        let content = completedText.isEmpty ? deltaText : completedText
        guard !content.isEmpty else {
            throw LLMError.invalidResponse("No content in wxO response")
        }
        return content
    }

    /// Extract string content from a value that could be a String, [{"text":"..."}], or {"text":"..."}.
    private func wxoContentValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let s = value as? String, !s.isEmpty { return s }
        if let arr = value as? [[String: Any]] {
            let joined = arr.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        if let dict = value as? [String: Any], let t = dict["text"] as? String {
            return t.isEmpty ? nil : t
        }
        return nil
    }

    private func getToken() async throws -> String {
        switch authType {
        case .local:
            // Read from ~/.cache/orchestrate/credentials.yaml
            // Try multiple home directory resolution methods for sandbox compatibility
            let candidates = [
                NSHomeDirectory() + "/.cache/orchestrate/credentials.yaml",
                "/Users/\(NSUserName())/.cache/orchestrate/credentials.yaml",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/orchestrate/credentials.yaml").path
            ]

            var content: String?
            for path in candidates {
                if let c = try? String(contentsOfFile: path, encoding: .utf8), !c.isEmpty {
                    content = c
                    break
                }
            }

            guard let content else {
                throw LLMError.authError("Could not read local orchestrate credentials. Tried: \(candidates.first ?? ""). Ensure the ADK instance is running.")
            }

            // Parse YAML: auth.local.wxo_mcsp_token
            var foundAuthLocal = false
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "local:" { foundAuthLocal = true; continue }
                if foundAuthLocal && trimmed.hasPrefix("wxo_mcsp_token:") {
                    let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !value.isEmpty { return value }
                }
                // Reset if we hit another top-level key
                if foundAuthLocal && !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.hasPrefix("wxo_mcsp_token") {
                    foundAuthLocal = false
                }
            }
            throw LLMError.authError("No wxo_mcsp_token found in credentials file. The ADK instance may need to be restarted.")
        }
    }
}

// MARK: - wxO Agent Discovery

struct WxOAgentInfo: Identifiable {
    let id: String
    let name: String
    let description: String
}

enum WxOAgentDiscovery {
    /// List available agents from the wxO API.
    static func listAgents(apiBase: String, token: String) async throws -> [WxOAgentInfo] {
        let base = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let url = URL(string: "\(cleanBase)/v1/orchestrate/agents?include_hidden=true")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.networkError("Could not list agents: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) \(body)")
        }

        // Try parsing as array or as { "results": [...] }
        var agents: [WxOAgentInfo] = []

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] ?? (json["agents"] as? [[String: Any]]) {
            for item in results {
                let id = item["agent_id"] as? String ?? item["id"] as? String ?? ""
                let name = item["name"] as? String ?? item["display_name"] as? String ?? id
                let desc = item["description"] as? String ?? ""
                if !id.isEmpty { agents.append(WxOAgentInfo(id: id, name: name, description: desc)) }
            }
        } else if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in array {
                let id = item["agent_id"] as? String ?? item["id"] as? String ?? ""
                let name = item["name"] as? String ?? item["display_name"] as? String ?? id
                let desc = item["description"] as? String ?? ""
                if !id.isEmpty { agents.append(WxOAgentInfo(id: id, name: name, description: desc)) }
            }
        }

        return agents
    }
}

// MARK: - Health Check

enum LLMHealthCheck {
    /// Sends a quick test question to the configured provider and returns the response.
    static func test(store: LLMProviderStore) async -> (success: Bool, message: String) {
        let provider = LLMProviderFactory.create(store: store)
        let startTime = Date()

        do {
            let result = try await provider.evaluate(
                systemInstructions: "You are a helpful assistant. Respond concisely.",
                prompt: "Reply with exactly: {\"hasAntiPattern\": false, \"antiPatternSeverity\": \"\", \"antiPatternSummary\": \"\", \"antiPatternDetail\": \"\", \"antiPatternNodes\": \"\", \"hasPositive\": true, \"positiveSummary\": \"Connection successful\", \"positiveDetail\": \"The LLM endpoint is responding correctly.\", \"positiveNodes\": \"\"}"
            )
            let duration = Date().timeIntervalSince(startTime)
            let durationStr = String(format: "%.1fs", duration)

            if let first = result.findings.first, !first.summary.isEmpty {
                return (true, "\(first.summary) (\(durationStr))")
            } else {
                return (true, "Connected — got response in \(durationStr)")
            }
        } catch let error as LLMError {
            return (false, error.localizedDescription)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
