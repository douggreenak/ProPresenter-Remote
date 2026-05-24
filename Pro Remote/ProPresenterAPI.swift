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

    private func buildURL(_ host: String, _ port: Int, path: String) throws -> URL {
        guard let url = URL(string: "\(base(host, port))\(path)") else {
            throw URLError(.badURL)
        }
        return url
    }

    // MARK: - Playlists

    func fetchPlaylists(host: String, port: Int) async throws -> [Playlist] {
        let url = try buildURL(host, port, path: "/v1/playlists")
        let (data, _) = try await session.data(from: url)
        let nodes = try JSONDecoder().decode([PlaylistNode].self, from: data)
        return nodes.compactMap { node in
            guard let id = node.id else { return nil }
            return Playlist(uuid: id.uuid, name: id.name)
        }
    }

    func fetchPlaylistItems(host: String, port: Int, uuid: String) async throws -> [Presentation] {
        let url = try buildURL(host, port, path: "/v1/playlist/\(uuid)")
        let (data, _) = try await session.data(from: url)
        let node = try JSONDecoder().decode(PlaylistNode.self, from: data)
        return node.allPresentations()
    }

    // MARK: - Active Presentation

    func fetchActivePresentation(host: String, port: Int, arrangementUUID: String? = nil) async throws -> Presentation {
        let url = try buildURL(host, port, path: "/v1/presentation/active")
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePresentationResponse.self, from: data)
        return mapPayload(response.presentation, arrangementUUID: arrangementUUID)
    }

    // MARK: - Fetch Presentation by UUID (read-only)

    func fetchPresentation(host: String, port: Int, uuid: String, arrangementUUID: String? = nil) async throws -> Presentation {
        let url = try buildURL(host, port, path: "/v1/presentation/\(uuid)")
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
        let url = try buildURL(host, port, path: "/v1/presentation/slide_index")
        let (data, _) = try await session.data(from: url)
        let r = try JSONDecoder().decode(SlideIndexPayload.self, from: data)
        return (r.presentationIndex?.index ?? 0, r.presentationIndex?.presentationId?.uuid)
    }

    // MARK: - Triggers

    func triggerNext(host: String, port: Int) async throws {
        let url = try buildURL(host, port, path: "/v1/trigger/next")
        _ = try await session.data(from: url)
    }

    func triggerPrevious(host: String, port: Int) async throws {
        let url = try buildURL(host, port, path: "/v1/trigger/previous")
        _ = try await session.data(from: url)
    }

    func triggerSlide(host: String, port: Int, uuid: String, index: Int) async throws {
        let url = try buildURL(host, port, path: "/v1/presentation/\(uuid)/trigger/\(index)")
        _ = try await session.data(from: url)
    }

    // MARK: - Thumbnails

    nonisolated func thumbnailURL(host: String, port: Int, uuid: String, index: Int) -> URL? {
        URL(string: "http://\(host):\(port)/v1/presentation/\(uuid)/thumbnail/\(index)")
    }

    // MARK: - Connection Test

    func testConnection(host: String, port: Int) async throws -> Bool {
        let url = try buildURL(host, port, path: "/v1/presentation/slide_index")
        let (_, resp) = try await session.data(from: url)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Mapping

    private func mapPayload(_ p: PresentationPayload, arrangementUUID: String? = nil) -> Presentation {
        var groupByUUID: [String: (group: SlideGroupPayload, rawStart: Int)] = [:]
        var rawStart = 0
        for group in p.groups {
            if let uuid = group.uuid {
                groupByUUID[uuid] = (group, rawStart)
            }
            rawStart += group.slides.count
        }

        let effectiveArrUUID = arrangementUUID ?? p.currentArrangement
        let displayArrangement = effectiveArrUUID.flatMap { arrUUID -> ArrangementPayload? in
            guard !arrUUID.isEmpty else { return nil }
            return p.arrangements?.first { $0.id.uuid == arrUUID }
        }

        let currentArrUUID = p.currentArrangement ?? ""
        let triggerArrangement = currentArrUUID.isEmpty ? nil : p.arrangements?.first { $0.id.uuid == currentArrUUID }

        // Build trigger context: the ordered slides that the API trigger/thumbnail endpoints use.
        // When current_arrangement is set, trigger indices follow that arrangement.
        // When empty, trigger indices follow raw group order.
        typealias TriggerEntry = (groupUUID: String, slideOffset: Int, triggerIndex: Int)
        var triggerContext: [TriggerEntry] = []

        if let triggerArrangement {
            var tIdx = 0
            for gUUID in triggerArrangement.groups {
                guard let entry = groupByUUID[gUUID] else { continue }
                for offset in 0..<entry.group.slides.count {
                    triggerContext.append((gUUID, offset, tIdx))
                    tIdx += 1
                }
            }
        } else {
            var tIdx = 0
            for group in p.groups {
                guard let gUUID = group.uuid else { continue }
                for offset in 0..<group.slides.count {
                    triggerContext.append((gUUID, offset, tIdx))
                    tIdx += 1
                }
            }
        }

        // Group trigger entries by (groupUUID, slideOffset) preserving order
        var triggerLookup: [String: [Int]] = [:]
        for entry in triggerContext {
            let key = "\(entry.groupUUID)|\(entry.slideOffset)"
            triggerLookup[key, default: []].append(entry.triggerIndex)
        }

        // Track how many times each (group, offset) pair has been seen in the display arrangement
        var occurrenceCounters: [String: Int] = [:]

        var idx = 0
        var slides: [Slide] = []
        var triggerToDisplay: [Int: [Int]] = [:]

        if let displayArrangement {
            for groupUUID in displayArrangement.groups {
                guard let entry = groupByUUID[groupUUID] else { continue }
                let group = entry.group
                let color: Color? = group.color.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
                for (offset, s) in group.slides.enumerated() {
                    let key = "\(groupUUID)|\(offset)"
                    let occurrence = occurrenceCounters[key, default: 0]
                    occurrenceCounters[key] = occurrence + 1

                    let availableTriggers = triggerLookup[key] ?? []
                    let triggerIdx: Int? = availableTriggers.isEmpty ? nil :
                        availableTriggers[occurrence % availableTriggers.count]

                    if let triggerIdx {
                        triggerToDisplay[triggerIdx, default: []].append(idx)
                    }

                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: triggerIdx,
                        triggerIndex: triggerIdx
                    ))
                    idx += 1
                }
            }
        } else {
            for group in p.groups {
                let color: Color? = group.color.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
                for (offset, s) in group.slides.enumerated() {
                    let tIdx = idx
                    triggerToDisplay[tIdx, default: []].append(idx)

                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: tIdx,
                        triggerIndex: tIdx
                    ))
                    idx += 1
                }
            }
        }

        return Presentation(uuid: p.id.uuid, name: p.id.name, index: p.id.index, slides: slides, arrangementUUID: arrangementUUID, triggerToDisplayMap: triggerToDisplay)
    }
}
