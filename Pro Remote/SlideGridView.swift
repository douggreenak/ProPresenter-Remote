import SwiftUI

struct SlideGridView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            if let presentation = viewModel.selectedPresentation {
                headerBar(for: presentation)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(presentation.slides) { slide in
                                SlideCell(
                                    slide: slide,
                                    thumbnailURL: viewModel.thumbnailURL(for: slide.index),
                                    isLive: viewModel.isViewingLivePresentation && slide.index == viewModel.liveSlideIndex
                                ) {
                                    Task { await viewModel.triggerSlide(at: slide.index) }
                                }
                                .id(slide.index)
                            }
                        }
                        .padding(6)
                    }
                    .background(Color(white: 0.12))
                    .onAppear {
                        if viewModel.isViewingLivePresentation {
                            proxy.scrollTo(viewModel.liveSlideIndex, anchor: .center)
                        }
                    }
                    .onChange(of: viewModel.liveSlideIndex) { _, newIndex in
                        if viewModel.isViewingLivePresentation {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }

                transportBar
            } else {
                ContentUnavailableView {
                    Label("No Presentation", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Select a presentation from the sidebar.")
                }
            }
        }
        .navigationTitle("")
        #if os(macOS)
        .navigationSubtitle("")
        #endif
    }

    private func headerBar(for presentation: Presentation) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(presentation.slides.count) slides")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.45))
            }

            Spacer()

            if viewModel.isViewingLivePresentation {
                Text("LIVE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ProPresenterViewModel.liveColor, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.09))
    }

    private var transportBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 16) {
                Button { Task { await viewModel.triggerSlide(at: 0) } } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Button { Task { await viewModel.triggerPrevious() } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(white: 0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: .command)

                if viewModel.isViewingLivePresentation,
                   let total = viewModel.selectedPresentation?.slides.count {
                    Text("\(viewModel.liveSlideIndex + 1) / \(total)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .frame(minWidth: 44)
                }

                Button { Task { await viewModel.triggerNext() } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(white: 0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button {
                    if let last = viewModel.selectedPresentation?.slides.last {
                        Task { await viewModel.triggerSlide(at: last.index) }
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(height: 28)
        .background(Color(white: 0.07))
    }
}

// MARK: - Slide Cell

private struct SlideCell: View {
    let slide: Slide
    let thumbnailURL: URL?
    let isLive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay {
                            if !slide.text.isEmpty {
                                Text(slide.text)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.4))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .padding(8)
                            }
                        }
                }

                HStack(spacing: 4) {
                    if let color = slide.groupColor {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 3, height: 12)
                    }

                    Text(slide.groupName.isEmpty ? "Slide \(slide.index + 1)" : slide.groupName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(slide.index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.18))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isLive ? ProPresenterViewModel.liveColor : Color(white: 0.25),
                        lineWidth: isLive ? 2.5 : 0.5
                    )
            )
            .opacity(isHovered ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
