// TrackingProtectionService.swift
// VeloBrowser
//
// Service for stripping tracking parameters from URLs.

import Foundation

/// Defines the contract for link tracking parameter removal.
///
/// Strips known tracking query parameters (UTM, Facebook, Google, etc.)
/// from URLs to improve user privacy.
@MainActor
protocol TrackingProtectionServiceProtocol: Sendable {
    /// Whether tracking protection is enabled.
    var isEnabled: Bool { get set }

    /// Total number of tracking parameters stripped across all sessions.
    var strippedCount: Int { get }

    /// Strips tracking parameters from a URL.
    ///
    /// - Parameter url: The URL to clean.
    /// - Returns: A tuple of (cleaned URL, number of params removed), or `nil` if no changes.
    func cleanURL(_ url: URL) -> (url: URL, removedCount: Int)?
}

/// Removes known tracking query parameters from URLs.
@Observable
@MainActor
final class TrackingProtectionService: TrackingProtectionServiceProtocol {
    /// Whether tracking parameter removal is active.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "trackingProtection") }
        set { UserDefaults.standard.set(newValue, forKey: "trackingProtection") }
    }

    /// Cumulative count of tracking parameters stripped.
    var strippedCount: Int {
        get { UserDefaults.standard.integer(forKey: "trackingStrippedCount") }
        set { UserDefaults.standard.set(newValue, forKey: "trackingStrippedCount") }
    }

    /// Known tracking parameter names to strip from URLs.
    private static let trackingParams: Set<String> = [
        // Facebook
        "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
        // Google
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        // UTM
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        // Microsoft
        "msclkid",
        // Twitter
        "twclid",
        // Others
        "mc_cid", "mc_eid", "_ga", "_gl", "igshid", "yclid",
        // Additional common trackers
        "ref", "ref_src", "ref_url", "s_cid", "zanpid", "otc",
    ]

    func cleanURL(_ url: URL) -> (url: URL, removedCount: Int)? {
        guard isEnabled else { return nil }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }

        let filtered = queryItems.filter { item in
            !Self.trackingParams.contains(item.name.lowercased())
        }

        let removedCount = queryItems.count - filtered.count
        guard removedCount > 0 else { return nil }

        components.queryItems = filtered.isEmpty ? nil : filtered

        guard let cleanedURL = components.url else { return nil }

        strippedCount += removedCount
        return (cleanedURL, removedCount)
    }
}
