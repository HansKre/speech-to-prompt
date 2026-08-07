import SwiftUI

struct KeyboardShortcutsView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                ShortcutSection(title: "Recording") {
                    ShortcutRow(description: "Start / Stop recording", shortcut: "⌘R")
                }

                ShortcutSection(title: "Navigation") {
                    ShortcutRow(description: "Show keyboard shortcuts", shortcut: "⌘K")
                }

                ShortcutSection(title: "Dialogs") {
                    ShortcutRow(description: "Confirm / Submit", shortcut: "Return")
                    ShortcutRow(description: "Cancel / Close", shortcut: "Esc")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

private struct ShortcutSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            content
        }
    }
}

private struct ShortcutRow: View {
    let description: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(description)
                .font(.body)
            Spacer()
            ShortcutBadge(text: shortcut)
        }
    }
}

private struct ShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(5)
    }
}
