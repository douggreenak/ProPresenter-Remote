import Foundation
import Network

/// A ProPresenter instance found on the local network.
struct DiscoveredServer: Identifiable, Hashable {
    /// Bonjour instance name — the machine name ProPresenter shows in its Network settings.
    let name: String
    let host: String
    let port: Int

    var id: String { "\(name)|\(host)|\(port)" }
}

/// Finds ProPresenter machines over Bonjour so a connection can be set up without knowing
/// the IP. ProPresenter advertises its network API as `_proapiv1ws._tcp`, and the advertised
/// port is the one in its Network settings — which is also the port the REST API listens on.
@Observable
@MainActor
final class ProPresenterDiscovery {
    static let serviceType = "_proapiv1ws._tcp"

    private(set) var servers: [DiscoveredServer] = []
    private(set) var isBrowsing = false
    private(set) var errorMessage: String?

    private var browser: NWBrowser?
    private var resolveTasks: [String: Task<Void, Never>] = [:]

    var hasSearched: Bool { browser != nil }

    func start() {
        guard browser == nil else { return }
        errorMessage = nil

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: NWParameters())

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isBrowsing = true
                case .failed(let error):
                    // Most often this is the user declining local network access.
                    self.errorMessage = error.localizedDescription
                    self.stop()
                case .cancelled:
                    self.isBrowsing = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.apply(results)
            }
        }

        self.browser = browser
        isBrowsing = true
        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        for task in resolveTasks.values { task.cancel() }
        resolveTasks.removeAll()
    }

    func restart() {
        stop()
        servers = []
        start()
    }

    private func apply(_ results: Set<NWBrowser.Result>) {
        var present: Set<String> = []

        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            present.insert(name)
            guard resolveTasks[name] == nil, !servers.contains(where: { $0.name == name }) else { continue }

            resolveTasks[name] = Task { [weak self] in
                let resolved = await Self.resolve(result.endpoint)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.resolveTasks[name] = nil
                    guard let resolved else { return }
                    let server = DiscoveredServer(name: name, host: resolved.host, port: resolved.port)
                    guard !self.servers.contains(where: { $0.id == server.id }) else { return }
                    self.servers.append(server)
                    self.servers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
            }
        }

        // Drop machines that have gone off the network.
        servers.removeAll { !present.contains($0.name) }
        for (name, task) in resolveTasks where !present.contains(name) {
            task.cancel()
            resolveTasks[name] = nil
        }
    }

    private static func resolve(_ endpoint: NWEndpoint) async -> (host: String, port: Int)? {
        await resolveEndpoint(endpoint)
    }
}

// MARK: - Resolution

/// How long to wait for a service to resolve to an address before giving up on it.
private nonisolated let resolveTimeout: TimeInterval = 5

/// Guards a continuation so it resumes exactly once, however the connection ends.
/// Network callbacks arrive off the main actor, so this stays nonisolated.
private nonisolated final class ResolveOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns true for the first caller only.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

/// Browsing yields a service endpoint, not an address. Opening a short-lived connection makes
/// the system resolve it, and the established path carries the real host and port. It also
/// means only machines we can actually reach get listed.
private nonisolated func resolveEndpoint(_ endpoint: NWEndpoint) async -> (host: String, port: Int)? {
    let queue = DispatchQueue(label: "com.douggreenak.proremote.resolve")
    let once = ResolveOnce()

    return await withCheckedContinuation { continuation in
        let connection = NWConnection(to: endpoint, using: .tcp)

        @Sendable func finish(_ value: (host: String, port: Int)?) {
            guard once.claim() else { return }
            connection.cancel()
            continuation.resume(returning: value)
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                guard let remote = connection.currentPath?.remoteEndpoint,
                      case let .hostPort(host, port) = remote else {
                    finish(nil)
                    return
                }
                finish((addressString(of: host), Int(port.rawValue)))
            case .failed, .cancelled:
                finish(nil)
            default:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + resolveTimeout) { finish(nil) }
        connection.start(queue: queue)
    }
}

private nonisolated func addressString(of host: NWEndpoint.Host) -> String {
    switch host {
    case .ipv4(let address):
        // Addresses print with an interface suffix when scoped ("169.254.1.1%en0").
        return "\(address)".components(separatedBy: "%").first ?? "\(address)"
    case .ipv6(let address):
        return "\(address)".components(separatedBy: "%").first ?? "\(address)"
    case .name(let name, _):
        return name
    @unknown default:
        return ""
    }
}
