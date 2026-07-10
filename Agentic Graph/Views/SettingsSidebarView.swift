import SwiftUI

struct SettingsSidebarView: View {
    @Bindable var document: GraphDocument
    @Environment(\.colorScheme) private var colorScheme

    private struct TabItem: Identifiable {
        let id: String
        let label: LocalizedStringKey
        let icon: String
    }

    private struct TabSection: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let items: [TabItem]
    }

    private var sections: [TabSection] {
        [
            TabSection(id: "general", title: "General", items: [
                TabItem(id: "general", label: "Language", icon: "globe"),
            ]),
            TabSection(id: "components", title: "Components", items: [
                TabItem(id: NodeKind.agent.rawValue, label: "Agent", icon: NodeKind.agent.sfSymbol),
                TabItem(id: NodeKind.tool.rawValue, label: "Tool", icon: NodeKind.tool.sfSymbol),
                TabItem(id: NodeKind.knowledge.rawValue, label: "Knowledge", icon: NodeKind.knowledge.sfSymbol),
                TabItem(id: NodeKind.human.rawValue, label: "Human", icon: NodeKind.human.sfSymbol),
            ]),
            TabSection(id: "annotations", title: "Annotations", items: [
                TabItem(id: NodeKind.comment.rawValue, label: "Comment", icon: NodeKind.comment.sfSymbol),
            ]),
            TabSection(id: "shapes", title: "Shapes", items: [
                TabItem(id: NodeKind.shapeRectangle.rawValue, label: "Rectangle", icon: NodeKind.shapeRectangle.sfSymbol),
                TabItem(id: NodeKind.shapeRoundedRect.rawValue, label: "Rounded Rect", icon: NodeKind.shapeRoundedRect.sfSymbol),
                TabItem(id: NodeKind.shapeOval.rawValue, label: "Oval", icon: NodeKind.shapeOval.sfSymbol),
                TabItem(id: NodeKind.shapeText.rawValue, label: "Text", icon: NodeKind.shapeText.sfSymbol),
            ]),
            TabSection(id: "analysis", title: "Analysis", items: [
                TabItem(id: "llm", label: "LLM Provider", icon: "cpu"),
                TabItem(id: "analysisConfig", label: "Configuration", icon: "slider.horizontal.3"),
                TabItem(id: "analysis", label: "Patterns", icon: "wand.and.stars"),
                TabItem(id: "promptAnalysis", label: "Prompt Analysis", icon: "text.magnifyingglass"),
            ]),
            TabSection(id: "sizing", title: "Sizing", items: [
                TabItem(id: "sizing", label: "Parameters", icon: "square.stack.3d.up"),
            ]),
            TabSection(id: "latency", title: "Latency", items: [
                TabItem(id: "latency", label: "Parameters", icon: "stopwatch"),
            ]),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            Button {
                document.viewMode = .workspace
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Workspace")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Tab list
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sections) { section in
                        sectionHeader(section.title)
                        ForEach(section.items) { tab in
                            tabButton(tab)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(colorScheme == .light ? Color(white: 0.88) : Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .padding(.horizontal, 8)
    }

    private func tabButton(_ tab: TabItem) -> some View {
        let isSelected = document.settingsTab == tab.id
        return Button {
            document.settingsTab = tab.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(tab.label)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
