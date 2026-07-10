import SwiftUI

@main
struct Agentic_GraphApp: App {
    /// Watches for pending file loads even when no windows exist.
    @State private var pendingLoadWatcher = PendingLoadWatcher()

    init() {
        // Apply the user's saved language preference before SwiftUI loads any views,
        // so Bundle.main string lookups pick up the right .lproj at startup.
        let saved = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? ""
        if !saved.isEmpty {
            UserDefaults.standard.set([saved], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .background { NewWindowListener(watcher: pendingLoadWatcher) }
                .onOpenURL { url in
                    guard url.pathExtension == "ag" else { return }
                    // If already open, just bring that window to front
                    if PendingFileLoad.activateExistingWindow(for: url) { return }
                    SessionRestorer.clearSession()
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
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
                    NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
                }
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            AppMenuCommands()
            FileMenuCommands()
            EditMenuCommands()
            ArrangeMenuCommands()
            AnalysisMenuCommands()
        }

    }
}

/// App-level observer that ensures a window exists when pending file data arrives.
/// Unlike NewWindowListener (which lives inside WindowGroup and dies with the last window),
/// this persists for the entire app lifetime via @State on the App struct.
@Observable
private class PendingLoadWatcher {
    private var observer: Any?

    /// Stored reference to the SwiftUI openWindow action, set from a view context.
    var openWindowAction: ((String) -> Void)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .loadPendingOrOpenNew,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // If no visible windows exist, the in-window NewWindowListener is gone.
            // Create a window so the pending data can be consumed.
            let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.title != "" }
            if !hasVisibleWindow {
                NSApp.activate(ignoringOtherApps: true)
                self?.openWindowAction?("main")
                // After the new window appears, re-post so its .onReceive picks up the data
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
                }
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}

/// Listens for .requestNewWindow and .loadPendingOrOpenNew notifications.
/// Lives inside WindowGroup so it has access to @Environment(\.openWindow).
/// Also provides the openWindow action to PendingLoadWatcher for when no windows exist.
private struct NewWindowListener: View {
    @Environment(\.openWindow) private var openWindow
    var watcher: PendingLoadWatcher

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                // Give the app-level watcher access to openWindow
                watcher.openWindowAction = { id in openWindow(id: id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestNewWindow)) { _ in
                openWindow(id: "main")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows
                        .filter { $0.isVisible && $0.title != "" }
                        .last?
                        .makeKeyAndOrderFront(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .loadPendingOrOpenNew)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                // Give blank windows a chance to consume the pending data first.
                // If no blank window picked it up, open a new window as fallback.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard PendingFileLoad.shared.hasPending else { return }
                    openWindow(id: "main")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows
                            .filter { $0.isVisible && $0.title != "" }
                            .last?
                            .makeKeyAndOrderFront(nil)
                    }
                }
            }
    }
}
