import SwiftUI
import UniformTypeIdentifiers

struct FileMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.newDocumentAction) var newAction
    @FocusedValue(\.openDocumentAction) var openAction
    @FocusedValue(\.saveAction) var saveAction
    @FocusedValue(\.saveAsAction) var saveAsAction
    @FocusedValue(\.exportPNGAction) var exportPNGAction
    @FocusedValue(\.exportHTMLAction) var exportHTMLAction
    @FocusedValue(\.exportMarkdownAction) var exportMarkdownAction
    @FocusedValue(\.createVersionAction) var createVersionAction
    @FocusedValue(\.showVersionsAction) var showVersionsAction
    @FocusedValue(\.importWxOAction) var importWxOAction
    @FocusedValue(\.importCrewAIAction) var importCrewAIAction
    @FocusedValue(\.importLangGraphAction) var importLangGraphAction
    @FocusedValue(\.importOpenAIAgentsAction) var importOpenAIAgentsAction
    @FocusedValue(\.importAutoGenAction) var importAutoGenAction
    @FocusedValue(\.importMergeWxOAction) var importMergeWxOAction
    @FocusedValue(\.importMergeAGAction) var importMergeAGAction
    @FocusedValue(\.document) var document
    @FocusedValue(\.patternStore) var patternStore


    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Menu("Export") {
                if document?.viewMode != .settings {
                    Button("Image (PNG)...") {
                        exportPNGAction?()
                    }
                    .disabled(exportPNGAction == nil)

                    Button("HTML Report...") {
                        exportHTMLAction?()
                    }
                    .disabled(exportHTMLAction == nil)

                    Button("Markdown Documentation (ZIP)...") {
                        exportMarkdownAction?()
                    }
                    .disabled(exportMarkdownAction == nil)

                    Divider()
                }

                Button("Analysis Patterns (JSON)...") {
                    exportPatterns()
                }
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("New") {
                if let newAction {
                    newAction()
                } else {
                    // No focused window — open directly via openWindow
                    // (the notification-based NewWindowListener only exists
                    //  while a window is on screen, so it can't receive here)
                    openWindow(id: "main")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate()
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Window") {
                NotificationCenter.default.post(name: .requestNewWindow, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Open...") {
                if let openAction {
                    openAction()
                } else {
                    // No focused window — show open panel and open in new window
                    showOpenPanel()
                }
            }
            .keyboardShortcut("o", modifiers: .command)

            Menu("Open Recent") {
                let recents = RecentFilesManager.shared
                if recents.recentFiles.isEmpty {
                    Text("No Recent Items")
                } else {
                    ForEach(Array(recents.recentFiles.enumerated()), id: \.offset) { _, item in
                        Button(item.name) {
                            recents.openRecent(item.url)
                        }
                    }
                    Divider()
                    Button("Clear Menu") {
                        recents.clearRecents()
                    }
                }
            }

            Menu("Import") {
                Button("watsonx Orchestrate Project...") {
                    if let importWxOAction {
                        importWxOAction()
                    } else {
                        showWxOImportPanel()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("CrewAI Project...") {
                    if let importCrewAIAction {
                        importCrewAIAction()
                    } else {
                        showCrewAIImportPanel()
                    }
                }

                Button("LangGraph Project...") {
                    if let importLangGraphAction {
                        importLangGraphAction()
                    } else {
                        showLangGraphImportPanel()
                    }
                }

                Button("OpenAI Agents SDK Project...") {
                    if let importOpenAIAgentsAction {
                        importOpenAIAgentsAction()
                    } else {
                        showOpenAIAgentsImportPanel()
                    }
                }

                Button("AutoGen / AG2 Project...") {
                    if let importAutoGenAction {
                        importAutoGenAction()
                    } else {
                        showAutoGenImportPanel()
                    }
                }

                Divider()

                Button("Analysis Patterns (Replace)...") {
                    importPatternsWithWarning()
                }
                Button("Analysis Patterns (Merge)...") {
                    importPatternsMerge()
                }
            }

            Menu("Merge") {
                Button("watsonx Orchestrate Project...") {
                    importMergeWxOAction?()
                }
                .disabled(importMergeWxOAction == nil)

                Button("Agentic Graph Project...") {
                    importMergeAGAction?()
                }
                .disabled(importMergeAGAction == nil)
            }

            Divider()

            Button("Save") {
                saveAction?()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(saveAction == nil)

            Button("Save As...") {
                saveAsAction?()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(saveAsAction == nil)

            Divider()

            Button("Create Version...") {
                createVersionAction?()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(createVersionAction == nil)

            Button("Version History...") {
                showVersionsAction?()
            }
            .disabled(showVersionsAction == nil)
        }
    }

    /// If no windows exist, opens one first so the NewWindowListener can receive notifications.
    private func ensureWindowExists() {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.title != "" }
        if !hasVisibleWindow {
            openWindow(id: "main")
        }
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.agenticGraph, .zip]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            // If already open, just bring that window to front
            if PendingFileLoad.activateExistingWindow(for: url) { return }
            let result = ZIPExporter.importZIPWithDiagnostics(from: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let projectName = url.deletingPathExtension().lastPathComponent
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: projectName,
                url: url,
                manifest: ProjectManifest.from(document: loadedDoc),
                versions: loadedDoc.versions
            )
            RecentFilesManager.shared.addRecent(url)
            ensureWindowExists()
            // Small delay to let the new window's listener register
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func showWxOImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a watsonx Orchestrate project folder"
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = WxOImporter.importFolder(at: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let manifest = ProjectManifest.from(document: loadedDoc)
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: loadedDoc.projectName,
                url: url,
                manifest: manifest,
                versions: []
            )
            ensureWindowExists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func showCrewAIImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a CrewAI project folder"
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = CrewAIImporter.importFolder(at: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let manifest = ProjectManifest.from(document: loadedDoc)
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: loadedDoc.projectName,
                url: url,
                manifest: manifest,
                versions: []
            )
            ensureWindowExists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func showLangGraphImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a LangGraph project folder"
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = LangGraphImporter.importFolder(at: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let manifest = ProjectManifest.from(document: loadedDoc)
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: loadedDoc.projectName,
                url: url,
                manifest: manifest,
                versions: []
            )
            ensureWindowExists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func showOpenAIAgentsImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an OpenAI Agents SDK project folder"
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = OpenAIAgentsImporter.importFolder(at: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let manifest = ProjectManifest.from(document: loadedDoc)
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: loadedDoc.projectName,
                url: url,
                manifest: manifest,
                versions: []
            )
            ensureWindowExists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func showAutoGenImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an AutoGen / AG2 project folder"
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = AutoGenImporter.importFolder(at: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let manifest = ProjectManifest.from(document: loadedDoc)
            PendingFileLoad.shared.store(
                nodes: loadedDoc.nodes,
                edges: loadedDoc.edges,
                name: loadedDoc.projectName,
                url: url,
                manifest: manifest,
                versions: []
            )
            ensureWindowExists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    // MARK: - Pattern Export/Import

    private func exportPatterns() {
        guard let store = patternStore, let data = store.exportData() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "analysis-patterns.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func importPatternsWithWarning() {
        let alert = NSAlert()
        alert.messageText = "Replace All Patterns?"
        alert.informativeText = "This will replace all existing patterns and custom categories with the imported file."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace All")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        importPatterns()
    }

    private func importPatterns() {
        guard let store = patternStore else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try store.importData(data)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    private func importPatternsMerge() {
        guard let store = patternStore else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try store.importDataMerge(data)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Merge Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}

extension Notification.Name {
    static let requestNewWindow = Notification.Name("requestNewWindow")
    /// Try loading PendingFileLoad into an existing blank window first;
    /// if no blank window consumes it within 0.15s, open a new window.
    static let loadPendingOrOpenNew = Notification.Name("loadPendingOrOpenNew")
}
