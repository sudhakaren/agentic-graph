import Foundation

struct SessionState: Codable {
    var fileBookmarkData: Data?
    var manifestData: Data?
    var versionsData: Data?
    var projectName: String
    var canvasOffsetX: CGFloat
    var canvasOffsetY: CGFloat
    var canvasScale: CGFloat
}

struct SessionRestorer {

    /// Prevents multiple windows from restoring the same session simultaneously.
    private static var hasBeenRestored = false

    private static var sessionFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("AgenticGraph", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("last-session.json")
    }

    // MARK: - Save

    static func saveSession(document: GraphDocument) {
        var state = SessionState(
            projectName: document.projectName,
            canvasOffsetX: document.canvasOffset.width,
            canvasOffsetY: document.canvasOffset.height,
            canvasScale: document.canvasScale
        )

        if let fileURL = document.fileURL {
            state.fileBookmarkData = try? fileURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else if !document.nodes.isEmpty {
            let manifest = ProjectManifest.from(document: document)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            state.manifestData = try? encoder.encode(manifest)

            // Also persist versions for unsaved documents
            if !document.versions.isEmpty {
                let versionEncoder = JSONEncoder()
                versionEncoder.dateEncodingStrategy = .iso8601
                state.versionsData = try? versionEncoder.encode(document.versions)
            }
        } else {
            clearSession()
            return
        }

        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: sessionFileURL)
        }
    }

    // MARK: - Restore

    struct RestoredSession {
        var nodes: [GraphNode]
        var edges: [GraphEdge]
        var name: String
        var url: URL?
        var offset: CGSize
        var scale: CGFloat
        var manifest: ProjectManifest?
        var versions: [VersionSnapshot]
    }

    static func restoreSession() -> RestoredSession? {
        // Only allow one restore per app launch
        guard !hasBeenRestored else { return nil }
        hasBeenRestored = true

        guard let data = try? Data(contentsOf: sessionFileURL),
              let state = try? JSONDecoder().decode(SessionState.self, from: data)
        else { return nil }

        clearSession()

        let offset = CGSize(width: state.canvasOffsetX, height: state.canvasOffsetY)
        let scale = state.canvasScale

        // Case 1: Saved file — re-open via bookmark
        if let bookmarkData = state.fileBookmarkData {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }

            guard url.startAccessingSecurityScopedResource() else { return nil }

            guard let loadedDoc = ZIPExporter.importZIP(from: url) else {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
            // Note: We intentionally do NOT call stopAccessingSecurityScopedResource() here.
            // The security scope must remain active so the document can save back to this URL.
            // It will be released when the app terminates or the document is closed.
            let name = url.deletingPathExtension().lastPathComponent
            // Build a manifest to carry metadata through
            let loadedManifest = ProjectManifest.from(document: loadedDoc)
            return RestoredSession(nodes: loadedDoc.nodes, edges: loadedDoc.edges,
                                   name: name, url: url, offset: offset, scale: scale,
                                   manifest: loadedManifest, versions: loadedDoc.versions)
        }

        // Case 2: Unsaved document — decode manifest
        if let manifestData = state.manifestData {
            guard let manifest = try? JSONDecoder().decode(
                ProjectManifest.self, from: manifestData
            ) else { return nil }

            // Decode versions if present
            var versions: [VersionSnapshot] = []
            if let versionsData = state.versionsData {
                let versionDecoder = JSONDecoder()
                versionDecoder.dateDecodingStrategy = .iso8601
                versions = (try? versionDecoder.decode([VersionSnapshot].self, from: versionsData)) ?? []
            }

            return RestoredSession(nodes: manifest.nodes, edges: manifest.edges,
                                   name: state.projectName, url: nil, offset: offset, scale: scale,
                                   manifest: manifest, versions: versions)
        }

        return nil
    }

    // MARK: - Clear

    static func clearSession() {
        try? FileManager.default.removeItem(at: sessionFileURL)
    }
}
