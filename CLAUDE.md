# Pro Remote - UI Polish & Bug Fix Tracker

## Progress

### Batch 1 - Critical Fixes & Layout (DONE)
- [x] 1. Safe URL construction in API (crash prevention) - replaced 9 force-unwrapped URLs
- [x] 2. Adaptive grid columns for iPhone (140pt min on compact, 200pt on regular)
- [x] 3. Enforce dark color scheme (.preferredColorScheme(.dark))
- [x] 4. Port field numeric validation (filters non-digit chars)
- [x] 5. Transport bar disabled states (canTriggerNext/canTriggerPrevious)
- [x] 6. Larger tap targets in presentation list (20pt -> 28pt rows)
- [x] 7. Scrollable playlist section (maxHeight: 200)
- [x] 8. Rounded corners on NotesView thumbnails
- [x] 9. Better slide placeholder (gradient background, larger text)
- [x] 10. Clear test result when host/port changes
- [x] 11. Settings status matches toolbar badge (green/yellow/red)
- [x] 12. Space bar + Return advance slides
- [x] 13. Larger transport bar (36pt, bigger buttons)
- [x] 14. Disconnect clears connectionError and connectionHealthy

### Batch 2 - Visual Polish (DONE)
- [x] 15. Corner radius 4->6 on slide cells for consistency
- [x] 16. Live badge pulse animation (PhaseAnimator glow)
- [x] 17. Better slide counter readability (12pt, brighter)
- [x] 18. Group color indicator size increase (3x12 -> 4x14)
- [x] 19. Slide cell info bar improved spacing (5px padding, 10pt font)
- [x] 20. Selected presentation rounded highlight
- [x] 21. Brighter transport button icons (Color(white: 0.55))
- [x] 22. Notes view CURRENT label colored orange, NEXT label brighter
- [x] 23. Notes view group name label under thumbnails
- [x] 24. Improved empty state in NotesView (ContentUnavailableView)
- [x] 25. Slide cell hover feedback (scale + opacity effect)
- [x] 26. Connection badge shows host on hover tooltip
- [x] 27. Connection badge uses simple dot instead of icon
- [x] 28. Live slide cell gets subtle orange shadow
- [x] LIVE badge in list increased from 7pt to 8pt

### Batch 3 - Accessibility & Interaction (DONE)
- [x] 29. Accessibility labels on all 4 transport buttons
- [x] 30. Accessibility labels on slide cells with group name
- [x] 31. Accessibility label on connection badge with status
- [x] 32. Accessibility traits on live slide cells (.isSelected)
- [x] 33. Accessibility labels + disabled state on companion buttons
- [x] 34. Accessibility hints on slide cells and list items
- [x] 35. Haptic feedback on iOS (UIImpactFeedbackGenerator)
- [x] 36. "Go Live" button in header when viewing non-live presentation
- [x] 37. Presentation list item count header ("N items")
- [x] 38. goToLive() method in ViewModel
- [x] 39. Escape key returns to live presentation
- [x] 40. Accessibility on presentation list items

### Batch 4 - Animation & Transitions (DONE)
- [x] 41. Animated content on presentation switching
- [x] 42. Live slide border animates smoothly (0.3s easeInOut)
- [x] 43. Header bar animates between Go Live / LIVE states
- [x] 44. Connection status badge color animates (0.5s)
- [x] 45. Slide counter uses numericText content transition
- [x] 46. Presentation list selection animates
- [x] 47. Notes view animates on slide changes
- [x] 48. Notes view counter uses numericText transition

### Batch 5 - Additional Polish (DONE)
- [x] 49. Double-connect prevention (isLoading guard)
- [x] 50. Loading indicator in sidebar during connection
- [x] 51. Connect button shows progress, disabled when loading/empty
- [x] 52. WebSocket exponential backoff (3s -> 6s -> 12s -> max 30s)
- [x] 53. Companion buttons disabled when no URL configured
- [x] 54. Error section uses icon + callout font for visibility
- [x] 55. Presentation list section header with item count

