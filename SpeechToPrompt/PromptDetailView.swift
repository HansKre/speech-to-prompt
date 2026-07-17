import SwiftUI
import Combine

struct PromptDetailView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var diagnosticsManager: DiagnosticsManager

    @Binding var showSettings: Bool
    @Binding var showDiagnostics: Bool

    @State private var copyFeedback = false
    @State private var copyRefinedFeedback = false
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var saveCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(nsColor: .windowBackgroundColor).opacity(0.85), Color(nsColor: .underPageBackgroundColor)],
                center: .center,
                startRadius: 20,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                Divider().opacity(0.2)

                if !modelManager.isDownloaded {
                    modelDownloadView
                } else {
                    mainConsoleView
                }
            }
            .padding(30)
        }
        .onChange(of: projectStore.selectedPromptID) { oldID, _ in
            handlePromptSwitch(oldPromptID: oldID)
        }
        .onAppear {
            loadCurrentPrompt()
            setupTranscriptionObserver()
        }
        .onDisappear {
            saveCurrentPrompt()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(projectStore.selectedPrompt?.name ?? "Prompt")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if modelManager.isDownloaded {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Whisper Large v3 Turbo (Metal)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()

            if modelManager.isDownloaded {
                HStack(spacing: 8) {
                    ActionIconButton(icon: "gearshape.fill", tooltip: "Settings") {
                        showSettings = true
                    }
                    ActionIconButton(icon: "terminal.fill", tooltip: "Diagnostics") {
                        showDiagnostics = true
                    }
                }
            }
        }
    }

    // MARK: - Model Download View

    private var modelDownloadView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce.up.byLayer, options: .repeating, value: modelManager.isDownloading)

            VStack(spacing: 8) {
                Text("Local Model Required")
                    .font(.title2.bold())
                Text("Whisper Large v3 Turbo (~1.5 GB) will be saved to your local Application Support directory for fast, offline transcription.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if modelManager.isDownloading {
                VStack(spacing: 12) {
                    ProgressView(value: modelManager.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.purple)
                        .padding(.horizontal, 40)

                    HStack {
                        Text(String(format: "%.0f%%", modelManager.progress * 100))
                            .bold()
                        Spacer()
                        Text(modelManager.downloadSpeed)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("ETA: \(modelManager.timeRemaining)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 40)

                    Button(action: { modelManager.cancelDownload() }) {
                        Text("Cancel Download")
                            .font(.body.bold())
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 12) {
                    if let err = modelManager.errorMessage {
                        Text("Error: \(err)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { modelManager.startDownload() }) {
                        Text("Download Model")
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(10)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    // MARK: - Main Console

    private var mainConsoleView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .stroke(Color.purple.opacity(audioManager.isRecording ? 0.3 : 0.1), lineWidth: 2)
                                .frame(width: 100, height: 100)
                                .scaleEffect(audioManager.isRecording ? CGFloat(1.0 + audioManager.audioLevel * 0.4) : 1.0)
                                .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: audioManager.isRecording ? [.red, .orange] : [.purple, .indigo],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: (audioManager.isRecording ? Color.red : Color.purple).opacity(0.4), radius: 10, x: 0, y: 6)

                            Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .tooltip(audioManager.isRecording ? "Stop Recording (⌘R)" : "Start Recording (⌘R)")

                    Text(audioManager.isRecording ? formatDuration(audioManager.recordingDuration) : "Ready")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(audioManager.isRecording ? .red : .secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if audioManager.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(audioManager.recordingDuration.truncatingRemainder(dividingBy: 2) == 0 ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.5), value: audioManager.recordingDuration)
                            Text("Recording...")
                                .font(.body)
                                .foregroundColor(.red)

                            if whisperManager.isTranscribing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                            }
                        }
                    } else if whisperManager.isTranscribing || whisperManager.isProcessingFinalAudio {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text(whisperManager.statusMessage)
                                .font(.body)
                                .italic()
                        }
                    } else {
                        Text("Click the microphone to start recording.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if !audioManager.permissionGranted {
                        Text("⚠️ Microphone access denied. Check System Settings.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            transcriptionArea
        }
    }

    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(llmManager.improvedPrompt != nil ? "Transcription Panels" : "Transcription")
                    .font(.headline)
                Spacer()

                if !whisperManager.transcriptionResult.isEmpty {
                    if !audioManager.isRecording && !whisperManager.isTranscribing && !whisperManager.isProcessingFinalAudio {
                        Button(action: {
                            Task {
                                await llmManager.improvePrompt(text: whisperManager.transcriptionResult)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if llmManager.state.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(llmManager.state.isLoading ? "Improving..." : "Improve with AI")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(llmManager.state.isLoading)
                        .tooltip("Refine transcription with AI")
                    }

                    Button(action: {
                        whisperManager.clearResult()
                        llmManager.clearImprovedPrompt()
                    }) {
                        Text("Clear All")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Clear transcription and AI result")
                }
            }

            if llmManager.improvedPrompt != nil {
                dualPanelView
            } else if case .loading = llmManager.state {
                loadingPanelView
            } else if case .failure(let errorMsg) = llmManager.state {
                errorPanelView(errorMsg: errorMsg)
            } else {
                singlePanelView
            }
        }
    }

    // MARK: - Panel Views

    private var dualPanelView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Raw Speech")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copyFeedback ? "Copied!" : "Copy Raw")
                        }
                        .foregroundColor(copyFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Copy raw transcription to clipboard")
                }

                TextEditor(text: $whisperManager.transcriptionResult)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Refined Prompt (AI)")
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                    Spacer()
                    Button(action: copyRefinedToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyRefinedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copyRefinedFeedback ? "Copied!" : "Copy Improved")
                        }
                        .foregroundColor(copyRefinedFeedback ? .green : .purple)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Copy AI-improved text to clipboard")
                }

                TextEditor(text: Binding<String>(
                    get: { llmManager.improvedPrompt ?? "" },
                    set: { llmManager.improvedPrompt = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var loadingPanelView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Raw Speech")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copyFeedback ? "Copied!" : "Copy Raw")
                        }
                        .foregroundColor(copyFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Copy raw transcription to clipboard")
                }

                TextEditor(text: $whisperManager.transcriptionResult)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Text("Refining prompt with Azure OpenAI...")
                    .font(.body.italic())
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func errorPanelView(errorMsg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("AI Refinement Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
                Button("Dismiss") {
                    llmManager.clearImprovedPrompt()
                }
                .buttonStyle(.borderless)
                .tooltip("Dismiss error")
            }

            Text(errorMsg)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)

            if llmManager.configError != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Please configure `config.json` at either path:")
                        .font(.caption.bold())
                    Text("• `~/Library/Application Support/SpeechToPrompt/config.json` (Recommended)")
                        .font(.caption)
                    Text("• Inside the app bundle resources")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Raw Speech")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copyFeedback ? "Copied!" : "Copy Raw")
                        }
                        .foregroundColor(copyFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Copy raw transcription to clipboard")
                }

                TextEditor(text: $whisperManager.transcriptionResult)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var singlePanelView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Raw Speech")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if !whisperManager.transcriptionResult.isEmpty {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copyFeedback ? "Copied!" : "Copy Raw")
                        }
                        .foregroundColor(copyFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .tooltip("Copy raw transcription to clipboard")
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $whisperManager.transcriptionResult)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(8)

                if whisperManager.transcriptionResult.isEmpty {
                    Text("No transcription yet. Speak into your microphone and click stop, or type your prompt here...")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Logic

    private func toggleRecording() {
        if audioManager.isRecording {
            transcriptionTask?.cancel()
            transcriptionTask = nil

            whisperManager.isProcessingFinalAudio = true
            whisperManager.statusMessage = "Preparing transcription..."

            guard let url = audioManager.stopRecording() else {
                whisperManager.isProcessingFinalAudio = false
                whisperManager.statusMessage = ""
                return
            }
            Task {
                await whisperManager.transcribeAudio(fileURL: url, modelURL: modelManager.localModelURL)
            }
        } else {
            whisperManager.startNewSession()
            audioManager.startRecording()
            startLiveTranscriptionLoop()
        }
    }

    private func startLiveTranscriptionLoop() {
        transcriptionTask = Task {
            try? await Task.sleep(for: .seconds(1.0))

            var lastTranscribedSampleCount = 0

            while !Task.isCancelled && audioManager.isRecording {
                let currentSamples = audioManager.recordedSamples

                if currentSamples.count > lastTranscribedSampleCount + 8000 {
                    lastTranscribedSampleCount = currentSamples.count
                    await whisperManager.transcribeLive(samples: currentSamples, modelURL: modelManager.localModelURL)
                }

                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(whisperManager.transcriptionResult, forType: .string)

        withAnimation { copyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFeedback = false }
        }
    }

    private func copyRefinedToClipboard() {
        guard let improved = llmManager.improvedPrompt else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(improved, forType: .string)

        withAnimation { copyRefinedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyRefinedFeedback = false }
        }
    }

    // MARK: - Prompt Data Sync

    private func handlePromptSwitch(oldPromptID: UUID?) {
        projectStore.updatePromptTranscription(
            promptID: oldPromptID,
            rawText: whisperManager.transcriptionResult,
            refinedText: llmManager.improvedPrompt
        )
        loadCurrentPrompt()
    }

    private func loadCurrentPrompt() {
        guard let prompt = projectStore.selectedPrompt else { return }
        whisperManager.transcriptionResult = prompt.rawTranscription
        if let refined = prompt.refinedPrompt, !refined.isEmpty {
            llmManager.improvedPrompt = refined
        } else {
            llmManager.clearImprovedPrompt()
        }
    }

    private func saveCurrentPrompt() {
        projectStore.updatePromptTranscription(
            rawText: whisperManager.transcriptionResult,
            refinedText: llmManager.improvedPrompt
        )
    }

    private func setupTranscriptionObserver() {
        let store = projectStore
        let whisper = whisperManager
        let llm = llmManager
        saveCancellable = whisper.$transcriptionResult
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                store.updatePromptTranscription(
                    rawText: whisper.transcriptionResult,
                    refinedText: llm.improvedPrompt
                )
            }
    }
}

private struct ActionIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(isHovered ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .tooltip(tooltip)
    }
}
