import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<String?>(
                get: { viewModel.selectedPlaylist?.uuid },
                set: { uuid in
                    guard let uuid,
                          let playlist = viewModel.playlists.first(where: { $0.uuid == uuid })
                    else { return }
                    Task { await viewModel.selectPlaylist(playlist) }
                }
            )) {
                ForEach(viewModel.playlists) { playlist in
                    Text(playlist.name)
                        .lineLimit(2)
                        .tag(playlist.uuid)
                }
            }
            .listStyle(.sidebar)

            if !viewModel.playlistItems.isEmpty {
                PlaylistItemList(
                    items: viewModel.playlistItems,
                    selectedUUID: viewModel.selectedPresentation?.uuid,
                    liveUUID: viewModel.livePresentationUUID,
                    onSelect: { item in
                        Task { await viewModel.selectPresentation(item) }
                    }
                )
            }

            if viewModel.playlists.isEmpty && !viewModel.isConnected {
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
        .refreshable {
            await viewModel.refreshAll()
        }
        .navigationTitle("Playlists")
    }
}

// MARK: - Playlist Item List

private struct PlaylistItemList: View {
    let items: [Presentation]
    let selectedUUID: String?
    let liveUUID: String
    let onSelect: (Presentation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.uuid) { index, item in
                            let isSelected = item.uuid == selectedUUID
                            let isLive = item.uuid == liveUUID

                            Button { onSelect(item) } label: {
                                HStack(spacing: 0) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(isSelected ? .white : Color(white: 0.45))
                                        .frame(width: 22, alignment: .trailing)
                                        .padding(.leading, 4)

                                    Text(item.name)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(isSelected ? .white : Color(white: 0.8))
                                        .lineLimit(1)
                                        .padding(.leading, 6)

                                    Spacer(minLength: 4)

                                    if isLive {
                                        Text("LIVE")
                                            .font(.system(size: 7, weight: .heavy))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(ProPresenterViewModel.liveColor, in: Capsule())
                                            .padding(.trailing, 6)
                                    }
                                }
                                .frame(height: 22)
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? Color(white: 0.25) : Color.clear)
                            }
                            .buttonStyle(.plain)
                            .id(item.uuid)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedUUID, anchor: .center)
                }
                .onChange(of: selectedUUID) { _, newUUID in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newUUID, anchor: .center)
                    }
                }
            }
        }
        .background(Color(white: 0.08))
    }
}
