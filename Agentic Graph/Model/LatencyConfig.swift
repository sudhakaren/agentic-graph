import Foundation

// MARK: - Latency Configuration (persisted)

/// Configurable rule-of-thumb timings used by the latency estimator.
struct LatencyParameters: Codable, Equatable {
    // LLM inference time (seconds) for one model call, by agent complexity.
    var inferenceDeterministic: Double
    var inferenceConditional: Double
    var inferenceReasoning: Double
    var inferenceOpenEnded: Double

    // Tool call latency (seconds) for one call, by tool type.
    var toolOpenAI: Double
    var toolMCP: Double
    var toolPython: Double
    var toolAPI: Double
    var toolShell: Double
    var toolLangChain: Double
    var toolFlow: Double
    var toolCustom: Double

    // Fraction of an agent's Max Iterations actually executed.
    var typicalIterationFraction: Double
    var p95IterationFraction: Double

    // Per-call slowdown applied to the p95 ("tail") estimate.
    var p95CallMultiplier: Double

    static let defaults = LatencyParameters(
        inferenceDeterministic: 0.4,
        inferenceConditional: 1.2,
        inferenceReasoning: 3.5,
        inferenceOpenEnded: 6.0,
        toolOpenAI: 1.0,
        toolMCP: 0.5,
        toolPython: 0.2,
        toolAPI: 0.8,
        toolShell: 0.3,
        toolLangChain: 0.8,
        toolFlow: 1.5,
        toolCustom: 0.5,
        typicalIterationFraction: 0.35,
        p95IterationFraction: 0.9,
        p95CallMultiplier: 1.6
    )
}

// MARK: - Latency Config Store

@Observable
class LatencyConfigStore {
    var parameters: LatencyParameters {
        didSet { save() }
    }

    init() {
        let url = Self.storageURL
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let params = try? JSONDecoder().decode(LatencyParameters.self, from: data) {
            parameters = params
        } else {
            parameters = .defaults
        }
    }

    func resetToDefaults() {
        parameters = .defaults
    }

    // MARK: - Persistence

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Agentic Graph", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("latencyConfig.json")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(parameters)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to save latency config: \(error)")
        }
    }
}
