import SwiftUI

struct CreateVersionSheet: View {
    @Bindable var document: GraphDocument
    @Environment(\.dismiss) private var dismiss
    @State private var versionName = ""
    @State private var versionNote = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Version Snapshot")
                .font(.headline)

            Text("Save a snapshot of the current state. You can revert to this version later.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Version name", text: $versionName)
                .textFieldStyle(.roundedBorder)

            TextField("Note (optional)", text: $versionNote)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("\(document.nodes.count) nodes, \(document.edges.count) edges")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    document.createVersion(
                        name: versionName,
                        note: versionNote.isEmpty ? nil : versionNote
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(versionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            versionName = formatter.string(from: Date())
        }
    }
}
