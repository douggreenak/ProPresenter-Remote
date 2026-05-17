import SwiftUI

struct SlideGridView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 300), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            if let presentation = viewModel.selectedPresentation {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(presentation.slides) { slide in
                                SlideCell(
                                    slide: slide,
                                    thumbnailURL: viewModel.thumbnailURL(for: slide.index),
                                    isLive: slide.index == viewModel.currentSlideIndex,
                                    isNext: slide.index == viewModel.nextSlideIndex
                                ) {
                                    Task { await viewModel.triggerSlide(at: slide.index) }
                                }
                                .id(slide.index)
                            }
                        }
                        .padding(16)
                    }
                    .onAppear {
                        proxy.scrollTo(viewModel.currentSlideIndex, anchor: .center)
                    }
                    .onChange(of: viewModel.currentSlideIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
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
        .navigationTitle(viewModel.selectedPresentation?.name ?? "Slides")
        #if os(macOS)
        .navigationSubtitle(
            viewModel.selectedPresentation.map { "\($0.slides.count) slides" } ?? ""
        )
        #endif
    }

    private var transportBar: some View {
        HStack(spacing: 0) {
            Button {
                Task { await viewModel.triggerPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Spacer()

            if let slide = viewModel.currentSlide,
               let total = viewModel.selectedPresentation?.slides.count {
                VStack(spacing: 2) {
                    Text("\(slide.index + 1) / \(total)")
                        .font(.headline.monospacedDigit())
                    if !slide.groupName.isEmpty {
                        Text(slide.groupName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button {
                Task { await viewModel.triggerNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Slide Cell

private struct SlideCell: View {
    let slide: Slide
    let thumbnailURL: URL?
    let isLive: Bool
    let isNext: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                if !slide.text.isEmpty {
                                    Text(slide.text)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(4)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                    }

                    if isLive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.red, in: Capsule())
                            .padding(6)
                    } else if isNext {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor, in: Capsule())
                            .padding(6)
                    }
                }

                HStack {
                    Text("\(slide.index + 1)")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)

                    if !slide.groupName.isEmpty {
                        Text(slide.groupName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isLive {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.red, lineWidth: 2.5)
                } else if isNext {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: isLive ? .red.opacity(0.35) : .clear, radius: 10)
            .scaleEffect(isHovered ? 1.025 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
