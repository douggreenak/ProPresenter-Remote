import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                ForEach(viewModel.playlists) { playlist in
                    let isSelected = playlist.uuid == viewModel.selectedPlaylist?.uuid

                    Button {
                        Task { await viewModel.selectPlaylist(playlist) }
                    } label: {
                        Text(playlist.name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : Color(white: 0.8))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .background(isSelected ? Color(white: 0.25) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)

            if !viewModel.playlistItems.isEmpty {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.playlistItems.enumerated()), id: \.element.uuid) { index, item in
                                let isSelected = item.uuid == viewModel.selectedPresentation?.uuid
                                let isLive = item.uuid == viewModel.livePresentationUUID

                                Button {
                                    Task { await viewModel.selectPresentation(item) }
                                } label: {
                                    HStack(spacing: 0) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : Color(white: 0.4))
                                            .frame(width: 20, alignment: .trailing)
                                            .padding(.leading, 4)

                                        Text(item.name)
                                            .font(.system(size: 11))
                                            .foregroundColor(isSelected ? .white : Color(white: 0.75))
                                            .lineLimit(1)
                                            .padding(.leading, 5)

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
                                    .frame(height: 20)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                    .background(isSelected ? Color(white: 0.22) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                .id(item.uuid)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(viewModel.selectedPresentation?.uuid, anchor: .center)
                    }
                    .onChange(of: viewModel.selectedPresentation?.uuid) { _, newUUID in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newUUID, anchor: .center)
                        }
                    }
                }
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
        .background(Color(white: 0.1))
        .refreshable {
            await viewModel.refreshAll()
        }
        .navigationTitle("Playlists")
    }
}
