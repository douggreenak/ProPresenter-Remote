import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    private var userOverrodeSelection: Bool = false
    var isConnected: Bool = false
    var isLoading: Bool = false
    var connectionHealthy: Bool = false
    private var pollFailureCount: Int = 0
    private var lastUserTrigger: ContinuousClock.Instant?
    var connectionError: String?
    var showSettings: Bool = false
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
    private var presentationCache: [String: Presentation] = [:]

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

    var canTriggerNext: Bool {
        guard let pres = selectedPresentation else { return false }
        let currentIndex = isViewingLivePresentation ? liveSlideIndex : -1
        return pres.slides.contains { $0.index > currentIndex && $0.enabled && $0.triggerIndex != nil }
    }

    var canTriggerPrevious: Bool {
        guard let pres = selectedPresentation else { return false }
        let currentIndex = isViewingLivePresentation ? liveSlideIndex : pres.slides.count
        return pres.slides.contains { $0.index < currentIndex && $0.enabled && $0.triggerIndex != nil }
    }

    var canSelectNextPresentation: Bool {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.listID == current.listID }) else { return false }
        return idx + 1 < playlistItems.count
    }

    var canSelectPreviousPresentation: Bool {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.listID == current.listID }) else { return false }
        return idx > 0
    }

    // MARK: - Init

    init() {
        host = UserDefaults.standard.string(forKey: "pp_host") ?? ""
        port = UserDefaults.standard.string(forKey: "pp_port") ?? "1025"
        companionButtons = Self.loadCompanionButtons()

        webSocket.onSlideChanged = { [weak self] in
            Task { await self?.fetchSlideStatus() }
        }
    }

    // MARK: - Connection

    func connect() async {
        guard !host.isEmpty else {
            connectionError = "Enter a host address"
            return
        }
        guard !isLoading else { return }
        connectionError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let ok = try await api.testConnection(host: host, port: portInt)
            guard ok else {
                connectionError = "Server returned an error"
                return
            }
            isConnected = true
            connectionHealthy = true
            pollFailureCount = 0
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
        connectionHealthy = false
        connectionError = nil
        playlists = []
        selectedPlaylist = nil
        playlistItems = []
        selectedPresentation = nil
        presentationCache.removeAll()
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
            }
        }
    }

    // MARK: - Data Loading

    func refreshAll() async {
        presentationCache.removeAll()
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
        userOverrodeSelection = true
        selectedPlaylist = playlist
        guard let items = try? await api.fetchPlaylistItems(host: host, port: portInt, uuid: playlist.uuid) else {
            playlistItems = []
            return
        }
        playlistItems = items
        if let live = items.first(where: { $0.uuid == livePresentationUUID }) {
            userOverrodeSelection = false
            await selectPresentation(live)
        } else if let first = items.first {
            await loadPresentation(first)
        }
    }

    func fetchActivePresentation() async {
        let knownArrUUID = playlistItems.first(where: { $0.uuid == livePresentationUUID })?.arrangementUUID
        guard var active = try? await api.fetchActivePresentation(host: host, port: portInt, arrangementUUID: knownArrUUID) else { return }
        let previousLiveUUID = livePresentationUUID
        livePresentationUUID = active.uuid

        let cacheKey = "\(active.uuid)|\(active.arrangementUUID ?? "")"
        presentationCache[cacheKey] = active

        if !userOverrodeSelection || selectedPresentation == nil {
            if !playlistItems.contains(where: { $0.uuid == active.uuid }) || selectedPlaylist == nil {
                await findAndSelectPlaylistContaining(active.uuid)
                if let arrUUID = playlistItems.first(where: { $0.uuid == active.uuid })?.arrangementUUID,
                   active.arrangementUUID != arrUUID,
                   let corrected = try? await api.fetchActivePresentation(host: host, port: portInt, arrangementUUID: arrUUID) {
                    active = corrected
                    let correctedKey = "\(active.uuid)|\(active.arrangementUUID ?? "")"
                    presentationCache[correctedKey] = active
                }
            }
            active.itemUUID = playlistItems.first(where: { $0.uuid == active.uuid })?.itemUUID
            selectedPresentation = active
        }

        if active.uuid != previousLiveUUID && userOverrodeSelection {
            if let matchingItem = playlistItems.first(where: { $0.uuid == active.uuid }) {
                userOverrodeSelection = false
                if matchingItem.arrangementUUID != active.arrangementUUID,
                   let corrected = try? await api.fetchActivePresentation(host: host, port: portInt, arrangementUUID: matchingItem.arrangementUUID) {
                    active = corrected
                    let correctedKey = "\(active.uuid)|\(active.arrangementUUID ?? "")"
                    presentationCache[correctedKey] = active
                }
                active.itemUUID = matchingItem.itemUUID
                selectedPresentation = active
            }
        }
    }

    private func findAndSelectPlaylistContaining(_ presentationUUID: String) async {
        for playlist in playlists {
            if let items = try? await api.fetchPlaylistItems(host: host, port: portInt, uuid: playlist.uuid),
               items.contains(where: { $0.uuid == presentationUUID }) {
                selectedPlaylist = playlist
                playlistItems = items
                return
            }
        }
    }

    func fetchSlideStatus() async {
        guard let status = try? await api.fetchSlideIndex(host: host, port: portInt) else {
            pollFailureCount += 1
            if pollFailureCount >= 5 {
                connectionHealthy = false
            }
            return
        }

        pollFailureCount = 0
        connectionHealthy = true

        let previousUUID = livePresentationUUID
        let triggerIdx = status.slideIndex

        let recentTrigger = lastUserTrigger.map { ContinuousClock.now - $0 < .milliseconds(1500) } ?? false
        if !recentTrigger {
            if let pres = selectedPresentation,
               pres.uuid == (status.presentationUUID ?? livePresentationUUID),
               let candidates = pres.triggerToDisplayMap[triggerIdx],
               !candidates.isEmpty {
                liveSlideIndex = candidates.first(where: { $0 >= liveSlideIndex }) ?? candidates.first!
            } else {
                liveSlideIndex = triggerIdx
            }
        }

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
        if presentation.uuid != livePresentationUUID {
            userOverrodeSelection = true
        } else {
            userOverrodeSelection = false
        }
        await loadPresentation(presentation)
    }

    private func loadPresentation(_ presentation: Presentation) async {
        if presentation.uuid == selectedPresentation?.uuid &&
           presentation.listID == selectedPresentation?.listID { return }

        let cacheKey = "\(presentation.uuid)|\(presentation.arrangementUUID ?? "")"

        if var cached = presentationCache[cacheKey] {
            cached.itemUUID = presentation.itemUUID
            selectedPresentation = cached
            return
        }

        if presentation.uuid == livePresentationUUID {
            do {
                var full = try await api.fetchActivePresentation(host: host, port: portInt, arrangementUUID: presentation.arrangementUUID)
                full.itemUUID = presentation.itemUUID
                presentationCache[cacheKey] = full
                selectedPresentation = full
                return
            } catch { }
        }

        do {
            var full = try await api.fetchPresentation(host: host, port: portInt, uuid: presentation.uuid, arrangementUUID: presentation.arrangementUUID)
            full.itemUUID = presentation.itemUUID
            presentationCache[cacheKey] = full
            selectedPresentation = full
        } catch {
            selectedPresentation = presentation
        }
    }

    // MARK: - Actions (only called by explicit user interaction)

    func triggerSlide(at index: Int) async {
        guard let pres = selectedPresentation,
              let slide = pres.slides[safe: index],
              let triggerIdx = slide.triggerIndex else { return }
        liveSlideIndex = index
        livePresentationUUID = pres.uuid
        lastUserTrigger = .now
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        try? await api.triggerSlide(host: host, port: portInt, uuid: pres.uuid, index: triggerIdx)
        try? await api.focusPresentation(host: host, port: portInt, uuid: pres.uuid)
    }

    func triggerNext() async {
        guard let pres = selectedPresentation else { return }
        let currentIndex = isViewingLivePresentation ? liveSlideIndex : -1
        guard let next = pres.slides.first(where: { $0.index > currentIndex && $0.enabled && $0.triggerIndex != nil }) else { return }
        await triggerSlide(at: next.index)
    }

    func triggerPrevious() async {
        guard let pres = selectedPresentation else { return }
        let currentIndex = isViewingLivePresentation ? liveSlideIndex : pres.slides.count
        guard let prev = pres.slides.last(where: { $0.index < currentIndex && $0.enabled && $0.triggerIndex != nil }) else { return }
        await triggerSlide(at: prev.index)
    }

    func goToLive() async {
        guard !livePresentationUUID.isEmpty else { return }
        userOverrodeSelection = false
        if let liveItem = playlistItems.first(where: { $0.uuid == livePresentationUUID }) {
            await loadPresentation(liveItem)
        } else {
            await fetchActivePresentation()
        }
    }

    func selectNextPresentation() async {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.listID == current.listID }),
              idx + 1 < playlistItems.count else { return }
        await selectPresentation(playlistItems[idx + 1])
    }

    func selectPreviousPresentation() async {
        guard let current = selectedPresentation,
              let idx = playlistItems.firstIndex(where: { $0.listID == current.listID }),
              idx > 0 else { return }
        await selectPresentation(playlistItems[idx - 1])
    }

    func thumbnailURL(for index: Int?) -> URL? {
        guard let index, let pres = selectedPresentation else { return nil }
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
