import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        #if os(macOS)
        macBody
        #else
        standardBody
        #endif
    }

    // MARK: - macOS sidebar

    #if os(macOS)
    /// A playlist menu on top and one native sidebar list underneath, instead of two stacked
    /// scrolling boxes: the items get the whole column, and selection looks like every other Mac app.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(viewModel.playlists) { playlist in
                        Button {
                            Task { await viewModel.selectPlaylist(playlist) }
                        } label: {
                            if playlist.uuid == viewModel.selectedPlaylist?.uuid {
                                Label(playlist.name, systemImage: "checkmark")
                            } else {
                                Text(playlist.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PLAYLIST")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(viewModel.selectedPlaylist?.name ?? "Choose a playlist")
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .disabled(viewModel.playlists.isEmpty)
                .accessibilityLabel("Playlist: \(viewModel.selectedPlaylist?.name ?? "none selected")")

                RefreshButton()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.playlistItems.isEmpty {
                ScrollViewReader { proxy in
                    List(selection: macSelection) {
                        ForEach(Array(viewModel.playlistItems.enumerated()), id: \.element.listID) { index, item in
                            MacPresentationRow(item: item, index: index)
                                .tag(item.listID)
                                .id(item.listID)
                        }
                    }
                    .listStyle(.sidebar)
                    .tint(ProPresenterViewModel.liveColor)
                    .onAppear {
                        proxy.scrollTo(viewModel.selectedPresentation?.listID, anchor: .center)
                    }
                    .onChange(of: viewModel.selectedPresentation?.listID) { _, newID in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
            } else if viewModel.selectedPlaylist != nil {
                ContentUnavailableView {
                    Label("No Items", systemImage: "tray")
                } description: {
                    Text("This playlist is empty.")
                }
            } else if viewModel.playlists.isEmpty && !viewModel.isConnected {
                ContentUnavailableView {
                    Label("Not Connected", systemImage: "wifi.slash")
                } description: {
                    Text("Connect to ProPresenter in Settings.")
                } actions: {
                    Button("Open Settings") {
                        viewModel.showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Playlists")
    }

    private var macSelection: Binding<String?> {
        Binding(
            get: { viewModel.selectedPresentation?.listID },
            set: { id in
                guard let id, let item = viewModel.playlistItems.first(where: { $0.listID == id }) else { return }
                Task { await viewModel.selectPresentation(item) }
            }
        )
    }
    #endif

    // MARK: - iPad / iPhone sidebar

    private var standardBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Playlists")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(white: 0.35))
                    .textCase(.uppercase)
                Spacer()
                if !viewModel.playlists.isEmpty {
                    Text("\(viewModel.playlists.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
                RefreshButton()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(white: 0.07))

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(viewModel.playlists) { playlist in
                        PlaylistRow(playlist: playlist)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)

            if viewModel.selectedPlaylist != nil {
                HStack {
                    Text(viewModel.selectedPlaylist?.name ?? "Items")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(white: 0.55))
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Spacer()
                    Text("\(viewModel.playlistItems.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(white: 0.07))
            }

            if !viewModel.playlistItems.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.playlistItems.enumerated()), id: \.element.listID) { index, item in
                                PresentationRow(item: item, index: index)
                                    .id(item.listID)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(viewModel.selectedPresentation?.listID, anchor: .center)
                    }
                    .onChange(of: viewModel.selectedPresentation?.listID) { _, newID in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
            } else if viewModel.selectedPlaylist != nil {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 22))
                        .foregroundColor(Color(white: 0.3))
                    Text("No items in this playlist")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 24)
            }

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.playlists.isEmpty && !viewModel.isConnected {
                ContentUnavailableView {
                    Label("Not Connected", systemImage: "wifi.slash")
                } description: {
                    Text("Connect to ProPresenter in Settings.")
                } actions: {
                    Button("Open Settings") {
                        viewModel.showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(Color(white: 0.1))
        .refreshable {
            await viewModel.refreshAll()
        }
        .navigationTitle("Playlists")
        #if os(iOS)
        // The large-title style leaves an empty nav-bar row above the title on iPhone, since this
        // column has no toolbar items.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Refresh Button

private struct RefreshButton: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var isRefreshing = false

    var body: some View {
        Button {
            guard !isRefreshing else { return }
            isRefreshing = true
            Task {
                await viewModel.refreshAll()
                isRefreshing = false
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(viewModel.isConnected ? Color(white: 0.5) : Color(white: 0.25))
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isConnected || isRefreshing)
        .help("Refresh - reload playlists, presentations, and live status from ProPresenter")
        .accessibilityLabel("Refresh")
        .accessibilityHint("Reloads all data from ProPresenter")
    }
}

// MARK: - Playlist Row

private struct PlaylistRow: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    let playlist: Playlist
    @State private var isHovered = false

    var body: some View {
        let isSelected = playlist.uuid == viewModel.selectedPlaylist?.uuid

        Button {
            Task { await viewModel.selectPlaylist(playlist) }
        } label: {
            Text(playlist.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(white: 0.8))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color(white: 0.25) : (isHovered ? Color(white: 0.16) : Color.clear))
                        .padding(.horizontal, 4)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Presentation Row

private struct PresentationRow: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.showDetail) private var showDetail
    let item: Presentation
    let index: Int
    @State private var isHovered = false

    var body: some View {
        let isSelected = item.listID == viewModel.selectedPresentation?.listID
        let isLive = item.uuid == viewModel.livePresentationUUID

        Button {
            showDetail()
            Task { await viewModel.selectPresentation(item) }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isLive ? ProPresenterViewModel.liveColor : Color.clear)
                    .frame(width: 2.5)
                    .padding(.vertical, isLive ? 6 : 0)

                Text("\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color(white: 0.4))
                    .frame(width: 24, alignment: .trailing)
                    .padding(.leading, 4)

                Text(item.name)
                    .font(.system(size: 13, weight: isLive ? .semibold : .regular))
                    .foregroundColor(isLive ? .white : (isSelected ? .white : Color(white: 0.75)))
                    .lineLimit(1)
                    .padding(.leading, 8)

                Spacer(minLength: 4)

                if isLive && viewModel.liveArrangementMismatch {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                        .help("Arrangement mismatch - ProPresenter's library arrangement doesn't match Sunday Service's selection for this song.")
                        .accessibilityLabel("Arrangement mismatch")
                        .padding(.trailing, isLive ? 4 : 0)
                }

                if isLive {
                    PhaseAnimator([false, true]) { isGlowing in
                        Text("LIVE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ProPresenterViewModel.liveColor, in: Capsule())
                            .shadow(color: ProPresenterViewModel.liveColor.opacity(isGlowing ? 0.5 : 0), radius: isGlowing ? 4 : 0)
                    } animation: { _ in
                        .easeInOut(duration: 1.5)
                    }
                    .padding(.trailing, 8)
                }
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowFillColor(isSelected: isSelected, isLive: isLive))
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityLabel("\(item.name)\(isLive ? ", live" : "")\(isLive && viewModel.liveArrangementMismatch ? ", arrangement mismatch" : "")")
        .accessibilityHint("Double tap to select")
    }

    private func rowFillColor(isSelected: Bool, isLive: Bool) -> Color {
        if isSelected { return Color(white: 0.22) }
        if isLive { return ProPresenterViewModel.liveColor.opacity(0.08) }
        if isHovered { return Color(white: 0.16) }
        return .clear
    }
}

#if os(macOS)
/// One item in the Mac sidebar: its position, its name, and a LIVE badge when it is the one on screen.
private struct MacPresentationRow: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    let item: Presentation
    let index: Int

    var body: some View {
        let isLive = item.uuid == viewModel.livePresentationUUID

        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(item.name)
                .font(.system(size: 13, weight: isLive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(item.name)

            Spacer(minLength: 4)

            if isLive && viewModel.liveArrangementMismatch {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                    .help("Arrangement mismatch - ProPresenter's library arrangement doesn't match Sunday Service's selection for this song.")
            }

            if isLive {
                Text("LIVE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ProPresenterViewModel.liveColor, in: Capsule())
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)\(isLive ? ", live" : "")\(isLive && viewModel.liveArrangementMismatch ? ", arrangement mismatch" : "")")
        .accessibilityHint("Double tap to select")
    }
}
#endif
