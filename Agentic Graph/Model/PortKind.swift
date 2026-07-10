import Foundation

enum PortKind: String, Codable {
    case input
    case output
}

struct NodePort: Identifiable, Hashable {
    var id: UUID
    var label: String
    var kind: PortKind
    var isAutoCreated: Bool

    init(id: UUID = UUID(), label: String, kind: PortKind, isAutoCreated: Bool = false) {
        self.id = id
        self.label = label
        self.kind = kind
        self.isAutoCreated = isAutoCreated
    }
}

extension NodePort: Codable {
    enum CodingKeys: String, CodingKey {
        case id, label, kind, isAutoCreated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        kind = try c.decode(PortKind.self, forKey: .kind)
        isAutoCreated = try c.decodeIfPresent(Bool.self, forKey: .isAutoCreated) ?? false
    }
}
