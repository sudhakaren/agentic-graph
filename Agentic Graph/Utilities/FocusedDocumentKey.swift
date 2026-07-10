import SwiftUI

// MARK: - FocusedValue Keys for Menu Commands

struct FocusedDocumentKey: FocusedValueKey {
    typealias Value = GraphDocument
}

struct NewDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct OpenDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveAsDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportPNGActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportHTMLActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportMarkdownActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct CreateVersionActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ShowVersionsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportWxOActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportCrewAIActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportLangGraphActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportOpenAIAgentsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportAutoGenActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportMergeWxOActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportMergeAGActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct AnalyzeGraphActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct PatternStoreKey: FocusedValueKey {
    typealias Value = AnalysisPatternStore
}

struct AnalysisDisabledKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var document: GraphDocument? {
        get { self[FocusedDocumentKey.self] }
        set { self[FocusedDocumentKey.self] = newValue }
    }
    var newDocumentAction: (() -> Void)? {
        get { self[NewDocumentActionKey.self] }
        set { self[NewDocumentActionKey.self] = newValue }
    }
    var openDocumentAction: (() -> Void)? {
        get { self[OpenDocumentActionKey.self] }
        set { self[OpenDocumentActionKey.self] = newValue }
    }
    var saveAction: (() -> Void)? {
        get { self[SaveDocumentActionKey.self] }
        set { self[SaveDocumentActionKey.self] = newValue }
    }
    var saveAsAction: (() -> Void)? {
        get { self[SaveAsDocumentActionKey.self] }
        set { self[SaveAsDocumentActionKey.self] = newValue }
    }
    var exportPNGAction: (() -> Void)? {
        get { self[ExportPNGActionKey.self] }
        set { self[ExportPNGActionKey.self] = newValue }
    }
    var exportHTMLAction: (() -> Void)? {
        get { self[ExportHTMLActionKey.self] }
        set { self[ExportHTMLActionKey.self] = newValue }
    }
    var exportMarkdownAction: (() -> Void)? {
        get { self[ExportMarkdownActionKey.self] }
        set { self[ExportMarkdownActionKey.self] = newValue }
    }
    var createVersionAction: (() -> Void)? {
        get { self[CreateVersionActionKey.self] }
        set { self[CreateVersionActionKey.self] = newValue }
    }
    var showVersionsAction: (() -> Void)? {
        get { self[ShowVersionsActionKey.self] }
        set { self[ShowVersionsActionKey.self] = newValue }
    }
    var importWxOAction: (() -> Void)? {
        get { self[ImportWxOActionKey.self] }
        set { self[ImportWxOActionKey.self] = newValue }
    }
    var importCrewAIAction: (() -> Void)? {
        get { self[ImportCrewAIActionKey.self] }
        set { self[ImportCrewAIActionKey.self] = newValue }
    }
    var importLangGraphAction: (() -> Void)? {
        get { self[ImportLangGraphActionKey.self] }
        set { self[ImportLangGraphActionKey.self] = newValue }
    }
    var importOpenAIAgentsAction: (() -> Void)? {
        get { self[ImportOpenAIAgentsActionKey.self] }
        set { self[ImportOpenAIAgentsActionKey.self] = newValue }
    }
    var importAutoGenAction: (() -> Void)? {
        get { self[ImportAutoGenActionKey.self] }
        set { self[ImportAutoGenActionKey.self] = newValue }
    }
    var importMergeWxOAction: (() -> Void)? {
        get { self[ImportMergeWxOActionKey.self] }
        set { self[ImportMergeWxOActionKey.self] = newValue }
    }
    var importMergeAGAction: (() -> Void)? {
        get { self[ImportMergeAGActionKey.self] }
        set { self[ImportMergeAGActionKey.self] = newValue }
    }
    var analyzeGraphAction: (() -> Void)? {
        get { self[AnalyzeGraphActionKey.self] }
        set { self[AnalyzeGraphActionKey.self] = newValue }
    }
    var patternStore: AnalysisPatternStore? {
        get { self[PatternStoreKey.self] }
        set { self[PatternStoreKey.self] = newValue }
    }
    var analysisDisabled: Bool? {
        get { self[AnalysisDisabledKey.self] }
        set { self[AnalysisDisabledKey.self] = newValue }
    }
}
