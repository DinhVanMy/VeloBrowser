// BrowserViewModel.swift
// VeloBrowser
//
// ViewModel managing browser state and navigation logic.

import SwiftUI
import WebKit

/// View model managing the state and logic for the main browser view.
///
/// Handles URL loading, navigation (back/forward/reload), address bar
/// input validation, and search engine fallback. Communicates with
/// ``WebViewContainer`` through published state and action callbacks.
@Observable
@MainActor
final class BrowserViewModel {
    // MARK: - Published State

    /// The URL currently being displayed.
    var currentURL: URL?

    /// The page title of the current page.
    var pageTitle: String = ""

    /// The text shown in the address bar (editable by user).
    var addressBarText: String = ""

    /// Whether the web view is currently loading content.
    var isLoading: Bool = false

    /// Estimated loading progress from 0.0 to 1.0.
    var loadingProgress: Double = 0

    /// Whether the web view can navigate back.
    var canGoBack: Bool = false

    /// Whether the web view can navigate forward.
    var canGoForward: Bool = false

    /// Whether the address bar is currently focused for editing.
    var isAddressBarFocused: Bool = false

    /// Number of ads blocked on the current page.
    var adsBlockedCount: Int = 0

    /// Whether the address bar/toolbar should be visible.
    var isToolbarVisible: Bool = true

    /// Error message to display, if any.
    var errorMessage: String?

    /// Whether the current page is detected as readable (for reader mode button).
    var isPageReadable: Bool = false

    /// Whether reader mode is currently shown.
    var showReaderMode: Bool = false

    /// The extracted reader content (populated when reader mode activates).
    var readerContent: ReaderContent?

    /// Whether desktop user-agent is active for this tab.
    var isDesktopMode: Bool = false

    /// Incremented to signal a user-agent change requiring reload.
    var desktopModeToken: Int = 0

    /// Whether a video is currently in fullscreen mode.
    var isFullscreen: Bool = false

    /// Weak reference to the WKWebView for media extraction and JS evaluation.
    weak var webView: WKWebView?

    // MARK: - Navigation Command

    /// The pending URL to load in the WebView.
    /// WebViewContainer observes this to trigger loads.
    var pendingURL: URL?

    /// Incremented to signal a reload command.
    var reloadToken: Int = 0

    /// Incremented to signal a stop-loading command.
    var stopToken: Int = 0

    /// Incremented to signal go-back command.
    var goBackToken: Int = 0

    /// Incremented to signal go-forward command.
    var goForwardToken: Int = 0

    // MARK: - Dependencies

    private let historyRepository: HistoryRepositoryProtocol
    private let searchEngineTemplate: String

    /// Whether this view model is for a private browsing tab.
    let isPrivate: Bool

    // MARK: - Init

    /// Creates a new BrowserViewModel.
    ///
    /// - Parameters:
    ///   - historyRepository: Repository for recording browsing history.
    ///   - searchEngineTemplate: URL template for search queries (use `%@` as placeholder).
    ///   - isPrivate: Whether this is a private browsing tab (skips history recording).
    init(
        historyRepository: HistoryRepositoryProtocol,
        searchEngineTemplate: String = "https://www.google.com/search?q=%@",
        isPrivate: Bool = false
    ) {
        self.historyRepository = historyRepository
        self.searchEngineTemplate = searchEngineTemplate
        self.isPrivate = isPrivate
    }

    // MARK: - Actions

    /// Submits the address bar text — loads URL or performs search.
    func submitAddressBar() {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url = resolveInput(trimmed)
        pendingURL = url
        isAddressBarFocused = false
        errorMessage = nil
    }

    /// Loads a specific URL directly.
    ///
    /// - Parameter url: The URL to navigate to.
    func loadURL(_ url: URL) {
        pendingURL = url
        addressBarText = url.absoluteString
        errorMessage = nil
    }

    /// Navigates back in web history.
    func goBack() {
        goBackToken += 1
    }

    /// Navigates forward in web history.
    func goForward() {
        goForwardToken += 1
    }

    /// Reloads the current page.
    func reload() {
        reloadToken += 1
    }

    /// Stops the current page load.
    func stopLoading() {
        stopToken += 1
    }

    /// Navigates the current tab to the home (new tab) page.
    ///
    /// Clears the URL, title, and address bar to show the NewTabPageView.
    func goHome() {
        currentURL = nil
        pendingURL = nil
        pageTitle = ""
        addressBarText = ""
        isLoading = false
        loadingProgress = 0
        errorMessage = nil
        // Increment stop to halt any current load
        stopToken += 1
    }

    /// Toggles reader mode on the current page.
    ///
    /// - Parameter readerService: The reader mode service to extract content.
    func toggleReaderMode(using readerService: ReaderModeServiceProtocol) {
        if showReaderMode {
            showReaderMode = false
            readerContent = nil
        } else {
            guard let webView else { return }
            Task {
                if let content = await readerService.extractContent(from: webView) {
                    readerContent = content
                    showReaderMode = true
                }
            }
        }
    }

