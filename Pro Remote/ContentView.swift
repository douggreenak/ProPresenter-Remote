import SwiftUI

struct ContentView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView(columnVisibility: $columnVisibility) {
            PresentationListView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            SlideGridView()
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusBadge(
                    isConnected: viewModel.isConnected,
                    isHealthy: viewModel.connectionHealthy,
                    host: viewModel.host
                )
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("Settings")
            }

            ToolbarItemGroup(placement: .automatic) {
                CompanionButtonsView()
            }
        }
        .sheet(isPresented: $vm.showSettings) {
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
        }
    }
}

// MARK: - Connection Status Badge

private struct ConnectionStatusBadge: View {
    let isConnected: Bool
    let isHealthy: Bool
    var host: String = ""

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

    private var icon: String {
        if isConnected && isHealthy { return "antenna.radiowaves.left.and.right" }
        if isConnected { return "network" }
        return "wifi.slash"
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .fixedSize()
        .animation(.easeInOut(duration: 0.5), value: isConnected)
        .animation(.easeInOut(duration: 0.5), value: isHealthy)
        .help(isConnected && !host.isEmpty ? host : "Not connected")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(label)")
        .accessibilityValue(isConnected && !host.isEmpty ? host : "")
    }
}

#Preview {
    ContentView()
        .environment(ProPresenterViewModel())
}
