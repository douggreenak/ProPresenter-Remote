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

                TextField("Port", text: $vm.port)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
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
                    Button("Connect") {
                        Task { await viewModel.connect() }
                    }
                }
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.connectionError {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if !viewModel.apiDebugLog.isEmpty {
                Section("API Debug Log") {
                    Text(viewModel.apiDebugLog)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxHeight: 200)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
