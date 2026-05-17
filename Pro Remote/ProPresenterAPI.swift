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

    // MARK: - Presentations

    func fetchPresentations(host: String, port: Int) async throws -> [Presentation] {
        let url = URL(string: "\(base(host, port))/v1/presentations")!
        let (data, _) = try await session.data(from: url)
        let items = try JSONDecoder().decode([PresentationListItem].self, from: data)
        return items.map {
            Presentation(uuid: $0.id.uuid, name: $0.id.name, index: $0.id.index)
        }
    }

    func fetchActivePresentation(host: String, port: Int) async throws -> Presentation {
        let url = URL(string: "\(base(host, port))/v1/presentation/active")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePresentationResponse.self, from: data)
        return mapPayload(response.presentation)
    }

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
