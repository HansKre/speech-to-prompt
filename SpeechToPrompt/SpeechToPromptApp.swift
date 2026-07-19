import SwiftUI
import AppKit

struct PointerCursorStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .onHover { hovering in
                guard isEnabled else { return }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct PointerOnHover: ViewModifier {
    @Environment(\.isEnabled) var isEnabled

    func body(content: Content) -> some View {
        content.onHover { hovering in
            guard isEnabled else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func pointerOnHover() -> some View {
        modifier(PointerOnHover())
    }
}

@main
struct SpeechToPromptApp: App {
    init() {
        NSApp?.activationPolicy()
        UserDefaults.standard.set(0.5, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .buttonStyle(PointerCursorStyle())
        }
        .windowResizability(.automatic)
    }
}
