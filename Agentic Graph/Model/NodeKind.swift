import SwiftUI

enum NodeKind: String, Codable, CaseIterable, Identifiable {
    case agent
    case tool
    case knowledge
    case human
    case comment
    case shapeRectangle
    case shapeRoundedRect
    case shapeOval
    case shapeText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agent:            String(localized: "Agent")
        case .tool:             String(localized: "Tool")
        case .knowledge:        String(localized: "Knowledge")
        case .human:            String(localized: "Human")
        case .comment:          String(localized: "Comment")
        case .shapeRectangle:   String(localized: "Rectangle")
        case .shapeRoundedRect: String(localized: "Rounded Rect")
        case .shapeOval:        String(localized: "Oval")
        case .shapeText:        String(localized: "Text")
        }
    }

    var sfSymbol: String {
        switch self {
        case .agent:            "person.crop.circle"
        case .tool:             "wrench.and.screwdriver"
        case .knowledge:        "book.closed"
        case .human:            "person.fill"
        case .comment:          "text.bubble"
        case .shapeRectangle:   "rectangle"
        case .shapeRoundedRect: "rectangle.roundedtop"
        case .shapeOval:        "oval"
        case .shapeText:        "textformat.size"
        }
    }

    var color: Color {
        switch self {
        case .agent:      .blue
        case .tool:       .orange
        case .knowledge:  .indigo
        case .human:      .green
        case .comment:    .gray
        case .shapeRectangle, .shapeRoundedRect, .shapeOval, .shapeText: .secondary
        }
    }

    var hasPorts: Bool {
        switch self {
        case .comment, .shapeRectangle, .shapeRoundedRect, .shapeOval, .shapeText: false
        default: true
        }
    }

    var canHaveOutput: Bool {
        switch self {
        case .knowledge, .comment, .shapeRectangle, .shapeRoundedRect, .shapeOval, .shapeText: false
        case .agent, .tool, .human: true
        }
    }

    var isShape: Bool {
        switch self {
        case .shapeRectangle, .shapeRoundedRect, .shapeOval, .shapeText: true
        default: false
        }
    }

    // Backward compatibility for old saved files
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "drawBox":    self = .shapeRectangle
        case "drawCircle": self = .shapeOval
        default:
            guard let kind = NodeKind(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: container.codingPath,
                          debugDescription: "Unknown NodeKind: \(raw)"))
            }
            self = kind
        }
    }
}
