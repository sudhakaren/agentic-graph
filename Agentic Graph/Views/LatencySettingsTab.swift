import SwiftUI

struct LatencySettingsTab: View {
    @Bindable var config: LatencyConfigStore
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Latency Parameters")
                        .font(.title2.bold())
                    Spacer()
                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 4)

                Text("Configure the rule-of-thumb timings used to estimate agent latency. Changes take effect immediately.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                inferenceSection
                toolSection
                loopSection
                tailSection
            }
            .padding(20)
        }
        .confirmationDialog("Reset all latency parameters to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { config.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all latency parameters to their default values.")
        }
    }

    // MARK: - Agent Inference

    private var inferenceSection: some View {
        GroupBox("Agent Inference Time") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Seconds for one LLM call, by agent complexity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                secondsRow("Deterministic", $config.parameters.inferenceDeterministic)
                secondsRow("Conditional", $config.parameters.inferenceConditional)
                secondsRow("Reasoning", $config.parameters.inferenceReasoning)
                secondsRow("Open-ended", $config.parameters.inferenceOpenEnded)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Tool Latency

    private var toolSection: some View {
        GroupBox("Tool Call Latency") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Seconds for one tool call, by tool type. Sync tools add up; async tools overlap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                secondsRow("OpenAI", $config.parameters.toolOpenAI)
                secondsRow("MCP", $config.parameters.toolMCP)
                secondsRow("Python", $config.parameters.toolPython)
                secondsRow("API", $config.parameters.toolAPI)
                secondsRow("Shell", $config.parameters.toolShell)
                secondsRow("LangChain", $config.parameters.toolLangChain)
                secondsRow("Flow", $config.parameters.toolFlow)
                secondsRow("Custom", $config.parameters.toolCustom)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Reasoning Loops

    private var loopSection: some View {
        GroupBox("Reasoning Loops") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fraction of an agent's Max Iterations actually executed in a typical run and a p95 (worst-case) run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                secondsRow("Typical fraction", $config.parameters.typicalIterationFraction, unit: "")
                secondsRow("p95 fraction", $config.parameters.p95IterationFraction, unit: "")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Tail Estimate

    private var tailSection: some View {
        GroupBox("Tail Estimate") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Per-call slowdown applied to the p95 estimate to account for tail variability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                secondsRow("p95 call multiplier", $config.parameters.p95CallMultiplier, unit: "×")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Row helper

    private func secondsRow(_ label: LocalizedStringKey, _ value: Binding<Double>,
                            unit: String = "s") -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 160, alignment: .leading)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            if !unit.isEmpty {
                Text(verbatim: unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
