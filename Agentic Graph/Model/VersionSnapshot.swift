import Foundation

struct VersionSnapshot: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var note: String?
    var manifest: ProjectManifest

    init(name: String, note: String? = nil, document: GraphDocument) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.note = note
        self.manifest = ProjectManifest.from(document: document)
    }
}
