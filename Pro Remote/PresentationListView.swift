import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(viewModel.playlists) { playlist in
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
                                        .fill(isSelected ? Color(white: 0.25) : Color.clear)
                                        .padding(.horizontal, 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)

            if !viewModel.playlistItems.isEmpty {
                HStack {
                    Text("\(viewModel.playlistItems.count) items")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(white: 0.35))
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(white: 0.07))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.playlistItems.enumerated()), id: \.element.listID) { index, item in
                                let isSelected = item.listID == viewModel.selectedPresentation?.listID
                                let isLive = item.uuid == viewModel.livePresentationUUID

                                Button {
                                    Task { await viewModel.selectPresentation(item) }
                                } label: {
                                    HStack(spacing: 0) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : Color(white: 0.4))
                                            .frame(width: 24, alignment: .trailing)
                                            .padding(.leading, 6)

                                        Text(item.name)
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? .white : Color(white: 0.75))
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
                                            .fill(isSelected ? Color(white: 0.22) : Color.clear)
                                            .padding(.horizontal, 4)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(item.listID)
                                .animation(.easeOut(duration: 0.15), value: isSelected)
                                .accessibilityLabel("\(item.name)\(isLive ? ", live" : "")")
                                .accessibilityHint("Double tap to select")
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
