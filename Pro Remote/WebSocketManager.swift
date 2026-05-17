import Foundation

@MainActor
final class WebSocketManager {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var reconnectWork: Task<Void, Never>?
    private var shouldReconnect = false
    private var host = ""
    private var port = 1025

    var onSlideUpdate: ((_ slideIndex: Int, _ presentationUUID: String) -> Void)?
    var onConnectionChange: ((_ connected: Bool) -> Void)?

    func connect(host: String, port: Int) {
        self.host = host
        self.port = port
        shouldReconnect = true
        tearDown()

        guard let url = URL(string: "ws://\(host):\(port)/v1/status/slide") else { return }
        task = session.webSocketTask(with: url)
        task?.resume()
        onConnectionChange?(true)
        receive()
    }

    func disconnect() {
        shouldReconnect = false
        tearDown()
        onConnectionChange?(false)
    }

    private func tearDown() {
        reconnectWork?.cancel()
        reconnectWork = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receive() {
        guard let task else { return }
        Task { [weak self] in
            do {
                let message = try await task.receive()
                guard let self else { return }
                self.handle(message)
                self.receive()
            } catch {
                guard let self else { return }
                self.onConnectionChange?(false)
                self.scheduleReconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let d): data = d
        @unknown default: data = nil
        }
        guard let data else { return }

        if let status = try? JSONDecoder().decode(SlideStatusPayload.self, from: data),
           let current = status.current {
            let uuid = current.presentationIndex?.presentationId?.uuid ?? ""
            onSlideUpdate?(current.slideIndex, uuid)
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        reconnectWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            self.connect(host: self.host, port: self.port)
        }
    }
}
