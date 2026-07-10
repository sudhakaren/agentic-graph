import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let document: GraphDocument
    let onSave: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.document = document
        context.coordinator.onSave = onSave

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            // Update dirty indicator (dot in close button)
            window.isDocumentEdited = document.isDirty

            // Update represented URL for window title proxy icon
            if let url = document.fileURL {
                window.representedURL = url
            }

            // Install delegate if not already ours
            if window.delegate !== context.coordinator {
                context.coordinator.previousDelegate = window.delegate
                window.delegate = context.coordinator
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, onSave: onSave)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var document: GraphDocument
        var onSave: () -> Void
        weak var previousDelegate: NSWindowDelegate?

        /// When the user clicks "Don't Save", we skip the session save
        /// in windowWillClose and clear the file instead. This avoids
        /// calling resetToNew() which would trigger a costly SwiftUI
        /// re-render on the about-to-close window.
        var discardSessionOnClose = false

        init(document: GraphDocument, onSave: @escaping () -> Void) {
            self.document = document
            self.onSave = onSave
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard document.isDirty else { return true }

            let alert = NSAlert()
            let format = String(localized: "Do you want to save changes to \"%@\"?")
            alert.messageText = String(format: format, document.projectName)
            alert.informativeText = String(localized: "Your changes will be lost if you don't save them.")
            alert.addButton(withTitle: String(localized: "Save"))
            alert.addButton(withTitle: String(localized: "Don't Save"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            alert.alertStyle = .warning

            alert.beginSheetModal(for: sender) { [weak self] response in
                switch response {
                case .alertFirstButtonReturn:
                    // Save then close
                    self?.onSave()
                    self?.document.markClean()
                    sender.close()
                case .alertSecondButtonReturn:
                    // Don't save — flag so windowWillClose clears
                    // the session instead of saving it.
                    self?.discardSessionOnClose = true
                    self?.document.markClean()
                    sender.close()
                default:
                    // Cancel — do nothing
                    break
                }
            }
            return false // Prevent immediate close; the sheet handles it
        }

        // Forward delegate methods to the previous delegate
        func windowDidBecomeKey(_ notification: Notification) {
            previousDelegate?.windowDidBecomeKey?(notification)
        }

        func windowDidResignKey(_ notification: Notification) {
            previousDelegate?.windowDidResignKey?(notification)
        }

        func windowWillClose(_ notification: Notification) {
            if discardSessionOnClose {
                SessionRestorer.clearSession()
            } else {
                SessionRestorer.saveSession(document: document)
            }
            if let url = document.fileURL {
                PendingFileLoad.unregisterActiveURL(url)
            }
            previousDelegate?.windowWillClose?(notification)
        }
    }
}
