import SwiftUI

struct CompanionButtonsView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @State private var showEditor = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.companionButtons) { button in
                Button {
                    Task { await viewModel.triggerCompanionButton(button) }
                } label: {
                    Text(button.label)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .frame(minWidth: 44, minHeight: 28)
                }
                .buttonStyle(.glass)
                .disabled(button.url == nil)
                .accessibilityLabel("Trigger \(button.label)")
                .accessibilityHint(button.urlString.isEmpty ? "No URL configured" : "")
            }

            Button {
                showEditor = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.glass)
        }
        .sheet(isPresented: $showEditor) {
            CompanionButtonEditor()
        }
    }
}

private struct CompanionButtonEditor: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                Section("Companion Buttons (up to 6)") {
                    ForEach($vm.companionButtons) { $button in
                        HStack {
                            TextField("Label", text: $button.label)
                                .frame(maxWidth: 120)
                            TextField("URL", text: $button.urlString)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                #endif
                        }
                    }
                    .onDelete { indices in
                        viewModel.companionButtons.remove(atOffsets: indices)
                    }

                    if viewModel.companionButtons.count < 6 {
                        Button("Add Button") {
                            viewModel.companionButtons.append(
                                CompanionButton(label: "Action", urlString: "")
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Companion Buttons")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
    }
}