### Batch 6 - Remote View & Cross-Device Layout Fixes (DONE)
- [x] 56. New Remote view (RemoteView.swift): large live slide + Previous / back / Next Up / Next Slide, opened from a toolbar button
- [x] 57. Toolbar items moved onto the detail column - on iPadOS, items declared on the NavigationSplitView root never render (Settings/Refresh/badge were unreachable)
- [x] 58. iPhone navigation: rows now reveal the detail column (preferredCompactColumn); previously the slide grid was unreachable
- [x] 59. iPhone portrait: header drops the zoom slider and transport bar goes icon-only via ViewThatFits (detail column had grown wider than the screen)
- [x] 60. Connection badge shows just the dot in portrait iPhone so all toolbar buttons fit
- [x] 61. Remote view: adaptive transport (roomy row / tight row / two rows), preview card sized from available height, clear "not live" state
- [x] 62. macOS Remote sheet min size reduced (720x480) so it fits the 900x600 minimum window
- [x] 63. Accessibility labels on Refresh / Settings toolbar buttons

### Batch 7 - Companion Virtual Stream Deck (DONE)
- [x] 64. Companion section in Settings: host, Satellite port (16622), Test Companion, Open Stream Deck
- [x] 65. CompanionDeck.swift: native client for Companion's Satellite API (registers as a surface; Companion pushes key images/text, app sends press/release)
- [x] 66. StreamDeckView.swift: native 8x4 SwiftUI key grid, press-down/release, haptics, page + connection indicator, auto-reconnect, releases held keys and the surface on close

### Batch 8 - Stream Deck Look & Unservable Presentations (DONE)
- [x] 67. Virtual Stream Deck: flat matte body, plain square keys with a hairline edge, press dim + haptics, one quiet status line (page / connection). (First pass was glossy and skeuomorphic; replaced as it looked over-designed)
- [x] 67b. Toolbar button next to Settings opens the Stream Deck (opens Settings instead if no Companion address is set)
- [x] 68. Companion's baked-in location strip ("1/0/3") cropped off each key by default and the gap filled with colours sampled from the picture's own top/bottom rows (in sRGB - sampling in device RGB tinted them); "Show button numbers" toggle in Settings restores it
- [x] 69. Playlist items whose presentation ProPresenter 404s (e.g. "slides for alaska 1/2") now show their slides, rebuilt from playlist thumbnails, with a "Preview" badge; controls stay disabled until the item is live

### Batch 9 - Mac App Distribution & Documentation (DONE)
- [x] 70. Scripts/build-mac-app.sh: archives a Release macOS build (universal arm64 + x86_64), signs it with the Bethel Church team's development certificate (THW3L89YM6), verifies the signature, zips it with `ditto` to Releases/Pro-Remote-macOS.zip and writes Releases/BUILD-INFO.txt (commit, date, signing). Touches nothing on the Apple Developer account
- [x] 71. Releases/ holds the built Mac app + Releases/README.md (install, first-launch approval, first connection, rebuild)
- [x] 72. README rewritten to match the app: Remote view, Stream Deck / Companion Satellite setup, Preview-only items, Bonjour discovery, keyboard shortcuts table, current architecture table, new troubleshooting entries. Removed the stale claim that NotesView is shown (it is not wired into the UI)

Notes for future work:
- The Mac build is NOT notarized (no Developer ID certificate on the build machine), so a browser-downloaded copy is blocked until approved once (System Settings > Privacy & Security > Open Anyway, or `xattr -dr com.apple.quarantine`). A locally built or git-cloned copy is not quarantined. Notarizing needs a Developer ID Application certificate plus `notarytool` credentials.
- Rebuild Releases/Pro-Remote-macOS.zip with Scripts/build-mac-app.sh whenever the app changes; BUILD-INFO.txt shows which commit the zip came from.

