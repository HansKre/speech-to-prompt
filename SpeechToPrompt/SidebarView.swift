import SwiftUI

struct SidebarView: View {
    @ObservedObject var projectStore: ProjectStore
    var isRecording: Bool

    @State private var showNewProject = false
    @State private var showNewPrompt = false
    @State private var newPromptProjectID: UUID?
    @State private var renamingProjectID: UUID?
    @State private var renamingPromptID: UUID?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<UUID?>(
                get: { projectStore.selectedPromptID },
                set: { id in
                    guard !isRecording, let id else { return }
                    projectStore.selectPrompt(id)
                }
            )) {
                ForEach(projectStore.projects) { project in
                    Section {
                        ForEach(project.prompts) { prompt in
                            promptRow(prompt: prompt, projectID: project.id)
                                .tag(prompt.id)
                        }
                    } header: {
                        projectHeader(project: project)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button(action: { showNewProject = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Project")
                }
                .font(.callout)
                .foregroundColor(hoveredNewProject ? .purple : .purple.opacity(0.7))
                .scaleEffect(hoveredNewProject ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredNewProject = isHovered
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .sheet(isPresented: $showNewProject) {
            NameInputSheet(
                title: "New Project",
                placeholder: "Project name",
                onSubmit: { name in
                    projectStore.createProject(name: name)
                    showNewProject = false
                },
                onCancel: { showNewProject = false }
            )
        }
        .sheet(isPresented: $showNewPrompt) {
            NameInputSheet(
                title: "New Prompt",
                placeholder: "Prompt name",
                onSubmit: { name in
                    if let projectID = newPromptProjectID {
                        projectStore.addPrompt(to: projectID, name: name)
                    }
                    showNewPrompt = false
                },
                onCancel: { showNewPrompt = false }
            )
        }
        .sheet(item: $renamingProjectID) { projectID in
            NameInputSheet(
                title: "Rename Project",
                placeholder: "Project name",
                initialText: renameText,
                onSubmit: { name in
                    projectStore.renameProject(id: projectID, name: name)
                    renamingProjectID = nil
                },
                onCancel: { renamingProjectID = nil }
            )
        }
        .sheet(item: $renamingPromptID) { promptID in
            NameInputSheet(
                title: "Rename Prompt",
                placeholder: "Prompt name",
                initialText: renameText,
                onSubmit: { name in
                    if let projectID = projectStore.selectedProjectID {
                        projectStore.renamePrompt(projectID: projectID, promptID: promptID, name: name)
                    }
                    renamingPromptID = nil
                },
                onCancel: { renamingPromptID = nil }
            )
        }
    }

    @State private var hoveredProjectID: UUID?
    @State private var hoveredPromptID: UUID?
    @State private var hoveredNewProject = false

    private func projectHeader(project: Project) -> some View {
        let isHovered = hoveredProjectID == project.id

        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundColor(.purple)
                .font(.callout)
            Text(project.name)
                .font(.callout.bold())
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 2) {
                sidebarActionButton(icon: "plus", color: .purple, tooltip: "Add Prompt") {
                    newPromptProjectID = project.id
                    showNewPrompt = true
                }
                sidebarActionButton(icon: "pencil", color: .secondary, tooltip: "Rename Project") {
                    renameText = project.name
                    renamingProjectID = project.id
                }
                sidebarActionButton(icon: "trash", color: .red.opacity(0.7), tooltip: "Delete Project") {
                    projectStore.deleteProject(id: project.id)
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            if hovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredProjectID = hovered ? project.id : nil
            }
        }
        .onTapGesture {
            guard !isRecording else { return }
            projectStore.selectProject(project.id)
        }
        .contextMenu {
            Button("Add Prompt") {
                newPromptProjectID = project.id
                showNewPrompt = true
            }
            Divider()
            Button("Rename") {
                renameText = project.name
                renamingProjectID = project.id
            }
            Button("Delete", role: .destructive) {
                projectStore.deleteProject(id: project.id)
            }
        }
    }

    private func promptRow(prompt: Prompt, projectID: UUID) -> some View {
        let isHovered = hoveredPromptID == prompt.id
        let isSelected = projectStore.selectedPromptID == prompt.id

        return HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.callout)
                .foregroundColor(.secondary)
            Text(prompt.name)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 2) {
                sidebarActionButton(icon: "pencil", color: .secondary, tooltip: "Rename Prompt") {
                    renameText = prompt.name
                    renamingPromptID = prompt.id
                }
                sidebarActionButton(icon: "trash", color: .red.opacity(0.7), tooltip: "Delete Prompt") {
                    projectStore.deletePrompt(projectID: projectID, promptID: prompt.id)
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered && !isSelected ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            if hovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredPromptID = hovered ? prompt.id : nil
            }
        }
        .contextMenu {
            Button("Rename") {
                renameText = prompt.name
                renamingPromptID = prompt.id
            }
            Button("Delete", role: .destructive) {
                projectStore.deletePrompt(projectID: projectID, promptID: prompt.id)
            }
        }
    }

    private func sidebarActionButton(icon: String, color: Color, tooltip: String, action: @escaping () -> Void) -> some View {
        SidebarActionButtonView(icon: icon, color: color, tooltip: tooltip, action: action)
    }
}

private struct SidebarActionButtonView: View {
    let icon: String
    let color: Color
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(color)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(isHovered ? 0.15 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .tooltip(tooltip)
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
