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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(white: 0.4))
                        Spacer()
                        if let total = viewModel.selectedPresentation?.slides.count {
                            Text("Slide \(slide.index + 1) of \(total)")
                                .font(.system(size: 9))
                                .foregroundColor(Color(white: 0.35))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    if let url = viewModel.thumbnailURL(for: slide.index) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(16 / 9, contentMode: .fit)
                        } placeholder: {
                            Rectangle().fill(Color(white: 0.13)).aspectRatio(16 / 9, contentMode: .fit)
                        }
                        .overlay(Rectangle().strokeBorder(ProPresenterViewModel.liveColor, lineWidth: 2))
                        .padding(.horizontal, 8)
                    }
                }

                // Next slide preview
                if let nextIndex = viewModel.nextSlideIndex {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("NEXT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(white: 0.4))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                        if let url = viewModel.thumbnailURL(for: nextIndex) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(16 / 9, contentMode: .fit)
                            } placeholder: {
                                Rectangle().fill(Color(white: 0.13)).aspectRatio(16 / 9, contentMode: .fit)
                            }
                            .overlay(Rectangle().strokeBorder(Color(white: 0.28), lineWidth: 1))
                            .padding(.horizontal, 8)
                        }
                    }
                }

                // Notes / text section
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
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.slash")
                            .font(.system(size: 28))
                            .foregroundColor(Color(white: 0.25))
                        Text("No Active Slide")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.3))
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
        .navigationTitle("Output")
    }
}
