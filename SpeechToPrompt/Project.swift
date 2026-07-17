import Foundation

struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rawTranscription: String
    var refinedPrompt: String?
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.rawTranscription = ""
        self.refinedPrompt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var prompts: [Prompt]
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.prompts = []
        self.createdAt = Date()
    }
}
