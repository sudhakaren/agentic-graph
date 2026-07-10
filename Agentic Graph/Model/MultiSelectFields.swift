import Foundation

/// Categories of inspector fields, used to determine which fields are common
/// when multiple nodes of different kinds are selected.
enum InspectorFieldCategory: Hashable {
    /// title, detail, lockState, colorHex — available for ALL node kinds
    case universal
    /// risk — available for agent, tool, knowledge (not comment, not shapes)
    case riskEnabled
    /// Agent-specific metadata fields
    case agent
    /// Tool-specific metadata fields
    case tool
    /// Knowledge-specific metadata fields
    case knowledge
    /// Shape stroke/fill fields (shared by all 4 shape kinds)
    case shape
    /// Text shape fields: fontSize, fontColorHex
    case textShape
    /// Comment appearance (colorHex as fill)
    case comment
    /// Edge fields: colorHex, lineStyle (independent of node categories)
    case edge

    /// Compute the intersection of field categories across a set of node kinds.
    static func commonCategories(for kinds: Set<NodeKind>) -> Set<InspectorFieldCategory> {
        guard let first = kinds.first else { return [] }
        var result = first.fieldCategories
        for kind in kinds.dropFirst() {
            result.formIntersection(kind.fieldCategories)
        }
        return result
    }
}

extension NodeKind {
    /// Which inspector field categories this node kind supports.
    var fieldCategories: Set<InspectorFieldCategory> {
        switch self {
        case .agent:            return [.universal, .riskEnabled, .agent]
        case .tool:             return [.universal, .riskEnabled, .tool]
        case .knowledge:        return [.universal, .riskEnabled, .knowledge]
        case .human:            return [.universal, .riskEnabled]
        case .comment:          return [.universal, .comment]
        case .shapeRectangle,
             .shapeRoundedRect,
             .shapeOval:        return [.universal, .shape]
        case .shapeText:        return [.universal, .shape, .textShape]
        }
    }
}
