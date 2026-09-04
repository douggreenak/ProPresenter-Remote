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
    let totalCues: Int?

    enum CodingKeys: String, CodingKey {
        case presentationId = "presentation_id"
        case index
        case totalCues = "total_cues"
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

    /// `playlistUUID` is the containing playlist's own uuid (the one `/v1/playlist/{uuid}` was
    /// fetched with) - it's not present anywhere in a `PlaylistItem`'s own JSON, so it has to be
    /// threaded down from the top-level fetch instead. Every resulting Presentation is stamped
    /// with it (alongside its own index within that playlist) so callers can address its
    /// thumbnails via the arrangement-scoped `/v1/playlist/{playlistUUID}/{itemIndex}/thumbnail/{cueIndex}`
    /// endpoint later, instead of the presentation-scoped one that can't address repeated slides.
    func allPresentations(playlistUUID: String) -> [Presentation] {
        var results: [Presentation] = []

        if let items {
            for item in items {
                if var pres = item.asPresentation() {
                    pres.playlistUUID = playlistUUID
                    pres.playlistItemIndex = pres.index
                    results.append(pres)
                }
            }
        }

        if !isContainer, let nodeId = id {
            results.append(Presentation(uuid: nodeId.uuid, name: nodeId.name, index: nodeId.index))
        }

        for child in children ?? [] {
            results.append(contentsOf: child.allPresentations(playlistUUID: playlistUUID))
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
        return Presentation(uuid: uuid, name: id.name, index: id.index, arrangementUUID: presentationInfo?.arrangementUUID, itemUUID: id.uuid)
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

// MARK: - Active Playlist Item (authoritative arrangement pointer for the live presentation)

/// `GET /v1/playlist/active` names exactly which playlist item is live right now - unlike
/// `/v1/presentation/active`, which only returns the presentation document itself (plus its
/// library-default `current_arrangement`) with no idea which playlist row it came from. This
/// is the one unambiguous source for "what arrangement did the service pick", even when the
/// same song sits in more than one playlist with a different arrangement chosen in each.
///
/// The nesting has been observed to vary (a bare `presentation` key, or one wrapped in
/// `data`), so both shapes are decoded and normalized through `playlistItem`. Every field is
/// optional: PCO-linked playlists and older Pro versions can omit `playlist_item` entirely,
/// and a decode that comes back empty just means "unknown" to the caller, not an error.
struct ActivePlaylistItemResponse: Codable {
    let presentation: ActivePlaylistPresentationEnvelope?
    let data: ActivePlaylistDataEnvelope?

    var playlistItem: PlaylistItem? {
        presentation?.playlistItem ?? data?.presentation?.playlistItem
    }

    /// The containing playlist's own uuid, alongside the item pointer above - needed to build
    /// the arrangement-scoped thumbnail URL for whatever's live (see `PlaylistNode.allPresentations`).
    var playlistUUID: String? {
        presentation?.playlist?.uuid ?? data?.presentation?.playlist?.uuid
    }
}

struct ActivePlaylistDataEnvelope: Codable {
    let presentation: ActivePlaylistPresentationEnvelope?
}

struct ActivePlaylistPresentationEnvelope: Codable {
    let playlist: PresentationIdentifier?
    let playlistItem: PlaylistItem?

    enum CodingKeys: String, CodingKey {
        case playlist
        case playlistItem = "playlist_item"
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
    var itemUUID: String?
    /// The playlist this presentation was pinned in, and its position within that playlist -
    /// together they address `/v1/playlist/{playlistUUID}/{playlistItemIndex}/thumbnail/{cueIndex}`,
    /// the one ProPresenter thumbnail endpoint that's scoped to the active arrangement rather
    /// than the raw document, so it can serve a real image for a repeated slide instead of
    /// 404ing past the document's own slide count. Nil when this presentation wasn't reached
    /// through a known playlist item (e.g. no playlist match found yet) - callers fall back to
    /// the presentation-scoped thumbnail endpoint in that case.
    var playlistUUID: String?
    var playlistItemIndex: Int?
    var triggerToDisplayMap: [Int: [Int]] = [:]

    var listID: String { itemUUID ?? uuid }

    init(uuid: String, name: String, index: Int? = nil, slides: [Slide] = [], arrangementUUID: String? = nil, itemUUID: String? = nil, playlistUUID: String? = nil, playlistItemIndex: Int? = nil, triggerToDisplayMap: [Int: [Int]] = [:]) {
        self.uuid = uuid
        self.name = name
        self.index = index
        self.slides = slides
        self.arrangementUUID = arrangementUUID
        self.itemUUID = itemUUID
        self.playlistUUID = playlistUUID
        self.playlistItemIndex = playlistItemIndex
        self.triggerToDisplayMap = triggerToDisplayMap
    }

    // Equatable is synthesized on purpose: it must compare the slides too. @Observable
    // suppresses the change notification when a new value compares equal to the old, so a
    // uuid-only == made every slide edit (enabling/disabling one, say) invisible to SwiftUI —
    // the model updated but the grid never repainted.
    //
    // Hashing only the uuid stays valid: equal presentations share a uuid, so they still
    // hash alike. It just means same-uuid revisions collide, which is cheap and fine.
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
    let thumbnailIndex: Int?
    let triggerIndex: Int?

    var index: Int { id }

    /// True when there's *some* index this slide can be triggered by - either as the routine
    /// "already live" cue (`thumbnailIndex`, used with `/v1/presentation/active/{index}/trigger`)
    /// or, for activating a different presentation from cold, `triggerIndex`. Whether either one
    /// actually applies depends on which of those two calls the trigger goes through as, decided
    /// in `ProPresenterViewModel.triggerSlide` - this just gates the UI's enabled/disabled state.
    var isTriggerable: Bool { thumbnailIndex != nil || triggerIndex != nil }

    var displayText: String {
        if !text.isEmpty { return text }
        if !label.isEmpty { return label }
        return ""
    }

    init(id: Int, text: String, label: String = "", notes: String, enabled: Bool, groupName: String, groupColor: Color? = nil, thumbnailIndex: Int? = nil, triggerIndex: Int? = nil) {
        self.id = id
        self.text = text
        self.label = label
        self.notes = notes
        self.enabled = enabled
        self.groupName = groupName
        self.groupColor = groupColor
        self.thumbnailIndex = thumbnailIndex
        self.triggerIndex = triggerIndex
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
