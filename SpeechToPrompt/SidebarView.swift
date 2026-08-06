import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var projectStore: ProjectStore
    var isRecording: Bool

    @State private var showNewProject = false
    @State private var showNewPrompt = false
    @State private var newPromptProjectID: UUID?
    @State private var renamingProjectID: UUID?
    @State private var renamingPromptID: UUID?
    @State private var renameText = ""
    @State private var deletingProjectID: UUID?
    @State private var deletingPromptID: UUID?
    @State private var deletingPromptProjectID: UUID?
    @State private var showDeleteProjectAlert = false
    @State private var showDeletePromptAlert = false

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
                        .onMove { source, destination in
                            projectStore.movePrompt(projectID: project.id, from: source, to: destination)
                        }
                    } header: {
                        projectHeader(project: project)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            if !projectStore.projects.isEmpty && projectStore.selectedPromptID != nil {
                Button(action: {
                    newPromptProjectID = projectStore.selectedProjectID
                    showNewPrompt = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                        Text("Add Prompt")
                    }
                    .font(.callout)
                    .foregroundColor(hoveredAddPrompt ? .purple : .purple.opacity(0.7))
                    .scaleEffect(hoveredAddPrompt ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredAddPrompt = isHovered
                    }
                }
                .padding(.top, 10)
            }

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
            .pointerOnHover()
            .padding(.vertical, 10)
            .onHover { isHovered in
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
        .alert("Delete Project", isPresented: $showDeleteProjectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = deletingProjectID {
                    projectStore.deleteProject(id: id)
                }
            }
        } message: {
            Text("This will permanently delete the project and all its prompts.")
        }
        .alert("Delete Prompt", isPresented: $showDeletePromptAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let promptID = deletingPromptID, let projectID = deletingPromptProjectID {
                    projectStore.deletePrompt(projectID: projectID, promptID: promptID)
                }
            }
        } message: {
            Text("This will permanently delete this prompt.")
        }
    }

    @State private var hoveredProjectID: UUID?
    @State private var hoveredPromptID: UUID?
    @State private var hoveredAddPrompt = false
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
                    deletingProjectID = project.id
                    showDeleteProjectAlert = true
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
                deletingProjectID = project.id
                showDeleteProjectAlert = true
            }
        }
    }

    private func promptRow(prompt: Prompt, projectID: UUID) -> some View {
        let isHovered = hoveredPromptID == prompt.id
        let isSelected = projectStore.selectedPromptID == prompt.id

        return HStack(spacing: 6) {
            Button(action: {
                projectStore.togglePromptDone(projectID: projectID, promptID: prompt.id)
            }) {
                Image(systemName: prompt.isDone ? "checkmark.square.fill" : "square")
                    .font(.callout)
                    .foregroundColor(prompt.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .pointerOnHover()

            Text(prompt.name)
                .font(.callout)
                .lineLimit(1)
                .strikethrough(prompt.isDone)
                .foregroundColor(prompt.isDone ? .secondary : .primary)

            Spacer()

            HStack(spacing: 2) {
                sidebarActionButton(icon: "pencil", color: .secondary, tooltip: "Rename Prompt") {
                    renameText = prompt.name
                    renamingPromptID = prompt.id
                }
                sidebarActionButton(icon: "trash", color: .red.opacity(0.7), tooltip: "Delete Prompt") {
                    deletingPromptID = prompt.id
                    deletingPromptProjectID = projectID
                    showDeletePromptAlert = true
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

        .opacity(prompt.isDone ? 0.5 : 1.0)
        .contextMenu {
            Button(prompt.isDone ? "Mark as To Do" : "Mark as Done") {
                projectStore.togglePromptDone(projectID: projectID, promptID: prompt.id)
            }
            Divider()
            Button("Rename") {
                renameText = prompt.name
                renamingPromptID = prompt.id
            }
            Button("Delete", role: .destructive) {
                deletingPromptID = prompt.id
                deletingPromptProjectID = projectID
                showDeletePromptAlert = true
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
        .pointerOnHover()
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
