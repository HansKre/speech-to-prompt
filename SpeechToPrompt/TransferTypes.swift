import Foundation
import UniformTypeIdentifiers

enum SidebarDragItem: Codable {
    case project(id: UUID)
    case prompt(promptID: UUID, sourceProjectID: UUID)
}

enum SidebarDragHelper {
    static let typeIdentifier = UTType.data.identifier

    static func makeProvider(for item: SidebarDragItem) -> NSItemProvider {
        let provider = NSItemProvider()
        guard let data = try? JSONEncoder().encode(item) else { return provider }
        provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func decode(from data: Data) -> SidebarDragItem? {
        try? JSONDecoder().decode(SidebarDragItem.self, from: data)
    }
}
