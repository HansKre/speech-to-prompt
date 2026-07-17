import SwiftUI

@main
struct SpeechToPromptApp: App {
    init() {
        NSApp?.activationPolicy()
        UserDefaults.standard.set(0.5, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowResizability(.automatic)
    }
}
