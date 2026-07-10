import SwiftUI
import AppKit

struct PopoverColorPicker: View {
    let label: LocalizedStringKey
    @Binding var color: Color
    @State private var showPopover = false
    @State private var hexInput = ""
    @State private var lastDismissed: Date = .distantPast
    @State private var instanceID = UUID()

    /// Tracks which PopoverColorPicker instance currently owns the NSColorPanel
    private static var currentPanelOwner: UUID?

    // Hardcoded hex ensures reliable round-trip matching for checkmarks
    private static let presetHexes: [[String]] = [
        ["FF3B30", "FF9500", "FFCC00", "34C759", "5AC8FA", "007AFF", "AF52DE", "FF2D55"],
        ["A2845E", "5856D6", "00C7BE", "30B0C7", "000000", "4D4D4D", "B3B3B3", "FFFFFF"]
    ]

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                Button {
                    // Ignore if the popover just dismissed (prevents re-open on same click)
                    guard Date().timeIntervalSince(lastDismissed) > 0.3 else { return }
                    hexInput = color.hexString
                    showPopover = true
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 32, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPopover, arrowEdge: .leading) {
                    popoverContent
                }
                .onChange(of: showPopover) { _, isShowing in
                    if !isShowing {
                        lastDismissed = Date()
                    }
                }

                Button {
                    toggleColorPanel()
                } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)
        ) { _ in
            guard Self.currentPanelOwner == instanceID else { return }
            color = Color(nsColor: NSColorPanel.shared.color)
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 6) {
            ForEach(0..<Self.presetHexes.count, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(Self.presetHexes[row], id: \.self) { hex in
                        presetButton(hex: hex)
                    }
                }
            }
            Divider()
            HStack(spacing: 6) {
                Text("#")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("Hex", text: $hexInput)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        let cleaned = hexInput.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                        if cleaned.count == 6 {
                            color = Color(hex: cleaned)
                            showPopover = false
                        }
                    }
            }
        }
        .padding(10)
        .onChange(of: color) { _, _ in
            hexInput = color.hexString
        }
    }

    private func toggleColorPanel() {
        let panel = NSColorPanel.shared
        if panel.isVisible && Self.currentPanelOwner == instanceID {
            panel.orderOut(nil)
            Self.currentPanelOwner = nil
        } else {
            panel.color = NSColor(color)
            panel.showsAlpha = false
            panel.isContinuous = true
            Self.currentPanelOwner = instanceID
            if let mainWindow = NSApp.mainWindow {
                let x = mainWindow.frame.maxX - panel.frame.width - 300
                let y = mainWindow.frame.maxY - 60
                panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
            }
            panel.orderFront(nil)
        }
    }

    private func presetButton(hex: String) -> some View {
        let presetColor = Color(hex: hex)
        let isMatch = color.hexString == hex

        return Button {
            color = presetColor
            showPopover = false
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(presetColor)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
                .overlay {
                    if isMatch {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(contrastColor(hex: hex))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Returns white or black depending on luminance of the color
    private func contrastColor(hex: String) -> Color {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }
}
