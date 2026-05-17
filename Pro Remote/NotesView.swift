import SwiftUI

struct NotesView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        Group {
            if let slide = viewModel.currentSlide {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let url = viewModel.thumbnailURL(for: slide.index) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(16 / 9, contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(.quaternary)
                                    .aspectRatio(16 / 9, contentMode: .fit)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("Slide \(slide.index + 1)")
                                .font(.title2.weight(.semibold))

                            if let total = viewModel.selectedPresentation?.slides.count {
                                Text("of \(total)")
                                    .font(.title3)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if !slide.groupName.isEmpty {
                                Text(slide.groupName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary, in: Capsule())
                            }
                        }

                        if !slide.text.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Slide Text", systemImage: "text.alignleft")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Text(slide.text)
                                    .font(.title3)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        if !slide.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Speaker Notes", systemImage: "note.text")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Text(slide.notes)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        if slide.text.isEmpty && slide.notes.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                Text("No notes for this slide")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("No Active Slide", systemImage: "rectangle.slash")
                } description: {
                    Text("Notes will appear here when a slide is active.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Notes")
    }
}
