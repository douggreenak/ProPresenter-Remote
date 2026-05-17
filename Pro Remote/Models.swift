import Foundation
import SwiftUI

// MARK: - API Response Types

struct PresentationListItem: Codable {
    let id: PresentationIdentifier
}

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
}

struct SlideGroupPayload: Codable {
    let name: String
    let color: GroupColorPayload?
    let slides: [SlidePayload]
}

struct GroupColorPayload: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

struct SlidePayload: Codable {
    let enabled: Bool
    let notes: String
    let text: String
}

struct SlideStatusPayload: Codable {
    let current: CurrentSlidePayload?
}

struct CurrentSlidePayload: Codable {
    let presentationIndex: PresentationIndexPayload?
    let slideIndex: Int

    enum CodingKeys: String, CodingKey {
        case presentationIndex = "presentation_index"
        case slideIndex = "slide_index"
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

struct PresentationListWrapper: Codable {
    let presentations: [PresentationListItem]
}

// MARK: - Playlist API Response Types (recursive)

struct PlaylistNode: Codable {
    let id: PresentationIdentifier?
    let type: String?
    let items: [PlaylistNode]?
    let children: [PlaylistNode]?
    let name: String?

    func allPresentations() -> [Presentation] {
        var results: [Presentation] = []

        if let nodeId = id {
            let containerTypes: Set<String> = ["playlist", "playlist_folder", "folder", "group"]
            let isContainer = type.map { containerTypes.contains($0.lowercased()) } ?? false
            if !isContainer {
                results.append(Presentation(uuid: nodeId.uuid, name: nodeId.name, index: nodeId.index))
            }
        }

        for item in items ?? [] {
            results.append(contentsOf: item.allPresentations())
        }
        for child in children ?? [] {
            results.append(contentsOf: child.allPresentations())
        }

        return results
    }
}

struct PlaylistListWrapper: Codable {
    let playlists: [PlaylistNode]?
}

// MARK: - App Models

struct Presentation: Identifiable, Hashable {
    var id: String { uuid }
    let uuid: String
    let name: String
    let index: Int?
    var slides: [Slide]

    init(uuid: String, name: String, index: Int? = nil, slides: [Slide] = []) {
        self.uuid = uuid
        self.name = name
        self.index = index
        self.slides = slides
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
    let notes: String
    let enabled: Bool
    let groupName: String

    var index: Int { id }
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
