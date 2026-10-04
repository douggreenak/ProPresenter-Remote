import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A virtual Stream Deck: the same buttons as Bitfocus Companion, drawn and driven natively.
///
/// The picture on each key comes straight from Companion (so icons, colours and live feedback match
/// the hardware exactly); everything around it - the chassis, key wells, glass caps, press feel,
/// page and connection state - is ordinary SwiftUI.
struct StreamDeckView: View {
    /// True when shown in its own macOS window rather than as a sheet over the main window.
    var inWindow = false

    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var deck = CompanionDeck()

    /// Sharper pictures where keys are big (iPad, Mac); smaller on phones to save bandwidth.
    private var bitmapSize: Int { sizeClass == .compact ? 192 : 320 }

    var body: some View {
        NavigationStack {
            ZStack {
                DeskBackground()

                if viewModel.companionConfigured {
                    DeckBody(deck: deck, showNumbers: viewModel.companionShowNumbers, isPhone: sizeClass == .compact)
                        .opacity(deck.state == .connected ? 1 : 0.4)
                        .saturation(deck.state == .connected ? 1 : 0.3)
                        .allowsHitTesting(deck.state == .connected)
                        .animation(.easeInOut(duration: 0.3), value: deck.state)

                    statusOverlay
                } else {
                    ContentUnavailableView {
                        Label("Companion Not Set Up", systemImage: "square.grid.3x3")
                    } description: {
                        Text("Add Companion's address in Settings.")
                    }
                }
            }
            .navigationTitle("Stream Deck")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !inWindow {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                #if os(macOS)
                if !inWindow {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // Close the sheet first: only one copy may hold the Companion surface.
                            dismiss()
                            openWindow(id: StreamDeckWindow.id)
                        } label: {
                            Label("Pop Out", systemImage: "arrow.up.forward.app")
                        }
                        .help("Open the Stream Deck in its own window")
                    }
                }
                #endif
            }
        }
        .task { connect() }
        .onAppear {
            #if os(macOS)
            if inWindow { viewModel.streamDeckWindowOpen = true }
            #endif
        }
        .onDisappear {
            deck.stop()
            #if os(macOS)
            if inWindow { viewModel.streamDeckWindowOpen = false }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // iOS suspends sockets in the background; reconnect cleanly on the way back.
            if phase == .active { connect() } else if phase == .background { deck.stop() }
        }
    }

    private func connect() {
        guard viewModel.companionConfigured else { return }
        deck.start(host: viewModel.companionHostTrimmed, port: viewModel.companionPortInt, bitmapSize: bitmapSize)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch deck.state {
        case .connecting:
            ProgressView("Connecting to Companion…")
                .progressViewStyle(.circular)
                .tint(.white)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("Can't Reach Companion")
                    .font(.headline)
                Text("\(message)\nCheck the address in Settings and that Companion's Satellite API is enabled.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { deck.retryNow() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .idle, .connected:
            EmptyView()
        }
    }
}

// MARK: - Desk

private struct DeskBackground: View {
    var body: some View {
        Color(white: 0.055).ignoresSafeArea()
    }
}

// MARK: - Deck

/// Everything is derived from the key size, so the deck keeps its proportions at any screen size.
private struct DeckMetrics {
    let key: CGFloat
    /// On a phone the chassis shrinks to a sliver so the keys get the room.
    var tight = false
    /// Turned on its side (4 across, 8 down): a phone held upright has far more height than width.
    var turned = false

    var columns: Int { turned ? CompanionDeck.rows : CompanionDeck.columns }
    var rows: Int { turned ? CompanionDeck.columns : CompanionDeck.rows }

    var gap: CGFloat { key * 0.11 }
    var edge: CGFloat { key * (tight ? 0.14 : 0.30) }
    var footer: CGFloat { key * (tight ? 0.30 : 0.34) }
    var bodyCorner: CGFloat { key * (tight ? 0.18 : 0.22) }

    var gridWidth: CGFloat { key * CGFloat(columns) + gap * CGFloat(columns - 1) }
    var gridHeight: CGFloat { key * CGFloat(rows) + gap * CGFloat(rows - 1) }
    var width: CGFloat { gridWidth + edge * 2 }
    var height: CGFloat { gridHeight + edge + footer }

    /// Which Companion key sits at this row and column of the drawn grid.
    func keyIndex(row: Int, column: Int) -> Int {
        turned ? column * CompanionDeck.columns + row : row * CompanionDeck.columns + column
    }

    /// The largest key that lets the whole deck fit inside `size`. With `canTurn`, the deck is
    /// laid on its side when that gives bigger keys (a phone held upright).
    static func fitting(_ size: CGSize, tight: Bool, canTurn: Bool) -> DeckMetrics {
        let margin: CGFloat = tight ? 6 : 24
        func best(turned: Bool) -> DeckMetrics {
            let unit = DeckMetrics(key: 1, tight: tight, turned: turned)
            let byWidth = (size.width - margin * 2) / unit.width
            let byHeight = (size.height - margin * 2) / unit.height
            return DeckMetrics(key: max(8, floor(min(byWidth, byHeight))), tight: tight, turned: turned)
        }
        let upright = best(turned: false)
        guard canTurn else { return upright }
        let turned = best(turned: true)
        return turned.key > upright.key ? turned : upright
    }
}

