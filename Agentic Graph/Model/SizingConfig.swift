import Foundation

// MARK: - Sizing Configuration (persisted)

struct SizingTierConfig: Codable, Equatable {
    var maxAgents: Int
    var maxTools: Int
    var vCPU: Int
    var ramGB: Int
}

struct SizingParameters: Codable, Equatable {
    // Tier thresholds & resources (per baseUserCount users)
    var simpleTier: SizingTierConfig
    var mediumTier: SizingTierConfig
    var hardTier: SizingTierConfig

    // Base user count for resource calculations
    var baseUserCount: Int

    // Concurrency: inference requests per delegating agent
    var concurrencyMultiplierLow: Int
    var concurrencyMultiplierHigh: Int

    // Caching impact estimates (percentages)
    var cachingCostSavingsMin: Int
    var cachingCostSavingsMax: Int
    var cachingLatencyReductionMin: Int
    var cachingLatencyReductionMax: Int

    // Architecture component mappings (toolCategories per tier)
    var frontDoorCategories: [String]       // e.g. ["caching", "routing", "security"]
    var agentRuntimeCategories: [String]    // e.g. ["guardrail", "monitoring", "workflow", "feedback"]
    var inferenceCategories: [String]       // e.g. ["testing"]

    static let defaults = SizingParameters(
        simpleTier: SizingTierConfig(maxAgents: 1, maxTools: 1, vCPU: 1, ramGB: 5),
        mediumTier: SizingTierConfig(maxAgents: 5, maxTools: 10, vCPU: 4, ramGB: 20),
        hardTier: SizingTierConfig(maxAgents: 999, maxTools: 999, vCPU: 18, ramGB: 90),
        baseUserCount: 100,
        concurrencyMultiplierLow: 5,
        concurrencyMultiplierHigh: 15,
        cachingCostSavingsMin: 60,
        cachingCostSavingsMax: 90,
        cachingLatencyReductionMin: 50,
        cachingLatencyReductionMax: 85,
        frontDoorCategories: ["caching", "routing", "security"],
        agentRuntimeCategories: ["guardrail", "monitoring", "workflow", "feedback"],
        inferenceCategories: ["testing"]
    )
}

// MARK: - Sizing Config Store

@Observable
class SizingConfigStore {
    var parameters: SizingParameters {
        didSet { save() }
    }

    init() {
        let url = Self.storageURL
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let params = try? JSONDecoder().decode(SizingParameters.self, from: data) {
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
        return dir.appendingPathComponent("sizingConfig.json")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(parameters)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to save sizing config: \(error)")
        }
    }
}
