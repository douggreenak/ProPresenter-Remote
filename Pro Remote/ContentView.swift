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
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            switch press.key {
            case .rightArrow:
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
            default:
                return .ignored
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusBadge(
                    isConnected: viewModel.isConnected,
                    isHealthy: viewModel.connectionHealthy
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

    private var color: Color {
        if isConnected && isHealthy { return .green }
        if isConnected { return .yellow }
        return .red
    }

    private var label: String {
        if isConnected && isHealthy { return "Connected" }
        if isConnected { return "Connecting" }
        return "Offline"
    }

    private var icon: String {
        if isConnected && isHealthy { return "antenna.radiowaves.left.and.right" }
        if isConnected { return "network" }
        return "wifi.slash"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .fixedSize()
    }
}

#Preview {
    ContentView()
        .environment(ProPresenterViewModel())
}
