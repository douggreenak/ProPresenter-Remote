import SwiftUI

/// The zoom slider for the slide grid. On iPad/iPhone it sits in the grid's header; on the Mac it
/// lives in the window toolbar.
struct ZoomControl: View {
    @AppStorage("slideMinWidth") private var slideMinWidth: Double = 200

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color(white: macIconWhite))
            #if os(macOS)
            // No `step`: on the Mac a stepped slider draws a row of tick marks under the track.
            Slider(value: Binding(get: { slideMinWidth }, set: { slideMinWidth = ($0 / 10).rounded() * 10 }), in: 120...350)
                .tint(ProPresenterViewModel.liveColor)
                .frame(width: 100)
                .accessibilityLabel("Slide size")
            #else
            Slider(value: $slideMinWidth, in: 120...350, step: 10)
                .frame(width: 120)
                .accessibilityLabel("Slide size")
            #endif
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color(white: macIconWhite))
            #if os(iOS)
            Text("\(Int(slideMinWidth))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 28, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: slideMinWidth)
            #endif
        }
        #if os(macOS)
        // The toolbar's glass capsule is rounded, so anything touching its ends is clipped.
        .padding(.horizontal, 12)
        .fixedSize()
        #endif
    }

    /// The Mac toolbar sits on glass, where the iPad's dim grey disappears.
    private var macIconWhite: Double {
        #if os(macOS)
        0.7
        #else
        0.4
        #endif
    }
}

/// The small status capsules for the presentation being viewed: Go to Active, Preview, LIVE, and the
/// announcement-layer indicator.
struct PresentationStatusBadges: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    let presentation: Presentation

    var body: some View {
        HStack(spacing: 8) {
            if !viewModel.isViewingLivePresentation && !viewModel.livePresentationUUID.isEmpty {
                Button {
                    Task { await viewModel.goToLive() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 8))
                        Text("Go to Active")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(ProPresenterViewModel.liveColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ProPresenterViewModel.liveColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to active presentation")
            }

            if presentation.previewOnly && !viewModel.isViewingLivePresentation {
                Label("Preview", systemImage: "eye")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(white: 0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.25), in: Capsule())
                    .help("ProPresenter won't share this item's slide details, so only thumbnails are shown. Start it in ProPresenter and the controls here will take over.")
                    .accessibilityLabel("Preview only")
                    .accessibilityHint("ProPresenter won't share this item's slide details. Start it in ProPresenter to control it from here.")
            }

            if viewModel.isViewingLivePresentation {
                PhaseAnimator([false, true]) { isGlowing in
                    Text("LIVE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ProPresenterViewModel.liveColor, in: Capsule())
                        .shadow(color: ProPresenterViewModel.liveColor.opacity(isGlowing ? 0.5 : 0), radius: isGlowing ? 5 : 0)
                } animation: { _ in
                    .easeInOut(duration: 1.5)
                }
            }

            AnnouncementLayerIndicator()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isViewingLivePresentation)
        .animation(.easeInOut(duration: 0.3), value: viewModel.announcementLayer)
    }
}

/// A small TV mark: this item is running on the announcement layer (the loop sent to the outside TVs),
/// separate from what is live on the main layer.
struct AnnouncementBadge: View {
    var body: some View {
        Image(systemName: "tv")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(red: 0.2, green: 0.45, blue: 0.8).opacity(0.28), in: Capsule())
            .help("Running on the announcement layer")
            .accessibilityLabel("Running on the announcement layer")
    }
}

/// Shown in the header or toolbar whenever something is running on the announcement layer.
struct AnnouncementLayerIndicator: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        if let layer = viewModel.announcementLayer {
            HStack(spacing: 4) {
                Image(systemName: "tv")
                    .font(.system(size: 9, weight: .bold))
                Text("Announcements")
                    .font(.system(size: 9, weight: .heavy))
            }
            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(red: 0.2, green: 0.45, blue: 0.8).opacity(0.28), in: Capsule())
            .help("\(layer.name) is running on the announcement layer")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(layer.name) is running on the announcement layer")
            .transition(.opacity)
        }
    }
}
