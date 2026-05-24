import SwiftUI

struct SettingsView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var isTesting = false
    @State private var testResult: Bool?

    var body: some View {
        @Bindable var vm = viewModel

        Form {
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
                    Button("Disconnect", role: .destructive) {
                        viewModel.disconnect()
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
    }
}
