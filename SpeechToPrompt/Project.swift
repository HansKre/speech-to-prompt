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
    var isDone: Bool
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.rawTranscription = ""
        self.refinedPrompt = nil
        self.attachments = []
        self.isDone = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rawTranscription = try container.decode(String.self, forKey: .rawTranscription)
        refinedPrompt = try container.decodeIfPresent(String.self, forKey: .refinedPrompt)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
