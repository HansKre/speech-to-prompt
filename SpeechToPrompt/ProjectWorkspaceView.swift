import SwiftUI

struct ProjectWorkspaceView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var diagnosticsManager: DiagnosticsManager

    @Binding var showSettings: Bool
    @Binding var showDiagnostics: Bool

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(
                projectStore: projectStore,
                isRecording: audioManager.isRecording
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
                    showSettings: $showSettings,
                    showDiagnostics: $showDiagnostics
                )
            } else {
                emptyPromptView
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar(.hidden)
        .frame(minWidth: 900, minHeight: 500)
    }

    private var emptyPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select or create a prompt")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Use the sidebar to add a prompt to your project")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
