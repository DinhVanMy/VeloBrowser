// WebViewContainer.swift
// VeloBrowser
//
// UIViewRepresentable wrapping WKWebView for use in SwiftUI.

import SwiftUI
import WebKit

/// A SwiftUI view that wraps a `WKWebView` for displaying web content.
///
/// Supports URL loading, imperative navigation commands (via token signals),
/// KVO observation for state changes, scroll direction detection, and
/// ad-block counting via WKScriptMessageHandler.
/// Designed to be driven by ``BrowserViewModel``.
struct WebViewContainer: UIViewRepresentable {
    /// The URL to load in the web view.
    var url: URL?

    /// The WKWebViewConfiguration to use (allows ad-block rules injection).
    var configuration: WKWebViewConfiguration?

    /// Whether this web view is for private browsing (uses non-persistent data store).
    var isPrivate: Bool = false

    /// Whether JavaScript should be enabled in web pages.
    var javaScriptEnabled: Bool = true

    /// Whether ad blocking is active for the current domain.
    var adBlockEnabled: Bool = true

    /// Token incremented to trigger reload.
    var reloadToken: Int = 0

    /// Token incremented to trigger stop loading.
    var stopToken: Int = 0

    /// Token incremented to trigger go back.
    var goBackToken: Int = 0

    /// Token incremented to trigger go forward.
    var goForwardToken: Int = 0

    /// Whether desktop user-agent is active.
    var isDesktopMode: Bool = false

    /// Token incremented to signal user-agent change.
    var desktopModeToken: Int = 0

    /// Callback invoked when the page title changes.
    var onTitleChange: ((String) -> Void)?

    /// Callback invoked when the URL changes during navigation.
    var onURLChange: ((URL?) -> Void)?

    /// Callback invoked when the page starts or finishes loading.
    var onLoadingChange: ((Bool) -> Void)?

    /// Callback invoked when estimated progress changes (0.0 to 1.0).
    var onProgressChange: ((Double) -> Void)?

    /// Callback invoked when back/forward capability changes.
    var onNavigationChange: ((_ canGoBack: Bool, _ canGoForward: Bool) -> Void)?

    /// Callback invoked when navigation fails.
    var onError: ((Error) -> Void)?

    /// Callback invoked with scroll direction changes.
    var onScrollDirectionChange: ((_ isScrollingDown: Bool) -> Void)?

    /// Callback invoked when the WKWebView instance is created.
    var onWebViewCreated: ((WKWebView) -> Void)?

    /// Callback invoked when the user long-presses a link and selects download.
    var onDownloadLink: ((URL) -> Void)?

    /// Callback invoked when the user long-presses a link and selects open in new tab.
    var onOpenInNewTab: ((URL) -> Void)?

    /// Callback invoked when an ad is blocked (increments count).
    var onAdBlocked: ((Int) -> Void)?

    /// Callback invoked when a favicon URL is detected on the page.
    var onFaviconDetected: ((URL) -> Void)?

    /// Callback to attempt HTTPS upgrade for a URL. Returns upgraded URL or nil.
    var httpsUpgradeURL: ((URL) -> URL?)?

    /// Callback to clean tracking parameters from a URL. Returns (cleanedURL, removedCount) or nil.
    var cleanTrackingParams: ((URL) -> (url: URL, removedCount: Int)?)?

    /// Optional fingerprint protection user script.
    var fingerprintProtectionScript: WKUserScript?

    /// Callback to share a URL.
    var onShareURL: ((URL) -> Void)?

    /// Callback to add a URL to the reading list.
    var onAddToReadingList: ((URL, String) -> Void)?

    /// Callback to open a URL in a private tab.
    var onOpenInPrivateTab: ((URL) -> Void)?

    /// Callback invoked when fullscreen state changes.
    var onFullscreenChange: ((Bool) -> Void)?

    /// An existing WKWebView to reuse (from the WebView pool). Avoids reload on tab switch.
    var existingWebView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        // Reuse pooled webview if available (tab switch back)
        if let existingWebView {
            let controller = existingWebView.configuration.userContentController
            // Remove old handlers (pointing to previous Coordinator) and re-add with new one
            for name in ["adBlockCounter", "faviconDetected", "fullscreenChange"] {
                controller.removeScriptMessageHandler(forName: name)
            }
            controller.add(context.coordinator, name: "adBlockCounter")
            controller.add(context.coordinator, name: "faviconDetected")
            controller.add(context.coordinator, name: "fullscreenChange")

            existingWebView.navigationDelegate = context.coordinator
            existingWebView.scrollView.delegate = context.coordinator
            existingWebView.uiDelegate = context.coordinator

            context.coordinator.webView = existingWebView
            // Set lastLoadedURL to pendingURL so updateUIView won't trigger a spurious reload
            context.coordinator.lastLoadedURL = url
            context.coordinator.setupObservers()
            onWebViewCreated?(existingWebView)
            return existingWebView
        }

