import Foundation

enum PromptFileType {
    case raw
    case refined
}

enum AttachmentKind: String, Codable {
    case image
    case file
}

struct Attachment: Identifiable, Codable, Equatable {
    let id: UUID
    var filename: String
    var storedFilename: String
    var kind: AttachmentKind
    var createdAt: Date
}

struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rawTranscription: String
    var refinedPrompt: String?
    var attachments: [Attachment]?
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.rawTranscription = ""
        self.refinedPrompt = nil
        self.attachments = []
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
