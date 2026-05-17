import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
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

            if let selected = viewModel.selectedPresentation, !selected.slides.isEmpty {
                SlideCueList(
                    presentation: selected,
                    currentSlideIndex: viewModel.liveSlideIndex,
                    isLivePresentation: selected.uuid == viewModel.livePresentationUUID,
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
    let isLivePresentation: Bool
    let onTrigger: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Text(presentation.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(white: 0.13))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(presentation.slides) { slide in
                            let isLive = isLivePresentation && slide.index == currentSlideIndex

                            Button { onTrigger(slide.index) } label: {
                                HStack(spacing: 0) {
                                    // Group color bar
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(slide.groupColor ?? Color.gray.opacity(0.4))
                                        .frame(width: 3, height: 14)
                                        .padding(.leading, 4)

                                    // Slide number
                                    Text("\(slide.index + 1)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(isLive ? .white : Color(white: 0.5))
                                        .frame(width: 26, alignment: .trailing)
                                        .padding(.leading, 4)

                                    // Slide text
                                    Text(slideLabel(slide))
                                        .font(.system(size: 12))
                                        .foregroundColor(isLive ? .white : Color(white: 0.85))
                                        .lineLimit(1)
                                        .padding(.leading, 6)

                                    Spacer(minLength: 0)
                                }
                                .frame(height: 22)
                                .frame(maxWidth: .infinity)
                                .background(isLive ? Color.red : Color.clear)
                            }
                            .buttonStyle(.plain)
                            .id(slide.index)
                        }
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
        .background(Color(white: 0.08))
    }

    private func slideLabel(_ slide: Slide) -> String {
        if !slide.text.isEmpty { return slide.text }
        if !slide.groupName.isEmpty { return slide.groupName }
        return "Slide \(slide.index + 1)"
    }
}
