import Foundation

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

    // MARK: - Fetch sidebar items (tries multiple strategies)

    func fetchSidebarItems(host: String, port: Int) async -> (items: [Presentation], debugLog: String) {
        var log = ""

        // Strategy 1: /v1/playlists
        do {
            let url = URL(string: "\(base(host, port))/v1/playlists")!
            let (data, resp) = try await session.data(from: url)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            log += "[/v1/playlists] status=\(status) body=\(raw.prefix(500))\n"

            if status == 200 {
                let decoder = JSONDecoder()
                // Try as array of playlist nodes
                if let nodes = try? decoder.decode([PlaylistNode].self, from: data) {
                    let items = nodes.flatMap { $0.allPresentations() }
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations from array\n"
                        return (items, log)
                    }
                }
                // Try as wrapper
                if let wrapper = try? decoder.decode(PlaylistListWrapper.self, from: data),
                   let playlists = wrapper.playlists {
                    let items = playlists.flatMap { $0.allPresentations() }
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations from wrapper\n"
                        return (items, log)
                    }
                }
                // Try the data as a single playlist node
                if let node = try? decoder.decode(PlaylistNode.self, from: data) {
                    let items = node.allPresentations()
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations from single node\n"
                        return (items, log)
                    }
                }
                log += "  -> could not decode\n"
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
            log += "[/v1/playlist/active] status=\(status) body=\(raw.prefix(500))\n"

            if status == 200 {
                let decoder = JSONDecoder()
                if let node = try? decoder.decode(PlaylistNode.self, from: data) {
                    let items = node.allPresentations()
                    if !items.isEmpty {
                        log += "  -> parsed \(items.count) presentations\n"
                        return (items, log)
                    }
                }
                log += "  -> could not decode\n"
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
            log += "[/v1/presentations] status=\(status) body=\(raw.prefix(500))\n"

            if status == 200 {
                let decoder = JSONDecoder()
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

        log += "All strategies failed.\n"
        return ([], log)
    }

    // MARK: - Active Presentation

    func fetchActivePresentation(host: String, port: Int) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/active")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePresentationResponse.self, from: data)
        return mapPayload(response.presentation)
    }

    // MARK: - Slide Status

    func fetchSlideStatus(host: String, port: Int) async throws -> (slideIndex: Int, presentationUUID: String?) {
        let url = URL(string: "\(base(host, port))/v1/status/slide")!
        let (data, _) = try await session.data(from: url)
        let r = try JSONDecoder().decode(SlideStatusPayload.self, from: data)
        return (r.current?.slideIndex ?? 0, r.current?.presentationIndex?.presentationId?.uuid)
    }

    // MARK: - Triggers

    func triggerNext(host: String, port: Int) async throws {
        var req = URLRequest(url: URL(string: "\(base(host, port))/v1/trigger/next")!)
        req.httpMethod = "POST"
        _ = try await session.data(for: req)
    }

    func triggerPrevious(host: String, port: Int) async throws {
        var req = URLRequest(url: URL(string: "\(base(host, port))/v1/trigger/previous")!)
        req.httpMethod = "POST"
        _ = try await session.data(for: req)
    }

    func triggerSlide(host: String, port: Int, uuid: String, index: Int) async throws {
        var req = URLRequest(url: URL(string: "\(base(host, port))/v1/presentation/\(uuid)/trigger/\(index)")!)
        req.httpMethod = "POST"
        _ = try await session.data(for: req)
    }

    // MARK: - Thumbnails

    nonisolated func thumbnailURL(host: String, port: Int, uuid: String, index: Int) -> URL? {
        URL(string: "http://\(host):\(port)/v1/presentation/\(uuid)/thumbnail/\(index)")
    }

    // MARK: - Connection Test

    func testConnection(host: String, port: Int) async throws -> Bool {
        let url = URL(string: "\(base(host, port))/v1/status/slide")!
        let (_, resp) = try await session.data(from: url)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Mapping

    private func mapPayload(_ p: PresentationPayload) -> Presentation {
        var idx = 0
        var slides: [Slide] = []
        for group in p.groups {
            for s in group.slides {
                slides.append(Slide(
                    id: idx,
                    text: s.text,
                    notes: s.notes,
                    enabled: s.enabled,
                    groupName: group.name
                ))
                idx += 1
            }
        }
        return Presentation(uuid: p.id.uuid, name: p.id.name, index: p.id.index, slides: slides)
    }
}
