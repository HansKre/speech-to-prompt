import Foundation
import whisper

class Whisper {
    private let ctx: OpaquePointer?
    
    init(fromFileURL fileURL: URL) throws {
        let modelPath = fileURL.path
        let params = whisper_context_default_params()
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw NSError(
                domain: "Whisper", 
                code: 1, 
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize Whisper context from model file."]
            )
        }
        self.ctx = ctx
    }
    
    deinit {
        if let ctx = ctx {
            whisper_free(ctx)
        }
    }
    
    func transcribe(audioFrames: [Float], isCancelled: UnsafePointer<Bool>? = nil) async throws -> String {
        guard let ctx = ctx else {
            throw NSError(
                domain: "Whisper", 
                code: 2, 
                userInfo: [NSLocalizedDescriptionKey: "Whisper context was deallocated."]
            )
        }
        
        return try await Task.detached(priority: .userInitiated) {
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
            params.print_progress = false
            params.print_realtime = false
            params.print_special = false
            params.print_timestamps = false
            
            if let isCancelled = isCancelled {
                let callback: @convention(c) (UnsafeMutableRawPointer?) -> Bool = { userData in
                    guard let userData = userData else { return false }
                    return userData.assumingMemoryBound(to: Bool.self).pointee
                }
                params.abort_callback = callback
                params.abort_callback_user_data = UnsafeMutableRawPointer(mutating: isCancelled)
            }
            
            // Set language to auto-detect safely
            return try "auto".withCString { langPtr in
                params.language = langPtr
                
                let result = audioFrames.withUnsafeBufferPointer { buffer in
                    whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
                }
                
                if result != 0 {
                    throw NSError(
                        domain: "Whisper", 
                        code: 3, 
                        userInfo: [NSLocalizedDescriptionKey: "Whisper inference failed with code \(result)."]
                    )
                }
                
                var transcription = ""
                let nSegments = whisper_full_n_segments(ctx)
                for i in 0..<nSegments {
                    if let segmentText = whisper_full_get_segment_text(ctx, i) {
                        transcription += String(cString: segmentText)
                    }
                }
                return transcription
            }
        }.value
    }
}
