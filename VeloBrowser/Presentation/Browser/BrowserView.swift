// BrowserView.swift
// VeloBrowser
//
// Main browser view with address bar, web content, and toolbar.

import SwiftUI

/// The main browser screen containing the address bar, web content area,
/// bottom toolbar, and pull-to-refresh support.
///
/// The address bar and toolbar collapse when the user scrolls down
/// and reappear when scrolling up, following Safari-like behavior.
struct BrowserView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(DIContainer.self) private var container

    /// Callback to open the tab switcher.
    var onShowTabSwitcher: () -> Void

    /// Current tab count to display on the tab button badge.
    var tabCount: Int

    @State private var showTabLimitAlert = false
    @State private var showFindInPage = false
    @State private var showNoMediaAlert = false
    @AppStorage("javaScriptEnabled") private var javaScriptEnabled: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Find in page bar
                if showFindInPage {
                    FindInPageBar(
                        isVisible: $showFindInPage,
                        webView: viewModel.webView
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Collapsible address bar
                if viewModel.isToolbarVisible {
                    AddressBarView(viewModel: viewModel)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Web content area
                webContentArea
            }

            // Bottom overlay: mini player + toolbar
            VStack(spacing: 0) {
                // Mini player bar (when media is active)
                if container.mediaPlayerService.currentMediaURL != nil {
                    MiniPlayerBar(
                        mediaPlayer: container.mediaPlayerService,
                        onExpand: { coordinator.showNowPlaying = true }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom toolbar
                if viewModel.isToolbarVisible {
                    bottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8),
            value: viewModel.isToolbarVisible
        )
        .onTapGesture {
            viewModel.showToolbar()
        }
        .ignoresSafeArea(.keyboard)
        .alert("Tab Limit Reached", isPresented: $showTabLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've reached the maximum of \(TabManager.maxTabs) tabs. Please close some tabs to open new ones.")
        }
        .alert("No Media Found", isPresented: $showNoMediaAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No playable audio or video was found on this page. Try playing a video first, then use this option.")
        }
        .fullScreenCover(isPresented: $viewModel.showReaderMode) {
            if let content = viewModel.readerContent {
                ReaderModeView(
                    content: content,
                    onDismiss: { viewModel.showReaderMode = false },
                    onShare: {
                        coordinator.showShareSheet = true
                    }
                )
            }
        }
        .statusBarHidden(viewModel.isFullscreen)
        // iPad keyboard shortcuts
        .background {
            keyboardShortcuts
        }
    }

    // MARK: - Keyboard Shortcuts

    /// Hidden buttons providing iPad keyboard shortcuts.
    @ViewBuilder
    private var keyboardShortcuts: some View {
        Group {
            // Cmd+T — New tab
            Button("") {
                if container.tabManager.tabCount < TabManager.maxTabs {
                    container.tabManager.createTab(url: nil, isPrivate: false)
                    HapticManager.light()
                }
            }
            .keyboardShortcut("t", modifiers: .command)

            // Cmd+W — Close tab
            Button("") {
                if let activeTab = container.tabManager.activeTab {
                    container.tabManager.closeTab(id: activeTab.id)
                    HapticManager.light()
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            // Cmd+L — Focus address bar
            Button("") {
                viewModel.isAddressBarFocused = true
            }
            .keyboardShortcut("l", modifiers: .command)

            // Cmd+R — Reload
            Button("") { viewModel.reload() }
                .keyboardShortcut("r", modifiers: .command)

            // Cmd+[ — Go back
            Button("") { viewModel.goBack() }
                .keyboardShortcut("[", modifiers: .command)

            // Cmd+] — Go forward
            Button("") { viewModel.goForward() }
                .keyboardShortcut("]", modifiers: .command)

            // Cmd+Shift+N — New private tab
            Button("") {
                if container.tabManager.tabCount < TabManager.maxTabs {
                    container.tabManager.createTab(url: nil, isPrivate: true)
                    HapticManager.light()
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        Group {
            // Cmd+F — Find on page
            Button("") {
                withAnimation { showFindInPage.toggle() }
            }
            .keyboardShortcut("f", modifiers: .command)

            // Cmd+D — Add bookmark
            Button("") { addBookmark() }
                .keyboardShortcut("d", modifiers: .command)

            // Cmd+Y — History
            Button("") { coordinator.navigate(to: .history) }
                .keyboardShortcut("y", modifiers: .command)

            // Cmd+, — Settings
            Button("") { coordinator.navigate(to: .settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Web Content

    private var webContentArea: some View {
        ZStack {
            WebViewContainer(
                url: viewModel.pendingURL,
                isPrivate: viewModel.isPrivate,
                javaScriptEnabled: javaScriptEnabled,
                reloadToken: viewModel.reloadToken,
                stopToken: viewModel.stopToken,
                goBackToken: viewModel.goBackToken,
                goForwardToken: viewModel.goForwardToken,
                isDesktopMode: viewModel.isDesktopMode,
                desktopModeToken: viewModel.desktopModeToken,
                onTitleChange: { title in
                    viewModel.handleTitleChange(title)
                    if let activeTab = container.tabManager.activeTab {
                        container.tabManager.updateTab(id: activeTab.id, title: title)
                    }
                },
                onURLChange: { url in
                    viewModel.handleURLChange(url)
                    if let activeTab = container.tabManager.activeTab, let url {
                        container.tabManager.updateTab(id: activeTab.id, url: url)
                    }
                },
                onLoadingChange: { loading in
                    viewModel.handleLoadingChange(loading)
                    if !loading {
                        viewModel.checkReadability(using: container.readerModeService)
                    }
                },
                onProgressChange: { viewModel.handleProgressChange($0) },
                onNavigationChange: { back, fwd in
                    viewModel.handleNavigationChange(canGoBack: back, canGoForward: fwd)
                },
                onError: { viewModel.handleError($0) },
                onScrollDirectionChange: { viewModel.handleScroll(isScrollingDown: $0) },
                onWebViewCreated: { viewModel.webView = $0 },
                onDownloadLink: { url in
                    Task { await container.downloadManager.startDownload(url: url) }
                    HapticManager.medium()
                },
                onOpenInNewTab: { url in
                    if container.tabManager.tabCount >= TabManager.maxTabs {
                        showTabLimitAlert = true
                        HapticManager.warning()
                    } else {
                        container.tabManager.createTab(url: url)
                        HapticManager.light()
                    }
                },
                onAdBlocked: { count in
                    viewModel.adsBlockedCount = count
                },
                onFaviconDetected: { faviconURL in
                    if let activeTab = container.tabManager.activeTab {
                        container.tabManager.updateTab(id: activeTab.id, faviconURL: faviconURL)
                    }
                },
                httpsUpgradeURL: { url in
                    container.httpsUpgradeService.upgradeURL(url)
                },
                cleanTrackingParams: { url in
                    container.trackingProtectionService.cleanURL(url)
                },
                fingerprintProtectionScript: container.fingerprintProtectionService.makeUserScript(),
                onShareURL: { url in
                    coordinator.shareURL = url
                    coordinator.showShareSheet = true
                },
                onAddToReadingList: { url, title in
                    let item = ReadingListItem(url: url, title: title)
                    Task {
                        try? await container.readingListRepository.save(item)
                        HapticManager.success()
                    }
                },
                onOpenInPrivateTab: { url in
                    if container.tabManager.tabCount < TabManager.maxTabs {
                        container.tabManager.createTab(url: url, isPrivate: true)
                        HapticManager.light()
                    } else {
                        showTabLimitAlert = true
                        HapticManager.warning()
                    }
                },
                onFullscreenChange: { fullscreen in
                    viewModel.handleFullscreenChange(fullscreen)
                }
            )

            // New Tab Page overlay (when no URL loaded)
            if viewModel.currentURL == nil && viewModel.pendingURL == nil {
                NewTabPageView(
                    bookmarkRepository: container.bookmarkRepository,
                    onSearch: { query in
                        viewModel.addressBarText = query
                        viewModel.submitAddressBar()
                    },
                    onOpenURL: { url in
                        viewModel.loadURL(url)
                    }
                )
                .transition(.opacity)
            }

            // Offline overlay
            if !container.networkMonitor.isConnected && viewModel.currentURL == nil {
                offlineOverlay
            }

            // Error overlay
            if let errorMessage = viewModel.errorMessage {
                errorOverlay(message: errorMessage)
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            // Back — long-press shows history
            Menu {
                // Long-press shows back list
                ForEach(viewModel.backList) { item in
                    Button {
                        viewModel.goToBackForwardItem(url: item.url)
                    } label: {
                        Text(item.title)
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundStyle(
                        viewModel.canGoBack ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary
                    )
                    .frame(minWidth: DesignSystem.minimumTouchTarget,
                           minHeight: DesignSystem.minimumTouchTarget)
                    .contentShape(Rectangle())
            } primaryAction: {
                viewModel.goBack()
            }
            .disabled(!viewModel.canGoBack)
            .accessibilityLabel("Back")

            Spacer()

            // Forward
            toolbarButton(icon: "chevron.right", label: "Forward", disabled: !viewModel.canGoForward) {
                viewModel.goForward()
            }

            Spacer()

            // Share
            toolbarButton(
                icon: "square.and.arrow.up",
                label: "Share",
                disabled: viewModel.currentURL == nil
            ) {
                coordinator.showShareSheet = true
            }

            Spacer()

            // Tabs
            Button(action: onShowTabSwitcher) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(DesignSystem.Colors.textPrimary, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    Text("\(min(tabCount, 99))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                .frame(minWidth: DesignSystem.minimumTouchTarget,
                       minHeight: DesignSystem.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(tabCount) tabs")

            Spacer()

            // More menu
            moreMenu
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            DesignSystem.Colors.backgroundPrimary
                .shadow(.drop(color: .black.opacity(0.1), radius: 4, y: -2))
        )
    }

    // MARK: - More Menu

    private var moreMenu: some View {
        Menu {
            // New Tab
            Button {
                if container.tabManager.tabCount < TabManager.maxTabs {
                    container.tabManager.createTab(url: nil, isPrivate: false)
                    HapticManager.light()
                } else {
                    showTabLimitAlert = true
                    HapticManager.warning()
                }
            } label: {
                Label("New Tab", systemImage: "plus")
            }

            // Home — navigate current tab back to the start page
            Button {
                viewModel.goHome()
                if let activeTab = container.tabManager.activeTab {
                    container.tabManager.resetTabToHome(id: activeTab.id)
                }
                HapticManager.light()
            } label: {
                Label("Home", systemImage: "house")
            }

            Button {
                viewModel.reload()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }

            if viewModel.currentURL != nil {
                Button {
                    addBookmark()
                } label: {
                    Label("Add Bookmark", systemImage: "star")
                }

                Button {
                    Task {
                        guard let webView = viewModel.webView else { return }
                        let found = await container.mediaPlayerService.extractAndPlay(
                            from: webView,
                            pageTitle: viewModel.pageTitle,
                            pageURL: viewModel.currentURL
                        )
                        if found {
                            HapticManager.success()
                        } else {
                            showNoMediaAlert = true
                            HapticManager.warning()
                        }
                    }
                } label: {
                    Label("Play in Background", systemImage: "play.circle")
                }

                Button {
                    withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
                        showFindInPage = true
                    }
                } label: {
                    Label("Find on Page", systemImage: "doc.text.magnifyingglass")
                }

                // Desktop mode toggle
                Button {
                    viewModel.toggleDesktopMode()
                    HapticManager.light()
                } label: {
                    Label(
                        viewModel.isDesktopMode ? "Request Mobile Site" : "Request Desktop Site",
                        systemImage: viewModel.isDesktopMode ? "iphone" : "desktopcomputer"
                    )
                }

                // Reader mode (only if page is readable)
                if viewModel.isPageReadable {
                    Button {
                        viewModel.toggleReaderMode(using: container.readerModeService)
                    } label: {
                        Label("Reader Mode", systemImage: "doc.plaintext")
                    }
                }
            }

            Divider()

            Button {
                coordinator.navigate(to: .bookmarks)
            } label: {
                Label("Bookmarks", systemImage: "book")
            }

            Button {
                coordinator.navigate(to: .history)
            } label: {
                Label("History", systemImage: "clock")
            }

            Button {
                coordinator.navigate(to: .downloads)
            } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }

            Button {
                coordinator.showReadingList = true
            } label: {
                Label("Reading List", systemImage: "eyeglasses")
            }

            // Add current page to reading list
            if viewModel.currentURL != nil {
                Button {
                    addToReadingList()
                } label: {
                    Label("Add to Reading List", systemImage: "plus.circle")
                }
            }

            Divider()

            Button {
                coordinator.navigate(to: .settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(minWidth: DesignSystem.minimumTouchTarget,
                       minHeight: DesignSystem.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More options")
    }

    // MARK: - Helpers

    private func toolbarButton(
        icon: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(
                    disabled ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary
                )
                .frame(minWidth: DesignSystem.minimumTouchTarget,
                       minHeight: DesignSystem.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .disabled(disabled)
        .hoverEffect(.highlight)
        .accessibilityLabel(label)
    }

    private func addBookmark() {
        guard let url = viewModel.currentURL else { return }
        let title = viewModel.pageTitle.isEmpty ? (url.host() ?? url.absoluteString) : viewModel.pageTitle
        let faviconURL: URL? = {
            if let activeTab = container.tabManager.activeTab {
                return activeTab.faviconURL
            }
            return nil
        }()
        let bookmark = Bookmark(url: url, title: title, faviconURL: faviconURL)
        Task {
            try? await container.bookmarkRepository.save(bookmark)
            HapticManager.success()
        }
    }

    private func addToReadingList() {
        guard let url = viewModel.currentURL else { return }
        let title = viewModel.pageTitle.isEmpty ? (url.host() ?? url.absoluteString) : viewModel.pageTitle
        let item = ReadingListItem(url: url, title: title)
        Task {
            try? await container.readingListRepository.save(item)
            HapticManager.success()
        }
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.Colors.warning)

            Text("Failed to Load Page")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.errorMessage = nil
                viewModel.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
    }

    private var offlineOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Internet Connection")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Check your connection and try again.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Button("Try Again") {
                viewModel.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}
