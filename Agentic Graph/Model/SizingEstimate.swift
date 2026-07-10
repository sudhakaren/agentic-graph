import Foundation
import SwiftUI

// MARK: - Sizing Tier

enum SizingTier: String, Codable, CaseIterable {
    case simple
    case medium
    case hard

    var displayName: String {
        switch self {
        case .simple: String(localized: "Simple")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        }
    }

    var sfSymbol: String {
        switch self {
        case .simple: "1.circle.fill"
        case .medium: "2.circle.fill"
        case .hard: "3.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .simple: Color(red: 0.2, green: 0.7, blue: 0.3)
        case .medium: Color(red: 0.95, green: 0.7, blue: 0.1)
        case .hard: Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
}

// MARK: - Interaction Pattern

enum InteractionPattern: String, Codable, CaseIterable {
    case conversational
    case taskExecution
    case eventDriven
    case mixed

    var displayName: String {
        switch self {
        case .conversational: String(localized: "Conversational")
        case .taskExecution: String(localized: "Task Execution")
        case .eventDriven: String(localized: "Event-Driven")
        case .mixed: String(localized: "Mixed")
        }
    }

    var latencyTarget: String {
        switch self {
        case .conversational: String(localized: "P95 < 5s")
        case .taskExecution: String(localized: "Minutes acceptable")
        case .eventDriven: String(localized: "< 1s")
        case .mixed: String(localized: "Varies")
        }
    }
}

// MARK: - Scaling Concern

enum ScalingConcern: String, Codable, CaseIterable {
    case latency
    case throughput
    case cost
    case quality

    var displayName: String {
        switch self {
        case .latency: String(localized: "Latency")
        case .throughput: String(localized: "Throughput")
        case .cost: String(localized: "Cost")
        case .quality: String(localized: "Quality")
        }
    }

    var sfSymbol: String {
        switch self {
        case .latency: "clock.arrow.circlepath"
        case .throughput: "arrow.up.right"
        case .cost: "dollarsign.circle"
        case .quality: "checkmark.seal"
        }
    }
}

// MARK: - Sizing Risk Level

enum SizingRiskLevel: String, Codable, CaseIterable {
    case low
    case moderate
    case high

    var displayName: String {
        switch self {
        case .low: String(localized: "Low")
        case .moderate: String(localized: "Moderate")
        case .high: String(localized: "High")
        }
    }

    var sfSymbol: String {
        switch self {
        case .low: "checkmark.circle.fill"
        case .moderate: "exclamationmark.triangle.fill"
        case .high: "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: Color(red: 0.2, green: 0.7, blue: 0.3)
        case .moderate: Color(red: 0.95, green: 0.7, blue: 0.1)
        case .high: Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: 0
        case .moderate: 1
        case .low: 2
        }
    }
}

// MARK: - Sizing Estimate (top-level result)

struct SizingEstimate {
    let timestamp: Date
    let workloadProfile: WorkloadProfile
    let infrastructure: InfrastructureEstimate
    let architecture: ArchitectureDecomposition
    let scalingRecommendations: [ScalingRecommendation]
    let cachingAssessment: CachingAssessment
}

// MARK: - Workload Profile (5 dimensions)

struct WorkloadProfile {
    let interactionPattern: InteractionPattern
    let interactionRationale: String
    let concurrency: ConcurrencyEstimate
    let tokenProfile: TokenProfile
    let externalCalls: ExternalCallProfile
    let consistencyAppetite: String
}

struct ConcurrencyEstimate {
    let userSessions: Int
    let inferencePerSession: String    // e.g. "5–15"
    let peakInferenceRequests: Int
    let rationale: String
}

struct TokenProfile {
    let inputRange: String             // e.g. "2K–15K"
    let outputRange: String            // e.g. "50–500"
    let totalPerSession: String        // e.g. "~50K"
    let rationale: String
}

struct ExternalCallProfile {
    let totalExternalTools: Int
    let asyncToolCount: Int
    let syncToolCount: Int
    let toolsWithTimeout: Int
    let toolsWithoutErrorHandling: Int
    let riskLevel: SizingRiskLevel
}

// MARK: - Infrastructure Estimate

struct InfrastructureEstimate {
    let tier: SizingTier
    let vCPU: Int
    let ramGB: Int
    let executorPods: Int
    let baseUserCount: Int
    let scaledVCPU: Int?
    let scaledRAMGB: Int?
    let scaledUserCount: Int?
    let rationale: String
    let riskAreas: [SizingRiskArea]
}

struct SizingRiskArea: Identifiable {
    let id: UUID
    let area: String
    let level: SizingRiskLevel
    let detail: String
    let relatedNodes: [NodeRef]
}

struct NodeRef: Identifiable {
    let id: UUID       // node ID
    let name: String
}

// MARK: - Architecture Decomposition

struct ArchitectureDecomposition {
    let frontDoor: TierAssessment
    let agentRuntime: TierAssessment
    let inference: TierAssessment
}

struct TierAssessment {
    let name: String
    let components: [String]
    let gaps: [String]
    let riskLevel: SizingRiskLevel
}

// MARK: - Scaling Recommendation

struct ScalingRecommendation: Identifiable {
    let id: UUID
    let concern: ScalingConcern
    let title: String
    let detail: String
    let priority: Int
}

// MARK: - Caching Assessment

struct CachingAssessment {
    let hasCachingTools: Bool
    let cachingToolNames: [String]
    let estimatedCostSavingsPercent: Int
    let estimatedLatencyReductionPercent: Int
    let recommendations: [String]
    let cacheCandidates: [CacheCandidate]
}

struct CacheCandidate: Identifiable {
    let id: UUID       // node ID
    let name: String
    let reason: String // e.g. "idempotent"
}
