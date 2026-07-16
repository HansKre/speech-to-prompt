import Foundation

class ModelManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isDownloaded = false
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var downloadSpeed: String = ""
    @Published var timeRemaining: String = ""
    @Published var errorMessage: String? = nil
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadStartTime: Date?
    
    let modelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
    
    var localModelURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SpeechToPrompt")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("ggml-large-v3-turbo.bin")
    }
    
    override init() {
        super.init()
        checkIfModelExists()
    }
    
    func checkIfModelExists() {
        isDownloaded = FileManager.default.fileExists(atPath: localModelURL.path)
    }
    
    func startDownload() {
        isDownloading = true
        errorMessage = nil
        progress = 0.0
        downloadStartTime = Date()
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        downloadTask = session.downloadTask(with: modelURL)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        progress = 0.0
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = Double(totalBytesExpectedToWrite)
        let written = Double(totalBytesWritten)
        
        DispatchQueue.main.async {
            self.progress = total > 0 ? (written / total) : 0.0
            
            let now = Date()
            guard let startTime = self.downloadStartTime else { return }
            let elapsedTime = now.timeIntervalSince(startTime)
            
            if elapsedTime > 0 {
                let speedBytesPerSec = Double(totalBytesWritten) / elapsedTime
                let speedMB = speedBytesPerSec / (1024 * 1024)
                self.downloadSpeed = String(format: "%.1f MB/s", speedMB)
                
                let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
                if speedBytesPerSec > 0 {
                    let secondsRemaining = Double(remainingBytes) / speedBytesPerSec
                    if secondsRemaining > 3600 {
                        self.timeRemaining = String(format: "%d hr %d min", Int(secondsRemaining) / 3600, (Int(secondsRemaining) % 3600) / 60)
                    } else if secondsRemaining > 60 {
                        self.timeRemaining = String(format: "%d min %d sec", Int(secondsRemaining) / 60, Int(secondsRemaining) % 60)
                    } else {
                        self.timeRemaining = String(format: "%d sec", Int(secondsRemaining))
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let destination = localModelURL
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            
            DispatchQueue.main.async {
                self.isDownloaded = true
                self.isDownloading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save model file: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                self.errorMessage = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
}
