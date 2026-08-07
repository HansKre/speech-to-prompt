import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @State private var collapsedProjectIDs: Set<UUID> = []
    @State private var dragOverProjectID: UUID?
    @State private var hoveredProjectID: UUID?
    @State private var hoveredPromptID: UUID?
    @State private var hoveredAddPrompt = false
    @State private var hoveredNewProject = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(projectStore.projects) { project in
                        projectHeader(project: project)
                            .onDrop(of: [.data], delegate: SidebarDropDelegate(
                                targetProjectID: project.id,
                                targetPromptID: nil,
                                projectStore: projectStore,
                                dragOverProjectID: $dragOverProjectID
                            ))

                        if !collapsedProjectIDs.contains(project.id) {
                            ForEach(project.prompts) { prompt in
                                promptRow(prompt: prompt, projectID: project.id)
                                    .padding(.leading, 16)
                                    .onDrop(of: [.data], delegate: SidebarDropDelegate(
                                        targetProjectID: project.id,
                                        targetPromptID: prompt.id,
                                        projectStore: projectStore,
                                        dragOverProjectID: $dragOverProjectID
                                    ))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

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
        .onAppear { loadCollapsedState() }
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

    // MARK: - Collapse Persistence

    private func loadCollapsedState() {
        let ids = UserDefaults.standard.stringArray(forKey: "collapsedProjectIDs") ?? []
        collapsedProjectIDs = Set(ids.compactMap { UUID(uuidString: $0) })
    }

    private func persistCollapsedState() {
        let ids = collapsedProjectIDs.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: "collapsedProjectIDs")
    }

    private func toggleCollapse(for projectID: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedProjectIDs.contains(projectID) {
                collapsedProjectIDs.remove(projectID)
            } else {
                collapsedProjectIDs.insert(projectID)
            }
        }
        persistCollapsedState()
    }

    // MARK: - Project Header

    private func projectHeader(project: Project) -> some View {
        let isHovered = hoveredProjectID == project.id
        let isDropTarget = dragOverProjectID == project.id

        return HStack(spacing: 6) {
            DragHandle {
                SidebarDragHelper.makeProvider(for: .project(id: project.id))
            }

            Image(systemName: collapsedProjectIDs.contains(project.id) ? "chevron.right" : "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleCollapse(for: project.id)
                }

            Image(systemName: "folder.fill")
                .foregroundColor(.purple)
                .font(.callout)
            Text(project.name)
                .font(.callout.bold())
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 2) {
                sidebarActionButton(icon: "plus", color: .purple, tooltip: "Add Prompt (⌘N)") {
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
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTarget ? Color.purple.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
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
            Button(collapsedProjectIDs.contains(project.id) ? "Expand" : "Collapse") {
                toggleCollapse(for: project.id)
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

    // MARK: - Prompt Row

    private func promptRow(prompt: Prompt, projectID: UUID) -> some View {
        let isHovered = hoveredPromptID == prompt.id
        let isSelected = projectStore.selectedPromptID == prompt.id

        return HStack(spacing: 6) {
            DragHandle {
                SidebarDragHelper.makeProvider(for: .prompt(promptID: prompt.id, sourceProjectID: projectID))
            }

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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isRecording else { return }
            projectStore.selectPrompt(prompt.id)
        }
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
            if projectStore.projects.count > 1 {
                Menu("Move to Project") {
                    ForEach(projectStore.projects.filter { $0.id != projectID }) { target in
                        Button(target.name) {
                            projectStore.movePromptToProject(
                                promptID: prompt.id,
                                fromProjectID: projectID,
                                toProjectID: target.id
                            )
                        }
                    }
                }
                Divider()
            }
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

// MARK: - Drag Handle

struct DragHandle: View {
    let provider: () -> NSItemProvider
    @State private var isHovered = false

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption2)
            .foregroundColor(isHovered ? .primary : .secondary.opacity(0.5))
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
            .onDrag(provider)
            .onHover { hovered in
                if hovered {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovered
                }
            }
    }
}

// MARK: - Unified Drop Delegate

struct SidebarDropDelegate: DropDelegate {
    let targetProjectID: UUID
    let targetPromptID: UUID?
    let projectStore: ProjectStore
    @Binding var dragOverProjectID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard targetPromptID == nil else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            dragOverProjectID = targetProjectID
        }
    }

    func dropExited(info: DropInfo) {
        guard targetPromptID == nil else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            if dragOverProjectID == targetProjectID {
                dragOverProjectID = nil
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        dragOverProjectID = nil

        guard let item = info.itemProviders(for: [.data]).first else { return false }

        item.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, _ in
            guard let data, let dragItem = SidebarDragHelper.decode(from: data) else { return }
            DispatchQueue.main.async {
                switch dragItem {
                case .project(let id):
                    projectStore.moveProject(from: id, to: targetProjectID)

                case .prompt(let promptID, let sourceProjectID):
                    if let targetPromptID, sourceProjectID == targetProjectID {
                        projectStore.reorderPrompt(projectID: targetProjectID, promptID: promptID, beforePromptID: targetPromptID)
                    } else {
                        projectStore.movePromptToProject(
                            promptID: promptID,
                            fromProjectID: sourceProjectID,
                            toProjectID: targetProjectID
                        )
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Action Button

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
