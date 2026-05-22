import Foundation
import SwiftUI

actor ProPresenterAPI {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func base(_ host: String, _ port: Int) -> String {
        "http://\(host):\(port)"
    }

    // MARK: - Playlists

    func fetchPlaylists(host: String, port: Int) async throws -> [Playlist] {
        let url = URL(string: "\(base(host, port))/v1/playlists")!
        let (data, _) = try await session.data(from: url)
        let nodes = try JSONDecoder().decode([PlaylistNode].self, from: data)
        return nodes.compactMap { node in
            guard let id = node.id else { return nil }
            return Playlist(uuid: id.uuid, name: id.name)
        }
    }

    func fetchPlaylistItems(host: String, port: Int, uuid: String) async throws -> [Presentation] {
        let url = URL(string: "\(base(host, port))/v1/playlist/\(uuid)")!
        let (data, _) = try await session.data(from: url)
        let node = try JSONDecoder().decode(PlaylistNode.self, from: data)
        return node.allPresentations()
    }

    // MARK: - Active Presentation

    func fetchActivePresentation(host: String, port: Int, arrangementUUID: String? = nil) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/active")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePresentationResponse.self, from: data)
        return mapPayload(response.presentation, arrangementUUID: arrangementUUID)
    }

    // MARK: - Fetch Presentation by UUID (read-only)

    func fetchPresentation(host: String, port: Int, uuid: String, arrangementUUID: String? = nil) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/\(uuid)")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(ActivePresentationResponse.self, from: data) {
            return mapPayload(wrapped.presentation, arrangementUUID: arrangementUUID)
        }
        let payload = try decoder.decode(PresentationPayload.self, from: data)
        return mapPayload(payload, arrangementUUID: arrangementUUID)
    }

    // MARK: - Slide Status

    func fetchSlideIndex(host: String, port: Int) async throws -> (slideIndex: Int, presentationUUID: String?) {
        let url = URL(string: "\(base(host, port))/v1/presentation/slide_index")!
        let (data, _) = try await session.data(from: url)
        let r = try JSONDecoder().decode(SlideIndexPayload.self, from: data)
        return (r.presentationIndex?.index ?? 0, r.presentationIndex?.presentationId?.uuid)
    }

    // MARK: - Triggers

    func triggerNext(host: String, port: Int) async throws {
        let url = URL(string: "\(base(host, port))/v1/trigger/next")!
        _ = try await session.data(from: url)
    }

    func triggerPrevious(host: String, port: Int) async throws {
        let url = URL(string: "\(base(host, port))/v1/trigger/previous")!
        _ = try await session.data(from: url)
    }

    func triggerSlide(host: String, port: Int, uuid: String, index: Int) async throws {
        let url = URL(string: "\(base(host, port))/v1/presentation/\(uuid)/trigger/\(index)")!
        _ = try await session.data(from: url)
    }

    // MARK: - Thumbnails

    nonisolated func thumbnailURL(host: String, port: Int, uuid: String, index: Int) -> URL? {
        URL(string: "http://\(host):\(port)/v1/presentation/\(uuid)/thumbnail/\(index)")
    }

    // MARK: - Connection Test

    func testConnection(host: String, port: Int) async throws -> Bool {
        let url = URL(string: "\(base(host, port))/v1/presentation/slide_index")!
        let (_, resp) = try await session.data(from: url)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Mapping

    private func mapPayload(_ p: PresentationPayload, arrangementUUID: String? = nil) -> Presentation {
        // Build lookup: group UUID → (group, raw thumbnail start index)
        var rawStart = 0
        var groupByUUID: [String: (group: SlideGroupPayload, rawThumbStart: Int)] = [:]
        for group in p.groups {
            if let uuid = group.uuid {
                groupByUUID[uuid] = (group, rawStart)
            }
            rawStart += group.slides.count
        }

        // When current_arrangement is set, ProPresenter indexes thumbnails by that
        // arrangement's slide order. Build a mapping from (groupUUID, slideOffset) →
        // thumbnail index so we can look up the correct thumbnail for any arrangement.
        var thumbnailMap: [String: Int]?
        if let ca = p.currentArrangement, !ca.isEmpty,
           let caArr = p.arrangements?.first(where: { $0.id.uuid == ca }) {
            var map: [String: Int] = [:]
            var caIdx = 0
            for groupUUID in caArr.groups {
                if let entry = groupByUUID[groupUUID] {
                    for offset in 0..<entry.group.slides.count {
                        let key = "\(groupUUID)-\(offset)"
                        if map[key] == nil {
                            map[key] = caIdx
                        }
                        caIdx += 1
                    }
                }
            }
            thumbnailMap = map
        }

        // Resolve which arrangement to display
        let effectiveArrUUID = arrangementUUID ?? p.currentArrangement
        let arrangement = effectiveArrUUID.flatMap { arrUUID -> ArrangementPayload? in
            guard !arrUUID.isEmpty else { return nil }
            return p.arrangements?.first { $0.id.uuid == arrUUID }
        }

        var idx = 0
        var slides: [Slide] = []

        if let arrangement {
            for groupUUID in arrangement.groups {
                guard let entry = groupByUUID[groupUUID] else { continue }
                let group = entry.group
                let color: Color? = group.color.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
                for (offset, s) in group.slides.enumerated() {
                    let thumbIdx: Int
                    if let map = thumbnailMap {
                        thumbIdx = map["\(groupUUID)-\(offset)"] ?? -1
                    } else {
                        thumbIdx = entry.rawThumbStart + offset
                    }
                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: thumbIdx
                    ))
                    idx += 1
                }
            }
        } else {
            var thumbIdx = 0
            for group in p.groups {
                let color: Color? = group.color.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
                for s in group.slides {
                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: thumbIdx
                    ))
                    idx += 1
                    thumbIdx += 1
                }
            }
        }

        return Presentation(uuid: p.id.uuid, name: p.id.name, index: p.id.index, slides: slides, arrangementUUID: arrangementUUID)
    }
}
