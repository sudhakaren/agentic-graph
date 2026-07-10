import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = ""
    @State private var showRestartAlert = false
    @State private var pendingLanguage: String = ""

    var body: some View {
        Form {
            Section("Language") {
                Text("Choose the language used throughout the application. Changes take effect after restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Language", selection: Binding(
                    get: { languageCode },
                    set: { newValue in
                        if newValue != languageCode {
                            pendingLanguage = newValue
                            showRestartAlert = true
                        }
                    }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(verbatim: lang.nativeName).tag(lang.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("Restart required", isPresented: $showRestartAlert) {
            Button("Restart now") {
                languageCode = pendingLanguage
                relaunchApp()
            }
            Button("Apply on next launch") {
                languageCode = pendingLanguage
            }
            Button("Cancel", role: .cancel) {
                pendingLanguage = languageCode
            }
        } message: {
            Text("The language change will take full effect after the app restarts.")
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        // Give the new process a moment to start before we exit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }
}
