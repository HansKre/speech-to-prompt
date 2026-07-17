import AVFoundation

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var permissionGranted = false
    @Published var recordedSamples: [Float] = []
    
    private var audioEngine: AVAudioEngine?
    private var audioConverter: AVAudioConverter?
    private var recordingURL: URL?
    private var durationTimer: Timer?
    
    private let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    override init() {
        super.init()
        self.recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        checkMicrophonePermission()
    }
    
    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    func startRecording() {
        print("AudioManager: startRecording called")
        checkMicrophonePermission()
        guard permissionGranted else {
            print("AudioManager Error: Microphone permission not granted")
            return
        }
        
        SpotifyManager.shared.pausePlaybackIfNeeded()
        
        recordedSamples = []
        audioLevel = 0.0
        recordingDuration = 0.0
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            print("AudioManager Error: Could not initialize AVAudioEngine")
            SpotifyManager.shared.resumePlaybackIfNeeded()
            return
        }
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("AudioManager: Microphone outputFormat = \(inputFormat)")
        guard inputFormat.sampleRate > 0 else {
            print("AudioManager Error: Microphone outputFormat sample rate is 0.0")
            SpotifyManager.shared.resumePlaybackIfNeeded()
            return
        }
        
        audioConverter = AVAudioConverter(from: inputFormat, to: whisperFormat)
        if audioConverter == nil {
            print("AudioManager Error: Could not create AVAudioConverter from \(inputFormat) to \(whisperFormat)")
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        print("AudioManager: Tap installed successfully")
        
        do {
            try engine.start()
            print("AudioManager: Audio Engine started successfully")
            isRecording = true
            
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 1.0
            }
        } catch {
            print("AudioManager Error: Failed to start audio engine: \(error)")
            SpotifyManager.shared.resumePlaybackIfNeeded()
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }
        
        let ratio = 16000.0 / buffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: targetCapacity) else { return }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        _ = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("AudioManager Error: Audio conversion failed: \(error)")
            return
        }
        
        guard convertedBuffer.frameLength > 0, let floatChannelData = convertedBuffer.floatChannelData else { return }
        let frameCount = Int(convertedBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.recordedSamples.append(contentsOf: samples)
            print("AudioManager: Appended \(samples.count) samples (Total: \(self.recordedSamples.count))")
            
            // Calculate audio level (RMS)
            var sum: Float = 0.0
            for sample in samples {
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(samples.count))
            self.audioLevel = min(1.0, rms * 5.0)
        }
    }
    
    func stopRecording() -> URL? {
        print("AudioManager: stopRecording called")
        durationTimer?.invalidate()
        durationTimer = nil
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioConverter = nil
        
        isRecording = false
        audioLevel = 0.0
        
        saveRecordedSamplesToDisk()
        SpotifyManager.shared.resumePlaybackIfNeeded()
        return recordingURL
    }
    
    private func saveRecordedSamplesToDisk() {
        guard let url = recordingURL, !recordedSamples.isEmpty else { return }
        print("AudioManager: Saving \(recordedSamples.count) samples to disk: \(url.path)")
        do {
            let file = try AVAudioFile(forWriting: url, settings: whisperFormat.settings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: AVAudioFrameCount(recordedSamples.count)) else { return }
            buffer.frameLength = AVAudioFrameCount(recordedSamples.count)
            if let floatChannelData = buffer.floatChannelData {
                for i in 0..<recordedSamples.count {
                    floatChannelData[0][i] = recordedSamples[i]
                }
            }
            try file.write(from: buffer)
            print("AudioManager: Saved WAV successfully")
        } catch {
            print("AudioManager Error: Failed to save audio samples: \(error)")
        }
    }
    
    static func loadAudioData(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAudioPCMBuffer"])
        }
        
        try file.read(into: buffer)
        
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio file contains no float data"])
        }
        
        let frameCount = Int(buffer.frameLength)
        let frames = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
        return frames
    }
}
