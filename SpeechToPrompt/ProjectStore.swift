import Foundation
import Combine

class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectID: UUID?
    @Published var selectedPromptID: UUID?

    var hasProjects: Bool { !projects.isEmpty }

    var selectedProject: Project? {
        projects.first { $0.id == selectedProjectID }
    }

    var selectedPrompt: Prompt? {
        selectedProject?.prompts.first { $0.id == selectedPromptID }
    }

    private var saveCancellable: AnyCancellable?
    private let defaults = UserDefaults.standard

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SpeechToPrompt")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("projects.json")
    }

    private var promptsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let promptsDir = appSupport
            .appendingPathComponent("SpeechToPrompt")
            .appendingPathComponent("prompts")
        try? FileManager.default.createDirectory(at: promptsDir, withIntermediateDirectories: true)
        return promptsDir
    }

    func promptFileURL(projectID: UUID, promptID: UUID, type: PromptFileType) -> URL {
        promptsBaseURL
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent(promptID.uuidString)
            .appendingPathComponent(type == .raw ? "raw.md" : "refined.md")
    }

    init() {
        load()
        restoreLastActive()
        setupAutoSave()
    }

    // MARK: - Project CRUD

    func createProject(name: String) {
        let project = Project(name: name)
        projects.append(project)
        selectedProjectID = project.id
        selectedPromptID = nil
        save()
    }

    func renameProject(id: UUID, name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
        save()
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
        if selectedProjectID == id {
            selectedProjectID = projects.first?.id
            selectedPromptID = selectedProject?.prompts.first?.id
        }
        let projectDir = promptsBaseURL.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: projectDir)
        save()
    }

    // MARK: - Prompt CRUD

    func addPrompt(to projectID: UUID, name: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let prompt = Prompt(name: name)
        projects[index].prompts.append(prompt)
        selectedPromptID = prompt.id
        save()
    }

    func renamePrompt(projectID: UUID, promptID: UUID, name: String) {
        guard let pIndex = projects.firstIndex(where: { $0.id == projectID }),
              let qIndex = projects[pIndex].prompts.firstIndex(where: { $0.id == promptID }) else { return }
        projects[pIndex].prompts[qIndex].name = name
        save()
    }

    func movePrompt(projectID: UUID, from source: IndexSet, to destination: Int) {
        guard let pIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[pIndex].prompts.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func deletePrompt(projectID: UUID, promptID: UUID) {
        guard let pIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[pIndex].prompts.removeAll { $0.id == promptID }
        if selectedPromptID == promptID {
            selectedPromptID = projects[pIndex].prompts.last?.id
        }
        let promptDir = promptsBaseURL
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent(promptID.uuidString)
        try? FileManager.default.removeItem(at: promptDir)
        save()
    }

    // MARK: - Selection

    func selectProject(_ id: UUID) {
        selectedProjectID = id
        selectedPromptID = projects.first(where: { $0.id == id })?.prompts.first?.id
        persistLastActive()
    }

    func selectPrompt(_ id: UUID) {
        selectedPromptID = id
        persistLastActive()
    }

    // MARK: - Transcription Persistence

    func updatePromptTranscription(rawText: String, refinedText: String?) {
        updatePromptTranscription(promptID: selectedPromptID, rawText: rawText, refinedText: refinedText)
    }

    func updatePromptTranscription(promptID: UUID?, rawText: String, refinedText: String?) {
        guard let projectID = selectedProjectID,
              let promptID,
              let pIndex = projects.firstIndex(where: { $0.id == projectID }),
              let qIndex = projects[pIndex].prompts.firstIndex(where: { $0.id == promptID }) else { return }
        projects[pIndex].prompts[qIndex].rawTranscription = rawText
        projects[pIndex].prompts[qIndex].refinedPrompt = refinedText
        projects[pIndex].prompts[qIndex].updatedAt = Date()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: storageURL, options: .atomic)
        persistLastActive()
        writePromptFiles()
    }

    private func writePromptFiles() {
        let fm = FileManager.default
        let iso = ISO8601DateFormatter()

        for project in projects {
            for prompt in project.prompts {
                let promptDir = promptsBaseURL
                    .appendingPathComponent(project.id.uuidString)
                    .appendingPathComponent(prompt.id.uuidString)
                try? fm.createDirectory(at: promptDir, withIntermediateDirectories: true)

                try? prompt.rawTranscription.write(
                    to: promptDir.appendingPathComponent("raw.md"),
                    atomically: true, encoding: .utf8
                )

                let refinedURL = promptDir.appendingPathComponent("refined.md")
                if let refined = prompt.refinedPrompt, !refined.isEmpty {
                    try? refined.write(to: refinedURL, atomically: true, encoding: .utf8)
                } else {
                    try? fm.removeItem(at: refinedURL)
                }

                let meta: [String: String] = [
                    "id": prompt.id.uuidString,
                    "name": prompt.name,
                    "project": project.name,
                    "projectId": project.id.uuidString,
                    "created": iso.string(from: prompt.createdAt),
                    "updated": iso.string(from: prompt.updatedAt)
                ]
                if let metaData = try? JSONSerialization.data(
                    withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]
                ) {
                    try? metaData.write(to: promptDir.appendingPathComponent("meta.json"))
                }
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: storageURL),
              let loaded = try? decoder.decode([Project].self, from: data) else { return }
        projects = loaded
    }

    private func persistLastActive() {
        defaults.set(selectedProjectID?.uuidString, forKey: "lastActiveProjectID")
        defaults.set(selectedPromptID?.uuidString, forKey: "lastActivePromptID")
    }

    private func restoreLastActive() {
        if let projectStr = defaults.string(forKey: "lastActiveProjectID"),
           let projectID = UUID(uuidString: projectStr),
           projects.contains(where: { $0.id == projectID }) {
            selectedProjectID = projectID
            if let promptStr = defaults.string(forKey: "lastActivePromptID"),
               let promptID = UUID(uuidString: promptStr),
               selectedProject?.prompts.contains(where: { $0.id == promptID }) == true {
                selectedPromptID = promptID
            }
        } else {
            selectedProjectID = projects.first?.id
        }
    }

    private func setupAutoSave() {
        saveCancellable = objectWillChange
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
    }
}
