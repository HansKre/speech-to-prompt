import SwiftUI

struct RootView: View {
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var whisperManager = WhisperManager()
    @StateObject private var llmManager = LLMManager()
    @StateObject private var diagnosticsManager = DiagnosticsManager.shared
    @StateObject private var attachmentManager = AttachmentManager()

    @State private var showSettings = false
    @State private var showDiagnostics = false
    @State private var showKeyboardShortcuts = false

    var body: some View {
        Group {
            if projectStore.hasProjects {
                ProjectWorkspaceView(
                    projectStore: projectStore,
                    modelManager: modelManager,
                    audioManager: audioManager,
                    whisperManager: whisperManager,
                    llmManager: llmManager,
                    diagnosticsManager: diagnosticsManager,
                    attachmentManager: attachmentManager,
                    showSettings: $showSettings,
                    showDiagnostics: $showDiagnostics,
                    showKeyboardShortcuts: $showKeyboardShortcuts
                )
            } else {
                DashboardView(
                    projectStore: projectStore,
                    showSettings: $showSettings
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsView
        }
        .sheet(isPresented: $showDiagnostics) {
            diagnosticsView
        }
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutsView(isPresented: $showKeyboardShortcuts)
        }
        .background(
            Button("") { showKeyboardShortcuts = true }
                .keyboardShortcut("k", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }

    // MARK: - Settings

    @State private var apiUrlSetting = ""
    @State private var apiKeySetting = ""
    @State private var modelSetting = ""
    @State private var apiVersionSetting = "2024-10-21"
    @State private var pauseSpotifySetting = true

    private var settingsView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AI Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    showSettings = false
                }
            }

            Divider().padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API URL")
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
                    Text("Model")
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
                .pointerOnHover()
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

    // MARK: - Diagnostics

    private var diagnosticsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("System Diagnostics")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    showDiagnostics = false
                }
                .keyboardShortcut(.defaultAction)
                .tooltip("Close (Return)")
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
                    .pointerOnHover()
                    .tooltip("Clear all diagnostic logs")
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

    // MARK: - Settings Persistence

    private func loadSettingsFromUserDefaults() {
        let defaults = UserDefaults.standard
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

    private func saveSettingsToUserDefaults() {
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
