import SwiftUI

struct NotesView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let slide = viewModel.currentSlide {
                // Current slide preview
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("CURRENT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ProPresenterViewModel.liveColor)
                        Spacer()
                        if let total = viewModel.selectedPresentation?.slides.count {
                            Text("Slide \(slide.index + 1) of \(total)")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.4))
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)

                    if let url = viewModel.thumbnailURL(for: slide.thumbnailIndex) {
                        ThumbnailImage(url: url)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(ProPresenterViewModel.liveColor, lineWidth: 2)
                            )
                            .padding(.horizontal, 8)
                    }
                }

                // Next slide preview
                if let nextIndex = viewModel.nextSlideIndex {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("NEXT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(white: 0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        if let nextSlide = viewModel.selectedPresentation?.slides[safe: nextIndex],
                           let url = viewModel.thumbnailURL(for: nextSlide.thumbnailIndex) {
                            ThumbnailImage(url: url)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color(white: 0.28), lineWidth: 1)
                                )
                                .padding(.horizontal, 8)
                        }
                    }
                }

                if !slide.groupName.isEmpty {
                    HStack(spacing: 5) {
                        if let color = slide.groupColor {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(color)
                                .frame(width: 4, height: 14)
                        }
                        Text(slide.groupName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !slide.text.isEmpty {
                            Text(slide.text)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.85))
                                .textSelection(.enabled)
                        }

                        if !slide.notes.isEmpty {
                            Text(slide.notes)
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.6))
                                .textSelection(.enabled)
                        }

                        if slide.text.isEmpty && slide.notes.isEmpty {
                            Text("No notes for this slide")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.3))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: .infinity)

                Spacer(minLength: 0)
            } else {
                ContentUnavailableView {
                    Label("No Active Slide", systemImage: "play.slash")
                } description: {
                    Text("Trigger a slide to see its details here.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
        .animation(.easeInOut(duration: 0.2), value: viewModel.liveSlideIndex)
        .navigationTitle("Output")
    }
}
