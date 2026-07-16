import Foundation

class WhisperManager: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionResult: String = ""
    @Published var statusMessage: String = ""
    
    private var whisper: Whisper?
    
    func transcribeAudio(fileURL: URL, modelURL: URL) async {
        await MainActor.run {
            self.isTranscribing = true
            self.statusMessage = "Initializing Whisper engine..."
        }
        
        do {
            if whisper == nil {
                whisper = try Whisper(fromFileURL: modelURL)
            }
            
            await MainActor.run {
                self.statusMessage = "Loading and resampling audio buffer..."
            }
            let audioFrames = try AudioManager.loadAudioData(from: fileURL)
            
            await MainActor.run {
                self.statusMessage = "Transcribing locally (Metal GPU Accelerated)..."
            }
            
            let resultText = try await whisper!.transcribe(audioFrames: audioFrames)
            
            await MainActor.run {
                self.transcriptionResult = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isTranscribing = false
                self.statusMessage = ""
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Transcription failed: \(error.localizedDescription)"
                self.isTranscribing = false
            }
        }
    }
    
    func clearResult() {
        transcriptionResult = ""
    }
}
