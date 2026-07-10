import SwiftUI

struct LoadSimulationInspectorView: View {
    @Bindable var document: GraphDocument
    let latencyConfig: LatencyConfigStore

    private var selectedAgent: GraphNode? {
        guard document.totalSelectedCount < 2,
              let index = document.selectedNodeIndex,
              index < document.nodes.count else { return nil }
        let node = document.nodes[index]
        return node.kind == .agent ? node : nil
    }

    var body: some View {
        Group {
            if let agent = selectedAgent {
                ScrollView {
                    agentView(agent)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                emptyView
            }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Load Simulation (BETA)")
                .font(.title3)
            Text("Select an agent node to estimate its latency. Whole-solution simulation and load charts are coming next.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Agent View

    @ViewBuilder
    private func agentView(_ agent: GraphNode) -> some View {
        let est = LatencyEstimator.estimateAgent(agent, document: document, config: latencyConfig)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: agent.kind.sfSymbol)
                    .foregroundStyle(agent.kind.color)
                Text(agent.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 10) {
                figureCard(label: "Typical", value: est.typicalSeconds, prominent: false, warn: false)
                figureCard(label: "p95", value: est.p95Seconds, prominent: true, warn: est.exceedsBudget)
            }

            if let budget = est.budgetSeconds {
                HStack(spacing: 6) {
                    Image(systemName: est.exceedsBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(est.exceedsBudget ? .orange : .green)
                    Text(est.exceedsBudget
                         ? "p95 exceeds the \(fmt(budget)) latency budget."
                         : "Within the \(fmt(budget)) latency budget.")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            Text("Typical breakdown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if est.selfIsOverridden {
                breakdownRow("Agent processing", est.selfSeconds,
                             detail: "Expected Duration, set on the agent")
            } else {
                breakdownRow("LLM inference", est.inferenceSeconds,
                             detail: "\(est.loopCountTypical) loop(s)")
                breakdownRow("Sync tools", est.syncToolSeconds,
                             detail: "\(est.syncToolCount) tool(s), serial")
                breakdownRow("Async tools", est.asyncToolSeconds,
                             detail: "\(est.asyncToolCount) tool(s), parallel")
            }
            breakdownRow("Delegated agents", est.delegationSeconds,
                         detail: "\(est.delegateCount) agent(s)")

            if est.syncToolCount > 0 && est.ifAsyncTypicalSeconds < est.typicalSeconds {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle")
                        .foregroundStyle(.blue)
                    Text("If the \(est.syncToolCount) sync tool(s) ran async, typical latency drops to about \(fmt(est.ifAsyncTypicalSeconds)) (from \(fmt(est.typicalSeconds))).")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Estimates from configurable rules of thumb — tune them in Settings ▸ Latency.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    // MARK: - Pieces

    private func figureCard(label: LocalizedStringKey, value: Double,
                            prominent: Bool, warn: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: fmt(value))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(warn ? Color.orange : (prominent ? Color.primary : Color.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }

    private func breakdownRow(_ label: LocalizedStringKey, _ seconds: Double,
                              detail: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(verbatim: fmt(seconds))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 60, alignment: .trailing)
        }
    }

    private func fmt(_ seconds: Double) -> String {
        if seconds < 1.0 {
            return "\(Int((seconds * 1000).rounded()))ms"
        }
        return String(format: "%.1fs", seconds)
    }
}
