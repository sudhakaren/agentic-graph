import SwiftUI

struct SizingInspectorView: View {
    @Bindable var document: GraphDocument
    let sizingConfig: SizingConfigStore

    private var estimate: SizingEstimate {
        SizingEstimator.estimate(document: document, config: sizingConfig)
    }

    private var hasContent: Bool {
        document.agentCount > 0 || document.toolCount > 0
    }

    var body: some View {
        if hasContent {
            contentView
        } else {
            emptyView
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Sizing Estimator")
                .font(.title3)
            Text("Add agents and tools to your graph to see infrastructure sizing recommendations.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        let est = estimate
        return VStack(spacing: 0) {
            summaryHeader(est)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    infrastructureSection(est.infrastructure)
                    workloadProfileSection(est.workloadProfile)
                    architectureSection(est.architecture)
                    if !est.scalingRecommendations.isEmpty {
                        scalingSection(est.scalingRecommendations)
                    }
                    cachingSection(est.cachingAssessment)
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Summary Header

    private func summaryHeader(_ est: SizingEstimate) -> some View {
        HStack(spacing: 8) {
            // Tier badge
            Text(est.infrastructure.tier.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(est.infrastructure.tier.color))

            Spacer()

            // Resources
            resourceChip(value: "\(est.infrastructure.vCPU)", label: "vCPU")
            resourceChip(value: "\(est.infrastructure.ramGB)", label: "GB RAM")
            resourceChip(value: "\(est.infrastructure.executorPods)", label: "Pods")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func resourceChip(value: String, label: String) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Infrastructure Section

    private func infrastructureSection(_ infra: InfrastructureEstimate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Infrastructure", helpKey: .infrastructure)

            card {
                VStack(alignment: .leading, spacing: 6) {
                    Text(infra.rationale)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    // Resource table
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Resource").font(.system(size: 11, weight: .semibold))
                            Text("Per \(infra.baseUserCount) users").font(.system(size: 11, weight: .semibold))
                            if infra.scaledUserCount != nil {
                                Text("Scaled").font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.secondary)
                        Divider()
                        resourceRow("vCPU", base: "\(infra.vCPU)", scaled: infra.scaledVCPU.map { "\($0)" })
                        resourceRow("RAM", base: "\(infra.ramGB) GB", scaled: infra.scaledRAMGB.map { "\($0) GB" })
                        resourceRow("Executor Pods", base: "\(infra.executorPods)", scaled: nil)
                    }

                    if let scaled = infra.scaledUserCount {
                        Text("Scaled for \(scaled) users")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Risk areas
            ForEach(infra.riskAreas) { risk in
                riskCard(risk)
            }
        }
    }

    private func resourceRow(_ label: LocalizedStringKey, base: String, scaled: String?) -> GridRow<some View> {
        GridRow {
            Text(label).font(.system(size: 11))
            Text(verbatim: base).font(.system(size: 11).monospacedDigit())
            if scaled != nil {
                Text(verbatim: scaled ?? "—").font(.system(size: 11).monospacedDigit())
            }
        }
    }

    // MARK: - Workload Profile Section

    private func workloadProfileSection(_ wp: WorkloadProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Workload Profile", helpKey: .workloadProfile)

            dimensionCard(
                title: "Interaction Pattern",
                value: String(format: String(localized: "%@ (%@)"), wp.interactionPattern.displayName, wp.interactionPattern.latencyTarget),
                detail: wp.interactionRationale
            )
            dimensionCard(
                title: "Concurrency",
                value: String(format: String(localized: "%lld sessions × %@ inferences = %lld peak"),
                              wp.concurrency.userSessions,
                              wp.concurrency.inferencePerSession,
                              wp.concurrency.peakInferenceRequests),
                detail: wp.concurrency.rationale
            )
            dimensionCard(
                title: "Token Profile",
                value: String(format: String(localized: "Input: %@  Output: %@"),
                              wp.tokenProfile.inputRange,
                              wp.tokenProfile.outputRange),
                detail: wp.tokenProfile.rationale
            )
            dimensionCard(
                title: "External Calls",
                value: String(format: String(localized: "%lld tools (%lld async, %lld sync)"),
                              wp.externalCalls.totalExternalTools,
                              wp.externalCalls.asyncToolCount,
                              wp.externalCalls.syncToolCount),
                detail: String(format: String(localized: "%lld with timeout, %lld without error handling"),
                               wp.externalCalls.toolsWithTimeout,
                               wp.externalCalls.toolsWithoutErrorHandling)
            )
            dimensionCard(
                title: "Consistency",
                value: wp.consistencyAppetite,
                detail: nil
            )
        }
    }

    // MARK: - Architecture Section

    private func architectureSection(_ arch: ArchitectureDecomposition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Architecture Decomposition", helpKey: .architecture)

            ForEach([arch.frontDoor, arch.agentRuntime, arch.inference], id: \.name) { tier in
                tierCard(tier)
            }
        }
    }

    private func tierCard(_ tier: TierAssessment) -> some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tier.name)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: tier.riskLevel.sfSymbol)
                        .foregroundStyle(tier.riskLevel.color)
                        .font(.system(size: 12))
                }

                ForEach(tier.components, id: \.self) { comp in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(comp)
                            .font(.system(size: 11))
                    }
                }

                ForEach(tier.gaps, id: \.self) { gap in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text(gap)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Scaling Recommendations

    private func scalingSection(_ recs: [ScalingRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Scaling Recommendations", helpKey: .scaling)

            ForEach(recs) { rec in
                card {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: rec.concern.sfSymbol)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(rec.title)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(rec.concern.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(.secondary.opacity(0.15)))
                        }
                        Text(rec.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Caching Assessment

    private func cachingSection(_ cache: CachingAssessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Caching Impact", helpKey: .caching)

            card {
                VStack(alignment: .leading, spacing: 6) {
                    if cache.hasCachingTools {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 11))
                            Text("Caching tools: \(cache.cachingToolNames.joined(separator: ", "))")
                                .font(.system(size: 11))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 11))
                            Text("No caching tools detected")
                                .font(.system(size: 11))
                        }
                    }

                    // Savings bars
                    savingsBar(label: "Cost savings", percent: cache.estimatedCostSavingsPercent, color: .green)
                    savingsBar(label: "Latency reduction", percent: cache.estimatedLatencyReductionPercent, color: .blue)

                    if !cache.recommendations.isEmpty {
                        Divider()
                        ForEach(cache.recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(rec)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !cache.cacheCandidates.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(cache.cacheCandidates) { candidate in
                                nodeChip(NodeRef(id: candidate.id, name: candidate.name))
                            }
                        }
                    }
                }
            }
        }
    }

    private func savingsBar(label: LocalizedStringKey, percent: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    // Footer removed — disclaimer now shown at top of sidebar via DetailSidebarView.

    // MARK: - Navigation

    private func selectNode(_ nodeID: UUID) {
        document.selectedEdgeID = nil
        document.selectedNodeIDs = []
        document.selectedNodeID = nodeID
        DispatchQueue.main.async {
            document.panToNode(nodeID)
        }
    }

    private func selectAndInspectNode(_ nodeID: UUID) {
        selectNode(nodeID)
        DispatchQueue.main.async {
            document.inspectorTab = .properties
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: LocalizedStringKey, helpKey: SizingHelpKey? = nil) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .textCase(.uppercase)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            if let key = helpKey {
                SizingInfoButton(helpKey: key)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
    }

    @ViewBuilder
    private func nodeChip(_ ref: NodeRef) -> some View {
        let node = document.node(for: ref.id)
        let chipColor = node?.kind.color ?? Color.accentColor
        HStack(spacing: 3) {
            if let node {
                Image(systemName: node.kind.sfSymbol)
                    .font(.system(size: 10))
            }
            Text(ref.name)
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(chipColor.opacity(0.15)))
        .overlay(Capsule().strokeBorder(chipColor.opacity(0.3), lineWidth: 0.5))
        .contentShape(Capsule())
        .onTapGesture(count: 2) {
            selectAndInspectNode(ref.id)
        }
        .onTapGesture(count: 1) {
            selectNode(ref.id)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func dimensionCard(title: LocalizedStringKey, value: String, detail: String?) -> some View {
        card {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(verbatim: value)
                    .font(.system(size: 11))
                if let detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func riskCard(_ risk: SizingRiskArea) -> some View {
        card {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: risk.level.sfSymbol)
                        .font(.system(size: 11))
                        .foregroundStyle(risk.level.color)
                    Text(risk.area)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(risk.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if !risk.relatedNodes.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(risk.relatedNodes) { ref in
                            nodeChip(ref)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Contextual Help

enum SizingHelpKey {
    case infrastructure
    case workloadProfile
    case architecture
    case scaling
    case caching

    var title: String {
        switch self {
        case .infrastructure: "Infrastructure Estimate"
        case .workloadProfile: "Workload Profile"
        case .architecture: "Architecture Decomposition"
        case .scaling: "Scaling Recommendations"
        case .caching: "Caching Impact"
        }
    }

    var explanation: String {
        switch self {
        case .infrastructure:
            """
            Estimates the compute resources needed to run your agent architecture.

            Tier is classified by agent and tool count:
            • Simple (1 agent, 1 tool) — minimal resources
            • Medium (up to 5 agents, 10 tools) — moderate cluster
            • Hard (10+ agents, 50+ tools) — significant infrastructure

            vCPU and RAM are per base user count (default 100). If Team Size is set on your project, values are scaled proportionally.

            Executor Pods follow a 1:4 CPU-to-memory ratio — each pod gets 1 vCPU per 4 GB RAM.

            Risk areas flag potential infrastructure concerns like high tool diversity (more virtual environments) or large knowledge volumes.
            """
        case .workloadProfile:
            """
            Characterises your workload across 5 dimensions:

            Interaction Pattern — How users interact:
            • Conversational: real-time chat (P95 < 5s)
            • Task Execution: async processing (minutes)
            • Event-Driven: real-time triggers (< 1s)

            Concurrency — How many inference requests happen simultaneously. A single user session with delegating agents can generate 5–15 concurrent LLM calls.

            Token Profile — Estimated input/output token volumes per call and session, driven by agent complexity and iteration counts.

            External Calls — Tools calling external APIs. Async tools can run in parallel; sync tools block. Tools without error handling are flagged as risks.

            Consistency — Whether load is business-hours, global 24/7, or event-driven with spikes.
            """
        case .architecture:
            """
            Maps your graph to a 3-tier deployment model:

            Front Door — The entry point layer. Should include caching, routing, and security tools to handle request throttling and protection.

            Agent Runtime — The core execution layer. Should include agents, guardrail tools, monitoring, workflow tools, and feedback mechanisms.

            Inference — The LLM backend layer. Checks deployment target (cloud/on-prem/hybrid), whether agents have models specified, and if testing tools exist for validation.

            ✅ marks components present in your graph.
            ⚠️ marks expected components that are missing.
            """
        case .scaling:
            """
            Identifies potential scaling concerns using a decision tree:

            Latency — Are there bottlenecks? Checks for async tools, caching, and latency budgets.

            Throughput — Can the system handle load? Checks for monitoring tools and queue-based patterns.

            Cost — Is spending controlled? Checks for iteration limits, cost budgets, and model right-sizing.

            Quality — Will it stay reliable? Checks for error handling, fallback paths, and circuit-breaker patterns.

            Recommendations are prioritised — address higher-priority items first for the biggest impact.
            """
        case .caching:
            """
            Assesses caching readiness and estimates the potential impact:

            With caching tools present, prompt prefix caching alone can deliver 60–90% cost savings and 50–85% latency reduction by reusing computed attention from static prompt prefixes.

            Tool result caching further reduces cost by avoiding repeated calls to idempotent tools that return the same data.

            The progress bars show current estimated savings — 0% if no caching tools are present, maximum if they are.

            Idempotent tools (those safe to call multiple times) are highlighted as candidates for caching.
            """
        }
    }
}

private struct SizingInfoButton: View {
    let helpKey: SizingHelpKey
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(helpKey.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(helpKey.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 280)
        }
    }
}
