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
        return node.allPresentations(playlistUUID: uuid)
    }

    /// Resolves the arrangement pointer for whatever is *currently live*, straight from the
    /// active playlist item rather than by searching every playlist for a matching
    /// presentation UUID. Returns nil (never throws to the caller's detriment beyond that)
    /// when the server doesn't expose this - older Pro versions and some PCO-linked
    /// playlists omit `playlist_item` entirely - so callers should fall back to matching
    /// against an already-loaded playlist in that case. The playlist uuid returned alongside
    /// the item is what addresses the arrangement-scoped thumbnail endpoint.
    func fetchActivePlaylistItem(host: String, port: Int) async throws -> (item: PlaylistItem, playlistUUID: String?)? {
        let url = try buildURL(host, port, path: "/v1/playlist/active")
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ActivePlaylistItemResponse.self, from: data)
        guard let item = response.playlistItem else { return nil }
        return (item, response.playlistUUID)
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

    func fetchSlideIndex(host: String, port: Int) async throws -> (slideIndex: Int, presentationUUID: String?, totalCues: Int?) {
        let url = try buildURL(host, port, path: "/v1/presentation/slide_index")
        let (data, _) = try await session.data(from: url)
        let r = try JSONDecoder().decode(SlideIndexPayload.self, from: data)
        return (r.presentationIndex?.index ?? 0, r.presentationIndex?.presentationId?.uuid, r.presentationIndex?.totalCues)
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

    /// Used only to activate a presentation that ISN'T currently live (e.g. jumping ahead to
    /// start a different song from a specific slide) - `/v1/presentation/active/{index}/trigger`
    /// below can't do that since "active" only ever refers to whatever's already live. `index`
    /// here must be the slide's position within the presentation's LIBRARY arrangement
    /// (`current_arrangement`), not the playlist's pinned one - see the long comment on
    /// `apiTriggerIndex` in `mapPayload`. There is no cue-level trigger endpoint scoped to a
    /// non-live presentation's playlist arrangement, so `Slide.triggerIndex` is already
    /// resolved into this space by the time it gets here, and a slide that only exists at its
    /// position because of a repeat in the playlist's pin can't be addressed this way - a rare
    /// cost for "start a different song partway through", vs. the routine case below.
    func triggerSlide(host: String, port: Int, uuid: String, index: Int) async throws {
        // Per the ProPresenter OpenAPI spec (openapi.propresenter.com), the real path is
        // `/v1/presentation/{uuid}/{index}/trigger` - index before `trigger`, not after.
        let url = try buildURL(host, port, path: "/v1/presentation/\(uuid)/\(index)/trigger")
        _ = try await session.data(from: url)
    }

    /// The routine path for controlling whatever's already live. Unlike the uuid-scoped
    /// `triggerSlide` above, `index` here correctly respects the arrangement that's actually
    /// active - which, for anything reached through a playlist item, is the playlist's pin, not
    /// the library selection - and CAN address an individual repeated slide (confirmed live:
    /// jumping straight to the arrangement's 2nd repeat of a "Bridge" group worked correctly
    /// and immediately, no seeding step needed, unlike `/v1/presentation/focused/{index}/trigger`
    /// which needed the presentation focused via its playlist item first and reset playback to
    /// its start every time that happened). So `index` here is `Slide.thumbnailIndex` (the
    /// cue-relative index), not `Slide.triggerIndex`.
    ///
    /// Deliberately NOT addressed by uuid: "active" is whatever ProPresenter itself currently
    /// has live, re-resolved fresh on every call - if it's changed since this app's last poll
    /// (someone at the console switched songs), this lands on that new presentation's same cue
    /// number instead of on the stale one this app still believes is live. That's an accepted,
    /// narrow race inherent to any two-controller live setup (and the app's own polling already
    /// detects and reconciles active-presentation changes); the alternative - addressing by
    /// uuid - would be worse here, since it could snap the live output back to a presentation
    /// the operator had just deliberately moved off of.
    func triggerActiveCue(host: String, port: Int, index: Int) async throws {
        let url = try buildURL(host, port, path: "/v1/presentation/active/\(index)/trigger")
        _ = try await session.data(from: url)
    }

    func focusPresentation(host: String, port: Int, uuid: String) async throws {
        let url = try buildURL(host, port, path: "/v1/presentation/\(uuid)")
        _ = try await session.data(from: url)
    }

    // MARK: - Thumbnails

    /// The presentation-scoped thumbnail endpoint. Its `index` respects the presentation's
    /// LIBRARY arrangement selection, not any playlist pin (confirmed against ProPresenter's
    /// own OpenAPI docs and live behavior - see the comment on `apiTriggerIndex` in
    /// `mapPayload`), so it can't correctly address a slide that only exists at a given
    /// position because of the *playlist's* arrangement. Kept only as a fallback for when a
    /// presentation has no known playlist context at all (see `thumbnailURL(playlistUUID:...)`
    /// below, which should be preferred whenever that context is available).
    nonisolated func thumbnailURL(host: String, port: Int, uuid: String, index: Int) -> URL? {
        URL(string: "http://\(host):\(port)/v1/presentation/\(uuid)/thumbnail/\(index)")
    }

    /// The playlist-scoped thumbnail endpoint (`/v1/playlist/{playlist}/{item}/thumbnail/{cueIndex}`).
    /// Unlike the presentation-scoped one above, ProPresenter's docs say this one's `cue_index`
    /// "respects the selected arrangement of cues" for *this playlist item specifically* - and
    /// live testing confirms it: it correctly served a distinct thumbnail for a slide that only
    /// exists at cue 15 because a group repeats three times in the playlist's pinned
    /// arrangement, something the presentation-scoped endpoint 404s on entirely. `itemIndex` is
    /// the item's position within the playlist (`Presentation.playlistItemIndex`), `cueIndex`
    /// is `Slide.thumbnailIndex`.
    nonisolated func thumbnailURL(host: String, port: Int, playlistUUID: String, itemIndex: Int, cueIndex: Int) -> URL? {
        URL(string: "http://\(host):\(port)/v1/playlist/\(playlistUUID)/\(itemIndex)/thumbnail/\(cueIndex)")
    }

    /// Directly verifies ProPresenter actually has a real thumbnail for every cue a resolved
    /// arrangement expects to show, via the same playlist-scoped endpoint the grid itself uses
    /// - so this only trips for a genuine problem, not for the presentation-scoped endpoint's
    /// unrelated inability to address repeated slides (see `thumbnailURL(playlistUUID:...)`).
    /// Checked concurrently since this only runs once per live-song change, not on every poll
    /// tick, and it's a local network call.
    func verifyThumbnailsAvailable(host: String, port: Int, playlistUUID: String, itemIndex: Int, count: Int) async -> Bool {
        guard count > 0 else { return true }
        let session = self.session
        return await withTaskGroup(of: Bool.self) { group in
            for cueIndex in 0..<count {
                group.addTask {
                    guard let url = URL(string: "http://\(host):\(port)/v1/playlist/\(playlistUUID)/\(itemIndex)/thumbnail/\(cueIndex)") else { return false }
                    guard let (_, response) = try? await session.data(from: url) else { return false }
                    return (response as? HTTPURLResponse)?.statusCode == 200
                }
            }
            var allAvailable = true
            for await ok in group where !ok {
                allAvailable = false
            }
            return allAvailable
        }
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

        func resolveArrangement(_ uuid: String?) -> ArrangementPayload? {
            guard let uuid, !uuid.isEmpty else { return nil }
            guard let match = p.arrangements?.first(where: { $0.id.uuid == uuid }) else { return nil }
            // Some Pro builds (observed on 21.3.1/Windows) report Master as a real arrangement
            // object with an empty `groups` array - treat that the same as "no arrangement" so
            // it falls through to natural document order below instead of rendering zero slides.
            guard !match.groups.isEmpty else { return nil }
            return match
        }

        // `arrangementUUID`, when supplied, is the pointer pinned on a specific playlist item
        // (`presentation_info.arrangement_uuid`) - the per-service selection. We deliberately
        // do NOT fall back to `p.currentArrangement` for *display*: `current_arrangement` is
        // the presentation's default arrangement in the library, not a per-playlist-item
        // override, and falling back to it here was exactly the bug where a song displayed
        // with its library arrangement instead of the one chosen in the service. With no
        // explicit pointer, treat the presentation as Master (natural group order) for display.
        let effectiveArrangement: ArrangementPayload? = {
            guard let arrangementUUID, !arrangementUUID.isEmpty else { return nil }
            guard let resolved = resolveArrangement(arrangementUUID) else {
                print("ProPresenterAPI: arrangement_uuid \(arrangementUUID) not found on presentation \(p.id.uuid) (\(p.id.name)); falling back to Master")
                return nil
            }
            return resolved
        }()
        let displayArrangement = effectiveArrangement

        // ProPresenter's OWN docs (openapi.propresenter.com) say the `index` on
        // `/v1/presentation/{uuid}/{index}/trigger` and `/v1/presentation/{uuid}/thumbnail/{index}`
        // "respects the selected arrangement of cues" - but that arrangement is the
        // presentation's LIBRARY selection (`current_arrangement`), not whatever a playlist
        // item pins it to, and there is no playlist-scoped, cue-level trigger endpoint to use
        // instead. Verified live: with the playlist pinning a 21-cue "ableton" arrangement
        // while the library had nothing selected (`current_arrangement == ""`, i.e. natural
        // order), `/thumbnail/0` and `/thumbnail/3` returned the document's 1st and 4th
        // physical slides - matching natural order exactly, not the playlist's cue 0/3. So the
        // index actually sent to `/trigger` has to be this slide's position within the
        // LIBRARY's own arrangement (falling back to natural document order when the library
        // has nothing selected, since that's what ProPresenter itself falls back to).
        let libraryArrangement = resolveArrangement(p.currentArrangement)
        var libraryIndexByKey: [String: Int] = [:]
        if let libraryArrangement {
            var libIdx = 0
            for gUUID in libraryArrangement.groups {
                guard let entry = groupByUUID[gUUID] else { continue }
                for offset in 0..<entry.group.slides.count {
                    // First occurrence wins: every repeat of a group in the library's own
                    // arrangement points at the same physical slide, so any one of their
                    // indices triggers the same content.
                    let key = "\(gUUID)|\(offset)"
                    if libraryIndexByKey[key] == nil {
                        libraryIndexByKey[key] = libIdx
                    }
                    libIdx += 1
                }
            }
        }
        func apiTriggerIndex(groupUUID: String, offset: Int) -> Int? {
            let key = "\(groupUUID)|\(offset)"
            if libraryArrangement != nil {
                return libraryIndexByKey[key]
            }
            guard let entry = groupByUUID[groupUUID] else { return nil }
            return entry.rawStart + offset
        }

        // Build cue context: the ordered position of every slide *within the active
        // (playlist-pinned) arrangement*. This is NOT the index used to call the presentation
        // trigger/thumbnail endpoints (see `apiTriggerIndex` above) - it exists purely to
        // translate ProPresenter's live status (`/v1/presentation/slide_index`, whose `index`
        // field is the slide's position within whichever arrangement the engine is actually
        // running) into a display index, and to address the arrangement-scoped playlist
        // thumbnail endpoint (`/v1/playlist/{playlist}/{item}/thumbnail/{cueIndex}`), which
        // - unlike the presentation-scoped one - genuinely does respect this arrangement and
        // can serve a distinct image for every repeat occurrence. Verified live: with a 21-cue
        // arrangement active, the 2nd repeat of a "Bridge" group reported status index 15 -
        // its sequential position among the arrangement's cues, repeats included - and
        // `/v1/playlist/.../thumbnail/15` correctly returned that Bridge slide's image.
        typealias CueEntry = (groupUUID: String, slideOffset: Int, cueIndex: Int)
        var cueContext: [CueEntry] = []

        if let effectiveArrangement {
            var cueIdx = 0
            for gUUID in effectiveArrangement.groups {
                guard let entry = groupByUUID[gUUID] else { continue }
                for offset in 0..<entry.group.slides.count {
                    cueContext.append((gUUID, offset, cueIdx))
                    cueIdx += 1
                }
            }
        } else {
            var cueIdx = 0
            for group in p.groups {
                guard let gUUID = group.uuid else { continue }
                for offset in 0..<group.slides.count {
                    cueContext.append((gUUID, offset, cueIdx))
                    cueIdx += 1
                }
            }
        }

        // Group cue entries by (groupUUID, slideOffset) preserving order
        var cueLookup: [String: [Int]] = [:]
        for entry in cueContext {
            let key = "\(entry.groupUUID)|\(entry.slideOffset)"
            cueLookup[key, default: []].append(entry.cueIndex)
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

                    let availableCues = cueLookup[key] ?? []
                    let cueIdx: Int? = availableCues.isEmpty ? nil :
                        availableCues[occurrence % availableCues.count]

                    if let cueIdx {
                        triggerToDisplay[cueIdx, default: []].append(idx)
                    }

                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: cueIdx,
                        triggerIndex: apiTriggerIndex(groupUUID: groupUUID, offset: offset)
                    ))
                    idx += 1
                }
            }
        } else {
            for group in p.groups {
                guard let gUUID = group.uuid else { continue }
                let color: Color? = group.color.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
                for (offset, s) in group.slides.enumerated() {
                    let cueIdx = idx
                    triggerToDisplay[cueIdx, default: []].append(idx)

                    slides.append(Slide(
                        id: idx,
                        text: s.text,
                        label: s.label ?? "",
                        notes: s.notes,
                        enabled: s.enabled ?? true,
                        groupName: group.name,
                        groupColor: color,
                        thumbnailIndex: cueIdx,
                        triggerIndex: apiTriggerIndex(groupUUID: gUUID, offset: offset)
                    ))
                    idx += 1
                }
            }
        }

        return Presentation(uuid: p.id.uuid, name: p.id.name, index: p.id.index, slides: slides, arrangementUUID: arrangementUUID, triggerToDisplayMap: triggerToDisplay)
    }
}
