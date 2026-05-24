# Pro Remote

A native SwiftUI remote control app for [ProPresenter 7](https://renewedvision.com/propresenter/), built for Mac, iPad, and iPhone.

Browse playlists, view slide thumbnails, trigger slides, and monitor the live output -- all from a fast, dark-themed interface that connects over your local network via ProPresenter's built-in REST API.

## Features

- **Playlist & Presentation Browser** -- Navigate playlists and presentations in a sidebar with live status indicators.
- **Slide Grid** -- Responsive thumbnail grid with adjustable sizing. Tap or click any slide to trigger it live.
- **Live Output Monitor** -- See the current and next slide thumbnails, slide text, and speaker notes in real time.
- **Transport Controls** -- First / Previous / Next / Last slide buttons, plus Previous Item / Next Item to navigate between presentations.
- **Keyboard Shortcuts** -- Arrow keys, Space, Return, Escape, and Cmd+arrow shortcuts for hands-free control.
- **Companion Buttons** -- Up to 6 configurable HTTP trigger buttons for Bitfocus Companion or other automation tools.
- **WebSocket Updates** -- Real-time slide change notifications with automatic reconnection and exponential backoff.
- **Thumbnail Caching** -- In-memory image cache (NSCache) eliminates flickering when scrolling through slides.
- **Presentation Caching** -- Fetched presentation data is cached to minimize API calls and prevent ProPresenter from showing focus outlines.
- **Accessibility** -- VoiceOver labels, traits, and hints throughout. Full keyboard navigation support.
- **Haptic Feedback** -- Tactile response when triggering slides on iPhone.

## Requirements

- macOS 26+ / iOS 26+ / iPadOS 26+
- Xcode 26+
- ProPresenter 7 with the Network API enabled
- Both devices on the same local network

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/douggreenak/ProPresenter-Remote.git
   ```
2. Open `Pro Remote.xcodeproj` in Xcode.
3. Build and run on your target device (Mac, iPad, or iPhone).
4. In Pro Remote, open **Settings** and enter your ProPresenter machine's IP address and port (default `1025`).
5. Tap **Connect**.

## ProPresenter Configuration

Make sure the Stage Display / Network API is enabled in ProPresenter:

1. Open **ProPresenter** > **Preferences** > **Network**.
2. Enable the network API and note the port number.
3. Ensure both machines are on the same network and the port is not blocked by a firewall.

## Architecture

The app is built with modern Swift concurrency and SwiftUI:

| File | Purpose |
|---|---|
| `Pro_RemoteApp.swift` | App entry point, window configuration, menu commands |
| `ContentView.swift` | NavigationSplitView layout, toolbar, keyboard handling |
| `PresentationListView.swift` | Sidebar with playlist and presentation lists |
| `SlideGridView.swift` | Adaptive slide thumbnail grid and transport bar |
| `NotesView.swift` | Live output monitor with current/next slide previews |
| `SettingsView.swift` | Connection settings form |
| `CompanionButtonsView.swift` | Configurable HTTP trigger buttons |
| `ProPresenterViewModel.swift` | `@Observable` view model, app state and business logic |
| `ProPresenterAPI.swift` | REST API client (actor-isolated) |
| `WebSocketManager.swift` | WebSocket connection for real-time slide updates |
| `Models.swift` | Data models and API response types |

## Built With AI

This project was developed with significant assistance from **Claude AI** (Anthropic). Claude contributed to the UI design, architecture decisions, accessibility implementation, bug fixes, and over 55 polish items across the codebase.

## License

This project is provided as-is for personal and church use.
