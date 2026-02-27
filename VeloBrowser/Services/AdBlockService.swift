// AdBlockService.swift
// VeloBrowser
//
// Ad blocking engine using WKContentRuleListStore and WKUserScript.

import WebKit

/// Protocol for ad blocking operations.
@MainActor
protocol AdBlockServiceProtocol {
    /// Whether ad blocking is globally enabled.
    var isEnabled: Bool { get set }

    /// The set of whitelisted domains where ads are allowed.
    var whitelist: Set<String> { get }

    /// Compiles ad block rules. Call once at app launch.
    func compileRules() async

    /// Returns the compiled content rule list, if available.
    func contentRuleList() -> WKContentRuleList?

    /// Returns a user script for cosmetic ad filtering.
    func cosmeticFilterScript() -> WKUserScript

    /// Adds a domain to the whitelist.
    func addToWhitelist(_ domain: String)

    /// Removes a domain from the whitelist.
    func removeFromWhitelist(_ domain: String)

    /// Checks if a domain is whitelisted.
    func isWhitelisted(_ domain: String) -> Bool
}

/// Ad blocking service using WebKit content rules.
///
/// Compiles a simplified EasyList-style rule set into
/// `WKContentRuleList` for network-level blocking, and
/// provides a `WKUserScript` for cosmetic filtering
/// (hiding ad elements via CSS injection).
@Observable
@MainActor
final class AdBlockService: AdBlockServiceProtocol {
    /// Whether ad blocking is enabled.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "adBlockEnabled")
        }
    }

    /// Domains where ad blocking is disabled.
    private(set) var whitelist: Set<String>

    /// The compiled content rule list for network blocking.
    private var compiledRuleList: WKContentRuleList?

    // MARK: - Init

    /// Creates a new AdBlockService, loading persisted state.
    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "adBlockEnabled") as? Bool ?? true
        let saved = UserDefaults.standard.stringArray(forKey: "adBlockWhitelist") ?? []
        self.whitelist = Set(saved)
    }

    // MARK: - Rule Compilation

    /// Compiles content blocking rules from the embedded rule set.
    ///
    /// This should be called once during app initialization.
    /// The compilation is asynchronous and stores the result
    /// for later use by ``contentRuleList()``.
    func compileRules() async {
        guard isEnabled else { return }

        let rules = Self.generateBlockingRules()

        do {
            let ruleList = try await WKContentRuleListStore.default()
                .compileContentRuleList(
                    forIdentifier: "VeloBrowserAdBlock",
                    encodedContentRuleList: rules
                )
            compiledRuleList = ruleList
        } catch {
            // Compilation failed — ad blocking won't work but app continues
            compiledRuleList = nil
        }
    }

    /// Returns the compiled content rule list, or `nil` if not ready or disabled.
    func contentRuleList() -> WKContentRuleList? {
        guard isEnabled else { return nil }
        return compiledRuleList
    }

    /// Returns a user script that hides common ad elements via CSS.
    ///
    /// This script runs at document end and injects CSS rules
    /// to hide known ad containers. It complements the network-level
    /// blocking done by ``contentRuleList()``.
    func cosmeticFilterScript() -> WKUserScript {
        let css = Self.cosmeticFilterCSS
        let js = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);
        })();
        """

        return WKUserScript(
            source: js,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }

    // MARK: - Whitelist

    /// Adds a domain to the ad-block whitelist.
    ///
    /// - Parameter domain: The domain to whitelist (e.g., "example.com").
    func addToWhitelist(_ domain: String) {
        whitelist.insert(domain.lowercased())
        persistWhitelist()
    }

    /// Removes a domain from the whitelist.
    ///
    /// - Parameter domain: The domain to remove.
    func removeFromWhitelist(_ domain: String) {
        whitelist.remove(domain.lowercased())
        persistWhitelist()
    }

    /// Checks whether a domain is whitelisted.
    ///
    /// - Parameter domain: The domain to check.
    /// - Returns: `true` if the domain is whitelisted.
    func isWhitelisted(_ domain: String) -> Bool {
        whitelist.contains(domain.lowercased())
    }

    // MARK: - Private

    private func persistWhitelist() {
        UserDefaults.standard.set(Array(whitelist), forKey: "adBlockWhitelist")
    }

    /// Generates WebKit content blocker JSON rules.
    ///
    /// These rules block common ad network URLs, tracking scripts,
    /// third-party ad frames, and YouTube-specific ad content.
    /// The format follows WebKit's Content Blocker specification.
    private static func generateBlockingRules() -> String {
        let rules: [[String: Any]] = [
            // --- Major Ad Networks ---
            blockRule(".*\\.doubleclick\\.net"),
            blockRule(".*\\.googlesyndication\\.com"),
            blockRule(".*\\.googleadservices\\.com"),
            blockRule(".*\\.google-analytics\\.com"),
            blockRule(".*\\.adnxs\\.com"),
            blockRule(".*\\.adsrvr\\.org"),
            blockRule(".*\\.amazon-adsystem\\.com"),
            blockRule(".*\\.moatads\\.com"),
            blockRule(".*\\.rubiconproject\\.com"),
            blockRule(".*\\.criteo\\.com"),
            blockRule(".*\\.outbrain\\.com"),
            blockRule(".*\\.taboola\\.com"),
            blockRule(".*\\.pubmatic\\.com"),
            blockRule(".*\\.openx\\.net"),
            blockRule(".*\\.casalemedia\\.com"),
            blockRule(".*\\.indexexchange\\.com"),
            blockRule(".*\\.bidswitch\\.net"),
            blockRule(".*\\.smartadserver\\.com"),
            blockRule(".*\\.adform\\.net"),
            blockRule(".*\\.33across\\.com"),
            blockRule(".*\\.sharethrough\\.com"),
            blockRule(".*\\.triplelift\\.com"),
            blockRule(".*\\.media\\.net"),
            blockRule(".*\\.revcontent\\.com"),
            blockRule(".*\\.mgid\\.com"),
            blockRule(".*\\.zergnet\\.com"),
            blockRule(".*\\.adblade\\.com"),
            blockRule(".*\\.adcolony\\.com"),
            blockRule(".*\\.inmobi\\.com"),
            blockRule(".*\\.unityads\\.unity3d\\.com"),
            blockRule(".*\\.chartboost\\.com"),
            // --- Trackers ---
            blockRule(".*\\.facebook\\.com/tr"),
            blockRule(".*\\.scorecardresearch\\.com"),
            blockRule(".*\\.quantserve\\.com"),
            blockRule(".*\\.segment\\.io"),
            blockRule(".*\\.segment\\.com"),
            blockRule(".*\\.hotjar\\.com"),
            blockRule(".*\\.mixpanel\\.com"),
            blockRule(".*\\.amplitude\\.com"),
            blockRule(".*\\.optimizely\\.com"),
            blockRule(".*\\.crazyegg\\.com"),
            blockRule(".*\\.newrelic\\.com.*bam"),
            blockRule(".*\\.doubleclick\\.com"),
            blockRule(".*\\.adsafeprotected\\.com"),
            blockRule(".*\\.demdex\\.net"),
            blockRule(".*\\.omtrdc\\.net"),
            blockRule(".*\\.everesttech\\.net"),
            // --- YouTube Ads ---
            blockRule(".*\\.youtube\\.com/api/stats/ads"),
            blockRule(".*\\.youtube\\.com/pagead"),
            blockRule(".*\\.youtube\\.com/ptracking"),
            blockRule(".*\\.youtube\\.com/get_midroll"),
            blockRule(".*googlevideo\\.com/videoplayback.*ctier=L"),
            blockRule(".*\\.youtube\\.com/api/stats/qoe.*ads"),
            // --- Ad script patterns ---
            blockRule(".*/ads\\.js"),
            blockRule(".*/ad[s]?[_-]?banner"),
            blockRule(".*/prebid"),
            blockRule(".*/gpt\\.js"),
            blockRule(".*/adsbygoogle\\.js"),
            // --- Tracking pixels ---
            [
                "trigger": [
                    "url-filter": ".*",
                    "resource-type": ["image"],
                    "if-domain": ["*tracking*", "*pixel*", "*beacon*"]
                ] as [String: Any],
                "action": ["type": "block"]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// Helper to create a simple block rule.
    private static func blockRule(_ urlFilter: String) -> [String: Any] {
        [
            "trigger": ["url-filter": urlFilter],
            "action": ["type": "block"]
        ]
    }

    /// CSS rules to hide common ad containers and YouTube ad overlays.
    private static let cosmeticFilterCSS = """
        [class*="ad-banner"],
        [class*="ad_banner"],
        [class*="adsbygoogle"],
        [id*="google_ads"],
        [id*="ad-container"],
        [id*="ad_container"],
        [class*="sponsored-content"],
        [class*="sponsored_content"],
        .ad-slot,
        .ad-wrapper,
        .advertisement,
        .ad-placement,
        iframe[src*="doubleclick"],
        iframe[src*="googlesyndication"],
        .ytp-ad-module,
        .ytp-ad-overlay-container,
        .ytp-ad-text-overlay,
        .ytd-promoted-sparkles-web-renderer,
        .ytd-display-ad-renderer,
        .ytd-promoted-video-renderer,
        .ytd-companion-slot-renderer,
        .ytd-action-companion-ad-renderer,
        .ytd-in-feed-ad-layout-renderer,
        .ytd-banner-promo-renderer,
        .ytd-statement-banner-renderer,
        .ytd-ad-slot-renderer,
        #player-ads,
        #masthead-ad,
        .video-ads {
            display: none !important;
            height: 0 !important;
            min-height: 0 !important;
            max-height: 0 !important;
            overflow: hidden !important;
        }
    """
}
