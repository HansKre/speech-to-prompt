import Foundation

class WhisperManager: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionResult: String = ""
    @Published var statusMessage: String = ""
    
    private var whisper: Whisper?
    private var currentCancellationPointer: UnsafeMutablePointer<Bool>?
    
    func transcribeAudio(fileURL: URL, modelURL: URL) async {
        // Cancel any active live transcription
        cancelCurrentTranscription()
        
        // Wait for the active transcription to yield and exit
        while isTranscribing {
            try? await Task.sleep(for: .milliseconds(10))
        }
        
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
     
     func transcribeLive(samples: [Float], modelURL: URL) async {
         guard !isTranscribing else {
             print("WhisperManager: Live transcription requested, but another run is already in progress. Skipping.")
             return
         }
         
         print("WhisperManager: Starting live transcription on \(samples.count) samples...")
         
         await MainActor.run {
             self.isTranscribing = true
             self.statusMessage = "Transcribing live..."
         }
         
         let cancelPtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
         cancelPtr.pointee = false
         self.currentCancellationPointer = cancelPtr
         
         do {
             if whisper == nil {
                 print("WhisperManager: Initializing Whisper model...")
                 whisper = try Whisper(fromFileURL: modelURL)
                 print("WhisperManager: Whisper model initialized successfully.")
             }
             
             let startTime = Date()
             let resultText = try await whisper!.transcribe(audioFrames: samples, isCancelled: cancelPtr)
             let duration = Date().timeIntervalSince(startTime)
             
             print("WhisperManager: Live transcription finished in \(String(format: "%.2f", duration))s. Result: \"\(resultText)\"")
             
             cancelPtr.deallocate()
             self.currentCancellationPointer = nil
             
             await MainActor.run {
                 self.transcriptionResult = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
                 self.isTranscribing = false
             }
         } catch {
             print("WhisperManager Error: Live transcription failed: \(error.localizedDescription)")
             cancelPtr.deallocate()
             self.currentCancellationPointer = nil
             
             await MainActor.run {
                 self.statusMessage = "Live transcription failed: \(error.localizedDescription)"
                 self.isTranscribing = false
             }
         }
     }
     
     func cancelCurrentTranscription() {
         if let ptr = currentCancellationPointer {
             ptr.pointee = true
             currentCancellationPointer = nil
             print("WhisperManager: Signaled cancellation to active transcription.")
         }
     }
     
     func clearResult() {
         transcriptionResult = ""
     }
 }
