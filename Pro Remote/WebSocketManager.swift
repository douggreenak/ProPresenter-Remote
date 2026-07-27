import Foundation

@MainActor
final class WebSocketManager {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var reconnectWork: Task<Void, Never>?
    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private var host = ""
    private var port = 1025

    var onSlideChanged: (() -> Void)?

    func connect(host: String, port: Int) {
        self.host = host
        self.port = port
        shouldReconnect = true
        reconnectAttempts = 0
        openSocket()
    }

    /// Opens the socket without touching `reconnectAttempts`. Retries must come through here:
    /// routing them via `connect(host:port:)` reset the counter every time, which pinned the
    /// backoff at its first step (3s) forever instead of easing off to 30s.
    private func openSocket() {
        tearDown()
        guard let url = URL(string: "ws://\(host):\(port)/v1/status/slide") else { return }
        task = session.webSocketTask(with: url)
        task?.resume()
        receive()
    }

    func disconnect() {
        shouldReconnect = false
        tearDown()
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
                // A torn-down socket's pending receive still lands here; ignore it, or a
                // stale failure schedules a reconnect that kills the socket we just opened.
                guard let self, self.task === task else { return }
                self.handle(message)
                self.receive()
            } catch {
                guard let self, self.task === task else { return }
                self.scheduleReconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        reconnectAttempts = 0
        onSlideChanged?()
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        let delay = min(3.0 * pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1
        reconnectWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.openSocket()
        }
    }
}
