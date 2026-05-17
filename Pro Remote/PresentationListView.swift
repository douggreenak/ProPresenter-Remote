import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // Playlist section
            List(selection: Binding<String?>(
                get: { viewModel.selectedPresentation?.uuid },
                set: { uuid in
                    guard let uuid,
                          let pres = viewModel.presentations.first(where: { $0.uuid == uuid })
                    else { return }
                    Task { await viewModel.selectPresentation(pres) }
                }
            )) {
                ForEach(viewModel.presentations) { presentation in
                    HStack(spacing: 0) {
                        Text(presentation.name)
                            .lineLimit(2)

                        Spacer(minLength: 6)

                        if presentation.uuid == viewModel.livePresentationUUID {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.red, in: Capsule())
                        }
                    }
                    .tag(presentation.uuid)
                }
            }
            .listStyle(.sidebar)

            // Slide cue list
            if let selected = viewModel.selectedPresentation, !selected.slides.isEmpty {
                Divider()

                SlideCueList(
                    presentation: selected,
                    currentSlideIndex: viewModel.currentSlideIndex,
                    onTrigger: { index in
                        Task { await viewModel.triggerSlide(at: index) }
                    }
                )
            }

            if viewModel.presentations.isEmpty && !viewModel.isConnected {
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
        .navigationTitle("Presentations")
    }
}

// MARK: - Slide Cue List

private struct SlideCueList: View {
    let presentation: Presentation
    let currentSlideIndex: Int
    let onTrigger: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(presentation.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(presentation.slides.count) slides")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    GlassEffectContainer(spacing: 2) {
                        VStack(spacing: 3) {
                            ForEach(presentation.slides) { slide in
                                let isLive = slide.index == currentSlideIndex

                                Button { onTrigger(slide.index) } label: {
                                    HStack(spacing: 8) {
                                        Text("\(slide.index + 1)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(isLive ? .white : .secondary)
                                            .frame(width: 22, alignment: .trailing)

                                        VStack(alignment: .leading, spacing: 0) {
                                            if !slide.groupName.isEmpty {
                                                Text(slide.groupName)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(isLive ? Color.white.opacity(0.8) : Color.gray)
                                            }

                                            Text(slide.text.isEmpty ? "—" : slide.text)
                                                .font(.system(size: 11))
                                                .foregroundStyle(isLive ? .white : .primary)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        isLive
                                            ? AnyShapeStyle(Color.red.opacity(0.85))
                                            : AnyShapeStyle(.clear),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .glassEffect(
                                        isLive ? .regular.tint(.red) : .regular,
                                        in: .rect(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(slide.index)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
                .onAppear {
                    proxy.scrollTo(currentSlideIndex, anchor: .center)
                }
                .onChange(of: currentSlideIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}
