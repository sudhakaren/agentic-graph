import SwiftUI

struct VersionListSheet: View {
    @Bindable var document: GraphDocument
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevert: VersionSnapshot? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Version History")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if document.versions.isEmpty {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
                Text("No versions saved yet.")
                    .foregroundStyle(.secondary)
                Text("Use File \u{2192} Create Version to save a snapshot.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                Spacer()
            } else {
                List {
                    ForEach(document.versions.reversed()) { snapshot in
                        versionRow(snapshot)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 440, height: 420)
        .confirmationDialog(
            "Revert to \"\(confirmRevert?.name ?? "")\"?",
            isPresented: Binding(
                get: { confirmRevert != nil },
                set: { if !$0 { confirmRevert = nil } }
            )
        ) {
            Button("Revert", role: .destructive) {
                if let snapshot = confirmRevert {
                    document.revertToVersion(snapshot)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                confirmRevert = nil
            }
        } message: {
            Text("This will replace all nodes, edges, and project metadata with the saved version. You can undo this action.")
        }
    }

    @ViewBuilder
    private func versionRow(_ snapshot: VersionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snapshot.name)
                    .fontWeight(.medium)

                Spacer()

                Button("Open as Copy") {
                    openAsCopy(snapshot)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Revert") {
                    confirmRevert = snapshot
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    document.deleteVersion(id: snapshot.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(snapshot.createdAt, style: .date)
                    Text(snapshot.createdAt, style: .time)
                }

                Text("·")

                Text("\(snapshot.manifest.nodes.count) nodes, \(snapshot.manifest.edges.count) edges")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let note = snapshot.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    /// Opens the snapshot in a new, editable window as a detached copy.
    /// The copy has no file of its own — Save As writes it to a new .ag file.
    private func openAsCopy(_ snapshot: VersionSnapshot) {
        PendingFileLoad.shared.store(
            nodes: snapshot.manifest.nodes,
            edges: snapshot.manifest.edges,
            name: snapshot.name,
            url: nil,
            manifest: snapshot.manifest,
            versions: []
        )
        NotificationCenter.default.post(name: .loadPendingOrOpenNew, object: nil)
        dismiss()
    }
}
