import Foundation

// MARK: - Analysis Pattern

struct AnalysisPattern: Codable, Identifiable {
    var id: UUID
    var number: Int
    var name: String
    var category: String
    var antiPatternSignals: String
    var positiveSignals: String
    var relevantNodeKinds: String
    var isBuiltIn: Bool
    var isEnabled: Bool

    init(id: UUID = UUID(), number: Int, name: String, category: String,
         antiPatternSignals: String, positiveSignals: String,
         relevantNodeKinds: String, isBuiltIn: Bool = true, isEnabled: Bool = true) {
        self.id = id
        self.number = number
        self.name = name
        self.category = category
        self.antiPatternSignals = antiPatternSignals
        self.positiveSignals = positiveSignals
        self.relevantNodeKinds = relevantNodeKinds
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
    }
}

// MARK: - Analysis Pattern Store

@Observable
class AnalysisPatternStore {
    var patterns: [AnalysisPattern] = []
    var customCategories: [String] = [] {
        didSet { saveCategories() }
    }

    static let standardCategories = [
        "Foundational",
        "Scale & Reliability",
        "Knowledge & Document Processing",
        "Design-Time",
        "Operational",
        "Performance"
    ]

    static let uncategorizedName = "Uncategorized"

    /// All categories in display order: standard (if they have patterns), then custom (always shown), then uncategorized if needed.
    var allCategories: [String] {
        let usedCategories = Set(patterns.map(\.category))
        var cats = Self.standardCategories.filter { usedCategories.contains($0) }
        cats += customCategories
        if usedCategories.contains(Self.uncategorizedName) { cats.append(Self.uncategorizedName) }
        return cats
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !Self.standardCategories.contains(trimmed),
              !customCategories.contains(trimmed),
              trimmed != Self.uncategorizedName
        else { return }
        customCategories.append(trimmed)
    }

    func removeCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        // Move orphaned patterns to Uncategorized
        for i in patterns.indices where patterns[i].category == name {
            patterns[i].category = Self.uncategorizedName
        }
        save()
    }

    var filterSummaryPerPattern: Bool = true {
        didSet { UserDefaults.standard.set(filterSummaryPerPattern, forKey: "filterSummaryPerPattern") }
    }
    var systemPrompt: String = AnalysisPatternStore.defaultSystemPrompt {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "analysisSystemPrompt") }
    }
    var patternPromptTemplate: String = AnalysisPatternStore.defaultPatternPromptTemplate {
        didSet { UserDefaults.standard.set(patternPromptTemplate, forKey: "analysisPatternPromptTemplate") }
    }

    static let defaultSystemPrompt = """
    You are an expert agentic AI architecture reviewer. You evaluate whether a specific \
    design pattern or anti-pattern applies to an architecture based on evidence from the graph data.

    RULES:
    - A pattern can have BOTH anti-pattern issues AND positive aspects simultaneously
    - Set hasAntiPattern=true if anti-pattern signals are present, with severity "warning" for clear issues or "recommendation" for improvements
    - Set hasPositive=true if positive signals are present
    - Both can be true if the architecture partially follows the pattern but also has issues
    - Set both to false only if the pattern is not relevant to this architecture
    - Reference specific node names from the graph
    - Be concise but specific with evidence
    """

    static let defaultPatternPromptTemplate = """
    Evaluate the pattern "{{name}}" against this architecture. \
    Report both anti-pattern issues AND positive aspects if both exist.

    ANTI-PATTERN SIGNALS TO CHECK: {{antiPatternSignals}}
    POSITIVE SIGNALS TO CHECK: {{positiveSignals}}
    RELEVANT NODE KINDS: {{relevantNodeKinds}}

    ARCHITECTURE:
    {{graphSummary}}
    """

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Agentic Graph", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analysisPatterns.json")
    }

    init() {
        load()
        loadCategories()
        filterSummaryPerPattern = UserDefaults.standard.object(forKey: "filterSummaryPerPattern") as? Bool ?? true
        if let sp = UserDefaults.standard.string(forKey: "analysisSystemPrompt"), !sp.isEmpty {
            systemPrompt = sp
        }
        if let pt = UserDefaults.standard.string(forKey: "analysisPatternPromptTemplate"), !pt.isEmpty {
            patternPromptTemplate = pt
        }
    }

    // MARK: - CRUD

    func addPattern(_ pattern: AnalysisPattern) {
        patterns.append(pattern)
        save()
    }

    func removePattern(id: UUID) {
        patterns.removeAll { $0.id == id }
        save()
    }

    func updatePattern(_ updated: AnalysisPattern) {
        guard let idx = patterns.firstIndex(where: { $0.id == updated.id }) else { return }
        patterns[idx] = updated
        save()
    }

    func toggleEnabled(id: UUID) {
        guard let idx = patterns.firstIndex(where: { $0.id == id }) else { return }
        patterns[idx].isEnabled.toggle()
        save()
    }

    func resetToDefaults() {
        patterns = Self.loadDefaults()
        customCategories = []
        save()
    }

    var enabledPatterns: [AnalysisPattern] {
        patterns.filter(\.isEnabled)
    }

    // MARK: - Persistence

    private func load() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            patterns = Self.loadDefaults()
            save()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            patterns = try JSONDecoder().decode([AnalysisPattern].self, from: data)
        } catch {
            patterns = Self.loadDefaults()
            save()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(patterns)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to save analysis patterns: \(error)")
        }
    }

    private func loadCategories() {
        customCategories = UserDefaults.standard.stringArray(forKey: "analysisCustomCategories") ?? []
    }

    private func saveCategories() {
        UserDefaults.standard.set(customCategories, forKey: "analysisCustomCategories")
    }

    // MARK: - Export / Import

    struct PatternExport: Codable {
        var patterns: [AnalysisPattern]
        var customCategories: [String]
    }

    func exportData() -> Data? {
        let export = PatternExport(patterns: patterns, customCategories: customCategories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(export)
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode(PatternExport.self, from: data)
        patterns = imported.patterns
        customCategories = imported.customCategories
        save()
    }

    func importDataMerge(_ data: Data) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode(PatternExport.self, from: data)
        // Merge patterns — add new ones, skip duplicates by name
        let existingNames = Set(patterns.map(\.name))
        var added = 0
        for pattern in imported.patterns {
            if !existingNames.contains(pattern.name) {
                patterns.append(pattern)
                added += 1
            }
        }
        // Merge custom categories
        for cat in imported.customCategories {
            if !customCategories.contains(cat) && !Self.standardCategories.contains(cat) {
                customCategories.append(cat)
            }
        }
        save()
        print("[Patterns] Merged: \(added) new patterns added, \(imported.patterns.count - added) duplicates skipped")
    }

    static func loadDefaults() -> [AnalysisPattern] {
        guard let url = Bundle.main.url(forResource: "DefaultAnalysisPatterns", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let patterns = try? JSONDecoder().decode([AnalysisPattern].self, from: data)
        else {
            return []
        }
        return patterns
    }
}
