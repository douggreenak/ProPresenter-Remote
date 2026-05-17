import SwiftUI

struct PresentationListView: View {
    @Environment(ProPresenterViewModel.self) private var viewModel

    var body: some View {
        Group {
            if viewModel.isConnected {
                List {
                    ForEach(viewModel.presentations) { presentation in
                        Button {
                            Task { await viewModel.selectPresentation(presentation) }
                        } label: {
                            PresentationRow(
                                presentation: presentation,
                                isLive: presentation.uuid == viewModel.livePresentationUUID,
                                isSelected: presentation.uuid == viewModel.selectedPresentation?.uuid
                            )
                        }
                        .listRowBackground(
                            presentation.uuid == viewModel.selectedPresentation?.uuid
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                    }
                }
                .refreshable {
                    await viewModel.fetchPresentations()
                }
            } else {
                ContentUnavailableView {
                    Label("Not Connected", systemImage: "wifi.slash")
                } description: {
                    Text("Connect to ProPresenter in Settings.")
                } actions: {
                    Button("Open Settings") {
                        viewModel.showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Presentations")
    }
}

private struct PresentationRow: View {
    let presentation: Presentation
    let isLive: Bool
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "doc.richtext")
                .foregroundStyle(isLive ? Color.accentColor : Color.secondary)

            Text(presentation.name)
                .fontWeight(isSelected ? .semibold : .regular)

            Spacer()

            if isLive {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.small)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
