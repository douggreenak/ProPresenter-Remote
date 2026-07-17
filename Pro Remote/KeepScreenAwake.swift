import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Holds the display awake while the app is on screen. Pro Remote sits untouched on a
/// stand for long stretches between slide triggers, so the normal idle timer would blank
/// the screen mid-service.
private struct KeepScreenAwake: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    #if os(macOS)
    @State private var activity: NSObjectProtocol?
    #endif

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                // .inactive still means visible — an unfocused iPad Split View pane, or a
                // Mac window that isn't frontmost — so only give the display back on .background.
                setEnabled(phase != .background)
            }
            .onDisappear { setEnabled(false) }
    }

    private func setEnabled(_ enabled: Bool) {
        #if os(iOS) || os(visionOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
        #elseif os(macOS)
        if enabled, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "Pro Remote is on screen"
            )
        } else if !enabled, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        #endif
    }
}

extension View {
    /// Prevents the display from sleeping while this view's scene is on screen.
    func keepScreenAwake() -> some View {
        modifier(KeepScreenAwake())
    }
}
