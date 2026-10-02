import SwiftUI

/// A full-screen "remote" for running the service from an iPad: the live slide large on top,
/// big transport buttons along the bottom. Deliberately has no slide strip — the main grid
/// already does that job.
struct RemoteView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private var nextPresentation: Presentation? {
        guard let current = viewModel.selectedPresentation,
              let idx = viewModel.playlistItems.firstIndex(where: { $0.listID == current.listID }),
              idx + 1 < viewModel.playlistItems.count else { return nil }
        return viewModel.playlistItems[idx + 1]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                Divider().overlay(Color(white: 0.2))

                transportBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .background(Color(white: 0.07).ignoresSafeArea())
            .navigationTitle("Remote")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.liveSlideIndex)
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        if let slide = viewModel.currentSlide {
            // The card is sized from the height we actually have (image is 16:9, plus its padding
            // and caption), otherwise a short screen leaves a thumbnail swimming in a gray slab.
            GeometryReader { geo in
                let fitted = (geo.size.height - 48) * 16 / 9 + 20
                slideCard(slide)
                    .frame(width: max(0, min(940, geo.size.width, fitted)))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        } else if let selected = viewModel.selectedPresentation, !viewModel.livePresentationUUID.isEmpty {
            // Viewing a song that isn't live. The transport below still drives *this* song (Next
            // Slide starts it, same as the main grid), so say so instead of looking like a dead end.
            VStack(spacing: 14) {
                Text(selected.name)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text("Not live — Next Slide starts this item")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Go to Active") { Task { await viewModel.goToLive() } }
                    .buttonStyle(.borderedProminent)
                    .tint(ProPresenterViewModel.liveColor)
            }
            .padding(24)
            .frame(maxWidth: 940)
        } else {
            ContentUnavailableView {
                Label("Nothing Live", systemImage: "play.slash")
            } description: {
                Text("Trigger a slide to see it here.")
            }
        }
    }

    private func slideCard(_ slide: Slide) -> some View {
        VStack(spacing: 0) {
            Group {
                if let url = viewModel.thumbnailURL(for: slide) {
                    ThumbnailImage(url: url)
                } else {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(white: 0.08), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay {
                            Text(slide.displayText.isEmpty ? slide.groupName : slide.displayText)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(24)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(10)

            HStack(spacing: 8) {
                if let color = slide.groupColor {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 4, height: 16)
                }
                Text("\(slide.index + 1). \(slide.groupName.isEmpty ? "Slide" : slide.groupName)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(white: 0.85))
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(Color(white: 0.4), in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }

    // MARK: - Transport

    private func previousButton(_ h: CGFloat) -> some View {
        pillButton(height: h, disabled: !viewModel.canTriggerPrevious) {
            Task { await viewModel.triggerPrevious() }
        } label: {
            Label("Previous", systemImage: "backward.end.fill")
        }
    }

    private func backItemButton(_ h: CGFloat) -> some View {
        pillButton(height: h, disabled: !viewModel.canSelectPreviousPresentation) {
            Task { await viewModel.selectPreviousPresentation() }
        } label: {
            Image(systemName: "arrow.left")
        }
        .accessibilityLabel("Previous item")
    }

    private func nextUpButton(_ h: CGFloat) -> some View {
        pillButton(height: h, disabled: nextPresentation == nil) {
            Task { await viewModel.selectNextPresentation() }
        } label: {
            HStack(spacing: 8) {
                if let next = nextPresentation {
                    Text("Next Up:").bold() + Text(" \(next.name)")
                } else {
                    Text("End of playlist")
                }
                Image(systemName: "arrow.right")
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
        }
        .accessibilityLabel(nextPresentation.map { "Next item: \($0.name)" } ?? "End of playlist")
    }

    private func nextSlideButton(_ h: CGFloat) -> some View {
        pillButton(height: h, disabled: !viewModel.canTriggerNext, prominent: true) {
            Task { await viewModel.triggerNext() }
        } label: {
            Label("Next Slide", systemImage: "play.fill")
        }
    }

    private var transportBar: some View {
        // Roomy single row (iPad); a tighter single row (phone landscape); and only then two
        // stacked rows (portrait phone) — so nothing truncates, and short screens keep their preview.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                previousButton(64).frame(maxWidth: 190)
                backItemButton(64).frame(width: 64)
                nextUpButton(64)
                nextSlideButton(64).frame(maxWidth: 220)
            }
            .font(.system(size: 22))

            HStack(spacing: 10) {
                previousButton(48).frame(maxWidth: 160)
                backItemButton(48).frame(width: 52)
                nextUpButton(48)
                nextSlideButton(48).frame(maxWidth: 180)
            }
            .font(.system(size: 17))

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    backItemButton(52).frame(width: 56)
                    nextUpButton(52)
                }
                HStack(spacing: 10) {
                    previousButton(52)
                    nextSlideButton(52)
                }
            }
            .font(.system(size: 18))
        }
    }

    private func pillButton<Label: View>(
        height: CGFloat,
        disabled: Bool,
        prominent: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundColor(disabled ? Color(white: 0.3) : .white)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(
                    Capsule().fill(
                        prominent
                            ? ProPresenterViewModel.liveColor.opacity(disabled ? 0.2 : 0.9)
                            : Color(white: disabled ? 0.13 : 0.22)
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    RemoteView()
        .environment(ProPresenterViewModel())
        .preferredColorScheme(.dark)
}
