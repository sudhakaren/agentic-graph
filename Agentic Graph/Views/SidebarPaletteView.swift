import SwiftUI

struct SidebarPaletteView: View {
    @Bindable var document: GraphDocument
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("Components")
                    PaletteItem(kind: .agent, document: document)
                    PaletteItem(kind: .tool, document: document)
                    PaletteItem(kind: .knowledge, document: document)
                    PaletteItem(kind: .human, document: document)

                    sectionHeader("Annotations")
                    PaletteItem(kind: .comment, document: document)

                    sectionHeader("Shapes")
                    PaletteItem(kind: .shapeRectangle, document: document)
                    PaletteItem(kind: .shapeRoundedRect, document: document)
                    PaletteItem(kind: .shapeOval, document: document)
                    PaletteItem(kind: .shapeText, document: document)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            Button {
                document.viewMode = .settings
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("Settings")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    }
}

struct PaletteItem: View {
    let kind: NodeKind
    @Bindable var document: GraphDocument

    private var isHidden: Bool {
        document.hiddenNodeKinds.contains(kind)
    }

    var body: some View {
        if isHidden {
            rowContent
        } else {
            rowContent
                .draggable(kind) {
                    HStack(spacing: 6) {
                        Image(systemName: kind.sfSymbol)
                            .foregroundStyle(kind.color)
                        Text(kind.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(8)
                    .background(kind.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.sfSymbol)
                .frame(width: 20)
                .foregroundStyle(kind.color)
            Text(kind.displayName)
                .font(.system(size: 13))
            Spacer()
            Button {
                if isHidden {
                    document.hiddenNodeKinds.remove(kind)
                } else {
                    document.hiddenNodeKinds.insert(kind)
                }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .opacity(isHidden ? 0.4 : 1.0)
    }
}
