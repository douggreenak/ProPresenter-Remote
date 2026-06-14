import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.playlists.isEmpty {
                HStack {
                    Text("Playlists")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(white: 0.35))
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(viewModel.playlists.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(white: 0.07))
            }

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
    let item: Presentation
    let index: Int
    @State private var isHovered = false

    var body: some View {
        let isSelected = item.listID == viewModel.selectedPresentation?.listID
        let isLive = item.uuid == viewModel.livePresentationUUID

        Button {
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
        .accessibilityLabel("\(item.name)\(isLive ? ", live" : "")")
        .accessibilityHint("Double tap to select")
    }

    private func rowFillColor(isSelected: Bool, isLive: Bool) -> Color {
        if isSelected { return Color(white: 0.22) }
        if isLive { return ProPresenterViewModel.liveColor.opacity(0.08) }
        if isHovered { return Color(white: 0.16) }
        return .clear
    }
}
