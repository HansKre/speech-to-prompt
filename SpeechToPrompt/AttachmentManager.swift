import Foundation
import SwiftUI
import Combine

class AttachmentManager: ObservableObject {
    @Published var attachments: [Attachment] = []

    var projectStore: ProjectStore?
    private var currentProjectID: UUID?
    private var currentPromptID: UUID?

    func loadAttachments(for prompt: Prompt, projectID: UUID, promptID: UUID) {
        currentProjectID = projectID
        currentPromptID = promptID
        attachments = prompt.attachments ?? []
    }

    func addAttachment(data: Data, filename: String, kind: AttachmentKind) -> Attachment? {
        guard let projectStore, let projectID = currentProjectID, let promptID = currentPromptID else { return nil }

        let ext = (filename as NSString).pathExtension.lowercased()
        let storedFilename = "\(UUID().uuidString).\(ext.isEmpty ? "bin" : ext)"

        let dir = projectStore.attachmentsDirectoryURL(projectID: projectID, promptID: promptID)
        let fileURL = dir.appendingPathComponent(storedFilename)

        do {
            try data.write(to: fileURL)
        } catch {
            return nil
        }

        let attachment = Attachment(
            id: UUID(),
            filename: filename,
            storedFilename: storedFilename,
            kind: kind,
            createdAt: Date()
        )
        attachments.append(attachment)
        projectStore.updatePromptAttachments(attachments: attachments)
        return attachment
    }

    func removeAttachment(id: UUID, rawText: inout String, refinedText: inout String?) {
        guard let projectStore, let projectID = currentProjectID, let promptID = currentPromptID else { return }
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }

        let attachment = attachments[index]
        let pattern = "!\\[[^\\]]*\\]\\(attachments/\(NSRegularExpression.escapedPattern(for: attachment.storedFilename))\\)"

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let rawRange = NSRange(rawText.startIndex..., in: rawText)
            rawText = regex.stringByReplacingMatches(in: rawText, range: rawRange, withTemplate: "")
            rawText = rawText.replacingOccurrences(of: "\n\n\n", with: "\n\n")

            if var refined = refinedText {
                let refinedRange = NSRange(refined.startIndex..., in: refined)
                refined = regex.stringByReplacingMatches(in: refined, range: refinedRange, withTemplate: "")
                refined = refined.replacingOccurrences(of: "\n\n\n", with: "\n\n")
                refinedText = refined
            }
        }

        let dir = projectStore.attachmentsDirectoryURL(projectID: projectID, promptID: promptID)
        let fileURL = dir.appendingPathComponent(attachment.storedFilename)
        try? FileManager.default.removeItem(at: fileURL)

        attachments.remove(at: index)
        projectStore.updatePromptAttachments(attachments: attachments)
    }

    func referenceString(for attachment: Attachment) -> String {
        let label = chipLabel(for: attachment)
        return "![\(label)](attachments/\(attachment.storedFilename))"
    }

    func chipLabel(for attachment: Attachment) -> String {
        switch attachment.kind {
        case .image:
            let imageAttachments = attachments.filter { $0.kind == .image }
            let idx = (imageAttachments.firstIndex(where: { $0.id == attachment.id }) ?? 0) + 1
            return "image #\(idx)"
        case .file:
            return attachment.filename
        }
    }

    func attachmentFileURL(for attachment: Attachment) -> URL? {
        guard let projectStore, let projectID = currentProjectID, let promptID = currentPromptID else { return nil }
        let dir = projectStore.attachmentsDirectoryURL(projectID: projectID, promptID: promptID)
        return dir.appendingPathComponent(attachment.storedFilename)
    }
}
