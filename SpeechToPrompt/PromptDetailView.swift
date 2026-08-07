import SwiftUI
import Combine

struct PromptDetailView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var diagnosticsManager: DiagnosticsManager
    @ObservedObject var attachmentManager: AttachmentManager

    @Binding var showSettings: Bool
    @Binding var showDiagnostics: Bool

    @AppStorage("pauseSpotifySetting") private var pauseSpotify = true
    @AppStorage("autoRefineSetting") private var autoRefine = false
    @AppStorage("autoTranslateSetting") private var autoTranslate = false
    @State private var copyFeedback = false
    @State private var copyRefinedFeedback = false
    @State private var copyRawURLFeedback = false
    @State private var copyRefinedURLFeedback = false
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var stoppingInternally = false
    @State private var rawSaveCancellable: AnyCancellable?
    @State private var refinedSaveCancellable: AnyCancellable?

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

                if modelManager.isDownloaded {
                    controlsRow
                }

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
        .onChange(of: audioManager.isRecording) { wasRecording, isRecording in
            if wasRecording && !isRecording && !stoppingInternally {
                handleRecordingStopped()
            }
        }
        .onAppear {
            attachmentManager.projectStore = projectStore
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

                if let prompt = projectStore.selectedPrompt {
                    Text("Created \(prompt.createdAt.formatted(date: .abbreviated, time: .shortened)) · Updated \(prompt.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            if modelManager.isDownloaded {
                HStack(spacing: 12) {
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

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Button(action: toggleRecording) {
                HStack(spacing: 4) {
                    Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                    Text(audioManager.isRecording ? "Stop" : "Record")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(audioManager.isRecording ? .red : .purple)
            .pointerOnHover()
            .keyboardShortcut("r", modifiers: .command)
            .tooltip(audioManager.isRecording ? "Stop Recording (⌘R)" : "Start Recording (⌘R)")

            Button(action: {
                guard let projectID = projectStore.selectedProjectID,
                      let promptID = projectStore.selectedPromptID else { return }
                projectStore.togglePromptDone(projectID: projectID, promptID: promptID)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: projectStore.selectedPrompt?.isDone == true ? "checkmark.square.fill" : "square")
                    Text("Done")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(projectStore.selectedPrompt?.isDone == true ? .green : .gray)
            .pointerOnHover()
            .tooltip(projectStore.selectedPrompt?.isDone == true ? "Mark as To Do" : "Mark as Done")

            Button(action: { pauseSpotify.toggle() }) {
                Image(systemName: pauseSpotify ? "pause.circle.fill" : "pause.circle")
                    .font(.system(size: 18))
                    .foregroundColor(pauseSpotify ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .tooltip(pauseSpotify ? "Spotify will pause during recording" : "Spotify will keep playing during recording")

            Button(action: { autoRefine.toggle() }) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18))
                    .foregroundColor(autoRefine ? .purple : .secondary)
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .tooltip(autoRefine ? "AI will refine after recording" : "AI refinement is manual")

            Button(action: { autoTranslate.toggle() }) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 18))
                    .foregroundColor(autoTranslate ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .tooltip(autoTranslate ? "Auto-translate to English enabled" : "Auto-translate to English disabled")

            Spacer()
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
                    .pointerOnHover()
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
                    .pointerOnHover()
                }
            }
            Spacer()
        }
    }

    // MARK: - Main Console

    private var mainConsoleView: some View {
        VStack(spacing: 16) {
            if !audioManager.permissionGranted {
                Text("Microphone access denied. Check System Settings.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
            }

            transcriptionArea
        }
    }


    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !whisperManager.transcriptionResult.isEmpty {
                    if !whisperManager.isTranscribing && !whisperManager.isProcessingFinalAudio {
                        Button(action: {
                            Task {
                                await llmManager.improvePrompt(text: whisperManager.transcriptionResult)
                                if llmManager.improvedPrompt != nil {
                                    projectStore.updatePromptTranscription(
                                        rawText: whisperManager.transcriptionResult,
                                        refinedText: llmManager.improvedPrompt
                                    )
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                if llmManager.state.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(llmManager.state.isLoading ? "Refining..." : "Refine with AI")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .pointerOnHover()
                        .tint(.purple)
                        .disabled(llmManager.state.isLoading)
                        .tooltip("Refine transcription with AI")
                    }

                    Spacer()

                    Button(action: {
                        whisperManager.clearResult()
                        llmManager.clearImprovedPrompt()
                    }) {
                        Text("Clear All")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Clear transcription and AI result")
                }
            }

            if llmManager.improvedPrompt != nil || llmManager.state.isLoading {
                dualPanelView
            } else if case .failure(let errorMsg) = llmManager.state {
                errorPanelView(errorMsg: errorMsg)
            } else {
                singlePanelView
            }

        }
    }

    // MARK: - Panel Views

    private var dualPanelView: some View {
        VStack(spacing: 16) {
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
                    .pointerOnHover()
                    .tooltip("Copy raw transcription to clipboard")
                    Button(action: copyRawURLToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyRawURLFeedback ? "checkmark.circle.fill" : "link")
                            Text(copyRawURLFeedback ? "Copied!" : "Copy URL")
                        }
                        .foregroundColor(copyRawURLFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Copy file path to clipboard")
                    Button(action: openRawFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Open in system editor")
                    Button(action: showRawFileInFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Finder")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Reveal in Finder")
                }

                VStack(spacing: 0) {
                    PastableTextView(
                        text: $whisperManager.transcriptionResult,
                        onPasteAttachments: { ctx in handlePasteRaw(context: ctx) },
                        onPasteTextFile: { item, cursor, decision in handleTextFilePaste(item: item, cursor: cursor, decision: decision) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AttachmentChipsView(
                        attachments: attachmentManager.attachments,
                        onDelete: { id in handleDeleteAttachment(id: id) },
                        onTap: { attachment in openAttachment(attachment) }
                    )
                }
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
                            Text(copyRefinedFeedback ? "Copied!" : "Copy Refined")
                        }
                        .foregroundColor(copyRefinedFeedback ? .green : .purple)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Copy refined text to clipboard")
                    Button(action: copyRefinedURLToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyRefinedURLFeedback ? "checkmark.circle.fill" : "link")
                            Text(copyRefinedURLFeedback ? "Copied!" : "Copy URL")
                        }
                        .foregroundColor(copyRefinedURLFeedback ? .green : .purple)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Copy file path to clipboard")
                    Button(action: openRefinedFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open")
                        }
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Open in system editor")
                    Button(action: showRefinedFileInFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Finder")
                        }
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Reveal in Finder")
                }

                VStack(spacing: 0) {
                    PastableTextView(
                        text: Binding<String>(
                            get: { llmManager.improvedPrompt ?? "" },
                            set: { llmManager.improvedPrompt = $0 }
                        ),
                        isEditable: !llmManager.state.isLoading,
                        onPasteAttachments: { ctx in handlePasteRefined(context: ctx) },
                        onPasteTextFile: { item, cursor, decision in handleTextFilePaste(item: item, cursor: cursor, decision: decision) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AttachmentChipsView(
                        attachments: attachmentManager.attachments,
                        onDelete: { id in handleDeleteAttachment(id: id) },
                        onTap: { attachment in openAttachment(attachment) }
                    )
                }
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
                .overlay {
                    if llmManager.state.isLoading {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.03))
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Refining...")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
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
                .pointerOnHover()
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
                    .pointerOnHover()
                    .tooltip("Copy raw transcription to clipboard")
                    Button(action: copyRawURLToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyRawURLFeedback ? "checkmark.circle.fill" : "link")
                            Text(copyRawURLFeedback ? "Copied!" : "Copy URL")
                        }
                        .foregroundColor(copyRawURLFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Copy file path to clipboard")
                    Button(action: openRawFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Open in system editor")
                    Button(action: showRawFileInFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Finder")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Reveal in Finder")
                }

                VStack(spacing: 0) {
                    PastableTextView(
                        text: $whisperManager.transcriptionResult,
                        onPasteAttachments: { ctx in handlePasteRaw(context: ctx) },
                        onPasteTextFile: { item, cursor, decision in handleTextFilePaste(item: item, cursor: cursor, decision: decision) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AttachmentChipsView(
                        attachments: attachmentManager.attachments,
                        onDelete: { id in handleDeleteAttachment(id: id) },
                        onTap: { attachment in openAttachment(attachment) }
                    )
                }
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
                    .pointerOnHover()
                    .tooltip("Copy raw transcription to clipboard")
                    Button(action: copyRawURLToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copyRawURLFeedback ? "checkmark.circle.fill" : "link")
                            Text(copyRawURLFeedback ? "Copied!" : "Copy URL")
                        }
                        .foregroundColor(copyRawURLFeedback ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Copy file path to clipboard")
                    Button(action: openRawFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Open in system editor")
                    Button(action: showRawFileInFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Finder")
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    .pointerOnHover()
                    .tooltip("Reveal in Finder")
                }
            }

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    PastableTextView(
                        text: $whisperManager.transcriptionResult,
                        onPasteAttachments: { ctx in handlePasteRaw(context: ctx) },
                        onPasteTextFile: { item, cursor, decision in handleTextFilePaste(item: item, cursor: cursor, decision: decision) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if whisperManager.transcriptionResult.isEmpty {
                        Text("No transcription yet. Speak into your microphone and click stop, or type your prompt here...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal, 12)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

                AttachmentChipsView(
                    attachments: attachmentManager.attachments,
                    onDelete: { id in handleDeleteAttachment(id: id) },
                    onTap: { attachment in openAttachment(attachment) }
                )
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
            stoppingInternally = true
            transcriptionTask?.cancel()
            transcriptionTask = nil

            whisperManager.isProcessingFinalAudio = true
            whisperManager.statusMessage = "Preparing transcription..."

            guard let url = audioManager.stopRecording() else {
                whisperManager.isProcessingFinalAudio = false
                whisperManager.statusMessage = ""
                stoppingInternally = false
                return
            }
            Task {
                await whisperManager.transcribeAudio(fileURL: url, modelURL: modelManager.localModelURL)
                stoppingInternally = false
                if autoTranslate && !whisperManager.transcriptionResult.isEmpty {
                    whisperManager.statusMessage = "Translating to English..."
                    let translated = await llmManager.translateToEnglish(text: whisperManager.transcriptionResult)
                    whisperManager.transcriptionResult = translated
                    whisperManager.statusMessage = ""
                }
                whisperManager.isProcessingFinalAudio = false
                if autoRefine && !whisperManager.transcriptionResult.isEmpty {
                    await llmManager.improvePrompt(text: whisperManager.transcriptionResult)
                }
            }
        } else {
            whisperManager.startNewSession()
            audioManager.startRecording()
            startLiveTranscriptionLoop()
        }
    }

    private func handleRecordingStopped() {
        transcriptionTask?.cancel()
        transcriptionTask = nil

        whisperManager.isProcessingFinalAudio = true
        whisperManager.statusMessage = "Preparing transcription..."

        guard let url = audioManager.recordingURL else {
            whisperManager.isProcessingFinalAudio = false
            whisperManager.statusMessage = ""
            return
        }
        Task {
            await whisperManager.transcribeAudio(fileURL: url, modelURL: modelManager.localModelURL)
            if autoTranslate && !whisperManager.transcriptionResult.isEmpty {
                whisperManager.statusMessage = "Translating to English..."
                let translated = await llmManager.translateToEnglish(text: whisperManager.transcriptionResult)
                whisperManager.transcriptionResult = translated
                whisperManager.statusMessage = ""
            }
            whisperManager.isProcessingFinalAudio = false
            if autoRefine && !whisperManager.transcriptionResult.isEmpty {
                await llmManager.improvePrompt(text: whisperManager.transcriptionResult)
            }
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

    private func copyRawURLToClipboard() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .raw)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(url.path, forType: .string)

        withAnimation { copyRawURLFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyRawURLFeedback = false }
        }
    }

    private func copyRefinedURLToClipboard() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .refined)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(url.path, forType: .string)

        withAnimation { copyRefinedURLFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyRefinedURLFeedback = false }
        }
    }

    private func openRawFile() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .raw)
        NSWorkspace.shared.open(url)
    }

    private func openRefinedFile() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .refined)
        NSWorkspace.shared.open(url)
    }

    private func showRawFileInFinder() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .raw)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func showRefinedFileInFinder() {
        guard let projectID = projectStore.selectedProjectID,
              let promptID = projectStore.selectedPromptID else { return }
        let url = projectStore.promptFileURL(projectID: projectID, promptID: promptID, type: .refined)
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
        guard let prompt = projectStore.selectedPrompt,
              let projectID = projectStore.selectedProjectID else { return }
        whisperManager.transcriptionResult = prompt.rawTranscription
        if let refined = prompt.refinedPrompt, !refined.isEmpty {
            llmManager.improvedPrompt = refined
        } else {
            llmManager.clearImprovedPrompt()
        }
        attachmentManager.loadAttachments(for: prompt, projectID: projectID, promptID: prompt.id)
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

        rawSaveCancellable = whisper.$transcriptionResult
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                store.updatePromptTranscription(
                    rawText: whisper.transcriptionResult,
                    refinedText: llm.improvedPrompt
                )
            }

        refinedSaveCancellable = llm.$improvedPrompt
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                store.updatePromptTranscription(
                    rawText: whisper.transcriptionResult,
                    refinedText: llm.improvedPrompt
                )
            }
    }

    private func handlePasteRaw(context: PasteContext) {
        for item in context.items {
            guard let attachment = attachmentManager.addAttachment(data: item.data, filename: item.filename, kind: item.kind) else { continue }
            let ref = attachmentManager.referenceString(for: attachment)
            let text = whisperManager.transcriptionResult
            let insertAt = min(context.cursorPosition, text.count)
            let idx = text.index(text.startIndex, offsetBy: insertAt)
            whisperManager.transcriptionResult.insert(contentsOf: "\n\(ref)\n", at: idx)
        }
    }

    private func handlePasteRefined(context: PasteContext) {
        for item in context.items {
            guard let attachment = attachmentManager.addAttachment(data: item.data, filename: item.filename, kind: item.kind) else { continue }
            let ref = attachmentManager.referenceString(for: attachment)
            var text = llmManager.improvedPrompt ?? ""
            let insertAt = min(context.cursorPosition, text.count)
            let idx = text.index(text.startIndex, offsetBy: insertAt)
            text.insert(contentsOf: "\n\(ref)\n", at: idx)
            llmManager.improvedPrompt = text
        }
    }

    private func handleTextFilePaste(item: PastedItem, cursor: Int, decision: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Paste as attachment?"
        alert.informativeText = "Do you want to attach \"\(item.filename)\" as a file, or paste its content as text?"
        alert.addButton(withTitle: "Attach as File")
        alert.addButton(withTitle: "Paste as Text")
        alert.alertStyle = .informational

        let response = alert.runModal()
        decision(response == .alertFirstButtonReturn)
    }

    private func handleDeleteAttachment(id: UUID) {
        var raw = whisperManager.transcriptionResult
        var refined = llmManager.improvedPrompt
        attachmentManager.removeAttachment(id: id, rawText: &raw, refinedText: &refined)
        whisperManager.transcriptionResult = raw
        llmManager.improvedPrompt = refined
    }

    private func openAttachment(_ attachment: Attachment) {
        guard let url = attachmentManager.attachmentFileURL(for: attachment) else { return }
        NSWorkspace.shared.open(url)
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
        .pointerOnHover()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .tooltip(tooltip)
    }
}
