import SwiftUI

struct ContentView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView(columnVisibility: $columnVisibility) {
            PresentationListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            SlideGridView()
        } detail: {
            NotesView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusBadge(
                    isConnected: viewModel.isConnected,
                    isWebSocketConnected: viewModel.isWebSocketConnected
                )
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
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
    let isWebSocketConnected: Bool

    private var color: Color {
        if isConnected && isWebSocketConnected { return .green }
        if isConnected { return .yellow }
        return .red
    }

    private var label: String {
        if isConnected && isWebSocketConnected { return "Live" }
        if isConnected { return "REST" }
        return "Offline"
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

#Preview {
    ContentView()
        .environment(ProPresenterViewModel())
}
