import Foundation
import SwiftUI

@Observable
@MainActor
final class ProPresenterViewModel {
    // MARK: - State

    static let liveColor = Color(red: 0.91, green: 0.41, blue: 0.15)

    var playlists: [Playlist] = []
    var selectedPlaylist: Playlist?
    var playlistItems: [Presentation] = []
    var selectedPresentation: Presentation?
    var liveSlideIndex: Int = 0
    var livePresentationUUID: String = ""
    var isConnected: Bool = false
    var isWebSocketConnected: Bool = false
    var connectionError: String?
    var showSettings: Bool = false
    var apiDebugLog: String = ""

    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "pp_host") }
    }
    var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "pp_port") }
    }
    var companionButtons: [CompanionButton] {
        didSet { saveCompanionButtons() }
    }

    // MARK: - Dependencies

    private let api = ProPresenterAPI()
    private let webSocket = WebSocketManager()
    private var pollTask: Task<Void, Never>?

    // MARK: - Computed

    var portInt: Int { Int(port) ?? 1025 }

    var isViewingLivePresentation: Bool {
        selectedPresentation?.uuid == livePresentationUUID
    }

    var currentSlideIndex: Int {
        isViewingLivePresentation ? liveSlideIndex : 0
    }

    var currentSlide: Slide? {
        guard isViewingLivePresentation else { return nil }
        return selectedPresentation?.slides[safe: liveSlideIndex]
    }

    var nextSlideIndex: Int? {
        guard isViewingLivePresentation,
              let slides = selectedPresentation?.slides,
              liveSlideIndex + 1 < slides.count else { return nil }
        return liveSlideIndex + 1
    }

    // MARK: - Init

    init() {
        host = UserDefaults.standard.string(forKey: "pp_host") ?? ""
        port = UserDefaults.standard.string(forKey: "pp_port") ?? "1025"
        companionButtons = Self.loadCompanionButtons()

        webSocket.onSlideChanged = { [weak self] in
            Task { await self?.fetchSlideStatus() }
        }
        webSocket.onConnectionChange = { [weak self] connected in
            self?.isWebSocketConnected = connected
        }
    }

    // MARK: - Connection

    func connect() async {
        guard !host.isEmpty else {
            connectionError = "Enter a host address"
            return
        }
        connectionError = nil
        do {
            let ok = try await api.testConnection(host: host, port: portInt)
            guard ok else {
                connectionError = "Server returned an error"
                return
            }
            isConnected = true
            webSocket.connect(host: host, port: portInt)
            await refreshAll()
            startPolling()
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }
    }

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        webSocket.disconnect()
        isConnected = false
        playlists = []
        selectedPlaylist = nil
        playlistItems = []
        selectedPresentation = nil
    }

    func testConnection() async -> Bool {
        connectionError = nil
        do {
            return try await api.testConnection(host: host, port: portInt)
        } catch {
            connectionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                await self.fetchSlideStatus()
                await self.fetchActivePresentation()
            }
        }
    }

    // MARK: - Data Loading

    func refreshAll() async {
        await fetchPlaylists()
        await fetchActivePresentation()
        await fetchSlideStatus()
    }

    func fetchPlaylists() async {
        guard let fetched = try? await api.fetchPlaylists(host: host, port: portInt) else { return }
        playlists = fetched
    }

    func selectPlaylist(_ playlist: Playlist) async {
        if playlist.uuid == selectedPlaylist?.uuid { return }
        selectedPlaylist = playlist
        guard let items = try? await api.fetchPlaylistItems(host: host, port: portInt, uuid: playlist.uuid) else {
            playlistItems = []
            return
        }
        playlistItems = items
        if let live = items.first(where: { $0.uuid == livePresentationUUID }) {
            await selectPresentation(live)
        } else if let first = items.first {
            await selectPresentation(first)
        }
    }

    func fetchActivePresentation() async {
        guard let active = try? await api.fetchActivePresentation(host: host, port: portInt) else { return }
        let wasViewingLive = selectedPresentation == nil || selectedPresentation?.uuid == livePresentationUUID
        livePresentationUUID = active.uuid
        if wasViewingLive {
            selectedPresentation = active
        }
        if selectedPlaylist == nil {
            for playlist in playlists {
                if let items = try? await api.fetchPlaylistItems(host: host, port: portInt, uuid: playlist.uuid),
                   items.contains(where: { $0.uuid == active.uuid }) {
                    selectedPlaylist = playlist
                    playlistItems = items
                    break
                }
            }
        }
    }

    func fetchSlideStatus() async {
        guard let status = try? await api.fetchSlideIndex(host: host, port: portInt) else { return }
        let previousUUID = livePresentationUUID
        liveSlideIndex = status.slideIndex
        if let uuid = status.presentationUUID {
            livePresentationUUID = uuid
            if uuid != previousUUID {
                await fetchActivePresentation()
            }
        }
    }

    // MARK: - Selection (read-only, never pushes state)

    func selectPresentation(_ presentation: Presentation) async {
        if presentation.uuid == selectedPresentation?.uuid { return }
        do {
            let full = try await api.fetchPresentation(host: host, port: portInt, uuid: presentation.uuid)
            selectedPresentation = full
        } catch {
            selectedPresentation = presentation
        }
    }

    // MARK: - Actions (only called by explicit user interaction)

    func triggerSlide(at index: Int) async {
        guard let pres = selectedPresentation else { return }
        liveSlideIndex = index
        livePresentationUUID = pres.uuid
        try? await api.triggerSlide(host: host, port: portInt, uuid: pres.uuid, index: index)
        await fetchSlideStatus()
    }

    func triggerNext() async {
        try? await api.triggerNext(host: host, port: portInt)
        await fetchSlideStatus()
    }

    func triggerPrevious() async {
        try? await api.triggerPrevious(host: host, port: portInt)
        await fetchSlideStatus()
    }

    func selectNextPresentation() async {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.uuid == current.uuid }),
              idx + 1 < playlistItems.count else { return }
        await selectPresentation(playlistItems[idx + 1])
    }

    func selectPreviousPresentation() async {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.uuid == current.uuid }),
              idx > 0 else { return }
        await selectPresentation(playlistItems[idx - 1])
    }

    func thumbnailURL(for index: Int) -> URL? {
        guard let pres = selectedPresentation else { return nil }
        return api.thumbnailURL(host: host, port: portInt, uuid: pres.uuid, index: index)
    }

    func triggerCompanionButton(_ button: CompanionButton) async {
        guard let url = button.url else { return }
        _ = try? await URLSession.shared.data(from: url)
    }

    // MARK: - Persistence

    private func saveCompanionButtons() {
        if let data = try? JSONEncoder().encode(companionButtons) {
            UserDefaults.standard.set(data, forKey: "pp_companionButtons")
        }
    }

    private static func loadCompanionButtons() -> [CompanionButton] {
        guard let data = UserDefaults.standard.data(forKey: "pp_companionButtons"),
              let buttons = try? JSONDecoder().decode([CompanionButton].self, from: data) else {
            return []
        }
        return buttons
    }
}
