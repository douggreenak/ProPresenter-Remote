import SwiftUI

/// The zoom slider for the slide grid. On iPad/iPhone it sits in the grid's header; on the Mac it
/// lives in the window toolbar.
struct ZoomControl: View {
    @AppStorage("slideMinWidth") private var slideMinWidth: Double = 200

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
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
                .foregroundColor(Color(white: 0.4))
            #if os(iOS)
            Text("\(Int(slideMinWidth))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 28, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: slideMinWidth)
            #endif
        }
    }
}

/// The small status capsules for the presentation being viewed: Go to Active, Preview, Arrangement
/// Mismatch, and LIVE.
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

            if viewModel.isViewingLivePresentation && viewModel.liveArrangementMismatch {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text("Arrangement Mismatch")
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.yellow, in: Capsule())
                .help("ProPresenter's library arrangement for this song doesn't match the one Sunday Service has selected, so the app is showing the raw slide order instead. Re-select the correct arrangement in ProPresenter to fix this.")
                .accessibilityLabel("Arrangement mismatch")
                .accessibilityHint("ProPresenter's library arrangement doesn't match the one Sunday Service selected. Showing the raw slide order instead. Re-select the correct arrangement in ProPresenter to fix this.")
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
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isViewingLivePresentation)
        .animation(.easeInOut(duration: 0.3), value: viewModel.liveArrangementMismatch)
    }
}
