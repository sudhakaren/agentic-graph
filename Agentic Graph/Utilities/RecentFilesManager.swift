import Foundation

@Observable
class RecentFilesManager {
    static let shared = RecentFilesManager()

    private let maxRecents = 10
    private let userDefaultsKey = "RecentFileBookmarks"

    var recentFiles: [(name: String, url: URL)] = []

    private init() {
        loadRecents()
    }

    // MARK: - Public API

    func addRecent(_ url: URL) {
        var bookmarks = loadBookmarkDataArray()

        // Remove any existing bookmark for this URL
        bookmarks.removeAll { data in
            if let resolved = resolveBookmark(data) {
                return resolved.path == url.path
            }
            return false
        }

        // Create new security-scoped bookmark
        guard let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        bookmarks.insert(bookmarkData, at: 0)

        if bookmarks.count > maxRecents {
            bookmarks = Array(bookmarks.prefix(maxRecents))
        }

        UserDefaults.standard.set(bookmarks, forKey: userDefaultsKey)
        loadRecents()
    }

    func clearRecents() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        recentFiles = []
    }

    func openRecent(_ url: URL) {
        // If already open, just bring that window to front
        if PendingFileLoad.activateExistingWindow(for: url) { return }

        guard url.startAccessingSecurityScopedResource() else { return }
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
        NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
        addRecent(url)
    }

    // MARK: - Private

    private func loadBookmarkDataArray() -> [Data] {
        UserDefaults.standard.array(forKey: userDefaultsKey) as? [Data] ?? []
    }

    private func loadRecents() {
        let bookmarks = loadBookmarkDataArray()
        var resolved: [(String, URL)] = []
        var validBookmarks: [Data] = []

        for data in bookmarks {
            if let url = resolveBookmark(data) {
                let name = url.deletingPathExtension().lastPathComponent
                resolved.append((name, url))
                validBookmarks.append(data)
            }
        }

        recentFiles = resolved

        if validBookmarks.count != bookmarks.count {
            UserDefaults.standard.set(validBookmarks, forKey: userDefaultsKey)
        }
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url
    }
}
