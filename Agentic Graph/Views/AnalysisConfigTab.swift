import SwiftUI

struct AnalysisConfigTab: View {
    let store: AnalysisPatternStore

    var body: some View {
        Form {
            filterSection
            warningSection
            systemPromptSection
            patternPromptSection
            resetSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Filter

    private var filterSection: some View {
        Section("Graph Summary") {
            Toggle("Filter summary per pattern", isOn: Binding(
                get: { store.filterSummaryPerPattern },
                set: { store.filterSummaryPerPattern = $0 }
            ))

            if store.filterSummaryPerPattern {
                Text("Each pattern only receives node types listed in its Relevant Node Kinds. Reduces token usage and improves accuracy by removing irrelevant information.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Every pattern receives the full graph summary with all node types. Uses more tokens but gives each evaluation broader context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - System Prompt

    private var warningSection: some View {
        Section {
            Label("Editing these prompts may cause analysis to fail or produce unexpected results. Use Reset to restore defaults if needed.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var systemPromptSection: some View {
        Section("System Prompt") {
            Text("Sent as the system instruction for every pattern evaluation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: Binding(
                get: { store.systemPrompt },
                set: { store.systemPrompt = $0 }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
        }
    }

    // MARK: - Pattern Prompt Template

    private var patternPromptSection: some View {
        Section("Pattern Prompt Template") {
            Text("Sent as the user message for each pattern. Use placeholders:")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                placeholderLabel("{{name}}", "Pattern name")
                placeholderLabel("{{antiPatternSignals}}", "Anti-pattern signal text")
                placeholderLabel("{{positiveSignals}}", "Positive signal text")
                placeholderLabel("{{relevantNodeKinds}}", "Comma-separated node kinds")
                placeholderLabel("{{graphSummary}}", "Generated graph summary")
            }
            .padding(.bottom, 4)

            TextEditor(text: Binding(
                get: { store.patternPromptTemplate },
                set: { store.patternPromptTemplate = $0 }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 140)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
        }
    }

    private func placeholderLabel(_ placeholder: String, _ description: String) -> some View {
        HStack(spacing: 6) {
            Text(placeholder)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.blue)
            Text("— \(description)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button("Reset Prompts to Defaults") {
                store.systemPrompt = AnalysisPatternStore.defaultSystemPrompt
                store.patternPromptTemplate = AnalysisPatternStore.defaultPatternPromptTemplate
            }
        }
    }
}