        // Create new webview
        let config = prepareConfiguration()
        injectUserScripts(into: config)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Register script message handlers
        config.userContentController.add(context.coordinator, name: "adBlockCounter")
        config.userContentController.add(context.coordinator, name: "faviconDetected")
        config.userContentController.add(context.coordinator, name: "fullscreenChange")

        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleRefresh(_:)),
            for: .valueChanged
        )
        webView.scrollView.refreshControl = refreshControl

        #if DEBUG
        webView.isInspectable = true
        #endif

        context.coordinator.webView = webView
        context.coordinator.setupObservers()
        onWebViewCreated?(webView)

        if let url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    /// Prepares the WKWebViewConfiguration with media, privacy, and cookie settings.
    private func prepareConfiguration() -> WKWebViewConfiguration {
        let config = configuration ?? {
            let cfg = WKWebViewConfiguration()
            cfg.allowsInlineMediaPlayback = true
            cfg.mediaTypesRequiringUserActionForPlayback = []
            cfg.allowsPictureInPictureMediaPlayback = true
            return cfg
        }()

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.suppressesIncrementalRendering = false
        config.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled

        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }

        let blockCookies = UserDefaults.standard.bool(forKey: "blockThirdPartyCookies")
        if blockCookies {
            config.websiteDataStore.httpCookieStore.setCookiePolicy(.allow) { }
        }

        return config
    }

    /// Injects all required user scripts into the configuration's content controller.
    private func injectUserScripts(into config: WKWebViewConfiguration) {
        let controller = config.userContentController

        controller.addUserScript(WKUserScript(
            source: Self.backgroundAudioJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        controller.addUserScript(WKUserScript(
            source: Self.adBlockCounterJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: Self.faviconExtractionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        if let fpScript = fingerprintProtectionScript {
            controller.addUserScript(fpScript)
        }
        controller.addUserScript(WKUserScript(
            source: Self.fullscreenDetectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: Self.lazyImageLoadingJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coord = context.coordinator

        // Update JavaScript preference if changed
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled

        // Load new URL if changed
        if let url, url != coord.lastLoadedURL {
            coord.lastLoadedURL = url
            webView.load(URLRequest(url: url))
        }

        // Process imperative commands via token comparison
        if reloadToken != coord.lastReloadToken {
            coord.lastReloadToken = reloadToken
            webView.reload()
        }
        if stopToken != coord.lastStopToken {
            coord.lastStopToken = stopToken
            webView.stopLoading()
        }
        if goBackToken != coord.lastGoBackToken {
            coord.lastGoBackToken = goBackToken
            if webView.canGoBack { webView.goBack() }
        }
        if goForwardToken != coord.lastGoForwardToken {
            coord.lastGoForwardToken = goForwardToken
            if webView.canGoForward { webView.goForward() }
        }

        // Desktop mode user-agent switch
        if desktopModeToken != coord.lastDesktopModeToken {
            coord.lastDesktopModeToken = desktopModeToken
            webView.customUserAgent = isDesktopMode ? Self.desktopUserAgent : nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Desktop Safari user-agent string for "Request Desktop Site".
    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// JavaScript that adds `loading="lazy"` to below-fold images.
    private static let lazyImageLoadingJS = """
    (function() {
        var images = document.querySelectorAll('img:not([loading])');
        var viewH = window.innerHeight || document.documentElement.clientHeight;
        images.forEach(function(img) {
            var rect = img.getBoundingClientRect();
            if (rect.top > viewH * 1.5) {
                img.setAttribute('loading', 'lazy');
            }
        });
    })();
    """

    /// JavaScript injected at documentStart to prevent sites (YouTube, etc.)
    /// from pausing media when the app enters background.
    ///
    /// Overrides `document.hidden` and `document.visibilityState` to always
    /// report "visible", and blocks `visibilitychange` events from reaching
    /// site scripts. This allows WKWebView audio to continue playing via
    /// the background audio session.
    private static let backgroundAudioJS = """
    (function() {
        // Override visibility API so sites think the page is always visible
        Object.defineProperty(document, 'hidden', {
            get: function() { return false; },
            configurable: false
        });
        Object.defineProperty(document, 'visibilityState', {
            get: function() { return 'visible'; },
            configurable: false
        });
        Object.defineProperty(document, 'webkitHidden', {
            get: function() { return false; },
            configurable: false
        });

        // Intercept and block visibilitychange events from reaching site scripts
        document.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);
        document.addEventListener('webkitvisibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);

        // Override hasFocus to always return true
        document.hasFocus = function() { return true; };
    })();
    """

    /// JavaScript that counts hidden ad elements and reports to native code.
    private static let adBlockCounterJS = """
    (function() {
        var selectors = [
            '[class*="ad-banner"]', '[class*="ad_banner"]', '[class*="adsbygoogle"]',
            '[id*="google_ads"]', '[id*="ad-container"]', '[id*="ad_container"]',
            '[class*="sponsored-content"]', '[class*="sponsored_content"]',
            '.ad-slot', '.ad-wrapper', '.advertisement', '.ad-placement',
            'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]'
        ];
        var count = 0;
        selectors.forEach(function(s) {
            try { count += document.querySelectorAll(s).length; } catch(e) {}
        });
        if (count > 0) {
            window.webkit.messageHandlers.adBlockCounter.postMessage(count);
        }
    })();
    """

    /// JavaScript that extracts the page favicon URL.
    private static let faviconExtractionJS = """
    (function() {
        var icon = document.querySelector('link[rel~="icon"]') ||
                   document.querySelector('link[rel="shortcut icon"]') ||
                   document.querySelector('link[rel="apple-touch-icon"]');
        if (icon && icon.href) {
            window.webkit.messageHandlers.faviconDetected.postMessage(icon.href);
        } else {
            var origin = window.location.origin;
            if (origin && origin !== 'null') {
                window.webkit.messageHandlers.faviconDetected.postMessage(origin + '/favicon.ico');
            }
        }
    })();
    """

    /// JavaScript that detects fullscreen video changes.
    private static let fullscreenDetectionJS = """
    (function() {
        function onFSChange() {
            var isFS = !!(document.fullscreenElement || document.webkitFullscreenElement);
            window.webkit.messageHandlers.fullscreenChange.postMessage(isFS);
        }
        document.addEventListener('fullscreenchange', onFSChange);
        document.addEventListener('webkitfullscreenchange', onFSChange);
    })();
    """

    // MARK: - Coordinator

    /// Coordinator acting as WKNavigationDelegate, UIScrollViewDelegate, WKUIDelegate,
    /// WKScriptMessageHandler, and KVO observer.
    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate,
                             WKUIDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        weak var webView: WKWebView?

        // Token tracking for imperative commands
        var lastLoadedURL: URL?
        var lastReloadToken: Int = 0
        var lastStopToken: Int = 0
        var lastGoBackToken: Int = 0
        var lastGoForwardToken: Int = 0
        var lastDesktopModeToken: Int = 0

        private var titleObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var progressObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var lastContentOffset: CGFloat = 0
        private var scrollThreshold: CGFloat = 10

        init(parent: WebViewContainer) {
            self.parent = parent
        }

        /// Sets up KVO observers for web view properties.
        func setupObservers() {
            guard let webView else { return }

            titleObservation = webView.observe(\.title, options: .new) { [weak self] _, change in
                guard let title = change.newValue ?? nil, !title.isEmpty else { return }
                Task { @MainActor in self?.parent.onTitleChange?(title) }
            }

            urlObservation = webView.observe(\.url, options: .new) { [weak self] _, change in
                let url = change.newValue ?? nil
                Task { @MainActor in self?.parent.onURLChange?(url) }
            }

            loadingObservation = webView.observe(\.isLoading, options: .new) { [weak self] wv, change in
                guard let isLoading = change.newValue else { return }
                Task { @MainActor in
                    self?.parent.onLoadingChange?(isLoading)
                    // End pull-to-refresh when loading completes
                    if !isLoading {
                        wv.scrollView.refreshControl?.endRefreshing()
                    }
                }
            }

            progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in self?.parent.onProgressChange?(progress) }
            }

            canGoBackObservation = webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.onNavigationChange?(wv.canGoBack, wv.canGoForward)
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.onNavigationChange?(wv.canGoBack, wv.canGoForward)
                }
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "adBlockCounter", let count = message.body as? Int {
                Task { @MainActor in
                    self.parent.onAdBlocked?(count)
                }
            } else if message.name == "faviconDetected", let urlString = message.body as? String,
                      let faviconURL = URL(string: urlString) {
                Task { @MainActor in
                    self.parent.onFaviconDetected?(faviconURL)
                }
            } else if message.name == "fullscreenChange", let isFullscreen = message.body as? Bool {
                Task { @MainActor in
                    self.parent.onFullscreenChange?(isFullscreen)
                }
            }
        }

        // MARK: - Pull-to-Refresh

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            // Refresh control will end in loading observer when isLoading becomes false
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            let scheme = url.scheme?.lowercased() ?? ""

            // Allow system-handled schemes (mailto, tel, sms) via UIApplication
            if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
                return .cancel
            }

            // Block all non-web schemes (itms-appss://, youtube://, twitter://, etc.)
            guard scheme == "http" || scheme == "https" || scheme == "about" || scheme == "blob" || scheme == "data" else {
                return .cancel
            }

            // HTTPS upgrade: redirect http → https
            if scheme == "http",
               let upgraded = parent.httpsUpgradeURL?(url) {
                Task { @MainActor in
                    webView.load(URLRequest(url: upgraded))
                }
                return .cancel
            }

            // Tracking parameter removal — only redirect if URL actually changed
            if scheme == "http" || scheme == "https",
               let cleaned = parent.cleanTrackingParams?(url),
               cleaned.url != url {
                Task { @MainActor in
                    webView.load(URLRequest(url: cleaned.url))
                }
                return .cancel
            }

            return .allow
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            Task { @MainActor in parent.onError?(error) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in parent.onError?(error) }
        }

        /// Handles web content process termination (crash recovery).
        ///
        /// iOS may terminate the web content process when the app is in background
        /// (e.g., FigApplicationStateMonitor err=-19431 from video rendering).
        /// Without this handler, the crash propagates to the main app process.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task { @MainActor in
                // Preserve current URL before reload for state restoration
                let currentURL = webView.url
                webView.reload()
                // If reload fails (no back-forward list), load the saved URL
                if webView.url == nil, let url = currentURL {
                    webView.load(URLRequest(url: url))
                }
            }
        }

        // MARK: - UIScrollViewDelegate

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let delta = currentOffset - lastContentOffset

            guard abs(delta) > scrollThreshold else { return }

            let isScrollingDown = delta > 0 && currentOffset > 0
            lastContentOffset = currentOffset

            Task { @MainActor in
                self.parent.onScrollDirectionChange?(isScrollingDown)
            }
        }

        // MARK: - WKUIDelegate

        /// Handle target="_blank" links by opening in a new tab or loading in current view.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
                if let url = navigationAction.request.url {
                    // Try to open in a new tab via callback; fall back to same view
                    if let openInNewTab = parent.onOpenInNewTab {
                        openInNewTab(url)
                    } else {
                        webView.load(URLRequest(url: url))
                    }
                }
            }
            return nil
        }

        // Context Menu
        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationFor elementInfo: WKContextMenuElementInfo
        ) async -> UIContextMenuConfiguration? {
            guard let linkURL = elementInfo.linkURL else {
                return nil
            }

            return UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: nil
            ) { [weak self] _ in
                guard let self else { return UIMenu(children: []) }
                return self.buildLinkContextMenu(for: linkURL)
            }
        }

        /// Builds the context menu for a long-pressed link.
        private func buildLinkContextMenu(for linkURL: URL) -> UIMenu {
            let openMenu = UIMenu(
                title: "", options: .displayInline,
                children: linkOpenActions(for: linkURL)
            )
            let actionsMenu = UIMenu(
                title: "", options: .displayInline,
                children: linkShareActions(for: linkURL)
            )
            let saveMenu = UIMenu(
                title: "", options: .displayInline,
                children: linkSaveActions(for: linkURL)
            )
            return UIMenu(children: [openMenu, actionsMenu, saveMenu])
        }

        private func linkOpenActions(for linkURL: URL) -> [UIAction] {
            [
                UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square")) { _ in
                    Task { @MainActor in self.parent.onOpenInNewTab?(linkURL); HapticManager.light() }
                },
                UIAction(title: "Open in Private Tab", image: UIImage(systemName: "eye.slash")) { _ in
                    Task { @MainActor in self.parent.onOpenInPrivateTab?(linkURL); HapticManager.light() }
                }
            ]
        }

        private func linkShareActions(for linkURL: URL) -> [UIAction] {
            [
                UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.url = linkURL; HapticManager.light()
                },
                UIAction(title: "Share…", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    Task { @MainActor in self.parent.onShareURL?(linkURL) }
                }
            ]
        }

        private func linkSaveActions(for linkURL: URL) -> [UIAction] {
            [
                UIAction(title: "Download Link", image: UIImage(systemName: "arrow.down.circle")) { _ in
                    Task { @MainActor in self.parent.onDownloadLink?(linkURL); HapticManager.medium() }
                },
                UIAction(title: "Add to Reading List", image: UIImage(systemName: "eyeglasses")) { _ in
                    Task { @MainActor in
                        let title = linkURL.host() ?? linkURL.absoluteString
                        self.parent.onAddToReadingList?(linkURL, title)
                        HapticManager.success()
                    }
                }
            ]
        }

        deinit {
            titleObservation?.invalidate()
            urlObservation?.invalidate()
            loadingObservation?.invalidate()
            progressObservation?.invalidate()
            canGoBackObservation?.invalidate()
            canGoForwardObservation?.invalidate()
            // Don't remove script message handlers here — the WKWebView may be
            // pooled for reuse. Handlers are re-wired in makeUIView on reuse,
            // and released automatically when the WKWebView is deallocated.
        }
    }
}