private struct DeckBody: View {
    let deck: CompanionDeck
    let showNumbers: Bool
    let isPhone: Bool

    var body: some View {
        GeometryReader { geometry in
            let m = DeckMetrics.fitting(geometry.size, tight: isPhone, canTurn: isPhone)

            VStack(spacing: 0) {
                VStack(spacing: m.gap) {
                    ForEach(0..<m.rows, id: \.self) { row in
                        HStack(spacing: m.gap) {
                            ForEach(0..<m.columns, id: \.self) { column in
                                let index = m.keyIndex(row: row, column: column)
                                DeckKey(
                                    image: deck.images[index],
                                    edges: deck.edges[index],
                                    label: deck.labels[index] ?? "",
                                    showNumbers: showNumbers,
                                    side: m.key,
                                    onChange: { deck.setKey(index, pressed: $0) }
                                )
                            }
                        }
                    }
                }
                .padding(.top, m.edge)

                StatusBar(deck: deck, metrics: m)
                    .frame(width: m.gridWidth, height: m.footer)
            }
            .frame(width: m.width, height: m.height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: m.bodyCorner, style: .continuous)
                    .fill(Color(white: 0.105))
                    .overlay(
                        RoundedRectangle(cornerRadius: m.bodyCorner, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: m.key * 0.25, y: m.key * 0.1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The first layout pass can see a different size than the final one; animating between
        // them made the deck grow out of a corner as the screen came up.
        .transaction { $0.animation = nil }
    }
}

// MARK: - Window

/// The Stream Deck in a window of its own (macOS), so it can sit beside the slides.
enum StreamDeckWindow {
    static let id = "stream-deck"
}

// MARK: - Status

/// One quiet line under the keys: the page on the left, the connection on the right.
private struct StatusBar: View {
    let deck: CompanionDeck
    let metrics: DeckMetrics

    private var dot: Color {
        switch deck.state {
        case .connected: .green
        case .connecting: .yellow
        case .failed: .red
        case .idle: Color(white: 0.4)
        }
    }

    private var statusText: String {
        switch deck.state {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .failed: "Offline"
        case .idle: "Idle"
        }
    }

    var body: some View {
        let size = max(11, metrics.key * 0.15)
        HStack {
            if let page = deck.page, deck.state == .connected {
                Text("Page \(page)")
                    .contentTransition(.numericText())
                    .animation(.snappy, value: page)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: size * 0.55, height: size * 0.55)
                Text(statusText)
            }
            .animation(.easeInOut(duration: 0.3), value: deck.state)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Companion \(statusText.lowercased())")
        }
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.45))
        .padding(.top, metrics.key * 0.02)
    }
}

// MARK: - Key

private struct DeckKey: View {
    let image: CGImage?
    let edges: CompanionDeck.EdgeColors?
    let label: String
    let showNumbers: Bool
    let side: CGFloat
    let onChange: (Bool) -> Void

    @State private var isDown = false

    private var corner: CGFloat { side * 0.10 }

    /// Companion paints a band of location text ("1/0/3") across the top of every picture. Drop it
    /// so the key looks like a real one; the key's own colour fills the space it leaves.
    private var displayedImage: CGImage? {
        guard let image, !showNumbers else { return image }
        let cut = Int((Double(image.height) * CompanionDeck.locationStripFraction).rounded(.up))
        guard cut < image.height else { return image }
        return image.cropping(to: CGRect(x: 0, y: cut, width: image.width, height: image.height - cut)) ?? image
    }

    var body: some View {
        ZStack {
            Color.black
            if let displayedImage {
                ZStack {
                    if !showNumbers, let edges {
                        VStack(spacing: 0) {
                            Color(cgColor: edges.top)
                            Color(cgColor: edges.bottom)
                        }
                    }
                    Image(decorative: displayedImage, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .brightness(isDown ? -0.12 : 0)
        .scaleEffect(isDown ? 0.96 : 1)
        .animation(.easeOut(duration: 0.1), value: isDown)
        .contentShape(RoundedRectangle(cornerRadius: corner))
        // Down on touch, up on release: Companion supports hold, latch and long-press actions,
        // exactly as a hardware key does.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDown else { return }
                    isDown = true
                    Haptics.press()
                    onChange(true)
                }
                .onEnded { _ in
                    guard isDown else { return }
                    isDown = false
                    Haptics.release()
                    onChange(false)
                }
        )
        .onDisappear {
            if isDown { isDown = false; onChange(false) }
        }
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Empty key" : label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onChange(true)
            onChange(false)
        }
    }
}

private enum Haptics {
    static func press() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        #endif
    }

    static func release() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
        #endif
    }
}
