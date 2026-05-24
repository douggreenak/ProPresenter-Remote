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

## Troubleshooting

### Slides are out of order or missing

ProPresenter presentations can have **arrangements** that reorder slide groups. Pro Remote reads the arrangement assigned to each playlist item. If slides appear out of order or don't match what you see in ProPresenter:

1. Open the presentation in **ProPresenter's Library**.
2. In the presentation editor, check the **Arrangement** dropdown (bottom of the slide area).
3. Make sure the correct arrangement is selected and saved to the library copy.
4. In your **Playlist**, remove and re-add the presentation so the playlist item picks up the correct arrangement UUID.

If no arrangement is set in the library, ProPresenter's API returns slides in raw group order, which may not match what plays on screen.

### Thumbnails not loading

- Verify both devices are on the same network and can reach each other.
- Check that the port is not blocked by a firewall.
- Thumbnails are fetched from `http://<host>:<port>/v1/presentation/<uuid>/thumbnail/<index>`. If the presentation has not been opened recently in ProPresenter, thumbnails may not be generated yet -- open the presentation once in ProPresenter to populate them.

### Connection drops frequently

- The app uses both HTTP polling (every 1 second) and a WebSocket connection for real-time updates.
- If the connection badge turns yellow, the WebSocket is reconnecting with exponential backoff (3s, 6s, 12s, up to 30s).
- Ensure your network is stable and the ProPresenter machine is not going to sleep.

### ProPresenter shows blue selection outlines

Pro Remote caches presentation data to avoid repeatedly hitting the `GET /v1/presentation/{uuid}` endpoint, which causes ProPresenter to "focus" on presentations. If you see blue outlines appearing, try pulling to refresh in the app -- this clears the cache and re-fetches using the safer `/v1/presentation/active` endpoint.

## 100% Built by AI

This entire project -- every line of code, every design decision, every bug fix -- was built by **Claude AI** (Anthropic). The app architecture, SwiftUI views, networking layer, accessibility implementation, animations, and over 55 polish items were all generated through conversation with Claude Code. No human-written code.

## License

This project is provided as-is for personal and church use.
