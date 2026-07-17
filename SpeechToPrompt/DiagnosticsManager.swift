import Foundation
import whisper

class DiagnosticsManager: ObservableObject {
    static let shared = DiagnosticsManager()
    
    @Published var logOutput: String = ""
    @Published var systemInfo: String = ""
    
    private var fileHandle: FileHandle?
    
    private init() {
        if let sysInfo = whisper_print_system_info() {
            systemInfo = String(cString: sysInfo)
        }
        setupLogFile()
        setupLogCallback()
    }
    
    func setupLogFile() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SpeechToPrompt")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let logURL = appDir.appendingPathComponent("diagnostics.log")
        
        // Clear or create file
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        } else {
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
        }
        
        fileHandle = try? FileHandle(forWritingTo: logURL)
        
        // Write system info on startup
        if let data = "SYSTEM INFO:\n\(systemInfo)\n\nLOGS:\n".data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    func setupLogCallback() {
        whisper_log_set({ level, text, userData in
            guard let text = text else { return }
            let message = String(cString: text)
            print(message, terminator: "")
            
            // Append log on the main queue for UI
            DispatchQueue.main.async {
                DiagnosticsManager.shared.logOutput += message
            }
            
            // Write to file
            if let data = message.data(using: .utf8) {
                DiagnosticsManager.shared.fileHandle?.write(data)
            }
        }, nil)
    }
    
    func log(_ message: String) {
        let formattedMessage = "[\(Date().description)] \(message)\n"
        print(formattedMessage, terminator: "")
        DispatchQueue.main.async {
            self.logOutput += formattedMessage
        }
        if let data = formattedMessage.data(using: .utf8) {
            self.fileHandle?.write(data)
        }
    }
    
    func clearLogs() {
        logOutput = ""
        setupLogFile() // resets file
    }
    
    deinit {
        try? fileHandle?.close()
    }
}
