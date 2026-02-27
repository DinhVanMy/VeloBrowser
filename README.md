# Velo Browser

A fast, private, and ad-free web browser built natively for iOS using Swift and SwiftUI.

![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)
![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-green)

## Features

- **Built-in Ad Blocker** — Network-level blocking (60+ rules) + cosmetic CSS filtering. Per-site whitelist, shield counter badge.
- **Background Audio** — Continue listening to web media when the app is backgrounded or the screen is locked, with full lock screen controls.
- **Picture-in-Picture** — Watch videos in a floating window while multitasking.
- **Tab Management** — Up to 100 tabs with grid-based tab switcher, swipe-to-close, private browsing mode.
- **File Downloads** — Download any file with progress tracking, accessible via iOS Files app.
- **Bookmarks & History** — Save pages, search history grouped by date, swipe-to-delete.
- **Private Browsing** — Isolated non-persistent data store, no history recorded, visual indicator.
- **Multiple Search Engines** — Google, DuckDuckGo, Bing.
- **Accessibility** — Dynamic Type, VoiceOver labels, 44pt touch targets.
- **Zero Data Collection** — No analytics, no tracking, no third-party services.

## Architecture

Velo Browser follows **Clean Architecture** with the MVVM-C (Model-View-ViewModel-Coordinator) pattern:

```
┌─────────────────────────────────────────────┐
│                Presentation                  │
│  Views ─── ViewModels ─── Coordinator        │
├─────────────────────────────────────────────┤
│                  Domain                      │
│  Models ─── Repository Protocols             │
├─────────────────────────────────────────────┤
│                   Data                       │
│  SwiftData Entities ─── Repositories         │
├─────────────────────────────────────────────┤
│                 Services                     │
│  TabManager, AdBlock, Media, Downloads, Net  │
└─────────────────────────────────────────────┘
```

- **Dependency Injection** — Protocol-based DI via `DIContainer` (supports in-memory mode for testing)
- **Navigation** — `AppCoordinator` manages NavigationStack and sheet presentations
- **WebView Bridge** — Token-based imperative commands from ViewModel to WKWebView
- **Strict Concurrency** — `@MainActor`, `Sendable`, `async/await` throughout

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6.0 |
| UI Framework | SwiftUI |
| Web Engine | WKWebView (WebKit) |
| Persistence | SwiftData |
| Media | AVFoundation, MediaPlayer |
| Networking | URLSession, Network.framework |
| Ad Blocking | WKContentRuleListStore, WKUserScript |
| Minimum Target | iOS 17.0 |
| Dependencies | **Zero** third-party libraries |

## Build Instructions

### Requirements
- Xcode 16.0+
- iOS 17.0+ Simulator or device
- macOS Sonoma 14.0+

### Build & Run
```bash
# Clone the repository
git clone <repository-url>
cd VeloBrowser

# Open in Xcode
open VeloBrowser.xcodeproj

# Or build from command line
xcodebuild -project VeloBrowser.xcodeproj \
  -scheme VeloBrowser \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests
xcodebuild -project VeloBrowser.xcodeproj \
  -scheme VeloBrowser \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Project Structure

```
VeloBrowser/
├── App/
│   ├── VeloBrowserApp.swift          # @main entry point
│   ├── DIContainer.swift             # Dependency injection container
│   └── AppCoordinator.swift          # Navigation coordinator
├── Presentation/
│   ├── Browser/
│   │   ├── BrowserView.swift         # Main browser UI
│   │   ├── BrowserViewModel.swift    # Browser state & logic
│   │   ├── WebViewContainer.swift    # WKWebView bridge
│   │   ├── AddressBarView.swift      # Collapsible address bar
│   │   └── TabSwitcherView.swift     # Tab grid view
│   ├── DesignSystem/
│   │   ├── ColorPalette.swift        # Semantic colors
│   │   ├── Typography.swift          # Font styles
│   │   └── Theme.swift               # Spacing, radius, animation
│   ├── Bookmarks/BookmarksView.swift
│   ├── History/HistoryView.swift
│   ├── Downloads/DownloadsView.swift
│   ├── Media/
│   │   ├── MiniPlayerBar.swift       # Floating audio bar
│   │   ├── NowPlayingView.swift      # Full media controls
│   │   └── PiPPlayerView.swift       # PiP controller
│   ├── Onboarding/FirstLaunchView.swift
│   ├── Settings/SettingsView.swift
│   └── Shared/
│       ├── ShareSheet.swift
│       └── HapticManager.swift
├── Domain/
│   ├── Models/                        # Tab, Bookmark, HistoryEntry, DownloadItem
│   └── Repositories/                  # Protocol definitions
├── Data/
│   ├── Local/
│   │   ├── SwiftDataStore.swift      # @Model entities
│   │   └── UserDefaultsStore.swift
│   └── Repositories/                  # SwiftData implementations
├── Services/
│   ├── TabManager.swift
│   ├── AdBlockService.swift
│   ├── MediaPlayerService.swift
│   ├── NowPlayingManager.swift
│   ├── DownloadManagerService.swift
│   └── NetworkMonitor.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Info.plist
    └── privacy-policy.html

VeloBrowserTests/
├── BrowserViewModelTests.swift       # URL resolution, navigation tokens
├── TabManagerTests.swift             # Tab lifecycle, max limit
├── AdBlockServiceTests.swift         # Whitelist, toggle logic
└── BookmarkRepositoryTests.swift     # SwiftData CRUD operations
```

## Testing

49 unit tests covering:
- **BrowserViewModel** — URL resolution (direct URL, domain, search query), navigation token increments, callback handling
- **TabManager** — Create/close/switch/reorder tabs, 100-tab limit, private tabs, close-all
- **AdBlockService** — Enable/disable toggle, whitelist CRUD, case-insensitive matching, persistence
- **BookmarkRepository** — Save/fetch/update/delete, search by title/URL, folder filtering

## License

All rights reserved. See LICENSE file for details.
