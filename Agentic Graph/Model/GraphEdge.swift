import Foundation
import SwiftUI

enum EdgeLineStyle: String, Codable, CaseIterable {
    case solid, dashed, dotted

    var displayName: String {
        switch self {
        case .solid:  "Solid"
        case .dashed: "Dashed"
        case .dotted: "Dotted"
        }
    }

    var dashPattern: [CGFloat] {
        switch self {
        case .solid:  []
        case .dashed: [8, 4]
        case .dotted: [2, 4]
        }
    }
}

struct GraphEdge: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceNodeID: UUID
    var sourcePortID: UUID
    var targetNodeID: UUID
    var targetPortID: UUID
    var colorHex: String?
    var lineStyle: EdgeLineStyle
    var comments: String?

    init(id: UUID = UUID(), sourceNodeID: UUID, sourcePortID: UUID,
         targetNodeID: UUID, targetPortID: UUID,
         colorHex: String? = nil, lineStyle: EdgeLineStyle = .solid,
         comments: String? = nil) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.sourcePortID = sourcePortID
        self.targetNodeID = targetNodeID
        self.targetPortID = targetPortID
        self.colorHex = colorHex
        self.lineStyle = lineStyle
        self.comments = comments
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, sourceNodeID, sourcePortID, targetNodeID, targetPortID
        case colorHex, lineStyle, comments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sourceNodeID = try c.decode(UUID.self, forKey: .sourceNodeID)
        sourcePortID = try c.decode(UUID.self, forKey: .sourcePortID)
        targetNodeID = try c.decode(UUID.self, forKey: .targetNodeID)
        targetPortID = try c.decode(UUID.self, forKey: .targetPortID)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        lineStyle = try c.decodeIfPresent(EdgeLineStyle.self, forKey: .lineStyle) ?? .solid
        comments = try c.decodeIfPresent(String.self, forKey: .comments)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sourceNodeID, forKey: .sourceNodeID)
        try c.encode(sourcePortID, forKey: .sourcePortID)
        try c.encode(targetNodeID, forKey: .targetNodeID)
        try c.encode(targetPortID, forKey: .targetPortID)
        try c.encodeIfPresent(colorHex, forKey: .colorHex)
        if lineStyle != .solid { try c.encode(lineStyle, forKey: .lineStyle) }
        try c.encodeIfPresent(comments, forKey: .comments)
    }
}
