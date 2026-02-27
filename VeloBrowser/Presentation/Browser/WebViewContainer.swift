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

    func makeUIView(context: Context) -> WKWebView {
        let config = configuration ?? {
            let cfg = WKWebViewConfiguration()
            cfg.allowsInlineMediaPlayback = true
            cfg.mediaTypesRequiringUserActionForPlayback = []
            cfg.allowsPictureInPictureMediaPlayback = true
            return cfg
        }()

        // Enable background media playback (keeps WKWebView audio alive when backgrounded)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        // JavaScript preference
        config.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled

        // Private browsing uses non-persistent data store
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }

        // Add ad-block counter script
        let counterScript = WKUserScript(
            source: Self.adBlockCounterJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(counterScript)

        // Add favicon extraction script
        let faviconScript = WKUserScript(
            source: Self.faviconExtractionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(faviconScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Register script message handlers
        config.userContentController.add(context.coordinator, name: "adBlockCounter")
        config.userContentController.add(context.coordinator, name: "faviconDetected")

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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

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

            loadingObservation = webView.observe(\.isLoading, options: .new) { [weak self] _, change in
                guard let isLoading = change.newValue else { return }
                Task { @MainActor in self?.parent.onLoadingChange?(isLoading) }
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
            }
        }

        // MARK: - Pull-to-Refresh

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.endRefreshing()
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            let scheme = url.scheme?.lowercased() ?? ""

            // Allow standard web schemes only — block external app deep links
            if scheme == "http" || scheme == "https" || scheme == "about" || scheme == "blob" || scheme == "data" {
                return .allow
            }

            // Allow system-handled schemes (mailto, tel, sms) via UIApplication
            if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
                return .cancel
            }

            // Block all other schemes (itms-appss://, youtube://, twitter://, etc.)
            return .cancel
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
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            guard let linkURL = elementInfo.linkURL else {
                completionHandler(nil)
                return
            }

            let config = UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: nil
            ) { [weak self] _ in
                var actions: [UIAction] = []

                let openAction = UIAction(
                    title: "Open in New Tab",
                    image: UIImage(systemName: "plus.square")
                ) { _ in
                    Task { @MainActor in
                        self?.parent.onOpenInNewTab?(linkURL)
                    }
                }
                actions.append(openAction)

                let copyAction = UIAction(
                    title: "Copy Link",
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    UIPasteboard.general.url = linkURL
                }
                actions.append(copyAction)

                let downloadAction = UIAction(
                    title: "Download Link",
                    image: UIImage(systemName: "arrow.down.circle")
                ) { _ in
                    Task { @MainActor in
                        self?.parent.onDownloadLink?(linkURL)
                    }
                }
                actions.append(downloadAction)

                return UIMenu(children: actions)
            }
            completionHandler(config)
        }

        deinit {
            titleObservation?.invalidate()
            urlObservation?.invalidate()
            loadingObservation?.invalidate()
            progressObservation?.invalidate()
            canGoBackObservation?.invalidate()
            canGoForwardObservation?.invalidate()
        }
    }
}
