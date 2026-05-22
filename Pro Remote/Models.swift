import Foundation
import SwiftUI

// MARK: - API Response Types

struct PresentationIdentifier: Codable, Hashable {
    let uuid: String
    let name: String
    let index: Int?

    init(uuid: String, name: String, index: Int? = nil) {
        self.uuid = uuid
        self.name = name
        self.index = index
    }
}

struct ActivePresentationResponse: Codable {
    let presentation: PresentationPayload
}

struct PresentationPayload: Codable {
    let id: PresentationIdentifier
    let groups: [SlideGroupPayload]
    let arrangements: [ArrangementPayload]?
    let currentArrangement: String?

    enum CodingKeys: String, CodingKey {
        case id, groups, arrangements
        case currentArrangement = "current_arrangement"
    }
}

struct ArrangementPayload: Codable {
    let id: PresentationIdentifier
    let groups: [String]
}

struct SlideGroupPayload: Codable {
    let name: String
    let color: GroupColorPayload?
    let slides: [SlidePayload]
    let uuid: String?
}

struct GroupColorPayload: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

struct SlidePayload: Codable {
    let enabled: Bool?
    let notes: String
    let text: String
    let label: String?
}

struct SlideIndexPayload: Codable {
    let presentationIndex: PresentationIndexPayload?

    enum CodingKeys: String, CodingKey {
        case presentationIndex = "presentation_index"
    }
}

struct PresentationIndexPayload: Codable {
    let presentationId: PresentationIdentifier?
    let index: Int

    enum CodingKeys: String, CodingKey {
        case presentationId = "presentation_id"
        case index
    }
}

// MARK: - Playlist API Response Types (recursive)

struct PlaylistNode: Codable {
    let id: PresentationIdentifier?
    let type: String?
    let fieldType: String?
    let items: [PlaylistItem]?
    let children: [PlaylistNode]?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id, type, items, children, name
        case fieldType = "field_type"
    }

    var isContainer: Bool {
        let containerTypes: Set<String> = ["playlist", "playlist_folder", "folder", "group"]
        let nodeType = fieldType ?? type
        return nodeType.map { containerTypes.contains($0.lowercased()) } ?? (items != nil || children != nil)
    }

    func allPresentations() -> [Presentation] {
        var results: [Presentation] = []

        if let items {
            for item in items {
                if let pres = item.asPresentation() {
                    results.append(pres)
                }
            }
        }

        if !isContainer, let nodeId = id {
            results.append(Presentation(uuid: nodeId.uuid, name: nodeId.name, index: nodeId.index))
        }

        for child in children ?? [] {
            results.append(contentsOf: child.allPresentations())
        }

        return results
    }
}

struct PlaylistItem: Codable {
    let id: PresentationIdentifier?
    let type: String?
    let presentationInfo: PlaylistPresentationInfo?
    let destination: String?

    enum CodingKeys: String, CodingKey {
        case id, type, destination
        case presentationInfo = "presentation_info"
    }

    func asPresentation() -> Presentation? {
        guard let id else { return nil }
        let uuid = presentationInfo?.presentationUUID ?? id.uuid
        return Presentation(uuid: uuid, name: id.name, index: id.index, arrangementUUID: presentationInfo?.arrangementUUID)
    }
}

struct PlaylistPresentationInfo: Codable {
    let presentationUUID: String?
    let arrangementUUID: String?
    let arrangementName: String?

    enum CodingKeys: String, CodingKey {
        case presentationUUID = "presentation_uuid"
        case arrangementUUID = "arrangement_uuid"
        case arrangementName = "arrangement_name"
    }
}

// MARK: - App Models

struct Presentation: Identifiable, Hashable {
    var id: String { uuid }
    let uuid: String
    let name: String
    let index: Int?
    var slides: [Slide]
    var arrangementUUID: String?

    init(uuid: String, name: String, index: Int? = nil, slides: [Slide] = [], arrangementUUID: String? = nil) {
        self.uuid = uuid
        self.name = name
        self.index = index
        self.slides = slides
        self.arrangementUUID = arrangementUUID
    }

    static func == (lhs: Presentation, rhs: Presentation) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

struct Slide: Identifiable, Hashable {
    let id: Int
    let text: String
    let label: String
    let notes: String
    let enabled: Bool
    let groupName: String
    let groupColor: Color?
    let thumbnailIndex: Int

    var index: Int { id }

    var displayText: String {
        if !text.isEmpty { return text }
        if !label.isEmpty { return label }
        return ""
    }

    init(id: Int, text: String, label: String = "", notes: String, enabled: Bool, groupName: String, groupColor: Color? = nil, thumbnailIndex: Int? = nil) {
        self.id = id
        self.text = text
        self.label = label
        self.notes = notes
        self.enabled = enabled
        self.groupName = groupName
        self.groupColor = groupColor
        self.thumbnailIndex = thumbnailIndex ?? id
    }
}

struct Playlist: Identifiable, Hashable {
    var id: String { uuid }
    let uuid: String
    let name: String
    var items: [Presentation]

    init(uuid: String, name: String, items: [Presentation] = []) {
        self.uuid = uuid
        self.name = name
        self.items = items
    }
}

struct CompanionButton: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var urlString: String

    var url: URL? { URL(string: urlString) }
}

// MARK: - Utilities

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
