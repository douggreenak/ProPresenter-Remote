import SwiftUI

struct SlideGridView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            if let presentation = viewModel.selectedPresentation {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
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
                        .padding(8)
                    }
                    .background(Color(white: 0.14))
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
        HStack {
            Spacer()
            HStack(spacing: 12) {
                Button { Task { await viewModel.triggerSlide(at: 0) } } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.55))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Button { Task { await viewModel.triggerPrevious() } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.55))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: .command)

                if let slide = viewModel.currentSlide,
                   let total = viewModel.selectedPresentation?.slides.count {
                    Text("\(slide.index + 1) / \(total)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                        .frame(minWidth: 44)
                }

                Button { Task { await viewModel.triggerNext() } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.55))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button {
                    if let last = viewModel.selectedPresentation?.slides.last {
                        Task { await viewModel.triggerSlide(at: last.index) }
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.55))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(height: 30)
        .background(Color(white: 0.09))
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

    private var borderColor: Color {
        if isLive { return ProPresenterViewModel.liveColor }
        return Color(white: 0.28)
    }

    private var borderWidth: CGFloat {
        if isLive { return 3 }
        return 1
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(white: 0.18))
                        .aspectRatio(16 / 9, contentMode: .fit)
                }

                // Info area — medium gray like ProPresenter
                VStack(alignment: .leading, spacing: 1) {
                    if !slide.groupName.isEmpty {
                        Text(slide.groupName + ":")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(white: 0.7))
                    }
                    if !slide.text.isEmpty {
                        Text(slide.text)
                            .font(.system(size: 9.5))
                            .foregroundColor(Color(white: 0.55))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    HStack {
                        Spacer()
                        Text("\(slide.index + 1)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                    }
                    .padding(.top, 1)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 3)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .background(Color(white: 0.22))
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
