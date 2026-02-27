# Velo Browser

A fast, private, and ad-free web browser built natively for iOS using Swift and SwiftUI.

![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)
![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-green)
![Tests](https://img.shields.io/badge/Tests-84%20passing-brightgreen)

## Features

### 🌐 Browser Core
- **Full Web Browsing** — WKWebView-powered with address bar, navigation, progress bar, pull-to-refresh
- **Tab Management** — Up to 100 tabs with grid-based switcher, swipe-to-close, drag-to-reorder
- **Private Browsing** — Isolated WKWebsiteDataStore, no history, visual indicator
- **Find in Page** — Text search with match highlighting and navigation
- **Multiple Search Engines** — Google, DuckDuckGo, Bing

### 🛡️ Ad Blocking & Privacy
- **Built-in Ad Blocker** — 60+ WKContentRuleList rules + cosmetic CSS filtering, per-site whitelist, shield counter
- **HTTPS-Only Mode** — Auto-upgrade HTTP → HTTPS with fallback warning
- **Tracking Parameter Removal** — Strips fbclid, gclid, utm_*, and 20+ tracking params
- **Fingerprint Protection** — Canvas, WebGL, navigator, screen, audio fingerprint randomization
- **Cookie Manager** — Browse, delete per-domain, block third-party cookies
- **Biometric App Lock** — Face ID / Touch ID with configurable lock timeout
- **Privacy Dashboard** — Centralized stats for all privacy protections

### 🎵 Media
- **Background Audio** — Web media continues playing when backgrounded or locked
- **Lock Screen Controls** — Play/pause, seek, track info via MPNowPlayingInfoCenter
- **Picture-in-Picture** — Floating video window during multitasking

### 📖 Reader Mode & Content
- **Reader Mode** — Extracts article content, configurable font/size/spacing/theme
- **Reading List** — Save articles for later with read/unread tracking
- **Desktop Mode Toggle** — Per-tab user agent switching

### 📥 Downloads & Data
- **File Downloads** — Progress tracking, pause/resume, iOS Files app integration
- **Bookmarks** — Save, edit, search with drag-to-reorder
- **History** — Grouped by date, searchable, swipe-to-delete
- **Spotlight Integration** — Bookmarks and history searchable from iOS search

### 📱 iPad Support
- **Adaptive Layout** — Sidebar navigation, horizontal tab bar, split view
- **Pointer & Trackpad** — Hover effects, right-click context menus
- **Drag & Drop** — URL dragging between apps
- **Keyboard Shortcuts** — Cmd+T/W/L/R/F/D and more

### ⚡ Performance
- **Tab Suspension** — Auto-suspend inactive tabs to free memory
- **Lazy Service Loading** — MediaPlayer, Downloads, Reader init on first use
- **WKProcessPool Sharing** — Shared pool for normal tabs, isolated for private
- **Image Lazy Loading** — JS injection for below-fold images
- **Memory Pressure Handling** — Auto-suspend on system memory warning
- **Battery Optimization** — Reduced animations in Low Power Mode

### 🌍 Localization
- **6 Languages** — English, Vietnamese, Japanese, Korean, Chinese (Simplified), Spanish
- **String Catalog** — Xcode 15+ xcstrings format with pluralization support

### 📲 iOS Integration
- **Quick Actions** — Home screen shortcuts for New Tab, Private Tab, Search
- **Deep Links** — `velobrowser://` URL scheme for search, open, newtab, privatetab
- **Spotlight & Handoff** — Indexed bookmarks/history, web activity continuation
- **App Store Review** — Smart review prompts based on usage metrics
- **Dynamic Type** — Full accessibility with VoiceOver labels, 44pt touch targets

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Presentation                    │
│  Views ─── ViewModels ─── Coordinator            │
│  DesignSystem (Colors, Typography, Spacing)      │
│  iPad (Sidebar, TabBar, Adaptive Layout)         │
├─────────────────────────────────────────────────┤
│                    Domain                        │
│  Models ─── Repository Protocols                 │
│  Tab, Bookmark, HistoryEntry, DownloadItem,      │
│  ReadingListItem, ReaderContent                  │
├─────────────────────────────────────────────────┤
│                     Data                         │
│  SwiftData Entities ─── Repositories             │
│  UserDefaults ─── App Group Shared Storage       │
├─────────────────────────────────────────────────┤
│                   Services                       │
│  TabManager, AdBlock, Media, Downloads,          │
│  ReaderMode, HTTPS Upgrade, Tracking Protection, │
│  Fingerprint, AppLock, TabSuspension,            │
│  Spotlight, ReviewManager, NetworkMonitor        │
└─────────────────────────────────────────────────┘
```

**Key patterns:**
- **MVVM-C** — Model-View-ViewModel-Coordinator with protocol-based DI
- **Token-based Commands** — ViewModel increments Int tokens; WebView Coordinator detects changes
- **Strict Concurrency** — `@MainActor`, `Sendable`, `async/await`, `@Observable`
- **Zero Dependencies** — Everything built with Apple frameworks only

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6.0 |
| UI Framework | SwiftUI |
| Web Engine | WKWebView (WebKit) |
| Persistence | SwiftData |
| Media | AVFoundation, MediaPlayer, AVKit |
| Privacy | LocalAuthentication, WebKit Content Rules |
| Search | CoreSpotlight |
| Ad Blocking | WKContentRuleListStore, WKUserScript |
| Networking | URLSession, Network.framework |
| Localization | String Catalog (xcstrings) |
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
git clone https://github.com/DinhVanMy/VeloBrowser.git
cd VeloBrowser

# Open in Xcode
open VeloBrowser.xcodeproj

# Or build from command line
xcodebuild -project VeloBrowser.xcodeproj \
  -scheme VeloBrowser \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests (84 tests across 8 suites)
xcodebuild -project VeloBrowser.xcodeproj \
  -scheme VeloBrowser \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Project Structure

```
VeloBrowser/                          # 64 production Swift files
├── App/
│   ├── VeloBrowserApp.swift          # @main, deep links, Spotlight, Quick Actions
│   ├── DIContainer.swift             # Protocol-based DI, lazy service init
│   └── AppCoordinator.swift          # Navigation, iPad/iPhone adaptive layout
├── Presentation/
│   ├── Browser/
│   │   ├── BrowserView.swift         # Main browser UI + keyboard shortcuts
│   │   ├── BrowserViewModel.swift    # Browser state, navigation, media detection
│   │   ├── WebViewContainer.swift    # WKWebView bridge, gestures, context menu
│   │   ├── AddressBarView.swift      # Collapsible bar, Paste & Go, domain display
│   │   ├── TabSwitcherView.swift     # Tab grid, swipe-close, private tabs
│   │   ├── FindInPageBar.swift       # Text search overlay
│   │   └── NewTabPageView.swift      # Home page with quick access
│   ├── DesignSystem/                 # Colors, Typography, Theme tokens
│   ├── Settings/
│   │   ├── SettingsView.swift        # All settings sections
│   │   ├── CookieManagerView.swift   # Per-domain cookie management
│   │   ├── CacheManagerView.swift    # Website data storage management
│   │   └── PrivacyDashboardView.swift
│   ├── Media/                        # MiniPlayerBar, NowPlayingView, PiPPlayerView
│   ├── Reader/ReaderModeView.swift   # Reader mode with font/theme settings
│   ├── ReadingList/                  # Reading list management
│   ├── Bookmarks/, History/, Downloads/
│   ├── iPad/                         # SidebarView, TabBarView, iPadLayoutView
│   ├── Onboarding/FirstLaunchView.swift
│   └── Shared/                       # DeviceHelper, HapticManager, LockScreen, Share
├── Domain/
│   ├── Models/                       # Tab, Bookmark, HistoryEntry, DownloadItem, etc.
│   └── Repositories/                 # Protocol definitions
├── Data/
│   ├── Local/                        # SwiftData entities, UserDefaults
│   └── Repositories/                 # SwiftData implementations
├── Services/                         # 14 services with protocol-based DI
│   ├── TabManager.swift              # Tab lifecycle, snapshots
│   ├── AdBlockService.swift          # Content rules compilation
│   ├── MediaPlayerService.swift      # Background audio extraction
│   ├── DownloadManagerService.swift  # URLSession download tasks
│   ├── ReaderModeService.swift       # HTML content extraction
│   ├── HTTPSUpgradeService.swift     # HTTP → HTTPS auto-upgrade
│   ├── TrackingProtectionService.swift
│   ├── FingerprintProtectionService.swift
│   ├── AppLockService.swift          # Biometric authentication
│   ├── TabSuspensionManager.swift    # Memory optimization
│   ├── SpotlightIndexer.swift        # CoreSpotlight indexing
│   ├── ReviewManager.swift           # App Store review prompts
│   ├── NetworkMonitor.swift          # Connectivity + battery monitoring
│   └── NowPlayingManager.swift       # Lock screen media controls
├── Resources/
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── privacy-policy.html
└── Localizable.xcstrings             # 6-language string catalog

VeloBrowserTests/                     # 84 tests across 8 suites
├── BrowserViewModelTests.swift       # URL resolution, navigation, callbacks
├── TabManagerTests.swift             # Tab CRUD, limits, private tabs
├── AdBlockServiceTests.swift         # Whitelist, toggle, persistence
├── BookmarkRepositoryTests.swift     # SwiftData CRUD, search
├── ReadingListRepositoryTests.swift  # Reading list persistence
├── HTTPSUpgradeServiceTests.swift    # HTTP upgrade, exceptions
├── TrackingProtectionServiceTests.swift  # URL param stripping
└── TabSuspensionManagerTests.swift   # Suspend/resume, memory warning
```

## Testing

84 unit tests across 8 suites using Swift Testing framework:

| Suite | Tests | Coverage |
|-------|-------|----------|
| BrowserViewModel | 15 | URL resolution, navigation tokens, callbacks, error handling |
| TabManager | 14 | Create/close/switch/reorder, 100-tab limit, private tabs |
| AdBlockService | 9 | Toggle, whitelist CRUD, case-insensitive matching |
| BookmarkRepository | 10 | SwiftData CRUD, search, folder filtering |
| ReadingListRepository | 8 | Save/fetch/update/delete, read status |
| HTTPSUpgradeService | 8 | HTTP→HTTPS upgrade, exception handling |
| TrackingProtection | 10 | URL cleaning for fbclid, utm_*, gclid, etc. |
| TabSuspensionManager | 10 | Suspend/resume lifecycle, memory warning |

## Localization

Velo Browser supports 6 languages via Xcode String Catalog:

| Language | Code | Status |
|----------|------|--------|
| English | en | ✅ Base |
| Vietnamese | vi | ✅ Complete |
| Japanese | ja | ✅ Complete |
| Korean | ko | ✅ Complete |
| Chinese (Simplified) | zh-Hans | ✅ Complete |
| Spanish | es | ✅ Complete |

### Contributing Translations
1. Open `VeloBrowser/Localizable.xcstrings` in Xcode
2. Add or edit translations for your target language
3. Submit a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.
