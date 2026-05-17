import SwiftUI

struct NotesView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        Group {
            if let slide = viewModel.currentSlide {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Slide \(slide.index + 1)")
                                .font(.headline)
                            Spacer()
                            if !slide.groupName.isEmpty {
                                Text(slide.groupName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        if !slide.text.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Slide Text", systemImage: "text.alignleft")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Text(slide.text)
                                    .font(.title3)
                                    .textSelection(.enabled)
                            }
                        }

                        if !slide.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Speaker Notes", systemImage: "note.text")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Text(slide.notes)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }

                        if slide.text.isEmpty && slide.notes.isEmpty {
                            ContentUnavailableView {
                                Label("No Notes", systemImage: "note.text")
                            } description: {
                                Text("This slide has no text or speaker notes.")
                            }
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
