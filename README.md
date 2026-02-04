# SvenSwipe

A SwiftUI iOS app that lets you sort through your photo library one photo at a time using a familiar swipe gesture. Swipe right to keep a photo, swipe left to mark it for deletion. Marked photos are batch-deleted in a single confirmation step, keeping the flow fast and the risk of accidental permanent deletion low.

---

## Features

- **Swipe to sort** — Swipe right to keep, left to delete. Visual overlays and haptic feedback guide each decision.
- **Batch deletion** — Photos marked for deletion are queued and deleted together in one system-confirmed batch when you tap the delete button in the header.
- **Image prefetching** — The next 6 photos are preloaded in the background so card transitions stay smooth.
- **Permission handling** — Requests read/write photo library access on first launch. Shows a clear prompt to go to system settings if access is denied.
- **AdMob banner ads** — An optional adaptive banner ad at the bottom of the screen, togglable in Settings.
- **Album picker** — A dedicated sheet lets you choose which album to swipe through. Selecting an album reloads the card stack from that album; "Alle Fotos" resets to the full library.
- **Settings sheet** — A simple sheet to enable or disable ads. The preference persists across launches via `UserDefaults`.
- **Portrait-only layout** — The app is locked to portrait orientation.

---

## Project Structure

```
SvenSwipe/
├── SvenSwipe/                      # App target
│   ├── SvenSwipeApp.swift          # App entry point, UIApplicationDelegate, AdMob init
│   ├── ContentView.swift           # Root view, state routing, header, banner placement
│   ├── SwipeCardView.swift         # Drag-gesture swipe card with animated overlays
│   ├── SvenSwipeViewModel.swift    # Central ViewModel – permissions, asset loading, swipe logic
│   ├── PhotoLibraryService.swift   # Photos framework wrapper – fetch, cache, delete
│   ├── Item.swift                  # SwiftData model (placeholder)
│   ├── Info.plist                  # Bundle config including GADApplicationID
│   └── Assets.xcassets/            # App icon and colors
├── AdSettings.swift                # UserDefaults-backed singleton for the ad toggle
├── BannerAdView.swift              # UIViewRepresentable wrapper around GADBannerView
├── SettingsView.swift              # Settings sheet with the ad toggle
└── README.md
```

---

## Architecture

The app follows a straightforward SwiftUI MVVM pattern.

### Views
| File | Responsibility |
|---|---|
| `ContentView` | Root view. Reads `LibraryAccessState` from the ViewModel and switches between loading, unauthorized, empty, and ready states. Hosts the header (including the album-picker button), the album-picker sheet, and the banner ad. |
| `SwipeCardView` | A single photo card. Handles the `DragGesture`, paints green/red overlays proportional to drag distance, animates the card off-screen on a confirmed swipe, and reports the decision back via a callback. |
| `SettingsView` | A `List`-based sheet with a single toggle. Writes through `AdSettings.shared`. |
| `BannerAdView` | `UIViewRepresentable` that wraps `GADBannerView`. Creates the banner inside a container's `layoutSubviews` so the width is known before the ad request is sent. Reports the loaded ad height back to SwiftUI via a `@Binding`. |

### ViewModel
`SvenSwipeViewModel` is the single source of truth during a session. It:
- Requests and tracks photo library authorization.
- Fetches the list of available albums and exposes them for the album picker.
- Fetches image assets (images only, newest first), optionally scoped to the selected album.
- Maintains a current index and prefetch window.
- Queues "delete" decisions into `pendingDeletes` without touching the library until the user confirms.
- Commits the batch deletion through `PhotoLibraryService` and refreshes the fetch result.

### Services
`PhotoLibraryService` is the only file that touches the `Photos` framework directly. It exposes async wrappers around authorization, album listing, scoped asset fetching, image requests, caching, and deletion, keeping the ViewModel free of UIKit/Photos details.

### Settings
`AdSettings` is a simple singleton backed by `UserDefaults`. It stores one boolean (`adsEnabled`) and is read by both `ContentView` (to show/hide the banner) and `SettingsView` (to drive the toggle).

---

## AdMob Integration

The app uses the Google Mobile Ads SDK (v12) shipped as a local `.xcframework`.

### Configuration checklist
1. `Info.plist` must contain a `GADApplicationID` key with your AdMob App ID.
2. `BannerAdView.swift` contains `bannerAdUnitID` — replace it with your production ad unit ID before shipping.
3. `SvenSwipeApp.swift` registers a test device identifier during development. Remove or replace it before release.

> **Note:** The current values in the repo are Google's official test IDs. They serve sample ads during development but must be swapped for production values before an App Store submission.

---

## Requirements

- Xcode 16+
- iOS 18+
- A Google AdMob account (for production ad serving)

---

## Getting Started

1. Clone the repository.
2. Open `SvenSwipe.xcodeproj` in Xcode.
3. Select a simulator or connected device and press **Run**.
4. Grant photo library access when prompted.

No external package manager setup is needed — the Google Mobile Ads SDK is bundled as an `.xcframework` inside the project.

---

## Before Shipping

- [ ] Replace `GADApplicationID` in `Info.plist` with your real AdMob App ID.
- [ ] Replace `bannerAdUnitID` in `BannerAdView.swift` with your production banner ad unit ID.
- [ ] Remove the `testDeviceIdentifiers` line in `SvenSwipeApp.swift`.
- [ ] Add the 49 required SKAdNetwork identifiers to `Info.plist` (see [Google's guide](https://developers.google.com/admob/ios/data-safety)).
- [ ] Set your app's Team ID and bundle identifier in Xcode project settings.
