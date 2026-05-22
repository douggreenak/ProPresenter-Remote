import SwiftUI

@main
struct Pro_RemoteApp: App {
    @State private var viewModel = ProPresenterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Presentation") {
                Button("Next Slide") {
                    Task { await viewModel.triggerNext() }
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Previous Slide") {
                    Task { await viewModel.triggerPrevious() }
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("Next Presentation") {
                    Task { await viewModel.selectNextPresentation() }
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Button("Previous Presentation") {
                    Task { await viewModel.selectPreviousPresentation() }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Divider()

                Button("Refresh All") {
                    Task { await viewModel.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(viewModel)
                .frame(minWidth: 450, minHeight: 300)
        }
        #endif
    }
}
