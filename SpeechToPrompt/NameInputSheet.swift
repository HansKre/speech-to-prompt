import SwiftUI

struct NameInputSheet: View {
    let title: String
    let placeholder: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(title: String, placeholder: String = "Enter name", initialText: String = "", onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    submit()
                }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .pointerOnHover()
                .keyboardShortcut(.cancelAction)
                .tooltip("Cancel (Esc)")

                Spacer()

                Button("OK") {
                    submit()
                }
                .pointerOnHover()
                .keyboardShortcut(.defaultAction)
                .tooltip("Confirm (Return)")
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            isFocused = true
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}
