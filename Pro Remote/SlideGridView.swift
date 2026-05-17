import SwiftUI

struct SlideGridView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            if let presentation = viewModel.selectedPresentation {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(presentation.slides) { slide in
                            SlideCell(
                                slide: slide,
                                thumbnailURL: viewModel.thumbnailURL(for: slide.index),
                                isLive: slide.index == viewModel.currentSlideIndex,
                                isNext: slide.index == viewModel.nextSlideIndex
                            ) {
                                Task { await viewModel.triggerSlide(at: slide.index) }
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                navigationBar
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

    private var navigationBar: some View {
        HStack(spacing: 40) {
            Button {
                Task { await viewModel.triggerPrevious() }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(minWidth: 100, minHeight: 50)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            if let slide = viewModel.currentSlide {
                Text("Slide \(slide.index + 1)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.triggerNext() }
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(minWidth: 100, minHeight: 50)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .padding()
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
            VStack(alignment: .leading, spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("\(slide.index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if !slide.groupName.isEmpty {
                        Text(slide.groupName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isLive {
                        Text("LIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    } else if isNext {
                        Text("NEXT")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay {
                if isLive {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.red, lineWidth: 3)
                } else if isNext {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 2)
                }
            }
            .shadow(color: isLive ? .red.opacity(0.4) : .clear, radius: 12)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
