import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var whisperManager: WhisperManager
    @AppStorage("autoRefineSetting") private var autoRefine = false
    @AppStorage("autoTranslateSetting") private var autoTranslate = false

    let onStop: () -> Void

    private var isRecording: Bool { audioManager.isRecording }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                stateIndicator
                    .frame(height: 80)

                if isRecording {
                    waveformView

                    stopButton

                    autoRefineToggle

                    autoTranslateToggle
                }
            }
            .padding(40)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                NSCursor.arrow.set()
            case .ended:
                break
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stateIndicator: some View {
        if isRecording {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(audioManager.recordingDuration.truncatingRemainder(dividingBy: 2) < 1 ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: audioManager.recordingDuration)

                    Text("Recording")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                Text(formatDuration(audioManager.recordingDuration))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        } else {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text(whisperManager.statusMessage.contains("Translating")
                     ? "Translating to English..."
                     : "Transcribing with Metal GPU...")
                    .font(.headline)
                    .foregroundColor(.white)

                if !whisperManager.statusMessage.contains("Translating") {
                    Text(whisperManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var waveformView: some View {
        let samples = audioManager.recordedSamples
        let barCount = 60
        let displaySamples: [Float] = {
            guard !samples.isEmpty else { return Array(repeating: 0, count: barCount) }
            let chunkSize = max(1, samples.count / barCount)
            return (0..<barCount).map { i in
                let start = i * chunkSize
                let end = min(start + chunkSize, samples.count)
                guard start < end else { return 0 }
                let chunk = samples[start..<end]
                let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
                return min(rms * 12.0, 1.0)
            }
        }()

        return HStack(spacing: 2) {
            ForEach(Array(displaySamples.enumerated()), id: \.offset) { _, height in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: CGFloat(max(4, height * 80)))
            }
        }
        .frame(height: 80)
        .animation(.easeOut(duration: 0.15), value: audioManager.recordedSamples.count)
    }

    private var stopButton: some View {
        Button(action: onStop) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Stop Recording")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .keyboardShortcut("r", modifiers: .command)
    }

    private var autoRefineToggle: some View {
        Button(action: { autoRefine.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                Text("Auto Refine")
                    .font(.subheadline)
            }
            .foregroundColor(autoRefine ? .purple : .secondary)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .tooltip(autoRefine ? "AI will refine recording" : "AI refinement manual")
    }

    private var autoTranslateToggle: some View {
        Button(action: { autoTranslate.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 14))
                Text("Auto Translate")
                    .font(.subheadline)
            }
            .foregroundColor(autoTranslate ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .tooltip(autoTranslate ? "Auto-translate to English enabled" : "Auto-translate to English disabled")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
