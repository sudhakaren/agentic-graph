import SwiftUI

struct PromptAnalysisSettingsTab: View {
    @AppStorage(PromptAnalysisEngine.systemPromptKey) private var systemPrompt: String = PromptAnalysisEngine.defaultSystemPrompt
    @AppStorage(PromptAnalysisEngine.userMessageTemplateKey) private var userMessageTemplate: String = PromptAnalysisEngine.defaultUserMessageTemplate
    @AppStorage(PromptAnalysisEngine.targetLanguageKey) private var targetLanguage: String = PromptAnalysisEngine.defaultTargetLanguage
    @AppStorage(PromptAnalysisEngine.reverseTargetLanguageKey) private var reverseTargetLanguage: String = ""

    var body: some View {
        Form {
            translationSection
            warningSection
            systemPromptSection
            userMessageSection
            resetSection
        }
        .formStyle(.grouped)
    }

    private var translationSection: some View {
        Section("Translation") {
            Text("Target language used by the Translate button in the Prompt Analysis tab. Leave empty to hide the button.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Language", text: $targetLanguage, prompt: Text(verbatim: "—"))
                .textFieldStyle(.roundedBorder)

            Text("Optional reverse target — enables a second Translate button that converts back into this language. Leave empty to hide the button.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            TextField("Reverse target", text: $reverseTargetLanguage, prompt: Text(verbatim: "—"))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var warningSection: some View {
        Section {
            Label("Editing this prompt may cause analysis to fail or produce unexpected results. Use Reset to restore the default if needed.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var systemPromptSection: some View {
        Section("System Prompt") {
            Text("Sent as the system instruction when analysing an agent prompt. The model is also told to return JSON containing an `issues` array.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $systemPrompt)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 220)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
        }
    }

    private var userMessageSection: some View {
        Section("User Message Template") {
            Text("Sent as the user message for each analysis. Use placeholders:")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                placeholderLabel("{{framing}}", "Single-agent or multi-agent chain framing (auto-selected)")
                placeholderLabel("{{agentContext}}", "Agents, their tools/knowledge/routing description")
                placeholderLabel("{{prompt}}", "The text from the prompt field")
            }
            .padding(.bottom, 4)

            TextEditor(text: $userMessageTemplate)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 220)
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

    private var resetSection: some View {
        Section {
            Button("Reset System Prompt to Default") {
                systemPrompt = PromptAnalysisEngine.defaultSystemPrompt
            }
            Button("Reset User Message Template to Default") {
                userMessageTemplate = PromptAnalysisEngine.defaultUserMessageTemplate
            }
            Button("Reset Target Language to Default") {
                targetLanguage = PromptAnalysisEngine.defaultTargetLanguage
            }
            Button("Clear Reverse Target") {
                reverseTargetLanguage = ""
            }
        }
    }
}
