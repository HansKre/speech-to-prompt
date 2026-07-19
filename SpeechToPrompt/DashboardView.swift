import SwiftUI

struct DashboardView: View {
    @ObservedObject var projectStore: ProjectStore
    @Binding var showSettings: Bool
    @State private var showCreateProject = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Speech To Prompt")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Create a project to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                Button(action: { showCreateProject = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Project")
                    }
                    .font(.body.bold())
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .tooltip("Create a new project")

                Button(action: { showSettings = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .tooltip("Open settings")
            }

            Spacer()
        }
        .frame(minWidth: 450, minHeight: 350)
        .sheet(isPresented: $showCreateProject) {
            NameInputSheet(
                title: "New Project",
                placeholder: "Project name",
                onSubmit: { name in
                    projectStore.createProject(name: name)
                    showCreateProject = false
                },
                onCancel: { showCreateProject = false }
            )
        }
    }
}
