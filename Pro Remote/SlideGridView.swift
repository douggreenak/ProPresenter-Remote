import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Cached Thumbnail Image

struct ThumbnailImage: View {
    let url: URL?

    @State private var image: Image?

    private static let cache: NSCache<NSURL, AnyObject> = {
        let c = NSCache<NSURL, AnyObject>()
        c.countLimit = 300
        return c
    }()

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(white: 0.13))
                    .aspectRatio(16 / 9, contentMode: .fit)
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = Self.platformImage(for: url) {
                image = cached
                return
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            if let decoded = Self.decode(data: data, url: url) {
                image = decoded
            }
        }
    }

    private static func platformImage(for url: URL) -> Image? {
        #if canImport(UIKit)
        if let img = cache.object(forKey: url as NSURL) as? UIImage {
            return Image(uiImage: img)
        }
        #else
        if let img = cache.object(forKey: url as NSURL) as? NSImage {
            return Image(nsImage: img)
        }
        #endif
        return nil
    }

    private static func decode(data: Data, url: URL) -> Image? {
        #if canImport(UIKit)
        guard let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: url as NSURL)
        return Image(uiImage: img)
        #else
        guard let img = NSImage(data: data) else { return nil }
        cache.setObject(img, forKey: url as NSURL)
        return Image(nsImage: img)
        #endif
    }
}

// MARK: - Slide Grid

struct SlideGridView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("slideMinWidth") private var slideMinWidth: Double = 200

    private var columns: [GridItem] {
        let compactDefault: CGFloat = 140
        let minimum: CGFloat = sizeClass == .compact ? max(compactDefault, CGFloat(slideMinWidth) * 0.7) : CGFloat(slideMinWidth)
        return [GridItem(.adaptive(minimum: minimum, maximum: 400), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let presentation = viewModel.selectedPresentation, !presentation.slides.isEmpty {
                headerBar(for: presentation)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(presentation.slides) { slide in
                                SlideCell(
                                    slide: slide,
                                    thumbnailURL: viewModel.thumbnailURL(for: slide.thumbnailIndex),
                                    isLive: viewModel.isViewingLivePresentation && slide.index == viewModel.liveSlideIndex
                                ) {
                                    Task { await viewModel.triggerSlide(at: slide.index) }
                                }
                                .id(slide.index)
                            }
                        }
                        .padding(6)
                    }
                    .background(Color(white: 0.12))
                    .onAppear {
                        if viewModel.isViewingLivePresentation {
                            proxy.scrollTo(viewModel.liveSlideIndex, anchor: .center)
                        }
                    }
                    .onChange(of: viewModel.liveSlideIndex) { _, newIndex in
                        if viewModel.isViewingLivePresentation {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }

                transportBar
            } else {
                ContentUnavailableView {
                    Label("No Presentation", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Select a playlist and presentation from the sidebar.")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPresentation?.uuid)
        .navigationTitle("")
        #if os(macOS)
        .navigationSubtitle("")
        #endif
    }

    private func headerBar(for presentation: Presentation) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(presentation.slides.count) slides")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.45))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
                Slider(value: $slideMinWidth, in: 120...350, step: 10)
                    .frame(width: 140)
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
            }

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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.09))
        .animation(.easeInOut(duration: 0.3), value: viewModel.isViewingLivePresentation)
    }

    private func transportButton(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(disabled ? Color(white: 0.2) : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(disabled ? Color(white: 0.1) : Color(white: 0.18))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var transportBar: some View {
        HStack(spacing: 8) {
            transportButton("Prev Item", disabled: !viewModel.canSelectPreviousPresentation) {
                Task { await viewModel.selectPreviousPresentation() }
            }

            Spacer()

            HStack(spacing: 8) {
                transportButton("First", disabled: !viewModel.canTriggerPrevious) {
                    if let first = viewModel.selectedPresentation?.slides.first(where: { $0.triggerIndex != nil }) {
                        Task { await viewModel.triggerSlide(at: first.index) }
                    }
                }

                transportButton("Previous", disabled: !viewModel.canTriggerPrevious) {
                    Task { await viewModel.triggerPrevious() }
                }

                if viewModel.isViewingLivePresentation,
                   let total = viewModel.selectedPresentation?.slides.count {
                    Text("\(viewModel.liveSlideIndex + 1) / \(total)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .frame(minWidth: 52)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: viewModel.liveSlideIndex)
                        .accessibilityLabel("Slide \(viewModel.liveSlideIndex + 1) of \(total)")
                }

                transportButton("Next", disabled: !viewModel.canTriggerNext) {
                    Task { await viewModel.triggerNext() }
                }

                transportButton("Last", disabled: !viewModel.canTriggerNext) {
                    if let last = viewModel.selectedPresentation?.slides.last(where: { $0.triggerIndex != nil }) {
                        Task { await viewModel.triggerSlide(at: last.index) }
                    }
                }
            }

            Spacer()

            transportButton("Next Item", disabled: !viewModel.canSelectNextPresentation) {
                Task { await viewModel.selectNextPresentation() }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(Color(white: 0.07))
    }
}

// MARK: - Slide Cell

private struct SlideCell: View {
    let slide: Slide
    let thumbnailURL: URL?
    let isLive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var slidePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.08), Color(white: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                Text(slide.displayText.isEmpty ? slide.groupName : slide.displayText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(slide.displayText.isEmpty ? Color(white: 0.3) : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .padding(8)
            }
    }

    var body: some View {
        Button(action: { if slide.enabled { onTap() } }) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if thumbnailURL != nil {
                        ThumbnailImage(url: thumbnailURL)
                    } else {
                        slidePlaceholder
                    }
                }

                HStack(spacing: 5) {
                    if let color = slide.groupColor {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color)
                            .frame(width: 4, height: 14)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(slide.groupName.isEmpty ? "Slide \(slide.index + 1)" : slide.groupName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(1)

                        if !slide.label.isEmpty {
                            Text(slide.label)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.45))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Text("\(slide.index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.18))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isLive ? ProPresenterViewModel.liveColor : Color(white: 0.25),
                        lineWidth: isLive ? 2.5 : 0.5
                    )
            )
            .shadow(color: isLive ? ProPresenterViewModel.liveColor.opacity(0.3) : .clear, radius: 6)
            .opacity(!slide.enabled ? 0.35 : isHovered ? 0.85 : 1.0)
            .scaleEffect(isHovered ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.3), value: isLive)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .allowsHitTesting(slide.enabled)
        .accessibilityLabel("\(slide.groupName.isEmpty ? "Slide" : slide.groupName) \(slide.index + 1)")
        .accessibilityAddTraits(isLive ? .isSelected : [])
        .accessibilityHint(slide.enabled ? "Double tap to trigger this slide" : "Slide is disabled")
    }
}
