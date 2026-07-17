import SwiftUI

struct ContentView: View {
    @StateObject private var modelManager = ModelManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var whisperManager = WhisperManager()
    @StateObject private var diagnosticsManager = DiagnosticsManager.shared
    @StateObject private var llmManager = LLMManager()
    
    @State private var copyFeedback = false
    @State private var copyRefinedFeedback = false
    @State private var transcriptionTask: Task<Void, Never>? = nil
    @State private var showDiagnostics = false
    
    @State private var showSettings = false
    @State private var apiTypeSetting = "azure"
    @State private var apiUrlSetting = ""
    @State private var apiKeySetting = ""
    @State private var modelSetting = ""
    @State private var apiVersionSetting = "2024-10-21"
    @State private var pauseSpotifySetting = true
    
    var body: some View {
        ZStack {
            // Dark radial background
            RadialGradient(
                colors: [Color(nsColor: .windowBackgroundColor).opacity(0.85), Color(nsColor: .underPageBackgroundColor)],
                center: .center,
                startRadius: 20,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speech to Prompt")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
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
                        } else {
                            HStack(spacing: 6) {
                                Circle().fill(Color.yellow).frame(width: 8, height: 8)
                                Text("Model Required")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    
                    if modelManager.isDownloaded {
                        HStack(spacing: 8) {
                            Button(action: { showSettings = true }) {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button(action: { showDiagnostics = true }) {
                                Label("Diagnostics", systemImage: "terminal.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider().opacity(0.2)
                
                if !modelManager.isDownloaded {
                    // Download View
                    modelDownloadView
                } else {
                    // Recording and Transcription View
                    mainConsoleView
                }
            }
            .padding(30)
        }
        .frame(minWidth: llmManager.improvedPrompt != nil || llmManager.state.isLoading ? 850 : 550, minHeight: 480)
        .sheet(isPresented: $showDiagnostics) {
            diagnosticsView
        }
        .sheet(isPresented: $showSettings) {
            settingsView
        }
    }
    
    // MARK: - Model Download View
    var modelDownloadView: some View {
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
                    
                    Button(action: {
                        modelManager.cancelDownload()
                    }) {
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
                    
                    Button(action: {
                        modelManager.startDownload()
                    }) {
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
    
    // MARK: - Main Application Console
    var mainConsoleView: some View {
        VStack(spacing: 24) {
            // Audio recording state
            HStack(spacing: 40) {
                // Record Button & Equalizer animation
                VStack(spacing: 12) {
                    Button(action: toggleRecording) {
                        ZStack {
                            // Pulsing background rings
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
                    
                    Text(audioManager.isRecording ? formatDuration(audioManager.recordingDuration) : "Ready")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(audioManager.isRecording ? .red : .secondary)
                }
                
                // Transcription status & info
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
            
            // Transcription display area
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(llmManager.improvedPrompt != nil ? "Transcription Panels" : "Transcription")
                        .font(.headline)
                    Spacer()
                    
                    if !whisperManager.transcriptionResult.isEmpty {
                        // Improve with AI Button
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
                        }
                        
                        Button(action: {
                            whisperManager.clearResult()
                            llmManager.clearImprovedPrompt()
                        }) {
                            Text("Clear All")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                if llmManager.improvedPrompt != nil {
                    HStack(spacing: 16) {
                        // Left Panel: Raw transcription
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
                        
                        // Right Panel: Refined prompt
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
                } else if case .loading = llmManager.state {
                    HStack(spacing: 16) {
                        // Left Panel: Raw
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
                        
                        // Right Panel: Loading indicator
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
                } else if case .failure(let errorMsg) = llmManager.state {
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
                        
                        // Raw transcription
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
                } else {
                    // Regular transcription view
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
            }
        }
    }
    
    // MARK: - Logic Helpers
    func toggleRecording() {
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
    
    func startLiveTranscriptionLoop() {
        print("ContentView: startLiveTranscriptionLoop started")
        transcriptionTask = Task {
            // Wait for some initial audio to accumulate
            try? await Task.sleep(for: .seconds(1.0))
            
            var lastTranscribedSampleCount = 0
            
            while !Task.isCancelled && audioManager.isRecording {
                let currentSamples = audioManager.recordedSamples
                print("ContentView Live Loop: Samples count = \(currentSamples.count), Last count = \(lastTranscribedSampleCount)")
                
                // Only transcribe if we have new samples (e.g., at least 0.5s of new audio)
                // 16000 samples = 1 second
                if currentSamples.count > lastTranscribedSampleCount + 8000 {
                    lastTranscribedSampleCount = currentSamples.count
                    print("ContentView Live Loop: Requesting live transcription with \(currentSamples.count) samples")
                    await whisperManager.transcribeLive(samples: currentSamples, modelURL: modelManager.localModelURL)
                }
                
                // Check/poll every 1 second
                try? await Task.sleep(for: .seconds(1.0))
            }
            print("ContentView: startLiveTranscriptionLoop finished/cancelled")
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(whisperManager.transcriptionResult, forType: .string)
        
        withAnimation {
            copyFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copyFeedback = false
            }
        }
    }
    
    func copyRefinedToClipboard() {
        guard let improved = llmManager.improvedPrompt else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(improved, forType: .string)
        
        withAnimation {
            copyRefinedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copyRefinedFeedback = false
            }
        }
    }
    
    // MARK: - Diagnostics View Sheet
    var diagnosticsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("System Diagnostics")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    showDiagnostics = false
                }
                .keyboardShortcut(.defaultAction)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("System Configuration:")
                    .font(.headline)
                Text(diagnosticsManager.systemInfo)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Whisper/GGML Engine Logs:")
                        .font(.headline)
                    Spacer()
                    Button("Clear Logs") {
                        diagnosticsManager.clearLogs()
                    }
                    .buttonStyle(.borderless)
                }
                
                ScrollView {
                    Text(diagnosticsManager.logOutput.isEmpty ? "No logs captured yet. Start recording to generate logs." : diagnosticsManager.logOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - Settings View Sheet
    var settingsView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AI Refinement Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    showSettings = false
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API URL Endpoint")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("", text: $apiUrlSetting)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    SecureField("Enter API Key", text: $apiKeySetting)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deployment Name (Model)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("", text: $modelSetting)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Version")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("2024-10-21", text: $apiVersionSetting)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                Toggle("Pause Spotify playback during recording", isOn: $pauseSpotifySetting)
                    .toggleStyle(.checkbox)
            }
            
            HStack {
                Spacer()
                
                Button("Save Settings") {
                    saveSettingsToUserDefaults()
                    showSettings = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 480, height: 430)
        .onAppear {
            loadSettingsFromUserDefaults()
        }
    }
    
    func loadSettingsFromUserDefaults() {
        let defaults = UserDefaults.standard
        apiTypeSetting = "azure"
        apiUrlSetting = defaults.string(forKey: "LLM_apiUrl") ?? ""
        apiKeySetting = defaults.string(forKey: "LLM_apiKey") ?? ""
        modelSetting = defaults.string(forKey: "LLM_model") ?? ""
        apiVersionSetting = defaults.string(forKey: "LLM_apiVersion") ?? "2024-10-21"
        
        if defaults.object(forKey: "pauseSpotifySetting") == nil {
            pauseSpotifySetting = true
        } else {
            pauseSpotifySetting = defaults.bool(forKey: "pauseSpotifySetting")
        }
    }
    
    func saveSettingsToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set("azure", forKey: "LLM_apiType")
        defaults.set(apiUrlSetting, forKey: "LLM_apiUrl")
        defaults.set(apiKeySetting, forKey: "LLM_apiKey")
        defaults.set(modelSetting, forKey: "LLM_model")
        defaults.set(apiVersionSetting, forKey: "LLM_apiVersion")
        defaults.set(pauseSpotifySetting, forKey: "pauseSpotifySetting")
        
        llmManager.clearImprovedPrompt()
    }
}
