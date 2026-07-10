import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var document = GraphDocument()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showUnsavedAlert = false
    @State private var showCreateVersion = false
    @State private var showVersionList = false
    @State private var analysisEngine = GraphAnalysisEngine()
    @State private var promptAnalysisEngine = PromptAnalysisEngine()
    @State private var analysisPatternStore = AnalysisPatternStore()
    @State private var llmProviderStore = LLMProviderStore()
    @State private var sizingConfigStore = SizingConfigStore()
    @State private var latencyConfigStore = LatencyConfigStore()
    @State private var selectedPatternID: UUID?
    @State private var showAddPatternForm = false
    @State private var pendingAction: PendingAction? = nil
    @AppStorage("darkCanvas") private var darkCanvasPref = true
    @Environment(\.undoManager) private var undoManager

    enum PendingAction {
        case newDocument
    }

    var body: some View {
        mainContent
            // Version sheets
            .sheet(isPresented: $showCreateVersion) {
                CreateVersionSheet(document: document)
            }
            .sheet(isPresented: $showVersionList) {
                VersionListSheet(document: document)
            }
            // Unsaved changes alert
            .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
                Button("Save") {
                    handleSave()
                    executePendingAction()
                }
                Button("Don't Save", role: .destructive) {
                    executePendingAction()
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text("Do you want to save the changes to \"\(document.projectName)\"?")
            }
            // Window dirty state and close interception
            .background {
                WindowAccessor(document: document, onSave: { handleSave() })
            }
            // If this window is blank, consume pending file loads (e.g. Finder double-click)
            .onReceive(NotificationCenter.default.publisher(for: .loadPendingOrOpenNew)) { _ in
                guard document.nodes.isEmpty && document.fileURL == nil && !document.isDirty else { return }
                if let pending = PendingFileLoad.shared.consume() {
                    loadFromPending(pending)
                }
            }
            // Per-window dark/light — SwiftUI handles the window appearance and redraws
            .preferredColorScheme(document.darkCanvas ? .dark : .light)
            // Focused values for menu commands
            .focusedValue(\.document, document)
            .focusedValue(\.newDocumentAction, { handleNew() })
            .focusedValue(\.openDocumentAction, { handleOpen() })
            .focusedValue(\.saveAction, { handleSave() })
            .focusedValue(\.saveAsAction, { handleSaveAs() })
            .focusedValue(\.exportPNGAction, { exportPNG() })
            .focusedValue(\.exportHTMLAction, { exportHTML() })
            .focusedValue(\.exportMarkdownAction, { exportMarkdownZIP() })
            .focusedValue(\.createVersionAction, { showCreateVersion = true })
            .focusedValue(\.showVersionsAction, { showVersionList = true })
            .modifier(ImportCommandsModifier(
                wxO: { handleWxOImport() },
                mergeWxO: { handleMergeWxOImport() },
                mergeAG: { handleMergeAGImport() },
                crewAI: { handleCrewAIImport() },
                langGraph: { handleLangGraphImport() },
                openAIAgents: { handleOpenAIAgentsImport() },
                autoGen: { handleAutoGenImport() }
            ))
            .focusedValue(\.analyzeGraphAction, {
                document.inspectorTab = .analysis
                if case .idle = analysisEngine.state {
                    analysisEngine.analyze(document: document, patternStore: analysisPatternStore, llmStore: llmProviderStore)
                }
            })
            .focusedValue(\.patternStore, analysisPatternStore)
            .focusedValue(\.analysisDisabled, llmProviderStore.analysisDisabled)
    }

    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if document.viewMode == .workspace {
                SidebarPaletteView(document: document)
                    .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
            } else {
                SettingsSidebarView(document: document)
                    .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
            }
        } content: {
            if document.viewMode == .workspace {
                CanvasView(document: document)
                    .navigationSplitViewColumnWidth(min: 400, ideal: 800)
            } else {
                SettingsContentView(document: document, llmStore: llmProviderStore, patternStore: analysisPatternStore, sizingConfig: sizingConfigStore, latencyConfig: latencyConfigStore, selectedPatternID: $selectedPatternID, showAddPatternForm: $showAddPatternForm)
                    .navigationSplitViewColumnWidth(min: 400, ideal: 800)
            }
        } detail: {
            if document.viewMode == .workspace {
                DetailSidebarView(document: document, engine: analysisEngine, promptEngine: promptAnalysisEngine, patternStore: analysisPatternStore, llmStore: llmProviderStore, sizingConfig: sizingConfigStore, latencyConfig: latencyConfigStore)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 500)
            } else if document.settingsTab == "analysis" {
                PatternDetailView(store: analysisPatternStore, selectedPatternID: $selectedPatternID, showAddForm: $showAddPatternForm)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
            }
        }
        .navigationTitle(document.viewMode == .workspace ? document.projectName : "Settings")
        .navigationSubtitle(document.viewMode == .workspace && document.isDirty ? "Edited" : "")
        .onChange(of: document.darkCanvas) { _, isDark in
            darkCanvasPref = isDark
        }
        .onAppear { handleOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            SessionRestorer.saveSession(document: document)
        }
        .onChange(of: undoManager) { _, newUM in
            document.undoManager = newUM
        }
        .toolbarBackground(toolbarBG, for: .windowToolbar)
        .toolbarBackgroundVisibility(toolbarBGVisibility, for: .windowToolbar)
        .toolbar { toolbarItems }
    }

    private var toolbarBG: Color {
        if document.viewMode == .settings { return .clear }
        return document.darkCanvas ? .clear : Color(white: 0.88)
    }

    private var toolbarBGVisibility: Visibility {
        if document.viewMode == .settings { return .automatic }
        return document.darkCanvas ? .automatic : .visible
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // Tab-specific actions — grouped
        ToolbarItemGroup(placement: .primaryAction) {
            if document.viewMode == .settings && document.settingsTab == "analysis" {
                Button {
                    showAddPatternForm = true
                    selectedPatternID = nil
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add Pattern")

                Button {
                    if let id = selectedPatternID {
                        analysisPatternStore.removePattern(id: id)
                        selectedPatternID = nil
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedPatternID == nil)
                .help("Delete Selected Pattern")
            }

            if document.viewMode == .workspace && document.inspectorTab == .properties {
                Menu {
                    Button("Create Version...") { showCreateVersion = true }
                    Button("Version History...") { showVersionList = true }
                } label: {
                    Label("Versions", systemImage: "clock.arrow.circlepath")
                }

                Menu {
                    Button("Image (PNG)...") { exportPNG() }
                    Button("HTML Report...") { exportHTML() }
                    Button("Markdown (ZIP)...") { exportMarkdownZIP() }
                } label: {
                    Label("Export Project", systemImage: "square.and.arrow.up")
                }
            }

            if document.viewMode == .workspace && document.inspectorTab == .analysis {
                if case .analyzing = analysisEngine.state {
                    Button {
                        analysisEngine.cancel()
                    } label: {
                        Label("Cancel Analysis", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        analysisEngine.analyze(document: document, patternStore: analysisPatternStore, llmStore: llmProviderStore)
                    } label: {
                        Label("Run Analysis", systemImage: "play.fill")
                    }
                }

                Menu {
                    Button("Analysis Report (Markdown)...") { exportAnalysisMarkdown() }
                    Button("Analysis Report (HTML)...") { exportAnalysisHTML() }
                } label: {
                    Label("Export Analysis", systemImage: "square.and.arrow.up")
                }
            }

            if document.viewMode == .workspace && document.inspectorTab == .sizing {
                Menu {
                    Button("Sizing Report (Markdown)...") { exportSizingMarkdown() }
                    Button("Sizing Report (HTML)...") { exportSizingHTML() }
                } label: {
                    Label("Export Sizing", systemImage: "square.and.arrow.up")
                }
            }

            // Dark/light toggle — last item, visually separated as a lone button after menus
            if document.viewMode == .workspace {
                Button {
                    document.darkCanvas.toggle()
                } label: {
                    Label(document.darkCanvas ? "Light Canvas" : "Dark Canvas",
                          systemImage: document.darkCanvas ? "sun.max" : "moon")
                }
            }
        }
    }

    // MARK: - Lifecycle

    private func handleOnAppear() {
        document.darkCanvas = darkCanvasPref
        document.undoManager = undoManager
        if let pending = PendingFileLoad.shared.consume() {
            loadFromPending(pending)
        } else if let session = SessionRestorer.restoreSession() {
            if let manifest = session.manifest {
                manifest.apply(to: document)
            } else {
                document.nodes = session.nodes
                document.edges = session.edges
                document.updateContentExtent()
            }
            document.projectName = session.name
            document.fileURL = session.url
            document.versions = session.versions
            document.canvasOffset = session.offset
            document.canvasScale = session.scale
            document.selectedNodeID = nil
            if session.url != nil {
                document.markClean()
                PendingFileLoad.registerActiveURL(session.url!)
            } else {
                document.isDirty = true
            }
            document.needsZoomToFit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if document.needsZoomToFit {
                    document.needsZoomToFit = false
                    document.zoomToFit()
                }
            }
        }
    }

    /// Loads a file from PendingFileLoad into the current document.
    private func loadFromPending(_ pending: (nodes: [GraphNode], edges: [GraphEdge],
                                              name: String, url: URL?,
                                              manifest: ProjectManifest?,
                                              versions: [VersionSnapshot])) {
        if let manifest = pending.manifest {
            manifest.apply(to: document)
        } else {
            document.nodes = pending.nodes
            document.edges = pending.edges
            document.updateContentExtent()
        }
        document.projectName = pending.name
        document.fileURL = pending.url
        document.versions = pending.versions
        document.selectedNodeID = nil
        document.markClean()
        if let url = pending.url {
            PendingFileLoad.registerActiveURL(url)
        }
        document.needsZoomToFit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if document.needsZoomToFit {
                document.needsZoomToFit = false
                document.zoomToFit()
            }
            NSApp.activate(ignoringOtherApps: true)
            NSApp.keyWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Menu Action Handlers

    private func handleNew() {
        if document.isDirty {
            pendingAction = .newDocument
            showUnsavedAlert = true
        } else {
            document.resetToNew()
            SessionRestorer.clearSession()
        }
    }

    private func handleOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.agenticGraph, .zip]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            if PendingFileLoad.activateExistingWindow(for: url) { return }
            let result = ZIPExporter.importZIPWithDiagnostics(from: url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let projectName = url.deletingPathExtension().lastPathComponent
            let manifest = ProjectManifest.from(document: loadedDoc)
            RecentFilesManager.shared.addRecent(url)

            // If the current window is blank, load the file directly into it
            if document.nodes.isEmpty && document.fileURL == nil && !document.isDirty {
                loadFromPending((nodes: loadedDoc.nodes, edges: loadedDoc.edges,
                                 name: projectName, url: url,
                                 manifest: manifest, versions: loadedDoc.versions))
            } else {
                // Current window has content — open in a new window
                PendingFileLoad.shared.store(
                    nodes: loadedDoc.nodes,
                    edges: loadedDoc.edges,
                    name: projectName,
                    url: url,
                    manifest: manifest,
                    versions: loadedDoc.versions
                )
                NotificationCenter.default.post(name: .requestNewWindow, object: nil)
            }
        }
    }

    private func handleWxOImport() {
        runFolderImport(message: "Select a watsonx Orchestrate project folder") { url in
            let r = WxOImporter.importFolder(at: url)
            return (r.document, r.error)
        }
    }

    /// Re-imports a wxO project and merges it into the current graph rather
    /// than replacing it — snapshots first, then reconciles nodes and edges.
    private func handleMergeWxOImport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Select a watsonx Orchestrate project folder to merge into the current graph")
        panel.prompt = String(localized: "Merge")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = WxOImporter.importFolder(at: url)
            guard let incoming = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let summary = WxOMerge.merge(incoming: incoming, into: document,
                                         sourceName: url.lastPathComponent)
            WxOMerge.showSummary(summary, sourceName: url.lastPathComponent)
        }
    }

    /// Combines another Agentic Graph (.ag) project into the current graph.
    private func handleMergeAGImport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.agenticGraph, .zip]
        panel.message = String(localized: "Select an Agentic Graph project to merge into the current graph")
        panel.prompt = String(localized: "Merge")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = ZIPExporter.importZIPWithDiagnostics(from: url)
            guard let incoming = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }
            let summary = AGMerge.merge(incoming: incoming, into: document,
                                        sourceName: url.lastPathComponent)
            AGMerge.showSummary(summary, sourceName: url.lastPathComponent)
        }
    }

    private func handleCrewAIImport() {
        runFolderImport(message: "Select a CrewAI project folder") { url in
            let r = CrewAIImporter.importFolder(at: url)
            return (r.document, r.error)
        }
    }

    private func handleLangGraphImport() {
        runFolderImport(message: "Select a LangGraph project folder") { url in
            let r = LangGraphImporter.importFolder(at: url)
            return (r.document, r.error)
        }
    }

    private func handleOpenAIAgentsImport() {
        runFolderImport(message: "Select an OpenAI Agents SDK project folder") { url in
            let r = OpenAIAgentsImporter.importFolder(at: url)
            return (r.document, r.error)
        }
    }

    private func handleAutoGenImport() {
        runFolderImport(message: "Select an AutoGen / AG2 project folder") { url in
            let r = AutoGenImporter.importFolder(at: url)
            return (r.document, r.error)
        }
    }

    /// Shared folder-import flow: pick a directory, run `importer`, then load the
    /// resulting document into a blank window or open a new one.
    private func runFolderImport(message: String,
                                 importer: @escaping (URL) -> (document: GraphDocument?, error: String?)) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = message
        panel.prompt = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NSApp.activate(ignoringOtherApps: true)
            let result = importer(url)
            guard let loadedDoc = result.document else {
                if let error = result.error {
                    ZIPExporter.showImportError(error, filename: url.lastPathComponent)
                }
                return
            }

            // If current window is blank, load directly into it
            if document.nodes.isEmpty && document.fileURL == nil && !document.isDirty {
                let manifest = ProjectManifest.from(document: loadedDoc)
                manifest.apply(to: document)
                document.projectName = loadedDoc.projectName
                document.selectedNodeID = nil
                document.isDirty = true  // Imported, not saved yet
                document.needsZoomToFit = true
                document.createVersion(name: String(localized: "Imported"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if document.needsZoomToFit {
                        document.needsZoomToFit = false
                        document.zoomToFit()
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                }
            } else {
                // Open in a new window
                let manifest = ProjectManifest.from(document: loadedDoc)
                let snapshot = VersionSnapshot(name: String(localized: "Imported"),
                                               document: loadedDoc)
                PendingFileLoad.shared.store(
                    nodes: loadedDoc.nodes,
                    edges: loadedDoc.edges,
                    name: loadedDoc.projectName,
                    url: url,
                    manifest: manifest,
                    versions: [snapshot]
                )
                NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
            }
        }
    }

    private func handleSave() {
        if let url = document.fileURL {
            // Save to existing location
            if let data = ZIPExporter.exportZIP(document: document) {
                do {
                    try data.write(to: url, options: .atomic)
                    document.markClean()
                    RecentFilesManager.shared.addRecent(url)
                } catch {
                    // File write failed — fall back to Save As
                    handleSaveAs()
                }
            }
        } else {
            handleSaveAs()
        }
    }

    private func handleSaveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.agenticGraph]
        panel.nameFieldStringValue = "\(document.projectName).ag"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = ZIPExporter.exportZIP(document: document) {
                try? data.write(to: url)
                // Unregister old URL, register new
                if let oldURL = document.fileURL {
                    PendingFileLoad.unregisterActiveURL(oldURL)
                }
                document.fileURL = url
                PendingFileLoad.registerActiveURL(url)
                document.projectName = url.deletingPathExtension().lastPathComponent
                document.markClean()
                RecentFilesManager.shared.addRecent(url)
            }
        }
    }

    private func executePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .newDocument:
            document.resetToNew()
            SessionRestorer.clearSession()
        }
    }

    // MARK: - Toolbar Export

    private func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(document.projectName).png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = PNGExporter.export(document: document) {
                try? data.write(to: url)
            }
        }
    }

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(document.projectName).html"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = ZIPExporter.exportHTMLReport(document: document) {
                try? data.write(to: url)
            }
        }
    }

    private func exportMarkdownZIP() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "\(document.projectName)-docs.zip"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = ZIPExporter.exportMarkdownZIP(document: document) {
                try? data.write(to: url)
            }
        }
    }

    private func exportAnalysisMarkdown() {
        guard let result = document.lastAnalysisResult ?? {
            if case .completed(let r) = analysisEngine.state { return r }
            return nil
        }() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(document.projectName)-analysis.md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let md = Self.generateAnalysisMarkdown(result: result, projectName: document.projectName)
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportSizingMarkdown() {
        let est = SizingEstimator.estimate(document: document, config: sizingConfigStore)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(document.projectName)-sizing.md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let md = SizingEstimator.generateMarkdown(estimate: est, projectName: document.projectName, parameters: sizingConfigStore.parameters)
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportSizingHTML() {
        let est = SizingEstimator.estimate(document: document, config: sizingConfigStore)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(document.projectName)-sizing.html"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let html = SizingEstimator.generateHTML(estimate: est, projectName: document.projectName, parameters: sizingConfigStore.parameters)
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func generateAnalysisMarkdown(result: AnalysisResult, projectName: String) -> String {
        var md = "# Architecture Analysis — \(projectName)\n\n"
        md += "**Date:** \(result.timestamp.formatted(date: .long, time: .shortened))\n\n"
        md += "> **AI Disclaimer:** This analysis was generated with AI. Results may be inaccurate and should be reviewed by a qualified professional before making decisions.\n\n"

        // Summary
        md += "## Summary\n\n"
        md += "| | Count |\n|---|---|\n"
        md += "| Warnings | \(result.warnings.count) |\n"
        md += "| Recommendations | \(result.recommendations.count) |\n"
        md += "| Positive | \(result.positives.count) |\n"
        md += "| Info | \(result.infos.count) |\n\n"

        // Findings by category
        for group in result.groupedByCategory {
            md += "## \(group.category)\n\n"
            for finding in group.findings {
                let icon: String
                switch finding.severity {
                case .warning: icon = "\u{26A0}\u{FE0F}"
                case .recommendation: icon = "\u{1F4A1}"
                case .positive: icon = "\u{2705}"
                case .info: icon = "\u{2139}\u{FE0F}"
                }
                md += "### \(icon) #\(finding.patternNumber) \(finding.patternName)\n\n"
                md += "**Severity:** \(finding.severity.displayName)\n\n"
                md += "\(finding.summary)\n\n"
                if !finding.detail.isEmpty {
                    md += "\(finding.detail)\n\n"
                }
                if !finding.relatedNodeIDs.isEmpty {
                    let names = finding.diagnostics?.resolvedNodeNames ?? []
                    if !names.isEmpty {
                        md += "**Related nodes:** \(names.joined(separator: ", "))\n\n"
                    }
                }
                md += "---\n\n"
            }
        }

        return md
    }

    private func exportAnalysisHTML() {
        guard let result = document.lastAnalysisResult ?? {
            if case .completed(let r) = analysisEngine.state { return r }
            return nil
        }() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(document.projectName)-analysis.html"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let html = Self.generateAnalysisHTML(result: result, projectName: document.projectName)
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func generateAnalysisHTML(result: AnalysisResult, projectName: String) -> String {
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Analysis — \(esc(projectName))</title>
        <style>
            :root { --bg: #ffffff; --fg: #1d1d1f; --muted: #6e6e73; --border: #d2d2d7; --accent: #0066cc; --section-bg: #f5f5f7; }
            @media (prefers-color-scheme: dark) {
                :root:not([data-theme="light"]) { --bg: #1d1d1f; --fg: #f5f5f7; --muted: #98989d; --border: #424245; --accent: #2997ff; --section-bg: #2c2c2e; }
            }
            [data-theme="dark"] { --bg: #1d1d1f; --fg: #f5f5f7; --muted: #98989d; --border: #424245; --accent: #2997ff; --section-bg: #2c2c2e; }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--fg); line-height: 1.6; padding: 40px 20px; }
            .container { max-width: 900px; margin: 0 auto; }
            h1 { font-size: 2em; margin-bottom: 0.3em; }
            h2 { font-size: 1.4em; margin-top: 2em; margin-bottom: 0.6em; color: var(--accent); border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
            .overview { font-size: 1.1em; color: var(--muted); margin-bottom: 1.5em; }
            .summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 2em; }
            .summary-card { background: var(--section-bg); border-radius: 8px; padding: 16px; text-align: center; }
            .summary-card .count { font-size: 2em; font-weight: 700; }
            .summary-card .label { font-size: 0.85em; color: var(--muted); }
            .summary-card.warning .count { color: #ff3b30; }
            .summary-card.recommendation .count { color: #ff9500; }
            .summary-card.positive .count { color: #34c759; }
            .summary-card.info .count { color: #007aff; }
            .finding { background: var(--section-bg); border-radius: 8px; padding: 16px 20px; margin-bottom: 12px; }
            .finding.warning { border-left: 4px solid #ff3b30; }
            .finding.recommendation { border-left: 4px solid #ff9500; }
            .finding.positive { border-left: 4px solid #34c759; }
            .finding.info { border-left: 4px solid #007aff; }
            .finding-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
            .finding-header .icon { font-size: 1.2em; }
            .finding-header .title { font-weight: 600; }
            .finding-header .severity { font-size: 0.75em; text-transform: uppercase; letter-spacing: 0.05em; padding: 2px 7px; border-radius: 4px; font-weight: 600; }
            .severity-warning { background: #ff3b3015; color: #ff3b30; }
            .severity-recommendation { background: #ff950015; color: #ff9500; }
            .severity-positive { background: #34c75915; color: #34c759; }
            .severity-info { background: #007aff15; color: #007aff; }
            .finding .summary { margin-bottom: 4px; }
            .finding .detail { color: var(--muted); font-size: 0.9em; }
            .finding .nodes { margin-top: 8px; display: flex; flex-wrap: wrap; gap: 4px; }
            .finding .node-chip { display: inline-block; font-size: 0.8em; padding: 2px 8px; border-radius: 12px; background: var(--bg); border: 1px solid var(--border); }
            .footer { margin-top: 3em; padding-top: 1em; border-top: 1px solid var(--border); font-size: 0.85em; color: var(--muted); }
            .theme-toggle { position: fixed; top: 16px; right: 16px; background: var(--section-bg); border: 1px solid var(--border); border-radius: 8px; padding: 6px 10px; cursor: pointer; font-size: 18px; line-height: 1; color: var(--fg); z-index: 100; }
            .theme-toggle:hover { background: var(--border); }
        </style>
        </head>
        <body>
        <button class="theme-toggle" onclick="let d=document.documentElement;let t=d.getAttribute('data-theme');d.setAttribute('data-theme',t==='dark'?'light':'dark');this.textContent=t==='dark'?'\\u263E':'\\u2600\\uFE0F'" aria-label="Toggle theme">&#x263E;</button>
        <div class="container">
        <h1>Architecture Analysis</h1>
        <p class="overview">\(esc(projectName)) &mdash; \(result.timestamp.formatted(date: .long, time: .shortened))</p>

        <div style="background: var(--section-bg); border-left: 3px solid #ff9500; border-radius: 6px; padding: 10px 14px; margin-bottom: 1.5em; font-size: 0.85em; color: var(--muted);">
            <strong style="color: var(--fg);">AI Disclaimer:</strong> This analysis was generated with AI. Results may be inaccurate and should be reviewed by a qualified professional before making decisions.
        </div>

        <div class="summary-grid">
            <div class="summary-card warning"><div class="count">\(result.warnings.count)</div><div class="label">Warnings</div></div>
            <div class="summary-card recommendation"><div class="count">\(result.recommendations.count)</div><div class="label">Recommendations</div></div>
            <div class="summary-card positive"><div class="count">\(result.positives.count)</div><div class="label">Positive</div></div>
            <div class="summary-card info"><div class="count">\(result.infos.count)</div><div class="label">Info</div></div>
        </div>

        """

        for group in result.groupedByCategory {
            html += "<h2>\(esc(group.category))</h2>\n"
            for finding in group.findings {
                let sev = finding.severity.rawValue
                let icon: String
                switch finding.severity {
                case .warning: icon = "\u{26A0}\u{FE0F}"
                case .recommendation: icon = "\u{1F4A1}"
                case .positive: icon = "\u{2705}"
                case .info: icon = "\u{2139}\u{FE0F}"
                }
                html += """
                <div class="finding \(sev)">
                    <div class="finding-header">
                        <span class="icon">\(icon)</span>
                        <span class="title">#\(finding.patternNumber) \(esc(finding.patternName))</span>
                        <span class="severity severity-\(sev)">\(esc(finding.severity.displayName))</span>
                    </div>
                    <p class="summary">\(esc(finding.summary))</p>

                """
                if !finding.detail.isEmpty {
                    html += "    <p class=\"detail\">\(esc(finding.detail))</p>\n"
                }
                if let names = finding.diagnostics?.resolvedNodeNames, !names.isEmpty {
                    html += "    <div class=\"nodes\">\(names.map { "<span class=\"node-chip\">\(esc($0))</span>" }.joined())</div>\n"
                }
                html += "</div>\n"
            }
        }

        html += """
        <div class="footer">
            <p>Analyzed on-device &mdash; \(result.findings.count) findings across \(result.groupedByCategory.count) categories</p>
        </div>
        </div>
        </body>
        </html>
        """

        return html
    }

    private func exportZIP() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.agenticGraph]
        panel.nameFieldStringValue = "\(document.projectName).ag"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = ZIPExporter.exportZIP(document: document) {
                try? data.write(to: url)
                document.fileURL = url
                document.projectName = url.deletingPathExtension().lastPathComponent
                document.markClean()
            }
        }
    }
}

/// Groups the framework-import focused values into one modifier so the main
/// ContentView body stays small enough for the Swift type-checker.
private struct ImportCommandsModifier: ViewModifier {
    let wxO: () -> Void
    let mergeWxO: () -> Void
    let mergeAG: () -> Void
    let crewAI: () -> Void
    let langGraph: () -> Void
    let openAIAgents: () -> Void
    let autoGen: () -> Void

    func body(content: Content) -> some View {
        content
            .focusedValue(\.importWxOAction, wxO)
            .focusedValue(\.importMergeWxOAction, mergeWxO)
            .focusedValue(\.importMergeAGAction, mergeAG)
            .focusedValue(\.importCrewAIAction, crewAI)
            .focusedValue(\.importLangGraphAction, langGraph)
            .focusedValue(\.importOpenAIAgentsAction, openAIAgents)
            .focusedValue(\.importAutoGenAction, autoGen)
    }
}

#Preview {
    ContentView()
}
