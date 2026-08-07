import SwiftUI

struct ProjectWorkspaceView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var diagnosticsManager: DiagnosticsManager
    @ObservedObject var attachmentManager: AttachmentManager

    @Binding var showSettings: Bool
    @Binding var showDiagnostics: Bool
    @Binding var showKeyboardShortcuts: Bool

    private var showRecordingOverlay: Bool {
        audioManager.isRecording || whisperManager.isTranscribing || whisperManager.isProcessingFinalAudio
    }

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: .constant(.all)) {
                SidebarView(
                    projectStore: projectStore,
                    isRecording: showRecordingOverlay
                )
            } detail: {
                if projectStore.selectedPromptID != nil {
                    PromptDetailView(
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
                    emptyPromptView
                }
            }
            .navigationSplitViewStyle(.prominentDetail)
            .toolbar(.hidden)
            .blur(radius: showRecordingOverlay ? 6 : 0)
            .allowsHitTesting(!showRecordingOverlay)
            .disabled(showRecordingOverlay)

            if showRecordingOverlay {
                RecordingOverlayView(
                    audioManager: audioManager,
                    whisperManager: whisperManager,
                    onStop: {
                        whisperManager.isProcessingFinalAudio = true
                        _ = audioManager.stopRecording()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showRecordingOverlay)
        .frame(minWidth: 900, minHeight: 700)
    }

    private var emptyPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select or create prompt")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Use sidebar to add prompt to project")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
