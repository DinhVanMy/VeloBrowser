// AdBlockService.swift
// VeloBrowser
//
// Ad blocking engine using WKContentRuleListStore and WKUserScript.

import WebKit
import os.log

/// Protocol for ad blocking operations.
@MainActor
protocol AdBlockServiceProtocol {
    /// Whether ad blocking is globally enabled.
    var isEnabled: Bool { get set }

    /// The set of allowlisted domains where ads are allowed.
    var allowlist: Set<String> { get }

    /// Compiles ad block rules. Call once at app launch.
    func compileRules() async

    /// Returns the compiled content rule list, if available.
    func contentRuleList() -> WKContentRuleList?

    /// Returns a user script for cosmetic ad filtering.
    func cosmeticFilterScript() -> WKUserScript

    /// Adds a domain to the allowlist.
    func addToAllowlist(_ domain: String)

    /// Removes a domain from the allowlist.
    func removeFromAllowlist(_ domain: String)

    /// Checks if a domain is allowlisted.
    func isAllowlisted(_ domain: String) -> Bool
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
    private(set) var allowlist: Set<String>

    /// Total number of ads blocked across all sessions.
    var totalAdsBlocked: Int {
        get { UserDefaults.standard.integer(forKey: "totalAdsBlocked") }
        set { UserDefaults.standard.set(newValue, forKey: "totalAdsBlocked") }
    }

    /// Whether ad block rule compilation has failed.
    var compilationFailed: Bool = false

    /// The compiled content rule list for network blocking.
    private var compiledRuleList: WKContentRuleList?

    // MARK: - Init

    /// Creates a new AdBlockService, loading persisted state.
    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "adBlockEnabled") as? Bool ?? true
        let saved = UserDefaults.standard.stringArray(forKey: "adBlockAllowlist") ?? []
        self.allowlist = Set(saved)
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
            compilationFailed = false
        } catch {
            compiledRuleList = nil
            compilationFailed = true
            os_log(.error, "Ad block rule compilation failed: %{public}@", error.localizedDescription)
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

    // MARK: - Allowlist

    /// Adds a domain to the ad-block allowlist.
    ///
    /// - Parameter domain: The domain to allowlist (e.g., "example.com").
    func addToAllowlist(_ domain: String) {
        allowlist.insert(domain.lowercased())
        persistAllowlist()
    }

    /// Removes a domain from the allowlist.
    ///
    /// - Parameter domain: The domain to remove.
    func removeFromAllowlist(_ domain: String) {
        allowlist.remove(domain.lowercased())
        persistAllowlist()
    }

    /// Checks whether a domain is allowlisted.
    ///
    /// - Parameter domain: The domain to check.
    /// - Returns: `true` if the domain is allowlisted.
    func isAllowlisted(_ domain: String) -> Bool {
        allowlist.contains(domain.lowercased())
    }

    // MARK: - Private

    private func persistAllowlist() {
        UserDefaults.standard.set(Array(allowlist), forKey: "adBlockAllowlist")
    }

    /// Generates WebKit content blocker JSON rules.
    ///
    /// Loads rules from the bundled adblock-rules.json file which contains
    /// 200+ rules covering major ad networks, trackers, analytics, and
    /// social media pixels. Falls back to a minimal set if the file is missing.
    private static func generateBlockingRules() -> String {
        // Try loading from bundled JSON first
        if let url = Bundle.main.url(forResource: "adblock-rules", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Re-serialize to ensure valid JSON string
            if let serialized = try? JSONSerialization.data(withJSONObject: json),
               let str = String(data: serialized, encoding: .utf8) {
                os_log(.info, "Loaded %d ad block rules from bundle", json.count)
                return str
            }
        }

        // Fallback to hardcoded rules
        os_log(.error, "Failed to load bundled ad block rules, using fallback")
        let rules = fallbackRules
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// Minimal fallback rules if bundled JSON fails to load.
    private static var fallbackRules: [[String: Any]] {
        [
            blockRule(".*\\.doubleclick\\.net"),
            blockRule(".*\\.googlesyndication\\.com"),
            blockRule(".*\\.googleadservices\\.com"),
            blockRule(".*\\.google-analytics\\.com"),
            blockRule(".*\\.adnxs\\.com"),
            blockRule(".*\\.criteo\\.com"),
            blockRule(".*\\.outbrain\\.com"),
            blockRule(".*\\.taboola\\.com"),
            blockRule(".*\\.facebook\\.com/tr"),
            blockRule(".*\\.youtube\\.com/api/stats/ads"),
            blockRule(".*\\.youtube\\.com/pagead"),
        ]
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
