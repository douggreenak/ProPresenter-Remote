import SwiftUI

/// ProPresenter's macros as a grid of tiles.
///
/// Opening this page and scrolling it only ever *lists* macros. Running one happens only when a
/// tile is tapped and - unless turned off in Settings - the confirmation is accepted, because a
/// macro can switch lights, audio or cameras on the spot.
struct MacrosView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var search = ""
    @State private var pending: Macro?
    @State private var justRan: String?
    @State private var failure: String?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .compact ? 150 : 240), spacing: 10)]
    }

    private var filtered: [Macro] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return viewModel.macros }
        return viewModel.macros.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isConnected {
                    ContentUnavailableView {
                        Label("Not Connected", systemImage: "wifi.slash")
                    } description: {
                        Text("Connect to ProPresenter in Settings to see its macros.")
                    }
                } else if viewModel.macros.isEmpty {
                    if viewModel.macrosLoading {
                        ProgressView("Loading macros…")
                    } else {
                        ContentUnavailableView {
                            Label(viewModel.macrosError == nil ? "No Macros" : "Can't Load Macros", systemImage: "bolt.slash")
                        } description: {
                            Text(viewModel.macrosError ?? "ProPresenter has no macros.")
                        } actions: {
                            Button("Try Again") { Task { await viewModel.fetchMacros() } }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(filtered) { macro in
                                MacroTile(macro: macro, justRan: justRan == macro.uuid) {
                                    request(macro)
                                }
                            }
                        }
                        .padding(14)

                        if filtered.isEmpty {
                            ContentUnavailableView.search(text: search)
                        }
                    }
                }
            }
            .background(Color(white: 0.07).ignoresSafeArea())
            .navigationTitle("Macros")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $search, prompt: "Search macros")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.fetchMacros() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload macros")
                    .disabled(viewModel.macrosLoading || !viewModel.isConnected)
                }
            }
        }
        .task { await viewModel.fetchMacros() }
        .confirmationDialog(
            pending.map { "Run “\($0.name)”?" } ?? "Run macro?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { macro in
            Button("Run Macro", role: .destructive) { run(macro) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This runs on ProPresenter right now and may switch lights, audio or cameras.")
        }
        .alert("Macro didn't run", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    /// A tile was tapped: confirm first (default), or run straight away if the user turned that off.
    private func request(_ macro: Macro) {
        if viewModel.confirmMacros {
            pending = macro
        } else {
            run(macro)
        }
    }

    private func run(_ macro: Macro) {
        pending = nil
        Task {
            let ok = await viewModel.runMacro(macro)
            if ok {
                withAnimation(.snappy) { justRan = macro.uuid }
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.snappy) { if justRan == macro.uuid { justRan = nil } }
            } else {
                failure = "ProPresenter didn't accept “\(macro.name)”. Check the connection and try again."
            }
        }
    }
}

// MARK: - Tile

private struct MacroTile: View {
    let macro: Macro
    let justRan: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var accent: Color { macro.color ?? Color(white: 0.5) }

    private func symbol(for type: String) -> String {
        switch type {
        case "communication": "antenna.radiowaves.left.and.right"
        case "audience_look": "eye"
        case "stage_layout": "rectangle.3.group"
        case "timer": "timer"
        case "slide_destination": "arrow.triangle.branch"
        case "macro": "bolt"
        case "clear": "xmark.rectangle"
        case "media": "film"
        case "prop": "photo.on.rectangle"
        case "message": "text.bubble"
        case "transport_control": "playpause"
        default: "square.dashed"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(macro.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ForEach(macro.actionTypes, id: \.self) { type in
                            Image(systemName: symbol(for: type))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(white: 0.6))
                        }
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 96)
            .background(accent.opacity(isHovered ? 0.24 : 0.16))
            .background(Color(white: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay {
                if justRan {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.7))
                        .overlay(Label("Sent", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline))
                        .transition(.opacity)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(macro.name)
        .accessibilityHint("Asks for confirmation, then runs this macro")
    }
}
