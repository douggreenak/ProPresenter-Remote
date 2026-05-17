import Foundation
import SwiftUI

@Observable
@MainActor
final class ProPresenterViewModel {
    // MARK: - State

    var presentations: [Presentation] = []
    var selectedPresentation: Presentation?
    var currentSlideIndex: Int = 0
    var livePresentationUUID: String = ""
    var isConnected: Bool = false
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

    // MARK: - Computed

    var portInt: Int { Int(port) ?? 1025 }

    var currentSlide: Slide? {
        selectedPresentation?.slides[safe: currentSlideIndex]
    }

    var nextSlideIndex: Int? {
        guard let slides = selectedPresentation?.slides,
              currentSlideIndex + 1 < slides.count else { return nil }
        return currentSlideIndex + 1
    }

    // MARK: - Init

    init() {
        host = UserDefaults.standard.string(forKey: "pp_host") ?? ""
        port = UserDefaults.standard.string(forKey: "pp_port") ?? "1025"
        companionButtons = Self.loadCompanionButtons()

        webSocket.onSlideUpdate = { [weak self] index, uuid in
            self?.handleSlideUpdate(index: index, uuid: uuid)
        }
        webSocket.onConnectionChange = { [weak self] connected in
            self?.isConnected = connected
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
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }
    }

    func disconnect() {
        webSocket.disconnect()
        isConnected = false
        presentations = []
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

    // MARK: - Data Loading

    func refreshAll() async {
        async let p: () = fetchPresentations()
        async let a: () = fetchActivePresentation()
        async let s: () = fetchSlideStatus()
        _ = await (p, a, s)
    }

    func fetchPresentations() async {
        guard let result = try? await api.fetchPresentations(host: host, port: portInt) else { return }
        presentations = result
    }

    func fetchActivePresentation() async {
        guard let active = try? await api.fetchActivePresentation(host: host, port: portInt) else { return }
        selectedPresentation = active
        livePresentationUUID = active.uuid
    }

    func fetchSlideStatus() async {
        guard let status = try? await api.fetchSlideStatus(host: host, port: portInt) else { return }
        currentSlideIndex = status.slideIndex
        if let uuid = status.presentationUUID { livePresentationUUID = uuid }
    }

    // MARK: - Actions

    func selectPresentation(_ presentation: Presentation) async {
        do {
            try await api.triggerSlide(host: host, port: portInt, uuid: presentation.uuid, index: 0)
            await fetchActivePresentation()
        } catch {
            selectedPresentation = presentation
        }
    }

    func triggerSlide(at index: Int) async {
        guard let pres = selectedPresentation else { return }
        currentSlideIndex = index
        try? await api.triggerSlide(host: host, port: portInt, uuid: pres.uuid, index: index)
    }

    func triggerNext() async {
        try? await api.triggerNext(host: host, port: portInt)
    }

    func triggerPrevious() async {
        try? await api.triggerPrevious(host: host, port: portInt)
    }

    func thumbnailURL(for index: Int) -> URL? {
        guard let pres = selectedPresentation else { return nil }
        return api.thumbnailURL(host: host, port: portInt, uuid: pres.uuid, index: index)
    }

    func triggerCompanionButton(_ button: CompanionButton) async {
        guard let url = button.url else { return }
        _ = try? await URLSession.shared.data(from: url)
    }

    // MARK: - WebSocket Handler

    private func handleSlideUpdate(index: Int, uuid: String) {
        currentSlideIndex = index
        if !uuid.isEmpty && uuid != livePresentationUUID {
            livePresentationUUID = uuid
            Task { await fetchActivePresentation() }
        }
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
