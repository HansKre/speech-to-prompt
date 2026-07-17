import AppKit
import Foundation

class SpotifyManager {
    static let shared = SpotifyManager()
    
    private var didPauseSpotify = false
    
    private func isSpotifyRunning() -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        return !apps.isEmpty
    }
    
    private func executeAppleScript(_ source: String) -> String? {
        DiagnosticsManager.shared.log("SpotifyManager: Executing AppleScript...")
        guard let script = NSAppleScript(source: source) else {
            DiagnosticsManager.shared.log("SpotifyManager Error: Could not initialize NSAppleScript")
            return nil
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            DiagnosticsManager.shared.log("SpotifyManager Error: AppleScript failed: \(error)")
            return nil
        }
        let val = result.stringValue
        DiagnosticsManager.shared.log("SpotifyManager: AppleScript returned: \(val ?? "nil")")
        return val
    }
    
    func pausePlaybackIfNeeded() {
        let defaults = UserDefaults.standard
        let shouldPause = defaults.object(forKey: "pauseSpotifySetting") == nil ? true : defaults.bool(forKey: "pauseSpotifySetting")
        
        guard shouldPause else {
            DiagnosticsManager.shared.log("SpotifyManager: Pause Spotify setting is disabled. Skipping pause.")
            didPauseSpotify = false
            return
        }
        
        let running = isSpotifyRunning()
        DiagnosticsManager.shared.log("SpotifyManager: Checking if Spotify is running: \(running)")
        guard running else {
            didPauseSpotify = false
            return
        }
        
        let scriptSource = """
        tell application "Spotify"
            if player state is playing then
                pause
                return "paused"
            end if
        end tell
        return "none"
        """
        
        if let result = executeAppleScript(scriptSource), result == "paused" {
            didPauseSpotify = true
            DiagnosticsManager.shared.log("SpotifyManager: Spotify was playing, paused it successfully.")
        } else {
            didPauseSpotify = false
            DiagnosticsManager.shared.log("SpotifyManager: Spotify was not playing or error occurred.")
        }
    }
    
    func resumePlaybackIfNeeded() {
        DiagnosticsManager.shared.log("SpotifyManager: resumePlaybackIfNeeded called (didPauseSpotify = \(didPauseSpotify))")
        guard didPauseSpotify else { return }
        
        // Reset flag first
        didPauseSpotify = false
        
        let running = isSpotifyRunning()
        DiagnosticsManager.shared.log("SpotifyManager: Checking if Spotify is running to resume: \(running)")
        guard running else { return }
        
        let scriptSource = """
        tell application "Spotify"
            play
        end tell
        """
        
        _ = executeAppleScript(scriptSource)
        DiagnosticsManager.shared.log("SpotifyManager: Executed resume play AppleScript.")
    }
}
