import AVFoundation

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var permissionGranted = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?
    private var durationTimer: Timer?
    
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
        checkMicrophonePermission()
        guard permissionGranted else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        guard let url = recordingURL else { return }
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingDuration = 0.0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                let level = max(0, (db + 50) / 50)
                self.audioLevel = level
            }
            
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 1.0
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        timer?.invalidate()
        durationTimer?.invalidate()
        timer = nil
        durationTimer = nil
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0.0
        return recordingURL
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
