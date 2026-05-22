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

    // MARK: - Fetch sidebar items (tries multiple strategies)

    func fetchSidebarItems(host: String, port: Int) async -> (items: [Presentation], debugLog: String) {
        var log = ""
        let decoder = JSONDecoder()

        // Strategy 1: /v1/playlists — get playlist list, then fetch each playlist's contents
        do {
            let url = URL(string: "\(base(host, port))/v1/playlists")!
            let (data, resp) = try await session.data(from: url)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            log += "[/v1/playlists] status=\(status) body=\(raw.prefix(800))\n"

            if status == 200 {
                // Try inline parsing first (items/children already populated)
                if let nodes = try? decoder.decode([PlaylistNode].self, from: data) {
                    let inline = nodes.flatMap { $0.allPresentations() }
                    if !inline.isEmpty {
                        log += "  -> parsed \(inline.count) presentations inline\n"
                        return (inline, log)
                    }

                    // Nodes found but no inline presentations — fetch each playlist individually
                    let playlistUUIDs = nodes.compactMap { $0.id?.uuid }
                    log += "  -> found \(playlistUUIDs.count) playlist UUIDs, fetching contents...\n"
                    var all: [Presentation] = []
                    for uuid in playlistUUIDs {
                        let fetched = await fetchPlaylistContents(host: host, port: port, uuid: uuid, log: &log)
                        all.append(contentsOf: fetched)
                    }
                    if !all.isEmpty {
                        log += "  -> total \(all.count) presentations from individual playlists\n"
                        return (all, log)
                    }
                }
                if let wrapper = try? decoder.decode(PlaylistListWrapper.self, from: data),
                   let playlists = wrapper.playlists {
                    let inline = playlists.flatMap { $0.allPresentations() }
                    if !inline.isEmpty {
                        log += "  -> parsed \(inline.count) presentations from wrapper\n"
                        return (inline, log)
                    }
                    let playlistUUIDs = playlists.compactMap { $0.id?.uuid }
                    log += "  -> found \(playlistUUIDs.count) playlist UUIDs (wrapper), fetching...\n"
                    var all: [Presentation] = []
                    for uuid in playlistUUIDs {
                        let fetched = await fetchPlaylistContents(host: host, port: port, uuid: uuid, log: &log)
                        all.append(contentsOf: fetched)
                    }
                    if !all.isEmpty { return (all, log) }
                }
                if let node = try? decoder.decode(PlaylistNode.self, from: data) {
                    let items = node.allPresentations()
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations from single node\n"
                        return (items, log)
                    }
                }
                log += "  -> could not extract presentations\n"
            }
        } catch {
            log += "[/v1/playlists] error: \(error.localizedDescription)\n"
        }

        // Strategy 2: /v1/playlist/active
        do {
            let url = URL(string: "\(base(host, port))/v1/playlist/active")!
            let (data, resp) = try await session.data(from: url)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            log += "[/v1/playlist/active] status=\(status) body=\(raw.prefix(800))\n"

            if status == 200 {
                if let node = try? decoder.decode(PlaylistNode.self, from: data) {
                    let items = node.allPresentations()
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations\n"
                        return (items, log)
                    }
                    // Active playlist found but empty inline — try fetching by UUID
                    if let uuid = node.id?.uuid {
                        log += "  -> active playlist UUID=\(uuid), fetching contents...\n"
                        let fetched = await fetchPlaylistContents(host: host, port: port, uuid: uuid, log: &log)
                        if !fetched.isEmpty { return (fetched, log) }
                    }
                }
                if let nodes = try? decoder.decode([PlaylistNode].self, from: data) {
                    let items = nodes.flatMap { $0.allPresentations() }
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations from array\n"
                        return (items, log)
                    }
                }
                log += "  -> could not extract presentations\n"
            }
        } catch {
            log += "[/v1/playlist/active] error: \(error.localizedDescription)\n"
        }

        // Strategy 3: /v1/presentations
        do {
            let url = URL(string: "\(base(host, port))/v1/presentations")!
            let (data, resp) = try await session.data(from: url)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            log += "[/v1/presentations] status=\(status) body=\(raw.prefix(800))\n"

            if status == 200 {
                if let items = try? decoder.decode([PresentationListItem].self, from: data) {
                    let result = items.map { Presentation(uuid: $0.id.uuid, name: $0.id.name, index: $0.id.index) }
                    if !result.isEmpty {
                        log += "  -> parsed \(result.count) presentations\n"
                        return (result, log)
                    }
                }
                if let wrapper = try? decoder.decode(PresentationListWrapper.self, from: data) {
                    let result = wrapper.presentations.map { Presentation(uuid: $0.id.uuid, name: $0.id.name, index: $0.id.index) }
                    if !result.isEmpty {
                        log += "  -> parsed \(result.count) presentations from wrapper\n"
                        return (result, log)
                    }
                }
                if let ids = try? decoder.decode([PresentationIdentifier].self, from: data) {
                    let result = ids.map { Presentation(uuid: $0.uuid, name: $0.name, index: $0.index) }
                    if !result.isEmpty {
                        log += "  -> parsed \(result.count) presentations flat\n"
                        return (result, log)
                    }
                }
                log += "  -> could not decode\n"
            }
        } catch {
            log += "[/v1/presentations] error: \(error.localizedDescription)\n"
        }

        log += "All strategies exhausted.\n"
        return ([], log)
    }

    // MARK: - Fetch Individual Playlist Contents

    private func fetchPlaylistContents(host: String, port: Int, uuid: String, log: inout String) async -> [Presentation] {
        do {
            let url = URL(string: "\(base(host, port))/v1/playlist/\(uuid)")!
            let (data, resp) = try await session.data(from: url)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            log += "  [/v1/playlist/\(uuid.prefix(8))...] status=\(status) body=\(raw.prefix(500))\n"

            guard status == 200 else { return [] }

            let decoder = JSONDecoder()
            if let node = try? decoder.decode(PlaylistNode.self, from: data) {
                let items = node.allPresentations()
                if !items.isEmpty {
                    log += "    -> \(items.count) presentations\n"
                    return items
                }
            }
            if let nodes = try? decoder.decode([PlaylistNode].self, from: data) {
                let items = nodes.flatMap { $0.allPresentations() }
                if !items.isEmpty {
                    log += "    -> \(items.count) presentations from array\n"
                    return items
                }
            }
            log += "    -> could not extract presentations\n"
        } catch {
            log += "  [/v1/playlist/\(uuid.prefix(8))...] error: \(error.localizedDescription)\n"
        }
        return []
    }

    // MARK: - Active Presentation

    func fetchActivePresentation(host: String, port: Int) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/active")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePresentationResponse.self, from: data)
        return mapPayload(response.presentation)
    }

    // MARK: - Fetch Presentation by UUID (read-only)

    func fetchPresentation(host: String, port: Int, uuid: String) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/\(uuid)")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(ActivePresentationResponse.self, from: data) {
            return mapPayload(wrapped.presentation)
        }
        let payload = try decoder.decode(PresentationPayload.self, from: data)
        return mapPayload(payload)
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

    private func mapPayload(_ p: PresentationPayload) -> Presentation {
        var idx = 0
        var slides: [Slide] = []
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
                    enabled: s.enabled,
                    groupName: group.name,
                    groupColor: color
                ))
                idx += 1
            }
        }
        return Presentation(uuid: p.id.uuid, name: p.id.name, index: p.id.index, slides: slides)
    }
}
