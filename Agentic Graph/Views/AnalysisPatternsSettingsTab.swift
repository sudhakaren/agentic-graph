import SwiftUI

// MARK: - Pattern List (Main Content Area)

struct PatternListView: View {
    let store: AnalysisPatternStore
    @Binding var selectedPatternID: UUID?
    @Binding var showAddForm: Bool
    @State private var showResetConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var selectionMode = false
    @State private var selectedForDeletion: Set<UUID> = []
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showRemoveCategoryConfirmation = false
    @State private var categoryToRemove: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            patternsList
        }
        .confirmationDialog("Reset all patterns to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                store.resetToDefaults()
                selectedPatternID = nil
                selectionMode = false
                selectedForDeletion.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all custom patterns and restore the built-in patterns.")
        }
        .confirmationDialog("Delete \(selectedForDeletion.count) pattern\(selectedForDeletion.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                for id in selectedForDeletion {
                    store.removePattern(id: id)
                }
                if let sel = selectedPatternID, selectedForDeletion.contains(sel) {
                    selectedPatternID = nil
                }
                selectedForDeletion.removeAll()
                selectionMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
        HStack(spacing: 8) {
            Text("\(store.enabledPatterns.count)/\(store.patterns.count) enabled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if selectionMode {
                Button {
                    if selectedForDeletion.count == store.patterns.count {
                        selectedForDeletion.removeAll()
                    } else {
                        selectedForDeletion = Set(store.patterns.map(\.id))
                    }
                } label: {
                    Text(selectedForDeletion.count == store.patterns.count ? "Deselect All" : "Select All")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button {
                    guard !selectedForDeletion.isEmpty else { return }
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete (\(selectedForDeletion.count))", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(selectedForDeletion.isEmpty)

                Button {
                    selectionMode = false
                    selectedForDeletion.removeAll()
                } label: {
                    Text("Done")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showAddCategory = true
                    newCategoryName = ""
                } label: {
                    Label("Category", systemImage: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Add Category")

                Button {
                    selectionMode = true
                    selectedForDeletion.removeAll()
                } label: {
                    Label("Select", systemImage: "checklist")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Select Multiple")

                Button {
                    showResetConfirmation = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Reset to Defaults")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)

        if showAddCategory {
            HStack(spacing: 6) {
                TextField("Category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { commitAddCategory() }
                Button("Add") { commitAddCategory() }
                    .font(.system(size: 12))
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { showAddCategory = false; newCategoryName = "" }
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        } // VStack
    }

    // MARK: - List

    private var patternsList: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(store.allCategories, id: \.self) { category in
                    let patterns = store.patterns
                        .filter { $0.category == category }
                        .sorted { $0.number < $1.number }

                    // Always show custom categories (even empty), only show standard if they have patterns
                    if !patterns.isEmpty || store.customCategories.contains(category) {
                        sectionHeader(category)
                        if patterns.isEmpty {
                            Text("No patterns")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        ForEach(patterns) { pattern in
                            patternRow(pattern)
                                .id(pattern.id)
                        }
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .onChange(of: selectedPatternID) { _, newID in
            if let newID {
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        } // ScrollViewReader
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        .confirmationDialog(
            "Remove category \"\(categoryToRemove ?? "")\"?",
            isPresented: $showRemoveCategoryConfirmation
        ) {
            Button("Remove", role: .destructive) {
                if let cat = categoryToRemove {
                    store.removeCategory(cat)
                }
                categoryToRemove = nil
            }
            Button("Cancel", role: .cancel) { categoryToRemove = nil }
        } message: {
            Text("Patterns in this category will be moved to Uncategorized.")
        }
    }

    /// Flat ordered list of patterns matching the display order.
    private var orderedPatterns: [AnalysisPattern] {
        store.allCategories.flatMap { category in
            store.patterns.filter { $0.category == category }.sorted { $0.number < $1.number }
        }
    }

    private func moveSelection(by offset: Int) {
        let ordered = orderedPatterns
        guard !ordered.isEmpty else { return }

        if let currentID = selectedPatternID,
           let currentIndex = ordered.firstIndex(where: { $0.id == currentID }) {
            let newIndex = min(max(currentIndex + offset, 0), ordered.count - 1)
            showAddForm = false
            selectedPatternID = ordered[newIndex].id
        } else {
            // Nothing selected — select first or last
            showAddForm = false
            selectedPatternID = offset > 0 ? ordered.first?.id : ordered.last?.id
        }
    }

    private func commitAddCategory() {
        store.addCategory(newCategoryName)
        newCategoryName = ""
        showAddCategory = false
    }

    private func isCustomCategory(_ title: String) -> Bool {
        store.customCategories.contains(title) || title == AnalysisPatternStore.uncategorizedName
    }

    private func sectionHeader(_ title: String) -> some View {
        let isCustom = isCustomCategory(title)
        return HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isCustom ? .blue : .secondary)
            if isCustom && title != AnalysisPatternStore.uncategorizedName {
                Text("Custom")
                    .font(.system(size: 8))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.blue.opacity(0.15)))
                    .foregroundStyle(.blue)
            }
            Spacer()
            if store.customCategories.contains(title) {
                Button {
                    categoryToRemove = title
                    showRemoveCategoryConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove category")
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 3)
        .padding(.horizontal, 10)
    }

    private func patternRow(_ pattern: AnalysisPattern) -> some View {
        let isSelected = selectedPatternID == pattern.id
        return Button {
            if selectionMode {
                if selectedForDeletion.contains(pattern.id) {
                    selectedForDeletion.remove(pattern.id)
                } else {
                    selectedForDeletion.insert(pattern.id)
                }
            } else {
                showAddForm = false
                selectedPatternID = pattern.id
            }
        } label: {
            HStack(spacing: 6) {
                if selectionMode {
                    Image(systemName: selectedForDeletion.contains(pattern.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedForDeletion.contains(pattern.id) ? .blue : .secondary)
                        .font(.system(size: 14))
                } else {
                    Toggle("", isOn: Binding(
                        get: { pattern.isEnabled },
                        set: { _ in store.toggleEnabled(id: pattern.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                }

                Text(pattern.name)
                    .font(.system(size: 13))
                    .foregroundStyle(pattern.isEnabled ? .primary : .tertiary)
                    .lineLimit(1)

                Spacer()

                if !pattern.isBuiltIn {
                    Text("Custom")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.blue.opacity(0.15)))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected && !selectionMode ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pattern Detail (Right Sidebar)

struct PatternDetailView: View {
    let store: AnalysisPatternStore
    @Binding var selectedPatternID: UUID?
    @Binding var showAddForm: Bool

    // Add form fields
    @State private var newName = ""
    @State private var newCategory = "Foundational"
    @State private var newAntiPatternSignals = ""
    @State private var newPositiveSignals = ""
    @State private var newRelevantNodeKinds = "agent"

    private var categories: [String] {
        store.allCategories
    }

    var body: some View {
        if showAddForm {
            addPatternForm
        } else if let id = selectedPatternID,
                  let pattern = store.patterns.first(where: { $0.id == id }) {
            patternEditor(pattern)
        } else {
            VStack {
                Spacer()
                Image(systemName: "wand.and.stars")
                    .font(.title)
                    .foregroundStyle(.quaternary)
                Text("Select a pattern")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Editor

    private func patternEditor(_ pattern: AnalysisPattern) -> some View {
        Form {
            Section("Pattern") {
                TextField("Name", text: Binding(
                    get: { pattern.name },
                    set: { val in var p = pattern; p.name = val; store.updatePattern(p) }
                ))

                Picker("Category", selection: Binding(
                    get: { pattern.category },
                    set: { val in var p = pattern; p.category = val; store.updatePattern(p) }
                )) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
            }

            Section("Anti-Pattern Signals") {
                growingTextEditor(Binding(
                    get: { pattern.antiPatternSignals },
                    set: { val in var p = pattern; p.antiPatternSignals = val; store.updatePattern(p) }
                ))
            }

            Section("Positive Signals") {
                growingTextEditor(Binding(
                    get: { pattern.positiveSignals },
                    set: { val in var p = pattern; p.positiveSignals = val; store.updatePattern(p) }
                ))
            }

            Section("Relevant Node Kinds") {
                nodeKindToggles(pattern)
            }

            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { pattern.isEnabled },
                    set: { _ in store.toggleEnabled(id: pattern.id) }
                ))
            }
        }
        .formStyle(.grouped)
    }

    private static let componentKinds: [(key: String, label: String, icon: String)] = [
        ("agent", "Agent", NodeKind.agent.sfSymbol),
        ("tool", "Tool", NodeKind.tool.sfSymbol),
        ("knowledge", "Knowledge", NodeKind.knowledge.sfSymbol),
        ("human", "Human", NodeKind.human.sfSymbol),
    ]

    private func nodeKindToggles(_ pattern: AnalysisPattern) -> some View {
        let current = Set(pattern.relevantNodeKinds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })

        return ForEach(Self.componentKinds, id: \.key) { kind in
            Toggle(isOn: Binding(
                get: { current.contains(kind.key) },
                set: { enabled in
                    var kinds = current
                    if enabled { kinds.insert(kind.key) } else { kinds.remove(kind.key) }
                    var p = pattern
                    p.relevantNodeKinds = kinds.sorted().joined(separator: ", ")
                    store.updatePattern(p)
                }
            )) {
                Label(kind.label, systemImage: kind.icon)
            }
        }
    }

    // MARK: - Add Form

    private var addPatternForm: some View {
        Form {
            Section("New Pattern") {
                TextField("Name", text: $newName)
                Picker("Category", selection: $newCategory) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
            }

            Section("Anti-Pattern Signals") {
                growingTextEditor($newAntiPatternSignals)
            }

            Section("Positive Signals") {
                growingTextEditor($newPositiveSignals)
            }

            Section("Relevant Node Kinds") {
                newPatternNodeKindToggles
            }

            Section {
                HStack {
                    Button("Cancel") { resetAddForm() }
                    Spacer()
                    Button("Add Pattern") { addPattern() }
                        .disabled(newName.isEmpty)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var newPatternNodeKindToggles: some View {
        let current = Set(newRelevantNodeKinds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })

        return ForEach(PatternDetailView.componentKinds, id: \.key) { kind in
            Toggle(isOn: Binding(
                get: { current.contains(kind.key) },
                set: { enabled in
                    var kinds = current
                    if enabled { kinds.insert(kind.key) } else { kinds.remove(kind.key) }
                    newRelevantNodeKinds = kinds.sorted().joined(separator: ", ")
                }
            )) {
                Label(kind.label, systemImage: kind.icon)
            }
        }
    }

    /// A TextEditor that auto-sizes to fit its content, left-aligned, no extra whitespace.
    private func growingTextEditor(_ text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            // Hidden Text that drives the height
            Text(text.wrappedValue.isEmpty ? " " : text.wrappedValue)
                .font(.body)
                .padding(6)
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Actual editor
            TextEditor(text: text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(1)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
    }

    private func addPattern() {
        let nextNumber = (store.patterns.map(\.number).max() ?? 0) + 1
        let pattern = AnalysisPattern(
            number: nextNumber,
            name: newName,
            category: newCategory,
            antiPatternSignals: newAntiPatternSignals,
            positiveSignals: newPositiveSignals,
            relevantNodeKinds: newRelevantNodeKinds,
            isBuiltIn: false,
            isEnabled: true
        )
        store.addPattern(pattern)
        selectedPatternID = pattern.id
        resetAddForm()
    }

    private func resetAddForm() {
        showAddForm = false
        newName = ""
        newCategory = "Foundational"
        newAntiPatternSignals = ""
        newPositiveSignals = ""
        newRelevantNodeKinds = "agent"
    }
}
