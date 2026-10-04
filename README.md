# Pro Remote

A native SwiftUI remote control app for [ProPresenter 7](https://renewedvision.com/propresenter/), built for Mac, iPad, and iPhone.

Browse playlists, view slide thumbnails, trigger slides, and monitor the live output -- all from a fast, dark-themed interface that connects over your local network via ProPresenter's built-in REST API. It can also show your [Bitfocus Companion](https://bitfocus.io/companion) buttons as a native virtual Stream Deck.

## Get the Mac app

A ready-to-run Mac build is in [`Releases/`](Releases/) -- download `Pro-Remote-macOS.zip`, unzip it, and drag **Pro Remote.app** to your Applications folder. No Xcode needed.

macOS will block it the first time because the build is not notarized; [`Releases/README.md`](Releases/README.md) has the one-time approval steps. For iPad and iPhone, build from Xcode (see [Setup](#setup)).

## Features

- **Playlist & Presentation Browser** -- Navigate playlists and presentations in a sidebar with live status indicators. On iPhone the sidebar and slide grid are separate screens with a back button.
- **Slide Grid** -- Responsive thumbnail grid with adjustable sizing. Tap or click any slide to trigger it live.
- **Remote View** -- A full-screen view for running the service from an iPad: the live slide large and sharp (requested from ProPresenter at 1600 px wide), with Previous, back, "Next Up: ...", and Next Slide buttons. Open it from the toolbar's stacked-screens button. If the presentation you're browsing isn't the live one, it says so and offers *Go to Active*.
- **Virtual Stream Deck** -- Your Bitfocus Companion buttons as a native 8x4 key grid. Icons, colors, and live feedback come straight from Companion; pressing a key sends a press and release like a hardware deck, so hold and long-press actions work. On an iPhone held upright the deck turns on its side (4 across, 8 down) so the keys are as large as possible. On the Mac, **Pop Out** opens it in its own window so it can sit beside the slides. See [Bitfocus Companion](#bitfocus-companion).
- **Macros** -- ProPresenter's macros as a grid of tiles in their own colors, with icons for what each does and a search box. Open it with the lightning-bolt button in the toolbar. Tapping a macro asks for confirmation before it runs (macros can switch lights, audio, and cameras); the confirmation can be turned off in Settings.
- **Transport Controls** -- First / Previous / Next / Last slide buttons, plus Previous Item / Next Item to navigate between presentations. Buttons disable themselves when they can't act.
- **Preview-only items** -- Some playlist items can't be read from ProPresenter's API (it answers 404 for their slide details). Pro Remote still shows their slides, rebuilt from the playlist thumbnails, with a **Preview** badge. They can't be started from the app; start them in ProPresenter and the app's controls take over.
- **Follows ProPresenter** -- The view follows whichever playlist item is live, even when the same presentation appears twice in a playlist, until you deliberately open a different item. Then it stays where you put it and shows *Go to Active*; Escape or Go to Active rejoins the live item.
- **Refresh on open** -- Opening the app, or coming back to it from the home screen, reloads everything from ProPresenter and jumps to the live slide. Slide controls stay locked until that finishes (and for a moment after), so the tap that opens the app can't fire a slide. The refresh button in the toolbar does the same full reload on demand: playlists, items, the live presentation, and every slide picture.
- **Automatic Discovery** -- ProPresenter is found over Bonjour; pick it from a list in Settings instead of typing an address.
- **Keyboard Shortcuts** -- Arrow keys, Space, Return, Escape, and Cmd+arrow shortcuts for hands-free control (see below).
- **WebSocket Updates** -- Real-time slide change notifications with automatic reconnection and exponential backoff.
- **Thumbnail & Presentation Caching** -- In-memory image cache and cached presentation data avoid flicker and minimize API calls (and keep ProPresenter from showing focus outlines).
- **Accessibility** -- VoiceOver labels, traits, and hints throughout. Full keyboard navigation support.
- **Haptic Feedback** -- Tactile response when triggering slides and pressing Stream Deck keys on iPhone and iPad.

### Keyboard shortcuts

| Key | Action |
|---|---|
| Right arrow, Space, Return | Next slide |
| Left arrow | Previous slide |
| Down / Up arrow | Next / previous presentation |
| Escape | Return to the live presentation |
| Cmd+Right / Cmd+Left | Next / previous slide (Presentation menu on Mac) |
| Cmd+Down / Cmd+Up | Next / previous presentation (Presentation menu on Mac) |
| Cmd+R | Refresh everything from ProPresenter |

## Requirements

- macOS 26.4+ / iOS 26.4+ / iPadOS 26.4+
- Xcode 26.4+ (only to build from source)
- ProPresenter 7 with the Network API enabled
- Both devices on the same local network
- Optional: Bitfocus Companion with its Satellite API reachable, for the virtual Stream Deck (tested with Companion 5.0.3)

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/douggreenak/ProPresenter-Remote.git
   ```
2. Open `Pro Remote.xcodeproj` in Xcode.
3. Build and run on your target device (Mac, iPad, or iPhone).
4. Allow **local network access** when prompted -- Pro Remote cannot find ProPresenter without it.
5. In Pro Remote, open **Settings** (gear icon) and choose your ProPresenter machine under **Discovered on Network**, or enter its IP address and the API port by hand. The port is shown in ProPresenter's network settings; it is not always 1025.
6. The app connects automatically; use **Connect** if it doesn't.

To build the Mac app as a distributable zip, run `Scripts/build-mac-app.sh` (see [`Releases/README.md`](Releases/README.md)).

## ProPresenter Configuration

Make sure the Network API is enabled in ProPresenter:

1. Open **ProPresenter** > **Preferences** > **Network**.
2. Enable the network API and note the port number.
3. Ensure both machines are on the same network and the port is not blocked by a firewall.

## Bitfocus Companion

The virtual Stream Deck connects to Companion the same way a hardware deck does: through Companion's **Satellite API**, a TCP connection (port **16622** by default). Pro Remote registers itself as a surface called "Pro Remote (iPad)" (or iPhone/Mac), Companion sends it the picture for every key whenever one changes, and Pro Remote sends back key presses and releases.

1. In **Settings**, scroll to **Bitfocus Companion**.
2. Enter Companion's address -- tap *Use ProPresenter's address* if Companion runs on the same machine.
3. Leave **Satellite Port** at 16622 unless you changed it in Companion.
4. Tap **Test Companion**; a green check means Companion answered.
5. Tap **Open Stream Deck**, or use the grid button next to the gear in the toolbar.

Notes:

- The deck shows the 32 keys (8 columns x 4 rows) of the page Companion assigns to the surface. Page changes made with Companion buttons show up here, and the current page is shown under the keys.
- Companion draws each button's location ("1/0/3") across the top of its picture. Pro Remote crops that off so keys look like a real deck. Turn on **Show button numbers** in Settings to see it, which also shows Companion's small warning triangle on buttons that have a problem.
- Closing the deck disconnects it, releases any held key, and removes the surface from Companion. Backgrounding the app does the same, and it reconnects when you return.

## Architecture

The app is built with modern Swift concurrency and SwiftUI:

| File | Purpose |
|---|---|
| `Pro_RemoteApp.swift` | App entry point, window configuration, menu commands |
| `ContentView.swift` | NavigationSplitView layout, toolbar, keyboard handling, sheets |
| `PresentationListView.swift` | Sidebar with playlist and presentation lists |
| `SlideGridView.swift` | Adaptive slide thumbnail grid, header, and transport bar |
| `RemoteView.swift` | Full-screen Remote view with large live slide and transport |
| `MacrosView.swift` | ProPresenter macros page (tile grid, search, confirm-then-run) |
| `StreamDeckView.swift` | Native virtual Stream Deck (key grid, phone layout, pop-out window, press handling, status) |
| `CompanionDeck.swift` | Companion Satellite API client (TCP, key images, presses, reconnect) |
| `SettingsView.swift` | Connection settings: ProPresenter, discovery, Companion |
| `ProPresenterViewModel.swift` | `@Observable` view model, app state and business logic |
| `ProPresenterAPI.swift` | REST API client (actor-isolated) |
| `ProPresenterDiscovery.swift` | Bonjour discovery of ProPresenter on the network |
| `WebSocketManager.swift` | WebSocket connection for real-time slide updates |
| `Models.swift` | Data models and API response types |
| `KeepScreenAwake.swift` | Keeps the screen on while the app is in use |
| `NotesView.swift` | Current/next slide preview with notes (not currently shown in the UI) |

Other folders: `Scripts/` (build script for the Mac app), `Releases/` (the built Mac app), `Pro RemoteUITests/` (UI tests that drive a real ProPresenter -- they trigger real slides, so only run them when no service is in progress).

## Troubleshooting

### macOS says Pro Remote "can't be opened"

The Mac build in `Releases/` isn't notarized. Approve it once in **System Settings > Privacy & Security > Open Anyway**, or run `xattr -dr com.apple.quarantine "/Applications/Pro Remote.app"`. Details in [`Releases/README.md`](Releases/README.md).

### The app can't find ProPresenter

- Allow local network access when asked. If you declined, turn it on in **Settings > Privacy & Security > Local Network** (iOS) or **System Settings > Privacy & Security > Local Network** (Mac).
- Make sure ProPresenter's network feature is enabled, then tap **Search Again** in Settings.

### Slides are out of order or missing

ProPresenter presentations can have **arrangements** that reorder slide groups. Pro Remote reads the arrangement assigned to each playlist item. If slides appear out of order or don't match what you see in ProPresenter:

1. Open the presentation in **ProPresenter's Library**.
2. In the presentation editor, check the **Arrangement** dropdown (bottom of the slide area).
3. Make sure the correct arrangement is selected and saved to the library copy.
4. In your **Playlist**, remove and re-add the presentation so the playlist item picks up the correct arrangement UUID.

If no arrangement is set in the library, ProPresenter's API returns slides in raw group order, which may not match what plays on screen.

### A presentation shows a "Preview" badge and its buttons are disabled

ProPresenter won't share that item's slide details through its API, so Pro Remote only has thumbnails. You can look at the slides but not start one from the app. Start the item in ProPresenter; once it's live the app's Next/Previous work.

### Thumbnails not loading

- Verify both devices are on the same network and can reach each other.
- Check that the port is not blocked by a firewall.
- Thumbnails are fetched from `http://<host>:<port>/v1/presentation/<uuid>/thumbnail/<index>`. If the presentation has not been opened recently in ProPresenter, thumbnails may not be generated yet -- open the presentation once in ProPresenter to populate them.

### Connection drops frequently

- The app uses both HTTP polling (every 1 second) and a WebSocket connection for real-time updates.
- If the connection badge turns yellow, the WebSocket is reconnecting with exponential backoff (3s, 6s, 12s, up to 30s).
- Ensure your network is stable and the ProPresenter machine is not going to sleep.

### The first tap after opening the app does nothing

On purpose. While the app catches up with ProPresenter after opening, returning from the home screen, or (on Mac) being clicked into from another app, slide controls ignore taps for about a second so a stale view can never fire the wrong slide.

### Macros don't load

The Macros page needs a connection to ProPresenter (the connection badge should be green). Opening the page only lists macros; nothing runs until you tap a tile and confirm. Use the reload button on the page, or **Try Again**, if the list is empty.

### The Stream Deck says "Can't Reach Companion"

- Check the address and Satellite port in **Settings > Bitfocus Companion**, and tap **Test Companion**.
- Make sure Companion is running and its Satellite API is enabled (TCP port 16622 by default).
- The deck retries on its own every few seconds; **Try Again** retries immediately.

### ProPresenter shows blue selection outlines

Pro Remote caches presentation data to avoid repeatedly hitting the `GET /v1/presentation/{uuid}` endpoint, which causes ProPresenter to "focus" on presentations. If you see blue outlines appearing, try pulling to refresh in the app -- this clears the cache and re-fetches using the safer `/v1/presentation/active` endpoint.

## 100% Built by AI

This entire project -- every line of code, every design decision, every bug fix -- was built by **Claude AI** (Anthropic). The app architecture, SwiftUI views, networking layer, Companion Stream Deck client, accessibility implementation, animations, and the 60+ polish and fix items tracked in [`CLAUDE.md`](CLAUDE.md) were all generated through conversation with Claude Code. No human-written code.

## License

This project is provided as-is for personal and church use.
