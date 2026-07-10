import Foundation
import AppKit

@Observable
class PendingFileLoad {
    static let shared = PendingFileLoad()

    /// Tracks file URLs of all open documents (standardized paths).
    /// Used by activateExistingWindow to detect duplicates even before
    /// the window's representedURL has been set.
    private static var activeDocumentPaths: Set<String> = []

    static func registerActiveURL(_ url: URL) {
        activeDocumentPaths.insert(url.standardizedFileURL.path)
    }

    static func unregisterActiveURL(_ url: URL) {
        activeDocumentPaths.remove(url.standardizedFileURL.path)
    }

    private var pendingNodes: [GraphNode]?
    private var pendingEdges: [GraphEdge]?
    private var pendingName: String?
    private var pendingURL: URL?
    private var pendingManifest: ProjectManifest?
    private var pendingVersions: [VersionSnapshot]?

    /// True when file data is waiting to be consumed by a window.
    var hasPending: Bool { pendingNodes != nil }

    private init() {}

    /// Returns true if the file is already open in an existing window,
    /// and brings that window to front.
    static func activateExistingWindow(for url: URL) -> Bool {
        let standardPath = url.standardizedFileURL.path

        // Check window representedURLs
        for window in NSApp.windows {
            if let represented = window.representedURL,
               represented.standardizedFileURL.path == standardPath {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return true
            }
        }

        // Also check the active document registry (covers the case where
        // a session-restored document hasn't had representedURL set yet)
        if activeDocumentPaths.contains(standardPath) {
            if let window = NSApp.windows.first(where: { $0.isVisible && !$0.title.isEmpty }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return true
        }

        return false
    }

    func store(nodes: [GraphNode], edges: [GraphEdge], name: String, url: URL?,
               manifest: ProjectManifest? = nil, versions: [VersionSnapshot] = []) {
        pendingNodes = nodes
        pendingEdges = edges
        pendingName = name
        pendingURL = url
        pendingManifest = manifest
        pendingVersions = versions
    }

    func consume() -> (nodes: [GraphNode], edges: [GraphEdge], name: String, url: URL?,
                        manifest: ProjectManifest?, versions: [VersionSnapshot])? {
        guard let nodes = pendingNodes,
              let edges = pendingEdges,
              let name = pendingName
        else { return nil }

        let url = pendingURL
        let manifest = pendingManifest
        let versions = pendingVersions ?? []

        pendingNodes = nil
        pendingEdges = nil
        pendingName = nil
        pendingURL = nil
        pendingManifest = nil
        pendingVersions = nil

        return (nodes, edges, name, url, manifest, versions)
    }
}