### Batch 10 - ProPresenter Macros Page (DONE)
- [x] 73. MacrosView.swift: ProPresenter macros as a tile grid (macro color accent, action-type icons, search, reload), opened from a lightning-bolt toolbar button next to the Stream Deck button
- [x] 74. Listing is read-only (`GET /v1/macros`). Running (`GET /v1/macro/{uuid}/trigger`) only happens from a tile tap and, by default, an explicit "Run macro?" confirmation; Settings > Macros has a switch to turn the confirmation off. Never trigger macros while testing: they control real lights, audio mixer, cameras and click tracks
- [x] 75. The trigger endpoint has NOT been verified against a live ProPresenter (testing during a live event, by request); a 404 would surface as the "Macro didn't run" alert

### Batch 11 - Removed per-button Companion shortcuts (DONE)
- [x] 76. Removed the older Companion buttons (labelled HTTP-GET shortcuts in the toolbar plus their "..." editor, CompanionButton model, view-model storage and CompanionButtonsView.swift). The Companion Stream Deck replaces them. Items 33 and 53 above refer to the removed feature. The old saved `pp_companionButtons` setting is deleted on launch

### Batch 12 - Mac Look (DONE)
- [x] 77. Mac: presentation name + "N slides · section" now live in the native window title/subtitle; the custom header band is iPad/iPhone only (shared ZoomControl + PresentationStatusBadges in SlideGridChrome.swift feed both)
- [x] 78. Mac toolbar: badges and zoom, then connection, then Refresh/Settings, then Stream Deck/Macros/Remote, each in its own glass group (ToolbarSpacer .fixed). Zoom shows no number and no tick marks on Mac; minimum window width raised to 1000 so every button stays visible
- [x] 79. Mac sidebar: playlist Menu on top + one native sidebar List (replaces the two stacked scroll boxes); orange tint scoped to the list and slider (a root-level tint turned every glass button orange)
- [x] 80. Mac transport bar: native glass buttons (Next is the orange glassProminent) on a material bar
- iPad/iPhone layouts are unchanged by this batch (all Mac-only changes are behind #if os(macOS))

### Batch 13 - Deck Layout, Refresh & Safe Resume (DONE)
- [x] 81. Stream Deck no longer grows out of a corner on open (layout size changes are not animated)
- [x] 82. iPhone Stream Deck: slimmer chassis and, when held upright, the deck is turned on its side (4 columns x 8 rows, each Companion row becomes a column) so keys are about twice as large; iPad and landscape are unchanged
- [x] 83. Mac: "Pop Out" button on the Stream Deck sheet opens it in its own window (`Window` scene id `stream-deck`); the toolbar button brings an existing pop-out forward instead of opening a second copy (two copies would share one Companion surface)
- [x] 84. Toolbar Refresh does a full reload (playlists, items, live + viewed presentation) and also clears the thumbnail cache and refetches every slide picture ignoring the HTTP cache; spins while working, acts as Connect when offline
- [x] 85. Returning from the background (`scenePhase`) reconnects the websocket, refreshes everything and goes to the live slide; opening the app already refreshes via `connect()`
- [x] 86. Input lock: slide triggers (taps, keys, Remote, menu commands) are ignored while resyncing (max 8 s) and for 0.7 s after, and for 0.6 s after the Mac app becomes active, so the tap that opens the app can't fire a slide. Companion deck keys are not affected
- [x] 87. Remote view asks ProPresenter for 1600 px thumbnails (`?quality=`, default is 400 px, max 1920) and shows the small cached one while the large one loads
- [x] 88. iPhone toolbar: the gear is hidden on compact width (the connection badge opens Settings) so Stream Deck, Macros and Remote no longer fall into the "..." overflow menu
- [x] 89. Mac: zoom control keeps its magnifier icons inside the toolbar's glass capsule (padding, brighter icons); the Stream Deck window is never opened or restored at launch
- [x] 90. Follow ProPresenter by playlist *item*, not just presentation: `liveItemUUID` comes from `/v1/playlist/active`, so a presentation that appears twice in a playlist (the announcement loop) highlights only the row that is really live, and clicking the other copy in ProPresenter makes the app follow (checked about once a second)
- [x] 91. The app stays put only when the user deliberately browsed to another item; Go to Active, Escape, or the live item arriving at the row being viewed restores the link. Previously a change of live item always pulled the view along, overriding that choice

