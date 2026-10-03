import SwiftUI

private struct ShowDetailKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Reveals the detail column when the split view is collapsed to a single column.
    var showDetail: () -> Void {
        get { self[ShowDetailKey.self] }
        set { self[ShowDetailKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Only matters at compact width (iPhone): a split view there shows one column at a time,
    /// and rows that merely mutate the view model never push the detail on their own.
    @State private var preferredColumn: NavigationSplitViewColumn = .detail
    @State private var showRemote = false

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            PresentationListView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
                .environment(\.showDetail) { preferredColumn = .detail }
        } detail: {
            // These live on the detail column, not the split view: on iPadOS, toolbar items
            // declared on the NavigationSplitView itself never render, which left Settings,
            // Refresh and the connection badge unreachable once connected.
            SlideGridView()
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        ConnectionStatusBadge(
                            isConnected: viewModel.isConnected,
                            isHealthy: viewModel.connectionHealthy,
                            host: viewModel.host
                        ) {
                            viewModel.showSettings = true
                        }
                    }

                    ToolbarItem(placement: .automatic) {
                        Button {
                            Task { await viewModel.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                        .accessibilityLabel("Refresh")
                    }

                    ToolbarItem(placement: .automatic) {
                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .help("Settings")
                        .accessibilityLabel("Settings")
                    }

                    ToolbarItem(placement: .automatic) {
                        Button {
                            // Without a Companion address there is nothing to show; go and set one.
                            if viewModel.companionConfigured {
                                viewModel.openStreamDeck()
                            } else {
                                viewModel.showSettings = true
                            }
                        } label: {
                            Image(systemName: "square.grid.3x3.fill")
                        }
                        .help("Stream Deck")
                        .accessibilityLabel("Stream Deck")
                    }

                    ToolbarItem(placement: .automatic) {
                        Button {
                            viewModel.showMacros = true
                        } label: {
                            Image(systemName: "bolt.fill")
                        }
                        .help("Macros")
                        .accessibilityLabel("Macros")
                    }

                    ToolbarItemGroup(placement: .automatic) {
                        CompanionButtonsView()
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showRemote = true
                        } label: {
                            Image(systemName: "rectangle.on.rectangle.angled")
                        }
                        .help("Remote View")
                        .accessibilityLabel("Remote view")
                    }
                }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .space, .return, .escape]) { press in
            switch press.key {
            case .rightArrow, .space, .return:
                Task { await viewModel.triggerNext() }
                return .handled
            case .leftArrow:
                Task { await viewModel.triggerPrevious() }
                return .handled
            case .downArrow:
                Task { await viewModel.selectNextPresentation() }
                return .handled
            case .upArrow:
                Task { await viewModel.selectPreviousPresentation() }
                return .handled
            case .escape:
                if !viewModel.isViewingLivePresentation {
                    Task { await viewModel.goToLive() }
                }
                return .handled
            default:
                return .ignored
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showRemote) {
            RemoteView()
        }
        .fullScreenCover(isPresented: $vm.showStreamDeck) {
            StreamDeckView()
        }
        .fullScreenCover(isPresented: $vm.showMacros) {
            MacrosView()
        }
        #else
        .sheet(isPresented: $showRemote) {
            RemoteView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .sheet(isPresented: $vm.showStreamDeck) {
            StreamDeckView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .sheet(isPresented: $vm.showMacros) {
            MacrosView()
                .frame(minWidth: 720, minHeight: 480)
        }
        #endif
        .sheet(isPresented: $vm.showSettings, onDismiss: {
            // A Stream Deck requested from Settings opens only once Settings is fully gone.
            if viewModel.pendingStreamDeck {
                viewModel.pendingStreamDeck = false
                viewModel.showStreamDeck = true
            }
        }) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { viewModel.showSettings = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 450, minHeight: 350)
            #endif
        }
        .task {
            if !viewModel.host.isEmpty && !viewModel.isConnected {
                await viewModel.connect()
            }
            // With no server there is nothing to control, so open Settings rather than leave
            // an empty grid. Only on launch, and only once: a dropped connection mid-service
            // must never throw a sheet over the operator's slides — the status badge covers
            // that case, and the websocket reconnects on its own.
            if !viewModel.isConnected {
                viewModel.showSettings = true
            }
        }
    }
}

// MARK: - Connection Status Badge

private struct ConnectionStatusBadge: View {
    let isConnected: Bool
    let isHealthy: Bool
    var host: String = ""
    var onTap: () -> Void = {}

    @State private var isHovered = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Portrait iPhone has no room for the word next to four other toolbar buttons; without
    /// this the system pushes the Remote button into the overflow menu.
    private var showsLabel: Bool { !(sizeClass == .compact && verticalSizeClass == .regular) }

    private var color: Color {
        if isConnected && isHealthy { return .green }
        if isConnected { return .yellow }
        return .red
    }

    private var label: String {
        if isConnected && isHealthy { return "Connected" }
        if isConnected { return "Reconnecting" }
        return "Offline"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                ZStack {
                    if isConnected && !isHealthy {
                        Circle()
                            .fill(color.opacity(0.4))
                            .frame(width: 14, height: 14)
                            .scaleEffect(isHovered ? 1.1 : 1.0)
                    }
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
                if showsLabel {
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.quaternary.opacity(isHovered ? 0.8 : 0.5))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(isHovered ? 0.4 : 0), lineWidth: 1)
            )
            .fixedSize()
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .symbolEffect(.pulse, options: .repeating, isActive: isConnected && !isHealthy)
        .animation(.easeInOut(duration: 0.5), value: isConnected)
        .animation(.easeInOut(duration: 0.5), value: isHealthy)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .help(isConnected && !host.isEmpty ? "\(host) — click to open Settings" : "Click to open Settings")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(label)")
        .accessibilityValue(isConnected && !host.isEmpty ? host : "")
        .accessibilityHint("Opens Settings")
    }
}

#Preview {
    ContentView()
        .environment(ProPresenterViewModel())
}