    /// Toggles desktop / mobile user-agent for this tab.
    func toggleDesktopMode() {
        isDesktopMode.toggle()
        desktopModeToken += 1
        // Reload automatically to apply the new UA
        reloadToken += 1
    }

    /// Checks page readability after load completes.
    ///
    /// - Parameter readerService: The reader mode service.
    func checkReadability(using readerService: ReaderModeServiceProtocol) {
        guard let webView else {
            isPageReadable = false
            return
        }
        Task {
            isPageReadable = await readerService.isReadable(from: webView)
        }
    }

    // MARK: - WebView Callbacks

    /// Called by WebViewContainer when the page title changes.
    func handleTitleChange(_ title: String) {
        pageTitle = title
    }

    /// Called by WebViewContainer when the URL changes.
    func handleURLChange(_ url: URL?) {
        currentURL = url
        if let url {
            addressBarText = url.absoluteString
        }
    }

    /// Called by WebViewContainer when loading state changes.
    func handleLoadingChange(_ loading: Bool) {
        isLoading = loading
        if !loading {
            recordHistory()
        }
    }

    /// Called by WebViewContainer when estimated progress changes.
    func handleProgressChange(_ progress: Double) {
        loadingProgress = progress
    }

    /// Called by WebViewContainer when navigation capabilities change.
    func handleNavigationChange(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }

    /// Called by WebViewContainer when navigation fails.
    func handleError(_ error: Error) {
        let nsError = error as NSError
        // Ignore cancelled navigations
        guard nsError.code != NSURLErrorCancelled else { return }
        errorMessage = error.localizedDescription
    }

    // MARK: - Toolbar Visibility

    /// Updates toolbar visibility based on scroll direction.
    ///
    /// - Parameter scrollingDown: Whether the user is scrolling down.
    func handleScroll(isScrollingDown: Bool) {
        withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
            isToolbarVisible = !isScrollingDown
        }
    }

    /// Ensures toolbar is visible (e.g., on tap).
    func showToolbar() {
        guard !isToolbarVisible else { return }
        withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
            isToolbarVisible = true
        }
    }

    // MARK: - Back/Forward List

    /// A simplified representation of a back/forward list item.
    struct BackForwardItem: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
    }

    /// Returns the back list from the WKWebView's backForwardList.
    var backList: [BackForwardItem] {
        guard let webView else { return [] }
        return webView.backForwardList.backList.reversed().map {
            BackForwardItem(url: $0.url, title: $0.title ?? $0.url.host() ?? $0.url.absoluteString)
        }
    }

    /// Navigates directly to a WKBackForwardList item by URL.
    func goToBackForwardItem(url: URL) {
        guard let webView else { return }
        if let item = webView.backForwardList.backList.first(where: { $0.url == url }) {
            webView.go(to: item)
        } else if let item = webView.backForwardList.forwardList.first(where: { $0.url == url }) {
            webView.go(to: item)
        }
    }

    // MARK: - Private

    /// Safe fallback URL for cases where URL construction fails.
    private static let blankURL: URL = {
        guard let url = URL(string: "about:blank") else {
            preconditionFailure("Static URL 'about:blank' must always be valid")
        }
        return url
    }()

    /// The domain-only string for display when address bar is not focused.
    var displayDomain: String {
        guard let currentURL, let host = currentURL.host() else { return "" }
        // Remove "www." prefix for cleaner display
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    /// Called by WebViewContainer when fullscreen state changes (video fullscreen).
    func handleFullscreenChange(_ fullscreen: Bool) {
        withAnimation(.easeInOut(duration: DesignSystem.AnimationDuration.fast)) {
            isFullscreen = fullscreen
            isToolbarVisible = !fullscreen
        }
    }

    /// Scrolls the WKWebView content to the top.
    func scrollToTop() {
        webView?.scrollView.setContentOffset(.zero, animated: true)
    }

    /// Resolves user input into a URL — either a direct URL or a search query.
    private func resolveInput(_ input: String) -> URL {
        // If it looks like a URL with scheme
        if let url = URL(string: input), let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return url
        }

        // If it looks like a domain (contains dot, no spaces)
        if input.contains(".") && !input.contains(" ") {
            let withScheme = "https://\(input)"
            if let url = URL(string: withScheme) {
                return url
            }
        }

        // Fallback: treat as search query
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        let searchURL = searchEngineTemplate.replacingOccurrences(of: "%@", with: encoded)
        return URL(string: searchURL) ?? Self.blankURL
    }

    /// Records the current page in browsing history.
    /// Skips recording for private browsing tabs.
    private func recordHistory() {
        guard !isPrivate, let url = currentURL else { return }
        let title = pageTitle.isEmpty ? url.absoluteString : pageTitle
        let entry = HistoryEntry(url: url, title: title)
        Task {
            try? await historyRepository.record(entry)
        }
    }
}
