// AppCoordinator.swift
// VeloBrowser
//
// Root navigation coordinator managing app-level routing.

import SwiftUI

/// Defines the possible navigation destinations at the app level.
enum AppDestination: Hashable {
    case browser
    case settings
    case bookmarks
    case history
    case downloads
}

/// Root navigation coordinator for the entire application.
///
/// Manages the navigation stack and provides methods for
/// programmatic navigation between top-level screens.
@Observable
@MainActor
final class AppCoordinator {
    /// The current navigation path managed by NavigationStack.
    var path = NavigationPath()

    /// Whether the settings sheet is presented.
    var showSettings = false

    /// Whether the bookmarks sheet is presented.
    var showBookmarks = false

    /// Whether the history sheet is presented.
    var showHistory = false

    /// Whether the downloads sheet is presented.
    var showDownloads = false

    /// Whether the tab switcher is presented.
    var showTabSwitcher = false

    /// Whether the now playing sheet is presented.
    var showNowPlaying = false

    /// Whether the reading list sheet is presented.
    var showReadingList = false

    /// Whether the share sheet is presented.
    var showShareSheet = false

    /// Navigates to a specific app destination.
    ///
    /// - Parameter destination: The destination to navigate to.
    func navigate(to destination: AppDestination) {
        switch destination {
        case .browser:
            path = NavigationPath()
        case .settings:
            showSettings = true
        case .bookmarks:
            showBookmarks = true
        case .history:
            showHistory = true
        case .downloads:
            showDownloads = true
        }
    }

    /// Pops the top destination from the navigation stack.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Resets navigation to the root (browser) screen.
    func popToRoot() {
        path = NavigationPath()
    }
}

/// The root view managed by AppCoordinator.
///
/// Wraps the browser view in a NavigationStack and provides
/// sheet presentation for secondary screens.
struct AppCoordinatorView: View {
    @State private var coordinator = AppCoordinator()
    @Environment(DIContainer.self) private var container

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                mainBrowserView
                    .navigationDestination(for: AppDestination.self) { destination in
                        destinationView(for: destination)
                    }

                // PiP host view (invisible, hosts AVPlayerLayer for PiP)
                if container.mediaPlayerService.player != nil {
                    PiPPlayerView(
                        player: container.mediaPlayerService.player,
                        onPiPControllerReady: { pip in
                            container.mediaPlayerService.pipController = pip
                        }
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
                }
            }
        }
        .environment(coordinator)
        .sheet(isPresented: $coordinator.showTabSwitcher) {
            TabSwitcherView(tabManager: container.tabManager)
        }
        .sheet(isPresented: $coordinator.showSettings) {
            NavigationStack {
                SettingsView(
                    adBlockService: container.adBlockService,
                    historyRepository: container.historyRepository
                )
            }
        }
        .sheet(isPresented: $coordinator.showNowPlaying) {
            NowPlayingView(mediaPlayer: container.mediaPlayerService)
        }
        .sheet(isPresented: $coordinator.showBookmarks) {
            BookmarksView(
                bookmarkRepository: container.bookmarkRepository,
                currentPageURL: container.tabManager.activeViewModel?.currentURL,
                currentPageTitle: container.tabManager.activeViewModel?.pageTitle,
                onOpenBookmark: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        }
        .sheet(isPresented: $coordinator.showHistory) {
            HistoryView(
                historyRepository: container.historyRepository,
                onOpenURL: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        }
        .sheet(isPresented: $coordinator.showDownloads) {
            NavigationStack {
                DownloadsView(downloadManager: container.downloadManager)
            }
        }
        .sheet(isPresented: $coordinator.showReadingList) {
            ReadingListView(
                repository: container.readingListRepository,
                onOpenURL: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        }
        .sheet(isPresented: $coordinator.showShareSheet) {
            if let url = container.tabManager.activeViewModel?.currentURL {
                ShareSheet(items: [url])
            }
        }
        .task {
            await container.adBlockService.compileRules()
            container.networkMonitor.start()
        }
    }

    @ViewBuilder
    private var mainBrowserView: some View {
        if let vm = container.tabManager.activeViewModel {
            BrowserView(
                viewModel: vm,
                onShowTabSwitcher: {
                    HapticManager.light()
                    // Capture snapshot of the active tab before showing switcher
                    // (inactive tabs already have snapshots from when they were switched away)
                    if let activeTab = container.tabManager.activeTab {
                        container.tabManager.captureSnapshot(for: activeTab.id)
                    }
                    // Small delay for snapshot completion before showing sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        coordinator.showTabSwitcher = true
                    }
                },
                tabCount: container.tabManager.tabCount
            )
            .navigationBarHidden(true)
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .browser:
            EmptyView()
        case .settings:
            SettingsView(
                adBlockService: container.adBlockService,
                historyRepository: container.historyRepository
            )
        case .bookmarks:
            BookmarksView(
                bookmarkRepository: container.bookmarkRepository,
                onOpenBookmark: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        case .history:
            HistoryView(
                historyRepository: container.historyRepository,
                onOpenURL: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        case .downloads:
            DownloadsView(downloadManager: container.downloadManager)
        }
    }
}
