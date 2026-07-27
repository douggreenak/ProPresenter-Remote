import SwiftUI

struct SettingsView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var discovery = ProPresenterDiscovery()
    @State private var showDisconnectConfirmation = false

    /// The friendly Bonjour name of whatever we're connected to, falling back to the address.
    private var connectedLabel: String {
        discovery.servers.first { $0.host == viewModel.host && String($0.port) == viewModel.port }?.name
            ?? viewModel.host
    }

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            discoverySection

            Section("ProPresenter Connection") {
                TextField("Host / IP Address", text: $vm.host)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: viewModel.host) { _, _ in testResult = nil }

                TextField("Port", text: $vm.port)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: viewModel.port) { _, newValue in
                        let filtered = newValue.filter(\.isNumber)
                        if filtered != newValue { viewModel.port = filtered }
                        testResult = nil
                    }
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        Task {
                            isTesting = true
                            testResult = nil
                            testResult = await viewModel.testConnection()
                            isTesting = false
                        }
                    }
                    Spacer()
                    if isTesting {
                        ProgressView()
                    } else if let result = testResult {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red)
                    }
                }

                if viewModel.isConnected {
                    Button(role: .destructive) {
                        showDisconnectConfirmation = true
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        Task { await viewModel.connect() }
                    } label: {
                        HStack {
                            Text("Connect")
                            if viewModel.isLoading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.host.isEmpty)
                }
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(viewModel.isConnected && viewModel.connectionHealthy ? .green : viewModel.isConnected ? .yellow : .red)
                        .frame(width: 10, height: 10)
                    Text(viewModel.isConnected && viewModel.connectionHealthy ? "Connected" : viewModel.isConnected ? "Reconnecting" : "Disconnected")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.connectionError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task {
            discovery.start()
        }
        .onDisappear {
            discovery.stop()
        }
        .confirmationDialog(
            "Disconnect from \(connectedLabel)?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                viewModel.disconnect()
                testResult = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pro Remote will stop following ProPresenter and clear the slide list until you connect again.")
        }
    }

    // MARK: - Discovery

    /// ProPresenter advertises itself over Bonjour, so the machine and its port can be picked
    /// from a list instead of typed — which also avoids guessing the wrong subnet or port.
    private var discoverySection: some View {
        Section {
            ForEach(discovery.servers) { server in
                Button {
                    select(server)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.name)
                                .foregroundStyle(.primary)
                            Text("\(server.host):\(String(server.port))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if isCurrent(server) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(server.name) at \(server.host) port \(String(server.port))")
                .accessibilityHint("Use this ProPresenter")
            }

            if discovery.servers.isEmpty {
                HStack(spacing: 8) {
                    if discovery.isBrowsing {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                    }
                    Text(discovery.isBrowsing ? "Searching for ProPresenter…" : "No ProPresenter found")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            if let error = discovery.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        } header: {
            HStack {
                Text("Discovered on Network")
                Spacer()
                Button("Search Again") { discovery.restart() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            }
        } footer: {
            Text("ProPresenter must have its network feature enabled.")
        }
    }

    private func isCurrent(_ server: DiscoveredServer) -> Bool {
        viewModel.host == server.host && viewModel.port == String(server.port)
    }

    private func select(_ server: DiscoveredServer) {
        viewModel.host = server.host
        viewModel.port = String(server.port)
        testResult = nil
        Task {
            if viewModel.isConnected { viewModel.disconnect() }
            await viewModel.connect()
        }
    }
}
